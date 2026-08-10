#!/usr/bin/env python3
"""Serve local HLS files with runtime-adjustable network conditions."""

from __future__ import annotations

import argparse
import json
import os
import time
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Lock
from typing import BinaryIO


PROFILES = {
    "fast": {
        "title": "Fast Wi-Fi",
        "bits_per_second": None,
        "latency_seconds": 0.0,
        "offline": False,
    },
    "5mbps": {
        "title": "5 Mbps",
        "bits_per_second": 5_000_000,
        "latency_seconds": 0.0,
        "offline": False,
    },
    "2mbps": {
        "title": "2 Mbps",
        "bits_per_second": 2_000_000,
        "latency_seconds": 0.0,
        "offline": False,
    },
    "1.2mbps": {
        "title": "1.2 Mbps",
        "bits_per_second": 1_200_000,
        "latency_seconds": 0.0,
        "offline": False,
    },
    "800kbps": {
        "title": "800 Kbps",
        "bits_per_second": 800_000,
        "latency_seconds": 0.0,
        "offline": False,
    },
    "high-latency": {
        "title": "High latency",
        "bits_per_second": None,
        "latency_seconds": 1.5,
        "offline": False,
    },
    "offline": {
        "title": "Offline",
        "bits_per_second": None,
        "latency_seconds": 0.0,
        "offline": True,
    },
}


class ProfileState:
    """Thread-safe storage shared by every HTTP request handler."""

    def __init__(self, initial_profile: str) -> None:
        self._profile = initial_profile
        self._lock = Lock()

    def get(self) -> tuple[str, dict]:
        with self._lock:
            name = self._profile
        return name, PROFILES[name]

    def set(self, name: str) -> None:
        if name not in PROFILES:
            raise ValueError(f"Unknown profile: {name}")
        with self._lock:
            self._profile = name


class BurstStreamRequestHandler(SimpleHTTPRequestHandler):
    """Static-file handler plus a small development-only profile API."""

    server: "BurstStreamHTTPServer"

    def do_GET(self) -> None:  # noqa: N802 - inherited HTTP method name
        if self.path.split("?", 1)[0] == "/__burststream/profile":
            self._send_profile_response()
            return

        profile_name, profile = self.server.profile_state.get()
        if profile["offline"]:
            self.send_error(HTTPStatus.SERVICE_UNAVAILABLE, "Network profile is offline")
            return

        latency = profile["latency_seconds"]
        if latency:
            time.sleep(latency)

        self._request_profile_name = profile_name
        super().do_GET()

    def do_POST(self) -> None:  # noqa: N802 - inherited HTTP method name
        if self.path.split("?", 1)[0] != "/__burststream/profile":
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(content_length) or b"{}")
            profile_name = payload.get("profile")
            self.server.profile_state.set(profile_name)
        except (ValueError, TypeError, json.JSONDecodeError) as error:
            self._send_json(
                {"error": str(error), "profiles": list(PROFILES)},
                status=HTTPStatus.BAD_REQUEST,
            )
            return

        print(f"Network profile changed to: {profile_name}", flush=True)
        self._send_profile_response()

    def copyfile(self, source: BinaryIO, outputfile: BinaryIO) -> None:
        """Copy a response in chunks and delay each chunk to enforce bandwidth."""

        chunk_size = 32 * 1024

        while chunk := source.read(chunk_size):
            _, profile = self.server.profile_state.get()

            # A profile can change while a segment is downloading. Closing the
            # connection makes an Offline selection observable immediately.
            if profile["offline"]:
                self.close_connection = True
                return

            outputfile.write(chunk)
            outputfile.flush()

            bits_per_second = profile["bits_per_second"]
            if bits_per_second:
                time.sleep((len(chunk) * 8) / bits_per_second)

    def log_message(self, format: str, *args: object) -> None:
        profile_name, _ = self.server.profile_state.get()
        super().log_message(f"[{profile_name}] {format}", *args)

    def _send_profile_response(self) -> None:
        profile_name, _ = self.server.profile_state.get()
        self._send_json(
            {
                "profile": profile_name,
                "profiles": [
                    {"id": name, **configuration}
                    for name, configuration in PROFILES.items()
                ],
            }
        )

    def _send_json(self, payload: dict, status: HTTPStatus = HTTPStatus.OK) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)


class BurstStreamHTTPServer(ThreadingHTTPServer):
    profile_state: ProfileState


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--directory", type=Path, default=Path("LocalMedia"))
    parser.add_argument("--profile", choices=PROFILES, default="fast")
    return parser.parse_args()


def main() -> None:
    arguments = parse_arguments()
    media_root = arguments.directory.resolve()
    media_root.mkdir(parents=True, exist_ok=True)
    os.chdir(media_root)

    server = BurstStreamHTTPServer(("", arguments.port), BurstStreamRequestHandler)
    server.profile_state = ProfileState(arguments.profile)

    print(f"Serving {media_root} on port {arguments.port}", flush=True)
    print(f"Initial network profile: {arguments.profile}", flush=True)
    print("Change profiles from the BurstStream app while playback is running.", flush=True)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
