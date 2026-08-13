#!/usr/bin/env bash
# Transcribes one local video into timestamped WebVTT, SRT, and JSON files.
# The media and generated subtitles remain under LocalMedia and are ignored by Git.
set -euo pipefail

if [[ $# -lt 3 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
Usage:
  Scripts/transcribe-subtitles.sh <video> <language-code> <stream-name>

Example:
  Scripts/transcribe-subtitles.sh \
    LocalMedia/sources/episode-spanish.mp4 \
    es \
    my-episode

Output:
  LocalMedia/subtitles/<stream-name>/<language-code>/subtitles.vtt
  LocalMedia/subtitles/<stream-name>/<language-code>/subtitles.srt
  LocalMedia/subtitles/<stream-name>/<language-code>/transcription.json

Requirements:
  brew install ffmpeg whisper-cpp

Whisper also requires a multilingual GGML model. By default, this script uses:
  ~/Library/Caches/BurstStream/Whisper/ggml-small.bin

Override it with BURSTSTREAM_WHISPER_MODEL. Optional controls:
  BURSTSTREAM_WHISPER_PROMPT="Teddy Ruxpin, Grundo, Rarilonia"
  BURSTSTREAM_TRANSCRIPTION_TEST_DURATION=180
USAGE
  exit 0
fi

for command in ffmpeg whisper-cli python3; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Error: $command is required." >&2
    echo "Install the media tools with: brew install ffmpeg whisper-cpp" >&2
    exit 1
  fi
done

INPUT="$1"
LANGUAGE="$2"
RAW_NAME="$3"

if [[ ! -f "$INPUT" ]]; then
  echo "Error: input video not found: $INPUT" >&2
  exit 1
fi

if ! [[ "$LANGUAGE" =~ ^[a-z]{2,3}$ ]]; then
  echo "Error: use a two- or three-letter language code such as es or en." >&2
  exit 1
fi

STREAM_NAME="${RAW_NAME%.*}"
STREAM_NAME="$(echo "$STREAM_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')"
[[ -n "$STREAM_NAME" ]] || STREAM_NAME="transcribed-video"

MODEL="${BURSTSTREAM_WHISPER_MODEL:-$HOME/Library/Caches/BurstStream/Whisper/ggml-small.bin}"
if [[ ! -f "$MODEL" ]]; then
  cat >&2 <<MODEL_ERROR
Error: Whisper model not found:
  $MODEL

Download a multilingual GGML model from:
  https://huggingface.co/ggerganov/whisper.cpp/tree/main

Then set BURSTSTREAM_WHISPER_MODEL to its path.
MODEL_ERROR
  exit 1
fi

MEDIA_ROOT="${BURSTSTREAM_MEDIA_ROOT:-LocalMedia}"
OUTPUT_DIR="$MEDIA_ROOT/subtitles/$STREAM_NAME/$LANGUAGE"
mkdir -p "$MEDIA_ROOT/subtitles/$STREAM_NAME"

# Generate everything in a sibling directory so a failed transcription cannot
# replace an existing valid subtitle package.
TEMP_DIR="$(mktemp -d "$MEDIA_ROOT/subtitles/$STREAM_NAME/.${LANGUAGE}.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

DURATION_ARGUMENTS=()
if [[ -n "${BURSTSTREAM_TRANSCRIPTION_TEST_DURATION:-}" ]]; then
  if ! [[ "$BURSTSTREAM_TRANSCRIPTION_TEST_DURATION" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "Error: BURSTSTREAM_TRANSCRIPTION_TEST_DURATION must be numeric." >&2
    exit 1
  fi
  DURATION_ARGUMENTS=(-t "$BURSTSTREAM_TRANSCRIPTION_TEST_DURATION")
fi

echo "Extracting mono 16 kHz audio..."
ffmpeg -hide_banner -loglevel error -y \
  -i "$INPUT" "${DURATION_ARGUMENTS[@]}" \
  -map 0:a:0 -ac 1 -ar 16000 -c:a pcm_s16le \
  "$TEMP_DIR/audio.wav"

WHISPER_ARGUMENTS=(
  --model "$MODEL"
  --file "$TEMP_DIR/audio.wav"
  --language "$LANGUAGE"
  --output-vtt
  --output-json-full
  --output-file "$TEMP_DIR/subtitles"
  --split-on-word
  --max-len 42
  --print-progress
  --no-prints
)

if [[ -n "${BURSTSTREAM_WHISPER_PROMPT:-}" ]]; then
  WHISPER_ARGUMENTS+=(--prompt "$BURSTSTREAM_WHISPER_PROMPT")
fi

echo "Transcribing with whisper.cpp..."
whisper-cli "${WHISPER_ARGUMENTS[@]}"

python3 Scripts/normalize_webvtt.py "$TEMP_DIR/subtitles.vtt"

# Regenerate SRT from the normalized WebVTT so both formats have identical,
# valid cue boundaries.
ffmpeg -hide_banner -loglevel error -y \
  -f webvtt -i "$TEMP_DIR/subtitles.vtt" \
  -map 0:s:0 -c:s srt "$TEMP_DIR/subtitles.srt"

mv "$TEMP_DIR/subtitles.json" "$TEMP_DIR/transcription.json"
rm "$TEMP_DIR/audio.wav"

rm -rf "$OUTPUT_DIR"
mv "$TEMP_DIR" "$OUTPUT_DIR"
trap - EXIT

cat <<DONE

Subtitle transcription created:
  $OUTPUT_DIR/subtitles.vtt
  $OUTPUT_DIR/subtitles.srt
  $OUTPUT_DIR/transcription.json

Review AI-generated text before publishing or distributing it.
DONE
