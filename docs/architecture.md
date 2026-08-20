---
layout: page
title: Player Architecture
---

# Player Architecture

[← HLS fundamentals](hls-fundamentals.md) · [Documentation home](index.md) · [Next: Playback and buffering →](playback-and-buffering.md)

Names such as `AVPlayerItem`, `AVPlayer`, and `AVPlayerLayer` look very similar
when you first meet them. Each one has a small, different job. Once those jobs
are clear, the rest of the player becomes much easier to follow.

This project deliberately uses only a few layers. The goal is readable code you
can study, not an architecture diagram filled with unnecessary abstractions.

## Design goal

BurstStream keeps playback logic out of SwiftUI views without creating layers
that do not solve a real problem.

```text
StreamPlayerView
    ↓ observes state and sends actions
PlayerViewModel
    ↓ coordinates
AVPlayer / AVPlayerItem
    ↓ presented by
PlayerSurface / AVPlayerLayer
    ↓ provides source layer to
PictureInPictureController

System notifications / scenePhase
    ↓ interpreted by
PlaybackLifecycleController
    ↓ sends safe play, pause, and recovery actions to
PlayerViewModel

PlaybackProgressController
    ↓ stores lightweight bookmarks through
PlaybackProgressStoring
```

## AVPlayerItem

`AVPlayerItem` represents the media being played. It exposes:

- readiness and failure status;
- duration;
- loaded time ranges;
- presentation size;
- access and error logs;
- media-selection groups;
- quality preferences.

Replacing the item discards its old media buffer. BurstStream intentionally does
this when changing the educational quality ceiling so the result is visible
immediately.

## AVPlayer

`AVPlayer` is the long-lived playback engine. It controls:

- play and pause;
- current time and seeking;
- the current item;
- whether playback is paused, waiting, or advancing.

The player remains stable when an item is replaced, which keeps the view and
most observations intact.

## AVPlayerLayer

`AVPlayerLayer` renders video frames. `PlayerSurface` wraps it for SwiftUI. The
layer does not provide controls, so BurstStream can build its own interface and
observe the exact behavior being studied.

The same layer is also the inline source for `AVPictureInPictureController`.
PiP therefore keeps the existing `AVPlayer` and timeline instead of creating a
second playback engine.

## PlayerViewModel

The view model owns coordination that would otherwise be scattered across the
view:

- playback state mapping;
- timeline and buffer observations;
- exact seeking;
- retry scheduling;
- item reconstruction;
- quality preferences;
- diagnostics snapshots;
- alternate-audio discovery and selection;
- subtitle discovery and selection;
- external AirPlay state observation.

Its published properties are lightweight values suitable for SwiftUI.
AVFoundation-specific selection objects remain private.

## Pragmatic dependency injection

Protocols are introduced only for boundaries with meaningful alternatives. For
example, retry waiting uses `RetryScheduling`, so tests can avoid real delays.

A pure calculation such as converting `loadedTimeRanges` into buffer ranges does
not need a protocol when it has only one obvious implementation.

## Main-actor isolation

`PlayerViewModel` is `@MainActor` because SwiftUI expects published interface
state on the main actor. KVO and notification callbacks return to the main actor
before changing state.

## Responsive layout

Portrait uses one column. iPad landscape places video and controls on the left
and technical information on the right. Rotation does not recreate the player,
so playback continues at the same position.

## Source organization

The source tree is grouped by feature rather than broad folders such as
`Managers` or `Helpers`:

```text
BurstStream/
├── App/
├── Streaming/
├── Playback/
│   ├── Core/
│   ├── UI/
│   ├── MediaSelection/
│   └── SystemFeatures/
├── Persistence/
├── NetworkSimulation/
├── Diagnostics/
└── Resources/
```

`Streaming` describes selectable HLS sources. `Playback` owns AVPlayer behavior
and its interface. `Persistence` owns Continue Watching records and policy;
it receives lightweight snapshots rather than owning AVPlayer.
`NetworkSimulation` talks only to the development throttling server.
`Diagnostics` records and presents what happened during playback.

## Related files

```text
BurstStream/App/ContentView.swift
BurstStream/Streaming/SampleStreams.swift
BurstStream/Playback/UI/StreamPlayerView.swift
BurstStream/Playback/Core/PlayerViewModel.swift
BurstStream/Playback/UI/PlayerSurface.swift
BurstStream/Playback/SystemFeatures/AirPlayRoutePicker.swift
BurstStream/Playback/SystemFeatures/PictureInPictureController.swift
BurstStream/Playback/SystemFeatures/PlaybackLifecycleController.swift
BurstStream/Playback/SystemFeatures/PlaybackAudioSession.swift
BurstStream/Playback/Core/RetryPolicy.swift
BurstStream/Playback/Core/PlaybackState.swift
BurstStream/Persistence/PlaybackProgressController.swift
BurstStream/Persistence/PlaybackProgressStore.swift
```

[← HLS fundamentals](hls-fundamentals.md) · [Next: Playback and buffering →](playback-and-buffering.md)
