# BurstStream

BurstStream is a hands-on **iOS HLS streaming learning lab and portfolio
project** built with SwiftUI, AVFoundation, and `AVPlayer`.

It is designed to study how a real streaming client loads HLS playlists,
buffers media, seeks, recovers from failures, switches adaptive bitrate (ABR)
variants, and selects alternate audio renditions. It also includes local tools
for packaging your own videos as HLS and simulating different network
conditions.

> BurstStream is an educational client and local-development environment. It is
> not a production video platform, CDN, transcoding service, or media server.

## What the project demonstrates

### Playback

- HLS `.m3u8` playback with `AVPlayer` and `AVPlayerLayer`
- Custom play, pause, skip, timeline, and exact scrubbing controls
- Playback state derived from `AVPlayerItem.status` and
  `AVPlayer.timeControlStatus`
- Visualized loaded buffer ranges
- Automatic retry with exponential backoff
- Responsive iPhone and iPad layouts, including iPad landscape

### Adaptive streaming

- A four-level 4:3 quality ladder: 1080p, 720p, 480p, and 360p
- Automatic ABR selection by `AVPlayer`
- Educational quality ceilings using `preferredPeakBitRate` and
  `preferredMaximumResolution`
- Access-log diagnostics for throughput, indicated bitrate, requests, bytes,
  stalls, and the current resource
- A bounded ABR experiment history with Swift Charts

### Alternate audio

- One shared adaptive video ladder with separate Spanish and English audio
  renditions
- Audio discovery through `AVMediaSelectionGroup`
- Seamless Latin American Spanish / English switching without restarting playback
- Restoration of the selected language after retrying or rebuilding an
  `AVPlayerItem`

### Local streaming tools

- FFmpeg scripts for single-quality, adaptive, and bilingual HLS packaging
- Atomic output replacement so a failed transcode does not replace a valid HLS
  package
- A threaded local HTTP server for Simulator and LAN testing
- Runtime profiles for bandwidth limits, latency, and offline simulation

## Architecture

The app intentionally uses a small, pragmatic structure:

```text
SwiftUI views
    ↓ render state and send user actions
PlayerViewModel
    ↓ coordinates
AVPlayer / AVPlayerItem
    ↓ rendered by
PlayerSurface / AVPlayerLayer
```

Protocols and dependency injection are used only at useful boundaries, such as
retry scheduling. The project avoids adding layers that do not yet solve a
real problem.

## Requirements

- macOS with Xcode
- iOS Simulator or a physical iPhone/iPad
- [Homebrew](https://brew.sh/) for installing FFmpeg
- FFmpeg and FFprobe:

```bash
brew install ffmpeg
```

The current Xcode project targets iOS 26.5 and supports both iPhone and iPad.

## Quick start

### 1. Clone and open the project

```bash
git clone git@github.com:oscast/burststream-ios.git
cd burststream-ios
open BurstStream.xcodeproj
```

### 2. Package a video as HLS

Use the local media workspace included in the clone:

```text
LocalMedia/
├── sources/   User-provided MP4, MKV, or MOV files
└── hls/       Generated playlists and media segments
```

Actual source and generated media are intentionally ignored by Git. The
instructional README files remain tracked so every clone explains the workflow.
You may alternatively pass an absolute path to a source stored elsewhere.

#### Single quality

```bash
Scripts/prepare-local-hls.sh LocalMedia/sources/my-video.mp4 my-video
```

#### Adaptive 1080p/720p/480p/360p

```bash
Scripts/prepare-adaptive-hls.sh LocalMedia/sources/my-video.mp4 my-video-adaptive
```

#### Adaptive video with Spanish and English audio

```bash
Scripts/prepare-bilingual-hls.sh \
  LocalMedia/sources/episode-spanish.mp4 \
  LocalMedia/sources/episode-english.mp4 \
  my-video-bilingual
```

The bilingual package has this structure:

```text
LocalMedia/hls/my-video-bilingual/
├── master.m3u8
├── video/
│   ├── 1080p/
│   ├── 720p/
│   ├── 480p/
│   └── 360p/
└── audio/
    ├── es/
    └── en/
```

The video variants are shared by both languages instead of being duplicated.

For a quick 30-second packaging test:

```bash
BURSTSTREAM_HLS_TEST_DURATION=30 \
Scripts/prepare-bilingual-hls.sh \
  LocalMedia/sources/episode-spanish.mp4 \
  LocalMedia/sources/episode-english.mp4 \
  bilingual-test
```

### 3. Start the local HLS server

```bash
Scripts/serve-local-hls.sh 8000
```

Keep this process running while using the app.

The server can start with a simulated network profile:

```bash
Scripts/serve-local-hls.sh 8000 2mbps
```

Available profiles:

```text
fast, 5mbps, 2mbps, 1.2mbps, 800kbps, high-latency, offline
```

Profiles can also be changed from the player while playback is running.

### 4. Load the stream

For the iOS Simulator:

```text
http://localhost:8000/hls/my-video-bilingual/master.m3u8
```

For a physical device on the same Wi-Fi, replace `localhost` with the Mac's LAN
IP address:

```text
http://192.168.1.25:8000/hls/my-video-bilingual/master.m3u8
```

`localhost` on a physical Apple TV, iPhone, or iPad refers to that device—not
to the Mac—so a LAN IP or remotely hosted HTTPS URL is required.

## Why HLS?

HLS describes media through playlists and divides it into small HTTP segments.
Instead of downloading one complete movie before playback, `AVPlayer` requests
segments as they are needed. A master playlist can advertise multiple video
qualities, audio languages, and subtitle renditions.

This enables the core behaviors studied in BurstStream:

- progressive buffering;
- seeking to content that has not been downloaded yet;
- automatic quality adaptation;
- alternate audio and subtitles;
- live and video-on-demand playback.

## Documentation

The segmented learning guide is available under `docs/` and is designed to be
published as a GitHub Pages site:

[BurstStream documentation](docs/index.md)

After GitHub Pages is enabled, the published site is available at:

[https://oscast.github.io/burststream-ios/](https://oscast.github.io/burststream-ios/)

It covers HLS fundamentals, architecture, playback and buffering, reliability,
ABR, network experiments, diagnostics, bilingual audio, and reproducible study
exercises.

## Media and repository policy

This repository does **not** include source videos, generated `.ts` segments,
or local HLS packages. `LocalMedia/sources/` is only an ignored workspace.
Contributors must use media they have the right to process and distribute.

The following remain local:

```text
LocalMedia/
Xcode user data
Derived build products
```

## Roadmap

- WebVTT subtitle renditions and subtitle selection
- Picture in Picture
- AirPlay
- Resume-progress persistence
- Offline HLS downloads
- Live-stream behavior
- Playback analytics
- FairPlay concepts
