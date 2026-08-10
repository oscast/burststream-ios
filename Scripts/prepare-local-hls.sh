#!/usr/bin/env bash
# Converts a local video file into an HLS playlist and .ts segments.
# `set -euo pipefail` stops on errors, undefined variables, or failures inside
# a command pipeline.
set -euo pipefail

print_usage() {
  cat <<USAGE
Usage:
  Scripts/prepare-local-hls.sh LocalMedia/sources/video.mp4 [stream-name]

Example:
  Scripts/prepare-local-hls.sh LocalMedia/sources/my-video.mp4 my-video

This creates:
  LocalMedia/hls/<stream-name>/master.m3u8
  LocalMedia/hls/<stream-name>/segment_000.ts
  LocalMedia/hls/<stream-name>/segment_001.ts
  ...
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  print_usage
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  cat <<'FFMPEG_MISSING'
Error: ffmpeg is not installed.

Install it with Homebrew:
  brew install ffmpeg

Then run this script again.
FFMPEG_MISSING
  exit 1
fi

INPUT_PATH="$1"
if [[ ! -f "$INPUT_PATH" ]]; then
  echo "Error: input video not found: $INPUT_PATH" >&2
  exit 1
fi

RAW_NAME="${2:-$(basename "$INPUT_PATH")}"
STREAM_NAME="${RAW_NAME%.*}"
# Keep stream folder names URL-friendly.
STREAM_NAME="$(echo "$STREAM_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')"
if [[ -z "$STREAM_NAME" ]]; then
  STREAM_NAME="my-video"
fi

MEDIA_ROOT="${BURSTSTREAM_MEDIA_ROOT:-LocalMedia}"
OUTPUT_DIR="$MEDIA_ROOT/hls/$STREAM_NAME"
mkdir -p "$MEDIA_ROOT/hls"

# Generate into a temporary directory so the server never exposes a new playlist
# that still references incomplete segments.
TEMP_OUTPUT_DIR="$(mktemp -d "$MEDIA_ROOT/hls/.${STREAM_NAME}.XXXXXX")"
trap 'rm -rf "$TEMP_OUTPUT_DIR"' EXIT

PLAYLIST_PATH="$TEMP_OUTPUT_DIR/master.m3u8"
SEGMENT_PATTERN="$TEMP_OUTPUT_DIR/segment_%03d.ts"

# An array keeps option groups readable without breaking the command.
FFMPEG_ARGS=(
  -y
  -i "$INPUT_PATH"

  # H.264 is broadly compatible with AVPlayer.
  -c:v libx264
  # veryfast reduces conversion time at the cost of slightly larger files.
  -preset veryfast
  -profile:v main
  # yuv420p provides broad compatibility with Apple devices.
  -pix_fmt yuv420p
  # CRF controls quality; lower values increase quality and file size.
  -crf 23
  # Keyframes every two seconds enable more precise seeks and aligned segments.
  -force_key_frames "expr:gte(t,n_forced*2)"
  -sc_threshold 0

  # AAC is the most common HLS audio codec on Apple devices.
  -c:a aac
  -b:a 128k
  -ac 2

  # HLS targets segments of approximately six seconds.
  -hls_time 6
  # VOD marks a complete video rather than a live stream.
  -hls_playlist_type vod
  # Every segment begins independently with a keyframe.
  -hls_flags independent_segments
  -hls_segment_filename "$SEGMENT_PATTERN"
  "$PLAYLIST_PATH"
)

ffmpeg "${FFMPEG_ARGS[@]}"

# Replace the previous version only after a successful conversion.
rm -rf "$OUTPUT_DIR"
mv "$TEMP_OUTPUT_DIR" "$OUTPUT_DIR"
trap - EXIT

PLAYLIST_PATH="$OUTPUT_DIR/master.m3u8"

PORT="${BURSTSTREAM_STREAM_PORT:-8000}"
LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"

cat <<DONE

HLS stream created:
  $PLAYLIST_PATH

Start the local server:
  Scripts/serve-local-hls.sh $PORT

Use this URL in the iOS Simulator:
  http://localhost:$PORT/hls/$STREAM_NAME/master.m3u8
DONE

if [[ -n "$LAN_IP" ]]; then
  cat <<DONE

Use this URL on a real iPhone on the same Wi-Fi:
  http://$LAN_IP:$PORT/hls/$STREAM_NAME/master.m3u8
DONE
fi
