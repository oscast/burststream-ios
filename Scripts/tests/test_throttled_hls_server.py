"""Deterministic regression tests for the local HLS development server."""

import http.client
import socket
import sys
import tempfile
import threading
import unittest
from functools import partial
from pathlib import Path
from unittest.mock import patch


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from throttled_hls_server import (  # noqa: E402
    BurstStreamHTTPServer,
    BurstStreamRequestHandler,
    ProfileState,
)


class LocalHLSFixture:
    def __init__(self, initial_profile="fast"):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.media_root = Path(self.temporary_directory.name)
        (self.media_root / "master.m3u8").write_text(
            "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\nvideo.m3u8\n",
            encoding="utf-8",
        )
        (self.media_root / "malformed.m3u8").write_text(
            "this is not an HLS playlist\n",
            encoding="utf-8",
        )

        handler = partial(BurstStreamRequestHandler, directory=self.media_root)
        self.server = BurstStreamHTTPServer(("", 0), handler)
        self.server.profile_state = ProfileState(initial_profile)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.temporary_directory.cleanup()

    def request(self, path, host="127.0.0.1"):
        connection = http.client.HTTPConnection(host, self.server.server_port, timeout=2)
        try:
            connection.request("GET", path)
            response = connection.getresponse()
            body = response.read()
            return response, body
        finally:
            connection.close()


class LocalHLSListenerTests(unittest.TestCase):
    def setUp(self):
        self.fixture = LocalHLSFixture()

    def tearDown(self):
        self.fixture.close()

    def test_localhost_accepts_ipv4_and_ipv6_when_dual_stack_is_supported(self):
        hosts = ["127.0.0.1"]
        if socket.has_dualstack_ipv6():
            hosts.append("::1")

        for host in hosts:
            with self.subTest(host=host):
                response, body = self.fixture.request("/master.m3u8", host=host)
                self.assertEqual(response.status, 200)
                self.assertTrue(body.startswith(b"#EXTM3U\n"))

    def test_missing_segment_returns_404(self):
        response, _ = self.fixture.request("/missing-segment.ts")

        self.assertEqual(response.status, 404)

    def test_malformed_playlist_fixture_is_served_with_hls_content_type(self):
        response, body = self.fixture.request("/malformed.m3u8")

        self.assertEqual(response.status, 200)
        self.assertEqual(response.getheader("Content-Type"), "application/vnd.apple.mpegurl")
        self.assertEqual(body, b"this is not an HLS playlist\n")

    def test_high_latency_profile_applies_configured_delay_without_real_sleep(self):
        self.fixture.server.profile_state.set("high-latency")

        with patch("throttled_hls_server.time.sleep") as sleep:
            response, _ = self.fixture.request("/master.m3u8")

        self.assertEqual(response.status, 200)
        sleep.assert_called_once_with(1.5)

    def test_offline_profile_returns_retryable_outage(self):
        self.fixture.server.profile_state.set("offline")

        response, body = self.fixture.request("/master.m3u8")

        self.assertEqual(response.status, 503)
        self.assertEqual(response.getheader("Retry-After"), "2")
        self.assertEqual(body, b"Network profile is offline\n")

    def test_stream_recovers_after_offline_profile_is_cleared(self):
        self.fixture.server.profile_state.set("offline")
        outage_response, _ = self.fixture.request("/master.m3u8")

        self.fixture.server.profile_state.set("fast")
        recovered_response, recovered_body = self.fixture.request("/master.m3u8")

        self.assertEqual(outage_response.status, 503)
        self.assertEqual(recovered_response.status, 200)
        self.assertTrue(recovered_body.startswith(b"#EXTM3U\n"))


if __name__ == "__main__":
    unittest.main()
