---
layout: page
title: Player Architecture
---

# Player Architecture

[← HLS fundamentals](hls-fundamentals.md) · [Documentation home](index.md) · [Next: Playback and buffering →](playback-and-buffering.md)

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

## Related files

```text
BurstStream/ContentView.swift
BurstStream/PlayerViewModel.swift
BurstStream/PlayerSurface.swift
BurstStream/AirPlayRoutePicker.swift
BurstStream/PlaybackAudioSession.swift
BurstStream/RetryPolicy.swift
BurstStream/PlaybackState.swift
```

[← HLS fundamentals](hls-fundamentals.md) · [Next: Playback and buffering →](playback-and-buffering.md)
