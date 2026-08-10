---
layout: page
title: Bilingual Audio
---

# Bilingual Audio

[← Network and ABR](network-and-abr.md) · [Documentation home](index.md) · [Next: Experiments →](experiments.md)

## Shared video, separate audio

A bilingual package should not duplicate every video rendition for every
language. Video consumes far more storage and bandwidth than audio.

BurstStream uses this structure:

```text
my-video-bilingual/
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

Both languages share the same four video playlists.

## Declaring alternate audio in HLS

The master playlist defines an audio group:

```m3u8
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Latin American Spanish",LANGUAGE="es",DEFAULT=YES,URI="audio/es/playlist.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",LANGUAGE="en",DEFAULT=NO,URI="audio/en/playlist.m3u8"
```

Every video rendition references that group:

```m3u8
#EXT-X-STREAM-INF:RESOLUTION=1440x1080,AUDIO="audio",...
video/1080p/playlist.m3u8
```

## Aligning source durations

Two separately prepared language files may differ by a fraction of a second.
The packaging script uses the Spanish video as the shared timeline and pads a
slightly shorter English audio source with silence. AAC frame boundaries can
leave a tiny final duration difference; this is normal.

## Discovering audio in AVFoundation

Once the item is ready, the view model loads its audible selection group:

```swift
let group = try await item.asset.loadMediaSelectionGroup(for: .audible)
```

`AVMediaSelectionGroup` represents the complete audio group, and each
`AVMediaSelectionOption` represents one rendition.

The view receives lightweight `AudioTrackOption` values instead of owning
AVFoundation objects.

## Switching language

```swift
item.select(mediaOption, in: group)
```

This changes audio on the existing item, preserving:

- playback position;
- buffered video;
- play/pause state;
- quality ceiling.

The preferred language is stored so a retry or quality-triggered item rebuild
can restore it afterward.

## Default-language behavior

Device language preferences may override the HLS `DEFAULT` declaration.
BurstStream explicitly selects `group.defaultOption` for deterministic initial
behavior, then honors the user's in-app choice.

## Related files

```text
Scripts/prepare-bilingual-hls.sh
BurstStream/AudioTrackOption.swift
BurstStream/PlayerViewModel.swift
BurstStream/ContentView.swift
```

[← Network and ABR](network-and-abr.md) · [Next: Experiments →](experiments.md)
