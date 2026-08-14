---
layout: page
title: Picture in Picture
---

# Picture in Picture

[← AirPlay](airplay.md) · [Documentation home](index.md) · [Next: Interruptions and lifecycle →](interruptions-and-lifecycle.md)

Picture in Picture is the familiar small video window that stays visible after
you leave a video app. In BurstStream, you can start it with the PiP button or
simply go to the Home Screen while the video is playing.

There is no second player hidden behind the floating window. This chapter shows
how the existing player continues seamlessly when iOS moves its presentation
outside the app.

## Goal

Picture in Picture (PiP) keeps the current video visible in a small floating
window while the user works in another app or visits the Home Screen.
BurstStream supports two entry paths:

- tap the system-style PiP button in the custom controls; or
- send the app to the background while the playing video is the primary
  onscreen content.

The second path is the behavior commonly described as minimizing the video.

## Reusing the existing player layer

BurstStream presents video with a custom `AVPlayerLayer`. The PiP controller
uses that same layer as its inline source:

```swift
let controller = AVPictureInPictureController(playerLayer: playerLayer)
```

PiP does not create another `AVPlayer`, restart the HLS stream, or duplicate
the playback timeline. The same player continues controlling position, audio,
subtitles, quality preferences, and buffering.

`PlayerSurface` exposes only its source layer to
`PictureInPictureController`. The manager retains Apple's controller strongly,
observes whether PiP is currently possible, and publishes lightweight state
for SwiftUI.

## Automatic background entry

The PiP controller enables:

```swift
controller.canStartPictureInPictureAutomaticallyFromInline = true
```

This tells iOS that the inline video is eligible to move automatically into a
floating window when the app enters the background. The system still decides
whether PiP is possible in the current context.

Manual starts happen only in response to tapping the PiP button. BurstStream
uses Apple's standard start and stop button images rather than inventing a new
icon.

## Required background mode

The generated app configuration includes the `audio` background mode. In
Xcode, this corresponds to **Audio, AirPlay, and Picture in Picture**. Combined
with the existing playback audio-session category, this allows supported media
playback to continue while the app is in the background.

This is an application capability, not a permission dialog. It does not add a
code-signing development team to the shared project file.

## State and failure handling

The manager exposes:

- `isSupported`: whether the device supports PiP;
- `isPossible`: whether PiP can start in the current context;
- `isActive`: whether the floating window is currently onscreen; and
- `errorMessage`: the latest failure to start PiP.

The PiP button is disabled until the system says PiP is possible. Delegate
callbacks update active state and report start failures without changing the
underlying playback item.

## How to test

Use a physical iPhone or iPad for the final test:

1. Start the Mac HLS server.
2. Run BurstStream on the physical device.
3. Load the LAN stream and begin playback.
4. Tap the PiP button and confirm that a floating video window appears.
5. Return to the app and stop PiP.
6. Start playback again and swipe to the Home Screen.
7. Confirm that PiP starts automatically.
8. Test pause, resume, skip, audio, and subtitles from the app and PiP controls.
9. Test PiP after disconnecting AirPlay so the playback route is local.

Automatic PiP generally requires active playback and may also depend on the
device's system Picture in Picture settings.

## Related files

```text
BurstStream/Playback/SystemFeatures/PictureInPictureController.swift
BurstStream/Playback/UI/PlayerSurface.swift
BurstStream/App/ContentView.swift
BurstStream/Playback/SystemFeatures/PlaybackAudioSession.swift
BurstStream.xcodeproj/project.pbxproj
```

[← AirPlay](airplay.md) · [Next: Interruptions and lifecycle →](interruptions-and-lifecycle.md)
