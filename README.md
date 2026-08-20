# BurstStream

BurstStream is a hands-on **iOS HLS streaming learning lab and portfolio
project** built with SwiftUI, AVFoundation, and `AVPlayer`.

If video streaming is new to you, that is exactly what this repository is for.
You can begin with one video on your Mac and follow the guide step by step; you
do not need a cloud account or an existing media platform.

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

### Subtitles and AirPlay

- Spanish and English segmented WebVTT subtitle renditions
- Native AirPlay route selection with `AVRoutePickerView`
- External playback state observed from the existing `AVPlayer`
- LAN-aware guidance when `localhost` cannot be reached by Apple TV
- End-to-end validation with a physical iPhone, Apple TV, and Mac-hosted HLS

### Picture in Picture

- PiP built around the existing custom `AVPlayerLayer`
- System-standard manual start and stop control
- Automatic floating playback when the playing app moves to the background
- Published availability, active state, and failure information
- Audio, AirPlay, and Picture in Picture background playback capability

### Interruptions and lifecycle

- Safe pause and conditional resume for calls, Siri, alarms, and other audio interruptions
- Automatic pause when headphones, Bluetooth, AirPlay, or another external route disconnects
- Foreground and background policy that preserves valid PiP and AirPlay playback
- Media-services reset recovery with position, quality, audio, and subtitle restoration
- A visible system-lifecycle panel for physical-device experiments

### Continue Watching

- Stable stream identity that survives app relaunches
- Saved position, duration, quality, audio, and subtitle preferences
- Friendly **Continue** and **Start Over** actions on the home screen
- 30-second resume and 90-percent completion rules
- Throttled periodic saves plus background and exit checkpoints
- Unit tests for persistence, thresholds, throttling, and restoration races

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

- Optional local AI transcription with whisper.cpp:

```bash
brew install whisper-cpp
mkdir -p ~/Library/Caches/BurstStream/Whisper
curl -L \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin \
  -o ~/Library/Caches/BurstStream/Whisper/ggml-small.bin
```

The current Xcode project targets iOS 18.0 and supports both iPhone and iPad.

## Quick start

### 1. Clone and open the project

```bash
git clone git@github.com:oscast/burststream-ios.git
cd burststream-ios
open BurstStream.xcodeproj
```

### 2. Package a video as HLS

BurstStream does not include a video because media files are usually large and
may be copyrighted. Instead, you can use a video of your own.

Start by copying an MP4, MKV, or MOV file into `LocalMedia/sources/`. For
example:

```bash
cp ~/Movies/my-video.mp4 LocalMedia/sources/
```

Your local media workspace will then look like this:

```text
LocalMedia/
├── sources/
│   └── my-video.mp4       Your original video
└── hls/                   Created by the packaging scripts
```

Now choose one of the packaging options below. If you are following the
streaming lessons, the **adaptive HLS** option is the recommended place to
start.

#### Option A: Single-quality HLS

This creates one video quality. It is the simplest option for learning what an
HLS playlist and its media segments look like. FFmpeg encodes one H.264/AAC
rendition, divides it into approximately six-second MPEG-TS segments, and
writes a complete VOD playlist. It does not create resolutions for automatic
quality switching.

```bash
Scripts/prepare-local-hls.sh LocalMedia/sources/my-video.mp4 my-video
```

The first `my-video.mp4` is your source file. The final `my-video` is the name
of the stream that the script will create under `LocalMedia/hls/`.

#### Option B: Adaptive HLS — recommended

This creates 1080p, 720p, 480p, and 360p versions. `AVPlayer` can switch
between them as network conditions change, which makes this the most useful
option for studying adaptive bitrate streaming.

```bash
Scripts/prepare-adaptive-hls.sh LocalMedia/sources/my-video.mp4 my-video-adaptive
```

#### Option C: Adaptive HLS with Spanish and English audio

Use this when you have two synchronized videos with the same visual timeline:
one with Spanish audio and another with English audio. The script creates one
shared adaptive video ladder and two selectable audio tracks.

```bash
Scripts/prepare-bilingual-hls.sh \
  LocalMedia/sources/episode-spanish.mp4 \
  LocalMedia/sources/episode-english.mp4 \
  my-video-bilingual
```

When a script finishes, it prints the path to the generated `master.m3u8`
playlist. Your original video stays unchanged, and the generated streaming
files appear under `LocalMedia/hls/`.

> The source videos and generated HLS files stay on your Mac and are ignored by
> Git. This prevents large media files from being uploaded if you fork the
> repository or commit your own changes. If you prefer not to copy a large
> video into the project, the scripts also accept its full path, such as
> `/Users/your-name/Movies/my-video.mkv`.

#### Optional: Generate subtitles with local AI

If your video does not include subtitles, do not worry. BurstStream can create
a local first draft from the spoken audio with
`Scripts/transcribe-subtitles.sh`. The script prepares mono 16 kHz audio for
whisper.cpp and generates WebVTT for HLS, SRT for convenient editing, and JSON
for detailed review.

Run the script once for each dubbed-language video. For example, start with the
Spanish version:

```bash
BURSTSTREAM_WHISPER_PROMPT="Teddy Ruxpin, Grundo, Rarilonia" \
Scripts/transcribe-subtitles.sh \
  LocalMedia/sources/episode-spanish.mp4 \
  es \
  my-video-bilingual
```

The second argument is the spoken language code. Run the script once for each
audio language, using `es` for Spanish and `en` for English. Generated files
appear under:

```text
LocalMedia/subtitles/my-video-bilingual/
├── es/
│   ├── subtitles.vtt
│   ├── subtitles.srt
│   └── transcription.json
└── en/
    ├── subtitles.vtt
    ├── subtitles.srt
    └── transcription.json
```

AI transcription is a starting point, not a finished publication. Review
names, fictional vocabulary, songs, overlapping dialogue, and punctuation
against the original audio. The prompt helps Whisper recognize uncommon names.

Why does the HLS workflow use WebVTT? It is readable text, `AVPlayer` supports
it as a selectable HLS subtitle rendition, and it can follow the same segmented
timeline as the video. The SRT copy is included because it is convenient in
many subtitle editors.

Pass the reviewed WebVTT files to the bilingual packager to expose them as HLS
subtitle renditions:

```bash
Scripts/prepare-bilingual-hls.sh \
  LocalMedia/sources/episode-spanish.mp4 \
  LocalMedia/sources/episode-english.mp4 \
  my-video-bilingual \
  LocalMedia/subtitles/my-video-bilingual/es/subtitles.vtt \
  LocalMedia/subtitles/my-video-bilingual/en/subtitles.vtt
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
├── audio/
    ├── es/
    └── en/
└── subtitles/
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

The published guide is available at:

[https://oscast.github.io/burststream-ios/](https://oscast.github.io/burststream-ios/)

It covers HLS fundamentals, architecture, playback and buffering, reliability,
ABR, network experiments, diagnostics, bilingual audio, subtitles, AirPlay,
Picture in Picture, interruptions, Continue Watching, and reproducible study
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

- Physical-device interruption and route-change validation
- Stale Continue Watching cleanup for deleted or replaced catalog media
- A series-and-episodes catalog home backed by a configurable HLS server
- External-SSD or second-laptop media hosting without hardcoded disk paths
- Offline HLS downloads
- Live-stream behavior
- Playback analytics
- FairPlay concepts
