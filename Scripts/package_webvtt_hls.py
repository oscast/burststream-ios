#!/usr/bin/env python3
"""Package one WebVTT file as an HLS subtitle rendition."""

from __future__ import annotations

import argparse
import math
import re
from dataclasses import dataclass
from pathlib import Path


TIMESTAMP_PATTERN = re.compile(
    r"^(?P<start>\d{2}:\d{2}:\d{2}\.\d{3})\s+-->\s+"
    r"(?P<end>\d{2}:\d{2}:\d{2}\.\d{3})$"
)


@dataclass(frozen=True)
class Cue:
    start_text: str
    end_text: str
    start_seconds: float
    end_seconds: float
    lines: tuple[str, ...]


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

        start_text = match.group("start")
        end_text = match.group("end")
        start_seconds = timestamp_seconds(start_text)
        end_seconds = timestamp_seconds(end_text)
        if end_seconds <= start_seconds:
            raise ValueError(
                f"Invalid cue duration: {start_text} --> {end_text}"
            )

        cues.append(
            Cue(
                start_text=start_text,
                end_text=end_text,
                start_seconds=start_seconds,
                end_seconds=end_seconds,
                lines=tuple(text_lines),
            )
        )

    if not cues:
        raise ValueError(f"No WebVTT cues were found in {path}")

    return cues


def parse_reference_durations(path: Path) -> list[float]:
    durations: list[float] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("#EXTINF:"):
            durations.append(float(line.removeprefix("#EXTINF:").split(",", 1)[0]))

    if not durations:
        raise ValueError(f"No EXTINF durations were found in {path}")

    return durations


def write_segment(
    path: Path,
    cues: list[Cue],
    mpegts_timestamp: int,
) -> None:
    output = [
        "WEBVTT",
        f"X-TIMESTAMP-MAP=LOCAL:00:00:00.000,MPEGTS:{mpegts_timestamp}",
        "",
    ]

    for cue in cues:
        output.append(f"{cue.start_text} --> {cue.end_text}")
        output.extend(cue.lines)
        output.append("")

    path.write_text("\n".join(output), encoding="utf-8")


def package_rendition(
    input_path: Path,
    reference_playlist: Path,
    output_directory: Path,
    mpegts_timestamp: int,
) -> tuple[int, int]:
    cues = parse_webvtt(input_path)
    durations = parse_reference_durations(reference_playlist)
    output_directory.mkdir(parents=True, exist_ok=True)

    segment_start = 0.0
    referenced_cue_count = 0
    for index, duration in enumerate(durations):
        segment_end = segment_start + duration

        # A cue spanning a segment boundary appears in both files. HLS clients
        # use its original absolute WebVTT timestamps and display it only for
        # the overlapping part of the current media timeline.
        segment_cues = [
            cue
            for cue in cues
            if cue.start_seconds < segment_end and cue.end_seconds > segment_start
        ]
        referenced_cue_count += len(segment_cues)

        write_segment(
            output_directory / f"segment_{index:04d}.vtt",
            segment_cues,
            mpegts_timestamp,
        )
        segment_start = segment_end

    target_duration = math.ceil(max(durations))
    playlist = [
        "#EXTM3U",
        "#EXT-X-VERSION:3",
        f"#EXT-X-TARGETDURATION:{target_duration}",
        "#EXT-X-MEDIA-SEQUENCE:0",
        "#EXT-X-PLAYLIST-TYPE:VOD",
    ]

    for index, duration in enumerate(durations):
        playlist.extend(
            [
                f"#EXTINF:{duration:.6f},",
                f"segment_{index:04d}.vtt",
            ]
        )

    playlist.append("#EXT-X-ENDLIST")
    (output_directory / "playlist.m3u8").write_text(
        "\n".join(playlist) + "\n",
        encoding="utf-8",
    )

    return len(durations), referenced_cue_count


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Split WebVTT cues according to an HLS video playlist."
    )
    parser.add_argument("input", type=Path, help="Normalized WebVTT source")
    parser.add_argument(
        "reference_playlist",
        type=Path,
        help="Video media playlist whose EXTINF boundaries should be reused",
    )
    parser.add_argument("output_directory", type=Path)
    parser.add_argument(
        "--mpegts-timestamp",
        type=int,
        required=True,
        help="90 kHz MPEG-TS timestamp corresponding to WebVTT time zero",
    )
    args = parser.parse_args()

    segment_count, referenced_cue_count = package_rendition(
        input_path=args.input,
        reference_playlist=args.reference_playlist,
        output_directory=args.output_directory,
        mpegts_timestamp=args.mpegts_timestamp,
    )
    print(
        f"Created {segment_count} subtitle segments "
        f"with {referenced_cue_count} cue references."
    )


if __name__ == "__main__":
    main()
