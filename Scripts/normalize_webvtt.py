#!/usr/bin/env python3
"""Normalize Whisper WebVTT output for reliable HLS packaging."""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


TIMESTAMP_PATTERN = re.compile(
    r"^(?P<start>\d{2}:\d{2}:\d{2}\.\d{3})\s+-->\s+"
    r"(?P<end>\d{2}:\d{2}:\d{2}\.\d{3})$"
)


@dataclass
class Cue:
    start: str
    end: str
    lines: list[str]

    @property
    def start_seconds(self) -> float:
        return timestamp_seconds(self.start)

    @property
    def end_seconds(self) -> float:
        return timestamp_seconds(self.end)


def timestamp_seconds(value: str) -> float:
    hours, minutes, seconds = value.split(":")
    return int(hours) * 3600 + int(minutes) * 60 + float(seconds)


def parse_webvtt(path: Path) -> list[Cue]:
    lines = path.read_text(encoding="utf-8").splitlines()
    cues: list[Cue] = []
    index = 0

    while index < len(lines):
        match = TIMESTAMP_PATTERN.match(lines[index].strip())
        if not match:
            index += 1
            continue

        index += 1
        text_lines: list[str] = []
        while index < len(lines) and lines[index].strip():
            text_lines.append(lines[index].strip())
            index += 1

        cues.append(
            Cue(
                start=match.group("start"),
                end=match.group("end"),
                lines=text_lines,
            )
        )

    if not cues:
        raise ValueError(f"No WebVTT cues were found in {path}")

    return cues


def normalize_cues(cues: list[Cue]) -> tuple[list[Cue], int]:
    normalized: list[Cue] = []
    merged_count = 0

    for cue in cues:
        if cue.end_seconds <= cue.start_seconds:
            # Whisper can create a zero-duration cue when a long sentence is
            # split exactly at the next cue boundary. Joining that text to the
            # preceding cue preserves the sentence without inventing timing.
            if normalized and normalized[-1].end == cue.start:
                normalized[-1].lines.extend(cue.lines)
                merged_count += 1
                continue
            raise ValueError(
                f"Cannot repair cue with invalid timing: {cue.start} --> {cue.end}"
            )

        if normalized and cue.start_seconds < normalized[-1].end_seconds:
            raise ValueError(
                f"Overlapping cues: {normalized[-1].end} and {cue.start}"
            )

        normalized.append(cue)

    return normalized, merged_count


def write_webvtt(path: Path, cues: list[Cue]) -> None:
    output = ["WEBVTT", ""]
    for cue in cues:
        output.append(f"{cue.start} --> {cue.end}")
        output.extend(cue.lines)
        output.append("")
    path.write_text("\n".join(output), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Repair zero-duration cues in Whisper WebVTT output."
    )
    parser.add_argument("input", type=Path, help="WebVTT file to normalize")
    parser.add_argument(
        "--output",
        type=Path,
        help="Destination path; defaults to replacing the input file",
    )
    args = parser.parse_args()

    destination = args.output or args.input
    cues, merged_count = normalize_cues(parse_webvtt(args.input))
    destination.parent.mkdir(parents=True, exist_ok=True)
    write_webvtt(destination, cues)

    print(f"Normalized {len(cues)} cues ({merged_count} invalid cues merged).")


if __name__ == "__main__":
    main()
