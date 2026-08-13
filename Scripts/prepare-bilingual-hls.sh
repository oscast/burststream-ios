#!/usr/bin/env bash
# Generates one adaptive video ladder with two alternate HLS audio renditions.
#
# The video is encoded only once per quality. Spanish and English are stored as
# independent audio playlists, so adding a language does not duplicate video.
set -euo pipefail

if [[ $# -lt 2 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
Usage:
  Scripts/prepare-bilingual-hls.sh \
    LocalMedia/sources/spanish.mp4 \
    LocalMedia/sources/english.mp4 \
    [stream-name] \
    [spanish-subtitles.vtt] \
    [english-subtitles.vtt]

Example:
  Scripts/prepare-bilingual-hls.sh \
    LocalMedia/sources/episode-spanish.mp4 \
    LocalMedia/sources/episode-english.mp4 \
    episode-bilingual \
    LocalMedia/subtitles/episode-bilingual/es/subtitles.vtt \
    LocalMedia/subtitles/episode-bilingual/en/subtitles.vtt

Output:
  LocalMedia/hls/<stream-name>/master.m3u8
  LocalMedia/hls/<stream-name>/video/{1080p,720p,480p,360p}/...
  LocalMedia/hls/<stream-name>/audio/{es,en}/...
  LocalMedia/hls/<stream-name>/subtitles/{es,en}/...

For a short development test, set a duration in seconds:
  BURSTSTREAM_HLS_TEST_DURATION=30 Scripts/prepare-bilingual-hls.sh ...
USAGE
  exit 0
fi

for command in ffmpeg ffprobe; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Error: $command is not installed. Run: brew install ffmpeg" >&2
    exit 1
  fi
done

SPANISH_INPUT="$1"
ENGLISH_INPUT="$2"
SPANISH_SUBTITLES="${4:-}"
ENGLISH_SUBTITLES="${5:-}"

for input in "$SPANISH_INPUT" "$ENGLISH_INPUT"; do
  if [[ ! -f "$input" ]]; then
    echo "Error: input video not found: $input" >&2
    exit 1
  fi
done

if [[ -n "$SPANISH_SUBTITLES" || -n "$ENGLISH_SUBTITLES" ]]; then
  if [[ -z "$SPANISH_SUBTITLES" || -z "$ENGLISH_SUBTITLES" ]]; then
    echo "Error: provide both Spanish and English WebVTT files." >&2
    exit 1
  fi

  for subtitles in "$SPANISH_SUBTITLES" "$ENGLISH_SUBTITLES"; do
    if [[ ! -f "$subtitles" ]]; then
      echo "Error: subtitle file not found: $subtitles" >&2
      exit 1
    fi
  done
fi

RAW_NAME="${3:-bilingual-video}"
STREAM_NAME="${RAW_NAME%.*}"
STREAM_NAME="$(echo "$STREAM_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')"
[[ -n "$STREAM_NAME" ]] || STREAM_NAME="bilingual-video"

MEDIA_ROOT="${BURSTSTREAM_MEDIA_ROOT:-LocalMedia}"
OUTPUT_DIR="$MEDIA_ROOT/hls/$STREAM_NAME"
mkdir -p "$MEDIA_ROOT/hls"

# Build in a sibling temporary directory. The previous valid package stays
# available until every playlist and segment has been generated successfully.
TEMP_OUTPUT_DIR="$(mktemp -d "$MEDIA_ROOT/hls/.${STREAM_NAME}.XXXXXX")"
trap 'rm -rf "$TEMP_OUTPUT_DIR"' EXIT

for variant in 1080p 720p 480p 360p; do
  mkdir -p "$TEMP_OUTPUT_DIR/video/$variant"
done
for language in es en; do
  mkdir -p "$TEMP_OUTPUT_DIR/audio/$language"
done
if [[ -n "$SPANISH_SUBTITLES" ]]; then
  for language in es en; do
    mkdir -p "$TEMP_OUTPUT_DIR/subtitles/$language"
  done
fi

SPANISH_DURATION="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$SPANISH_INPUT")"
if [[ -z "$SPANISH_DURATION" ]]; then
  echo "Error: could not read the Spanish input duration." >&2
  exit 1
fi

TARGET_DURATION="$SPANISH_DURATION"
if [[ -n "${BURSTSTREAM_HLS_TEST_DURATION:-}" ]]; then
  if ! [[ "$BURSTSTREAM_HLS_TEST_DURATION" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "Error: BURSTSTREAM_HLS_TEST_DURATION must be numeric." >&2
    exit 1
  fi
  TARGET_DURATION="$BURSTSTREAM_HLS_TEST_DURATION"
fi

echo "Encoding shared adaptive video..."
ffmpeg -y \
  -i "$SPANISH_INPUT" \
  -t "$TARGET_DURATION" \
  -filter_complex \
  "[0:v:0]split=4[v1080source][v720source][v480source][v360source];
   [v1080source]scale=1440:1080:flags=lanczos[v1080];
   [v720source]scale=960:720:flags=lanczos[v720];
   [v480source]scale=640:480:flags=lanczos[v480];
   [v360source]scale=480:360:flags=lanczos[v360]" \
  -map "[v1080]" -map "[v720]" -map "[v480]" -map "[v360]" \
  -an \
  -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p \
  -b:v:0 4500k -maxrate:v:0 5000k -bufsize:v:0 9000k \
  -b:v:1 2500k -maxrate:v:1 2800k -bufsize:v:1 5000k \
  -b:v:2 1200k -maxrate:v:2 1400k -bufsize:v:2 2400k \
  -b:v:3 600k  -maxrate:v:3 700k  -bufsize:v:3 1200k \
  -force_key_frames:v:0 "expr:gte(t,n_forced*2)" \
  -force_key_frames:v:1 "expr:gte(t,n_forced*2)" \
  -force_key_frames:v:2 "expr:gte(t,n_forced*2)" \
  -force_key_frames:v:3 "expr:gte(t,n_forced*2)" \
  -sc_threshold 0 \
  -f hls -hls_time 6 -hls_playlist_type vod \
  -hls_flags independent_segments \
  -var_stream_map "v:0,name:1080p v:1,name:720p v:2,name:480p v:3,name:360p" \
  -hls_segment_filename "$TEMP_OUTPUT_DIR/video/%v/segment_%04d.ts" \
  "$TEMP_OUTPUT_DIR/video/%v/playlist.m3u8"

echo "Encoding Spanish and English audio renditions..."
# aresample normalizes the start timestamp. apad adds a tiny amount of silence
# when the English source ends before the Spanish video timeline.
ffmpeg -y \
  -i "$SPANISH_INPUT" \
  -i "$ENGLISH_INPUT" \
  -t "$TARGET_DURATION" \
  -map 0:a:0 -map 1:a:0 \
  -filter:a:0 "aresample=async=1:first_pts=0,apad" \
  -filter:a:1 "aresample=async=1:first_pts=0,apad" \
  -c:a aac -b:a 128k -ac 2 -ar 48000 \
  -f hls -hls_time 6 -hls_playlist_type vod \
  -var_stream_map "a:0,name:es a:1,name:en" \
  -hls_segment_filename "$TEMP_OUTPUT_DIR/audio/%v/segment_%04d.ts" \
  "$TEMP_OUTPUT_DIR/audio/%v/playlist.m3u8"

SUBTITLE_MEDIA_LINES=""
SUBTITLE_STREAM_ATTRIBUTE=""

if [[ -n "$SPANISH_SUBTITLES" ]]; then
  # MPEG-TS uses a 90 kHz clock. Mapping WebVTT zero to the first video PTS
  # keeps subtitle cues synchronized with AVPlayer's presentation timeline.
  VIDEO_START_TIME="$(ffprobe -v error \
    -show_entries format=start_time \
    -of csv=p=0 \
    "$TEMP_OUTPUT_DIR/video/1080p/segment_0000.ts")"
  if [[ -z "$VIDEO_START_TIME" ]]; then
    echo "Error: could not read the first video segment timestamp." >&2
    exit 1
  fi

  MPEGTS_TIMESTAMP="$(python3 -c \
    'import sys; print(round(float(sys.argv[1]) * 90000))' \
    "$VIDEO_START_TIME")"

  echo "Packaging Spanish and English WebVTT renditions..."
  python3 Scripts/package_webvtt_hls.py \
    "$SPANISH_SUBTITLES" \
    "$TEMP_OUTPUT_DIR/video/1080p/playlist.m3u8" \
    "$TEMP_OUTPUT_DIR/subtitles/es" \
    --mpegts-timestamp "$MPEGTS_TIMESTAMP"
  python3 Scripts/package_webvtt_hls.py \
    "$ENGLISH_SUBTITLES" \
    "$TEMP_OUTPUT_DIR/video/1080p/playlist.m3u8" \
    "$TEMP_OUTPUT_DIR/subtitles/en" \
    --mpegts-timestamp "$MPEGTS_TIMESTAMP"

  SUBTITLE_MEDIA_LINES='#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subtitles",NAME="Spanish",LANGUAGE="es",AUTOSELECT=YES,DEFAULT=NO,FORCED=NO,URI="subtitles/es/playlist.m3u8"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subtitles",NAME="English",LANGUAGE="en",AUTOSELECT=YES,DEFAULT=NO,FORCED=NO,URI="subtitles/en/playlist.m3u8"'
  SUBTITLE_STREAM_ATTRIBUTE=',SUBTITLES="subtitles"'
fi

# FFmpeg can generate the child playlists, but writing this small master file
# ourselves makes the language names, default track, and AUDIO group explicit.
cat > "$TEMP_OUTPUT_DIR/master.m3u8" <<MASTER
#EXTM3U
#EXT-X-VERSION:6
#EXT-X-INDEPENDENT-SEGMENTS
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Latin American Spanish",LANGUAGE="es",AUTOSELECT=YES,DEFAULT=YES,URI="audio/es/playlist.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",LANGUAGE="en",AUTOSELECT=YES,DEFAULT=NO,URI="audio/en/playlist.m3u8"
$SUBTITLE_MEDIA_LINES

#EXT-X-STREAM-INF:BANDWIDTH=5943379,AVERAGE-BANDWIDTH=4752406,RESOLUTION=1440x1080,FRAME-RATE=29.970,CODECS="avc1.4d4028,mp4a.40.2${SPANISH_SUBTITLES:+,wvtt}",AUDIO="audio"$SUBTITLE_STREAM_ATTRIBUTE
video/1080p/playlist.m3u8

#EXT-X-STREAM-INF:BANDWIDTH=3365343,AVERAGE-BANDWIDTH=2706441,RESOLUTION=960x720,FRAME-RATE=29.970,CODECS="avc1.4d401f,mp4a.40.2${SPANISH_SUBTITLES:+,wvtt}",AUDIO="audio"$SUBTITLE_STREAM_ATTRIBUTE
video/720p/playlist.m3u8

#EXT-X-STREAM-INF:BANDWIDTH=1748155,AVERAGE-BANDWIDTH=1386979,RESOLUTION=640x480,FRAME-RATE=29.970,CODECS="avc1.4d401e,mp4a.40.2${SPANISH_SUBTITLES:+,wvtt}",AUDIO="audio"$SUBTITLE_STREAM_ATTRIBUTE
video/480p/playlist.m3u8

#EXT-X-STREAM-INF:BANDWIDTH=962349,AVERAGE-BANDWIDTH=779165,RESOLUTION=480x360,FRAME-RATE=29.970,CODECS="avc1.4d401e,mp4a.40.2${SPANISH_SUBTITLES:+,wvtt}",AUDIO="audio"$SUBTITLE_STREAM_ATTRIBUTE
video/360p/playlist.m3u8
MASTER

# Catch missing output before replacing an existing valid stream.
for playlist in \
  master.m3u8 \
  video/1080p/playlist.m3u8 video/720p/playlist.m3u8 \
  video/480p/playlist.m3u8 video/360p/playlist.m3u8 \
  audio/es/playlist.m3u8 audio/en/playlist.m3u8; do
  if [[ ! -s "$TEMP_OUTPUT_DIR/$playlist" ]]; then
    echo "Error: expected playlist was not generated: $playlist" >&2
    exit 1
  fi
done

if [[ -n "$SPANISH_SUBTITLES" ]]; then
  for playlist in subtitles/es/playlist.m3u8 subtitles/en/playlist.m3u8; do
    if [[ ! -s "$TEMP_OUTPUT_DIR/$playlist" ]]; then
      echo "Error: expected subtitle playlist was not generated: $playlist" >&2
      exit 1
    fi
  done
fi

rm -rf "$OUTPUT_DIR"
mv "$TEMP_OUTPUT_DIR" "$OUTPUT_DIR"
trap - EXIT

PORT="${BURSTSTREAM_STREAM_PORT:-8000}"
cat <<DONE

Bilingual adaptive HLS stream created:
  $OUTPUT_DIR/master.m3u8

Simulator URL:
  http://localhost:$PORT/hls/$STREAM_NAME/master.m3u8

Video variants:
  1080p, 720p, 480p, 360p

Audio renditions:
  Latin American Spanish (default), English
DONE

if [[ -n "$SPANISH_SUBTITLES" ]]; then
  cat <<DONE

Subtitle renditions:
  Off (default), Spanish, English
DONE
fi
