---
layout: home
title: BurstStream Documentation
---

# Learn HLS Streaming on iOS

BurstStream is a hands-on learning lab for building a streaming client with
SwiftUI, AVFoundation, and `AVPlayer`. These documents explain not only what the
code does, but why streaming applications need each behavior.

The guide starts with media fundamentals and progresses through custom playback,
buffering, failure recovery, adaptive bitrate, network experiments, diagnostics,
and alternate audio.

> The project is an educational client and local-development environment. It is
> not a production CDN, transcoding platform, or media service.

## Learning path

1. [Getting started](getting-started.md) — install the tools, package a video,
   start the server, and run the app.
2. [HLS fundamentals](hls-fundamentals.md) — containers, codecs, playlists,
   segments, keyframes, and local HTTP delivery.
3. [Player architecture](architecture.md) — responsibilities of the SwiftUI
   views, `PlayerViewModel`, `AVPlayerItem`, `AVPlayer`, and `AVPlayerLayer`.
4. [Playback controls and buffering](playback-and-buffering.md) — state,
   `CMTime`, seeking, scrubbing, and loaded ranges.
5. [Reliability and diagnostics](reliability-and-diagnostics.md) — retries,
   access logs, error logs, and live playback metrics.
6. [Adaptive streaming](adaptive-streaming.md) — the quality ladder, ABR,
   quality ceilings, segment alignment, and iPad layouts.
7. [Network and ABR experiments](network-and-abr.md) — local throttling,
   latency, offline simulation, and experiment history.
8. [Bilingual audio](bilingual-audio.md) — shared video, alternate audio
   renditions, and `AVMediaSelectionGroup`.
9. [Experiments](experiments.md) — reproducible exercises for studying player
   behavior.
10. [Glossary](glossary.md) — concise definitions of the key terms.

## Current feature coverage

| Area | Implemented |
|---|---|
| HLS VOD playback | Yes |
| Custom playback controls | Yes |
| Exact seeking and scrubbing | Yes |
| Buffer visualization | Yes |
| Retry with exponential backoff | Yes |
| Four-level adaptive quality ladder | Yes |
| Runtime network simulation | Yes |
| AVPlayer access/error diagnostics | Yes |
| ABR experiment history | Yes |
| Spanish and English alternate audio | Yes |
| WebVTT subtitles | Next |
| Picture in Picture | Planned |
| AirPlay | Planned |
| Offline downloads | Planned |

## How to use these documents

Read the chapters in order if you are new to streaming. If you already know
HLS, use the topic links as reference documentation. Each chapter links the
concepts to files in the repository and ends with practical takeaways.

[Start with Getting Started →](getting-started.md)
