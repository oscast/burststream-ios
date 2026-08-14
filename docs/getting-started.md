---
layout: page
title: Getting Started
---

# Getting Started

[Documentation home](index.md) · [Next: HLS fundamentals →](hls-fundamentals.md)

## Requirements

- macOS and Xcode
- An iOS Simulator or physical iPhone/iPad
- Homebrew
- FFmpeg and FFprobe

Install FFmpeg:

```bash
brew install ffmpeg
```

## Open the project

```bash
git clone git@github.com:oscast/burststream-ios.git
cd burststream-ios
open BurstStream.xcodeproj
```

## Package your media

BurstStream includes an empty, documented local workspace:

```text
LocalMedia/
├── sources/   Place source MP4, MKV, or MOV files here
└── hls/       Packaging scripts create this output automatically
```

The instructional README files are tracked, but actual source videos and HLS
output are ignored. Place media you have permission to use under `sources/`, or
pass an absolute path to a file stored elsewhere.

### Single-quality HLS

This is the simplest packaging option. It converts one source video into one
streaming quality instead of creating several resolutions for adaptive
switching.

```bash
Scripts/prepare-local-hls.sh LocalMedia/sources/my-video.mp4 my-video
```

The command has two inputs:

```text
LocalMedia/sources/my-video.mp4   Source video to convert
my-video                         Name of the generated stream folder
```

The script uses FFmpeg to:

1. read the MP4, MKV, MOV, or other FFmpeg-compatible source;
2. encode its video as H.264 without intentionally changing its dimensions;
3. encode its audio as 128 Kbps stereo AAC;
4. place keyframes every two seconds for seeking and segment boundaries;
5. divide the encoded presentation into MPEG-TS files of approximately six
   seconds each;
6. create a complete VOD playlist listing those segments; and
7. replace the previous output only after the entire conversion succeeds.

For example, the command above produces:

```text
LocalMedia/hls/my-video/
├── master.m3u8
├── segment_000.ts
├── segment_001.ts
└── ...
```

Despite its filename, this single-quality `master.m3u8` directly lists media
segments, so it is technically a **media playlist**. The project keeps the
filename consistent with its other stream URLs.

When `AVPlayer` opens this playlist, it can request and buffer the segments as
needed, but it cannot change between 360p, 720p, and 1080p because only one
rendition exists. Use this option to study basic HLS packaging and requests;
use adaptive HLS to study automatic quality switching.

### Adaptive HLS

```bash
Scripts/prepare-adaptive-hls.sh LocalMedia/sources/my-video.mp4 my-video-adaptive
```

This creates aligned 1080p, 720p, 480p, and 360p renditions.

### Bilingual adaptive HLS

```bash
Scripts/prepare-bilingual-hls.sh \
  LocalMedia/sources/episode-spanish.mp4 \
  LocalMedia/sources/episode-english.mp4 \
  my-video-bilingual
```

Use a short test before processing a long episode:

```bash
BURSTSTREAM_HLS_TEST_DURATION=30 \
Scripts/prepare-bilingual-hls.sh \
  LocalMedia/sources/episode-spanish.mp4 \
  LocalMedia/sources/episode-english.mp4 \
  bilingual-test
```

The scripts build in a temporary directory and replace the final directory only
after FFmpeg succeeds. A failed conversion therefore does not destroy a valid
package currently served to the player.

## Start the development server

```bash
Scripts/serve-local-hls.sh 8000
```

Keep this process running while testing. For the Simulator, load:

```text
http://localhost:8000/hls/my-video-bilingual/master.m3u8
```

For a physical device on the same Wi-Fi, use the Mac's LAN address:

```text
http://192.168.1.25:8000/hls/my-video-bilingual/master.m3u8
```

`localhost` on a physical iPhone, iPad, or Apple TV refers to that device, not
the development Mac.

## Run BurstStream

1. Choose an iPhone or iPad Simulator in Xcode.
2. Run the app.
3. Enter the HLS master URL or use the configured local stream.
4. Select **Load stream**.
5. Open the diagnostics and experiment with quality and network controls.

## Related files

```text
Scripts/prepare-local-hls.sh
Scripts/prepare-adaptive-hls.sh
Scripts/prepare-bilingual-hls.sh
Scripts/serve-local-hls.sh
Scripts/throttled_hls_server.py
```

[← Documentation home](index.md) · [Next: HLS fundamentals →](hls-fundamentals.md)
