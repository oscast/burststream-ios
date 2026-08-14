---
layout: page
title: AirPlay
---

# AirPlay

[← WebVTT subtitles](subtitles.md) · [Documentation home](index.md) · [Next: Experiments →](experiments.md)

## Implementation status

AirPlay is implemented and has been validated end to end with a physical
iPhone 14 Pro, an Apple TV, and the bilingual HLS stream served from the Mac
over the local network. Playback handoff, external-playback state, and remote
media presentation worked successfully.

The first Xcode device preparation required a USB connection so the developer
disk could be mounted. After preparation, the media itself continued to travel
over the LAN; the cable was not part of the AirPlay media path.

## What AirPlay changes

BurstStream does not upload video from the iPhone frame by frame and does not
create a second player. The existing `AVPlayer` hands external playback to the
route selected by the user. The app's play, pause, seek, audio, and subtitle
controls continue operating that same player.

```text
iPhone or iPad
  ├─ displays BurstStream controls
  ├─ owns the AVPlayer
  └─ selects an AirPlay route
                    ↓
                Apple TV
                    ↓ requests playlists and segments
             Mac HLS server
```

This last connection is important: every participating device must be able to
reach the stream URL.

## The system route picker

`AVRoutePickerView` provides Apple's supported AirPlay button and route menu.
It performs discovery and selection using system behavior:

```swift
let routePicker = AVRoutePickerView()
routePicker.prioritizesVideoDevices = true
```

`AirPlayRoutePicker` is only a small `UIViewRepresentable` bridge that lets the
UIKit control appear in SwiftUI. BurstStream does not create a custom device
list because iOS intentionally owns that interface.

## External playback state

The player explicitly permits external playback:

```swift
player.allowsExternalPlayback = true
```

`PlayerViewModel` observes `isExternalPlaybackActive`. When it becomes `true`,
the player panel explains that playback is external while the local controls
remain active. AVFoundation manages the actual handoff.

The public playback API reports whether external playback is active, but does
not provide a dependable application-level name for the selected television.
The system route menu remains the authoritative place to see and change the
device.

## Why localhost fails

`localhost` always means *this same machine*:

- in Simulator, it identifies the Mac;
- on an iPhone, it identifies the iPhone;
- on Apple TV, it identifies the Apple TV.

Therefore this Simulator URL is unsuitable for real AirPlay:

```text
http://localhost:8000/hls/my-video/master.m3u8
```

Start the server and use the LAN URL that it prints:

```bash
Scripts/serve-local-hls.sh 8000
```

Example:

```text
http://192.168.1.25:8000/hls/my-video/master.m3u8
```

The Mac, iPhone or iPad, and Apple TV must be on a network where they can reach
one another. The generated app configuration includes a local-network usage
description so iOS can ask for the necessary permission.

## How to test

The Simulator is useful for checking the panel layout, but it is not a complete
AirPlay test environment. For end-to-end testing:

1. Start the local HLS server on the Mac.
2. Connect the Mac, physical iPhone or iPad, and Apple TV to the same LAN.
3. On the physical device, enter the printed LAN URL instead of `localhost`.
4. Start playback.
5. Tap the AirPlay button and select the Apple TV.
6. Confirm that the player says **Playing with AirPlay**.
7. Test play, pause, seeking, audio languages, subtitles, and quality behavior.
8. Open the route menu again and return playback to the local device.

BurstStream also includes a development-only **Play Teddy Ruxpin over LAN /
AirPlay** shortcut for the validated local address. Because that address is
assigned by the router, update `LocalStreams.teddyRuxpinBilingualLAN` if the
Mac's LAN IP changes.

If the Apple TV cannot load the video, first open the same LAN URL on another
device. Also check the Mac firewall and make sure the server terminal remains
open.

## Related files

```text
BurstStream/AirPlayRoutePicker.swift
BurstStream/PlaybackAudioSession.swift
BurstStream/PlayerViewModel.swift
BurstStream/ContentView.swift
Scripts/serve-local-hls.sh
```

[← WebVTT subtitles](subtitles.md) · [Next: Experiments →](experiments.md)
