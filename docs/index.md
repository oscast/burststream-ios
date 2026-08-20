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
alternate audio, and subtitles.

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
9. [WebVTT subtitles](subtitles.md) — AI transcription, HLS subtitle packaging,
   timestamp mapping, and legible media selection.
10. [AirPlay](airplay.md) — system route selection, external playback state,
    and LAN delivery to Apple TV.
11. [Picture in Picture](picture-in-picture.md) — floating playback, automatic
    background entry, and custom-player integration.
12. [Interruptions and playback lifecycle](interruptions-and-lifecycle.md) —
    calls, Siri, route changes, media-service recovery, and scene policy.
13. [Continue Watching](continue-watching.md) — stable content identity,
    persistence thresholds, restoration timing, and resume behavior.
14. [Professional readiness roadmap](professional-roadmap.md) — prioritized
    client-side work for lifecycle handling, persistence, recovery, QoE,
    testing, accessibility, PiP, and offline playback.
15. [Experiments](experiments.md) — reproducible exercises for studying player
    behavior.
16. [Glossary](glossary.md) — concise definitions of the key terms.

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
| Spanish and English WebVTT subtitles | Yes |
| AirPlay route selection and external playback state | Yes — validated on iPhone and Apple TV |
| Picture in Picture | Yes — validated on physical hardware |
| Interruptions, route changes, and media-service recovery | Yes — physical-device validation pending |
| Continue Watching persistence | Yes — public sample testing available without LAN |
| Offline downloads | Planned |

## How to use these documents

Read the chapters in order if you are new to streaming. If you already know
HLS, use the topic links as reference documentation. Each chapter links the
concepts to files in the repository and ends with practical takeaways.

[Start with Getting Started →](getting-started.md)
