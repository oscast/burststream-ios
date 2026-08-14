#!/usr/bin/env bash
# Serves LocalMedia over HTTP so AVPlayer can request playlists and segments.
# The custom Python server can also simulate changing network conditions.
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<USAGE
Usage:
  Scripts/serve-local-hls.sh [port] [initial-profile]

Example:
  Scripts/serve-local-hls.sh 8000
  Scripts/serve-local-hls.sh 8000 2mbps

Profiles:
  fast, 5mbps, 2mbps, 1.2mbps, 800kbps, high-latency, offline
USAGE
  exit 0
fi

PORT="${1:-${BURSTSTREAM_STREAM_PORT:-8000}}"
INITIAL_PROFILE="${2:-${BURSTSTREAM_NETWORK_PROFILE:-fast}}"
if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
  echo "Error: port must be a number, got: $PORT" >&2
  exit 1
fi

MEDIA_ROOT="${BURSTSTREAM_MEDIA_ROOT:-LocalMedia}"

case "$INITIAL_PROFILE" in
  fast|5mbps|2mbps|1.2mbps|800kbps|high-latency|offline) ;;
  *)
    echo "Error: unknown network profile: $INITIAL_PROFILE" >&2
    exit 1
    ;;
esac

mkdir -p "$MEDIA_ROOT"

# Find the Mac LAN address for optional testing on a physical device.
LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"

cat <<INFO
Serving BurstStream local media

Root:
  $MEDIA_ROOT

Simulator URL pattern:
  http://localhost:$PORT/hls/<stream-name>/master.m3u8
INFO

if [[ -n "$LAN_IP" ]]; then
  cat <<INFO

Physical iPhone/iPad and AirPlay URL pattern, same Wi-Fi required:
  http://$LAN_IP:$PORT/hls/<stream-name>/master.m3u8

Use this LAN URL when sending playback to Apple TV. localhost refers to the
device that reads the URL, so it cannot identify this Mac from Apple TV.
INFO
fi

cat <<INFO

Keep this terminal open while testing playback.
Press Ctrl+C to stop the server.

Initial network profile:
  $INITIAL_PROFILE

INFO

# This server does not convert media. It serves generated files and controls how
# quickly each response is delivered so ABR can be studied locally.
python3 Scripts/throttled_hls_server.py \
  --port "$PORT" \
  --directory "$MEDIA_ROOT" \
  --profile "$INITIAL_PROFILE"
