#!/usr/bin/env bash
# Generates an HLS package with aligned qualities for adaptive bitrate.
#
# The source video remains outside the project. Only generated files are written
# to LocalMedia/, which Git ignores.
set -euo pipefail

if [[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
Usage:
  Scripts/prepare-adaptive-hls.sh LocalMedia/sources/video.mp4 [stream-name]

Example:
  Scripts/prepare-adaptive-hls.sh LocalMedia/sources/video-1080p.mp4 my-video-adaptive

Variants generated (4:3):
  1080p  1440x1080  4.5 Mbps
  720p    960x720   2.5 Mbps
  480p    640x480   1.2 Mbps
  360p    480x360   0.6 Mbps

For a short development test, set a duration in seconds:
  BURSTSTREAM_HLS_TEST_DURATION=30 Scripts/prepare-adaptive-hls.sh ...
USAGE
  exit 0
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: ffmpeg is not installed. Run: brew install ffmpeg" >&2
  exit 1
fi

INPUT_PATH="$1"
if [[ ! -f "$INPUT_PATH" ]]; then
  echo "Error: input video not found: $INPUT_PATH" >&2
  exit 1
fi

RAW_NAME="${2:-$(basename "$INPUT_PATH")}"
STREAM_NAME="${RAW_NAME%.*}"
STREAM_NAME="$(echo "$STREAM_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')"
[[ -n "$STREAM_NAME" ]] || STREAM_NAME="adaptive-video"

MEDIA_ROOT="${BURSTSTREAM_MEDIA_ROOT:-LocalMedia}"
OUTPUT_DIR="$MEDIA_ROOT/hls/$STREAM_NAME"
mkdir -p "$MEDIA_ROOT/hls"

# Work in a temporary directory and replace the previous stream only after FFmpeg
# succeeds, so the server never exposes partial output.
TEMP_OUTPUT_DIR="$(mktemp -d "$MEDIA_ROOT/hls/.${STREAM_NAME}.XXXXXX")"
trap 'rm -rf "$TEMP_OUTPUT_DIR"' EXIT

for variant in 1080p 720p 480p 360p; do
  mkdir -p "$TEMP_OUTPUT_DIR/$variant"
done

FFMPEG_ARGS=(
  -y
  -i "$INPUT_PATH"
)

# This option processes the first N seconds for a quick test without changing the
# production workflow. Without the variable, the full episode is processed.
if [[ -n "${BURSTSTREAM_HLS_TEST_DURATION:-}" ]]; then
  if ! [[ "$BURSTSTREAM_HLS_TEST_DURATION" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "Error: BURSTSTREAM_HLS_TEST_DURATION must be numeric." >&2
    exit 1
  fi
  FFMPEG_ARGS+=( -t "$BURSTSTREAM_HLS_TEST_DURATION" )
fi

# Decode once, split into four branches, and scale each branch while preserving
# the restored content's 4:3 aspect ratio.
FFMPEG_ARGS+=(
  -filter_complex
  "[0:v:0]split=4[v1080source][v720source][v480source][v360source];
   [v1080source]scale=1440:1080:flags=lanczos[v1080];
   [v720source]scale=960:720:flags=lanczos[v720];
   [v480source]scale=640:480:flags=lanczos[v480];
   [v360source]scale=480:360:flags=lanczos[v360]"

  # Every variant receives the same audio track.
  -map "[v1080]" -map 0:a:0
  -map "[v720]"  -map 0:a:0
  -map "[v480]"  -map 0:a:0
  -map "[v360]"  -map 0:a:0

  -c:v libx264
  -preset veryfast
  -profile:v main
  -pix_fmt yuv420p

  # Target bitrate, peak bitrate, and encoder buffer for each resolution.
  -b:v:0 4500k -maxrate:v:0 5000k -bufsize:v:0 9000k
  -b:v:1 2500k -maxrate:v:1 2800k -bufsize:v:1 5000k
  -b:v:2 1200k -maxrate:v:2 1400k -bufsize:v:2 2400k
  -b:v:3 600k  -maxrate:v:3 700k  -bufsize:v:3 1200k

  # Identical keyframes every two seconds allow quality switches without losing
  # synchronization. Every playlist cuts segments near six seconds.
  -force_key_frames:v:0 "expr:gte(t,n_forced*2)"
  -force_key_frames:v:1 "expr:gte(t,n_forced*2)"
  -force_key_frames:v:2 "expr:gte(t,n_forced*2)"
  -force_key_frames:v:3 "expr:gte(t,n_forced*2)"
  -sc_threshold 0

  -c:a aac
  -b:a 128k
  -ac 2

  -f hls
  -hls_time 6
  -hls_playlist_type vod
  -hls_flags independent_segments
  -master_pl_name master.m3u8
  -var_stream_map
  "v:0,a:0,name:1080p v:1,a:1,name:720p v:2,a:2,name:480p v:3,a:3,name:360p"
  -hls_segment_filename "$TEMP_OUTPUT_DIR/%v/segment_%04d.ts"
  "$TEMP_OUTPUT_DIR/%v/playlist.m3u8"
)

ffmpeg "${FFMPEG_ARGS[@]}"

rm -rf "$OUTPUT_DIR"
mv "$TEMP_OUTPUT_DIR" "$OUTPUT_DIR"
trap - EXIT

PORT="${BURSTSTREAM_STREAM_PORT:-8000}"

cat <<DONE

Adaptive HLS stream created:
  $OUTPUT_DIR/master.m3u8

Simulator URL:
  http://localhost:$PORT/hls/$STREAM_NAME/master.m3u8

Variants:
  1080p, 720p, 480p, 360p
DONE
