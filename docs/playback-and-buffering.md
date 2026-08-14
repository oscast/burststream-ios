---
layout: page
title: Playback and Buffering
---

# Playback Controls and Buffering

[← Architecture](architecture.md) · [Documentation home](index.md) · [Next: Reliability and diagnostics →](reliability-and-diagnostics.md)

A play button is easy to draw. Keeping that button, the timeline, and the real
player synchronized is the interesting part. This chapter explains the state
and timing decisions behind controls that feel predictable.

Do not worry if `CMTime` or asynchronous seeking is new to you. We will connect
each concept to something visible in the app.

## Playback state is a combination of signals

AVFoundation does not provide one property that explains the complete player
state. BurstStream combines `AVPlayerItem.status` with
`AVPlayer.timeControlStatus` and local flags.

| BurstStream state | Meaning |
|---|---|
| Loading | The item has not become ready yet |
| Ready | The item can play but has not started |
| Playing | The player clock is advancing |
| Paused | The user stopped playback |
| Buffering | The player wants to play but is waiting for data |
| Retrying | Recovery is scheduled after a failure |
| Failed | Automatic recovery was exhausted |
| Ended | Playback reached the end |

Loading and buffering are different: loading prepares initial playback, while
buffering occurs when a ready player cannot continue smoothly.

## CMTime

AVFoundation uses `CMTime` rather than `Double` because media timelines require
controlled precision. The interface converts valid finite times into seconds
for sliders and labels.

## Periodic timeline observation

The player reports time four times per second. This is smooth enough for the
slider without updating the interface for every video frame.

The observer also refreshes duration and polls the current access-log entry once
per second because fields in an existing log event may continue changing.

## Exact seeking

BurstStream requests zero seek tolerance:

```swift
player.seek(
    to: target,
    toleranceBefore: .zero,
    toleranceAfter: .zero
)
```

This favors educational precision over the faster alternative of accepting a
nearby keyframe.

Every seek has an identifier. If an older asynchronous completion arrives after
a newer seek, the view model ignores it instead of moving the slider backward.

## Scrubbing

Dragging the timeline uses temporary UI state:

1. The slider stops following periodic player updates.
2. The user's finger controls the displayed position.
3. Releasing the slider performs one seek.
4. Normal synchronization resumes after completion.

This prevents the slider from fighting the player clock while it is being
dragged.

## Loaded time ranges

`loadedTimeRanges` can contain multiple intervals. A seek may download content
far from the original buffer and produce separated ranges.

BurstStream models every range and draws them beneath the timeline. Buffer ahead
means only the downloaded time following the current position, not the total
number of seconds downloaded anywhere in the episode.

## Related files

```text
BurstStream/Playback/Core/PlayerViewModel.swift
BurstStream/Playback/Core/PlaybackState.swift
BurstStream/Playback/Core/PlaybackBufferRange.swift
BurstStream/App/ContentView.swift
```

[← Architecture](architecture.md) · [Next: Reliability and diagnostics →](reliability-and-diagnostics.md)
