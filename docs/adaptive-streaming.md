---
layout: page
title: Adaptive Streaming
---

# Adaptive Streaming

[← Reliability and diagnostics](reliability-and-diagnostics.md) · [Documentation home](index.md) · [Next: Network and ABR →](network-and-abr.md)

Have you noticed a streaming video become blurry on a slow connection and
sharper again when the network improves? That is adaptive bitrate streaming,
usually shortened to ABR.

Instead of trusting one large video quality to work everywhere, BurstStream
offers several versions of the same timeline and lets `AVPlayer` choose the
safest one for the current conditions.

## The quality ladder

BurstStream packages the same 4:3 content at four levels:

| Rendition | Resolution | Target video bitrate |
|---|---:|---:|
| 1080p | 1440 × 1080 | 4.5 Mbps |
| 720p | 960 × 720 | 2.5 Mbps |
| 480p | 640 × 480 | 1.2 Mbps |
| 360p | 480 × 360 | 0.6 Mbps |

The source is decoded once, split into four branches, and scaled with FFmpeg.
All branches receive matching keyframes and segment boundaries.

## How AVPlayer chooses quality

In automatic mode, `AVPlayer` considers information including:

- measured network throughput;
- current and target buffer health;
- advertised rendition bandwidth;
- display size and preferred resolution;
- recent playback stability.

ABR is dynamic. A fast connection does not guarantee 1080p forever, and a slow
connection can recover to a higher rendition after conditions improve.

## Quality ceilings

The app exposes educational maximums through:

```swift
item.preferredPeakBitRate
item.preferredMaximumResolution
```

These are ceilings, not exact-quality commands. **Up to 720p** excludes 1080p,
but `AVPlayer` may still choose 480p or 360p to prevent buffering.

The bitrate ceiling must be slightly above the rendition's declared
`BANDWIDTH`; setting it below that value makes the desired rendition ineligible.

## Why BurstStream rebuilds the item

Changing preferences affects future downloads, but an item may already contain
many old-quality segments. For immediate comparison, BurstStream creates a new
item at the same position and discards the previous buffer.

This is useful for a learning control. A production application would normally
let ABR transition naturally to avoid throwing away downloaded media.

## Visual differences

Upscaling an old low-resolution source adds encoded pixels but cannot recreate
native detail that was never captured. Flat-color animation can make rendition
differences subtle. Diagnostics are therefore more reliable than eyesight alone
when confirming the selected quality.

## iPad landscape

The larger landscape layout makes quality differences easier to inspect. The
video retains its detected aspect ratio instead of being stretched to fill a
16:9 frame.

## Related files

```text
Scripts/prepare-adaptive-hls.sh
BurstStream/Playback/Core/PlaybackQualityLimit.swift
BurstStream/Playback/Core/PlayerViewModel.swift
BurstStream/App/ContentView.swift
```

[← Reliability and diagnostics](reliability-and-diagnostics.md) · [Next: Network and ABR →](network-and-abr.md)
