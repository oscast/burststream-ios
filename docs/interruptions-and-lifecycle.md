---
layout: page
title: Interruptions and Playback Lifecycle
---

# Interruptions and Playback Lifecycle

[← Picture in Picture](picture-in-picture.md) · [Documentation home](index.md) · [Next: Continue Watching →](continue-watching.md)

Your stream can be healthy and fully buffered, but playback still shares the
device with phone calls, Siri, alarms, headphones, Bluetooth, and other apps.
A good player does not fight those system events or surprise the viewer by
starting audio at the wrong time.

BurstStream now turns those events into explicit, conservative decisions. The
player pauses when another experience takes control, resumes only when iOS says
that resuming is appropriate, and never moves disconnected-headphone audio to
the speaker unexpectedly.

## First, separate two responsibilities

It helps to understand what AVFoundation already does and what the application
still needs to decide.

`AVPlayer` already listens to the audio session and normally pauses when an
interruption or headphone disconnection occurs. The application should not
replace that system behavior. However, BurstStream still observes the same
events because the application has responsibilities that `AVPlayer` cannot
decide on its own:

- remember whether playback was active before the event;
- decide whether automatic resume would respect the viewer's intent;
- keep custom controls and diagnostics synchronized;
- explain the latest decision in the learning interface; and
- rebuild app-owned media objects after a media-services reset.

Calling `pause()` when AVPlayer is already paused is safe and makes the policy
explicit. More importantly, capturing the pre-interruption state before pausing
prevents the app from guessing later.

Apple's [Handling audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions)
guide describes AVPlayer's automatic response and explains why an app may still
observe the notifications to update its own state and interface.

## Configure the audio session, but activate it at the right time

An `AVAudioSession` tells iOS what kind of audio experience the app provides.
BurstStream uses:

```swift
try session.setCategory(
    .playback,
    mode: .moviePlayback,
    policy: .longFormVideo
)
```

Why these values?

- `.playback` says that consuming media is the app's main purpose. It also
  supports the expected Ring/Silent-switch and background behavior for a media
  app when the matching background capability is enabled.
- `.moviePlayback` helps iOS apply processing appropriate for movie audio.
- `.longFormVideo` describes a route-sharing experience suitable for video and
  AirPlay.

Configuration and activation are different operations. BurstStream configures
the category while creating the player, but calls `setActive(true)` only when
playback is requested or an allowed interruption resume occurs. Activating too
early can unnecessarily take audio focus from music, a podcast, or another app
before the viewer has actually started the video.

Apple's [`AVAudioSession` overview](https://developer.apple.com/documentation/avfaudio/avaudiosession)
recommends deferring activation until playback begins for this reason.

## The three kinds of events

### Audio interruptions

An interruption begins when another system experience needs the audio session.
BurstStream remembers whether the video was active and pauses the player.

The [`interruptionNotification`](https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionnotification)
contains a `userInfo` dictionary. Its interruption type answers whether the
event began or ended; the end event may also provide a resume recommendation.

When the interruption ends, two conditions must both be true before playback
continues:

1. the video was playing before the interruption; and
2. the notification contains Apple's `shouldResume` option.

If either condition is false, the video remains paused. Returning to the app
also does not start a video that the viewer had already paused.

### Why `shouldResume` is not a Play command

`shouldResume` means that iOS considers resuming appropriate. It does not mean
that the app must ignore its own playback state. BurstStream treats it as one
condition, not the only condition:

```swift
let shouldResume = wasPlayingBeforeInterruption
    && options.contains(.shouldResume)
```

This prevents a common bug:

1. the viewer pauses the video;
2. an interruption begins and ends; and
3. the app starts the video merely because iOS allowed resumption.

The compatibility note matters too. The current SDK marks `shouldResume` as
deprecated in favor of a newer resumption-recommendation notification.
BurstStream still supports iOS 18, so it uses the established interruption
option available across the project's deployment range. A future chapter can
migrate to the newer API after the minimum OS version makes that practical.

See Apple's [`shouldResume` reference](https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionoptions/shouldresume)
for the exact meaning of the option.

### Audio route changes

An audio route is the place where sound is currently playing. Examples include
the iPhone speaker, wired headphones, Bluetooth, a car, HDMI, and AirPlay.

When an external route becomes unavailable, BurstStream pauses. This avoids the
common and embarrassing behavior where removing headphones suddenly sends the
video's sound through the device speaker. Connecting a new route never starts
playback automatically.

This is not only a technical preference. Disconnecting headphones is an
implicit privacy request: the viewer no longer wants that audio delivered
through the private route. Apple explicitly recommends pausing instead of
moving playback to the speaker in
[Responding to audio route changes](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes).

BurstStream checks both the reason and the previous route:

- `.oldDeviceUnavailable` tells us that an output disappeared;
- `AVAudioSessionRouteChangePreviousRouteKey` tells us what disappeared.

Looking only at `currentRoute` would be too late—the removed headphones or
AirPlay receiver are no longer part of the current route. The previous route is
how the app distinguishes a disconnected external output from an unrelated
configuration change.

The app does **not** resume when `.newDeviceAvailable` arrives. Connecting
headphones selects a destination; it does not express an intention to start a
paused video.

`AVPlayer.isExternalPlaybackActive` continues to synchronize the AirPlay UI.
The lifecycle controller only decides whether a disconnected route should
pause; it does not implement a second routing system.

### Media-services reset

Very rarely, iOS restarts the system process that provides audio and video
services. Existing media objects can no longer be trusted after that reset.

Apple's [`mediaServicesWereResetNotification`](https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification)
documentation recommends reinitializing players and restoring the audio-session
category, options, and mode. It also says playback should not restart until a
user initiates it.

BurstStream responds by:

1. saving the latest known position and playback preferences;
2. removing observations from the old player and item;
3. configuring the audio session again;
4. creating a new `AVPlayer` and `AVPlayerItem`;
5. restoring the quality ceiling, audio language, subtitle selection, and
   position; and
6. leaving the restored video paused.

The last rule is important: a system reset is not permission to start sound.
The viewer must press Play again.

BurstStream also observes `mediaServicesWereLostNotification` so the UI can
report that the service disappeared, but reset is the important recovery event.
Most applications do not need to rebuild anything at the moment of loss because
the service is not usable yet. Rebuilding after reset avoids creating objects
against a service that is still unavailable.

The lifecycle notification observers themselves remain registered. Apple notes
that apps do not need to register those audio-session notifications again after
a reset. BurstStream does recreate observations attached to the old `AVPlayer`
and `AVPlayerItem`, because those specific objects are replaced.

Some HLS playlists become ready before they publish a finite duration.
BurstStream therefore keeps the saved position until seeking is actually
possible instead of discarding it during that short loading window.

## Scene lifecycle policy

SwiftUI reports whether the scene is `active`, `inactive`, or in the
`background`.

BurstStream observes those states but does not automatically pause merely
because the app enters the background. Doing so would break valid Picture in
Picture and AirPlay playback. Interruption and route notifications remain the
authority for audio ownership.

When the scene becomes active again, BurstStream may reactivate an audio session
that is already playing, but it never uses foregrounding as a reason to call
Play.

`inactive` also does not automatically mean that audio was interrupted. A scene
can become inactive during a temporary system transition, such as displaying a
system interface. Treating every inactive transition as Pause would create
false pauses and conflict with AVAudioSession's more precise notifications.

Apple documents the meaning of the three states in
[`ScenePhase`](https://developer.apple.com/documentation/swiftui/scenephase).
The important lesson is that scene visibility and audio ownership are related,
but they are not the same signal.

## Recommendations and the reason behind each one

| Recommendation | Why it matters |
|---|---|
| Capture `wasPlayingBeforeInterruption` before pausing | Once paused, the player alone cannot tell whether the viewer wanted playback beforehand. |
| Require both prior playback and the system resume recommendation | Prevents an interruption from starting media the viewer had paused. |
| Reactivate the audio session before an automatic resume | The interruption may have deactivated the session; resuming without ownership can fail or behave inconsistently. |
| Pause when a private or external output disconnects | Protects privacy and avoids moving unexpected sound to the speaker. |
| Inspect the previous route on disconnection | The missing device is no longer present in `currentRoute`. |
| Never auto-play merely because a new route connected | Choosing an output device is not the same as pressing Play. |
| Do not use every `scenePhase` change as an audio decision | Scene visibility cannot distinguish PiP, AirPlay, Control Center, and real audio interruptions. |
| Recreate AVPlayer only after a media-services reset | Normal interruptions do not invalidate the player; rebuilding for every event would discard buffers and create unnecessary network work. |
| Preserve position and media preferences before rebuilding | A technically successful recovery is still poor if the viewer loses progress, language, subtitles, or quality choice. |
| Keep reset recovery paused | A system failure is not user consent to begin playback. |
| Remove old player and item observations before replacement | Prevents duplicate callbacks, stale state, and retained AVFoundation objects. |
| Perform published UI-state changes on the main actor | SwiftUI expects observable interface state to change on its UI isolation domain. |
| Test on physical hardware | Simulator builds cannot faithfully reproduce calls, cable removal, Bluetooth, AirPlay, or media-server resets. |

## Common incorrect approaches

### Resume after every ended interruption

This ignores both the system recommendation and the viewer's previous intent.
It can make paused media start unexpectedly.

### Pause on every background transition

This may look safe, but it breaks the exact background experiences the app
supports: Picture in Picture and AirPlay.

### Rebuild the player after a phone call

A normal interruption deactivates audio; it does not invalidate the HLS item.
Rebuilding would throw away the buffer, create new requests, and risk losing
media selections. Rebuilding belongs to the rare media-services reset path.

### Check only whether AVPlayer is paused when the interruption ends

AVPlayer normally pauses automatically, so that state no longer answers whether
the video was playing before the interruption. Save the intent at the beginning.

### Treat a connected headset as permission to play

A new route tells the app where sound could go, not whether the viewer wants to
hear it.

## Why this code has a small protocol

`PlaybackLifecycleController` needs only four things from the player:

```swift
var isPlaybackActive: Bool { get }
func play()
func pause()
func recoverAfterMediaServicesReset()
```

The `PlaybackLifecycleControlling` protocol expresses that real boundary. It
allows notification behavior to be tested with a small fake player later,
without inventing protocols for every AVFoundation type.

The audio-session reactivation function and `NotificationCenter` are also
injected with practical defaults. Tests can replace them without affecting app
code.

## Visible diagnostics

The **System lifecycle** panel shows the latest event and decision. It makes
experiments understandable without requiring the Xcode console.

For example, disconnecting headphones should change the message to:

```text
Playback paused because an audio route disconnected
```

## How to test

Use a physical iPhone or iPad for route and interruption tests:

1. Start a video and connect headphones or a Bluetooth speaker.
2. Disconnect the device and confirm that playback pauses.
3. Reconnect it and confirm that playback does not start by itself.
4. While playing, trigger Siri, an alarm, or another audio interruption.
5. Confirm that the lifecycle panel records the event.
6. Verify that a video paused before the interruption remains paused afterward.
7. Test while using AirPlay and Picture in Picture.
8. From the iOS Developer settings, use **Reset Media Services**.
9. Confirm that the item returns at the saved position with the selected
   quality, audio, and subtitles, but remains paused.

The Simulator is useful for scene transitions and basic builds, but it cannot
faithfully reproduce every phone call, hardware route, or media-server event.

## Related files

```text
BurstStream/Playback/SystemFeatures/PlaybackLifecycleController.swift
BurstStream/Playback/SystemFeatures/PlaybackAudioSession.swift
BurstStream/Playback/Core/PlayerViewModel.swift
BurstStream/Playback/UI/PlaybackLifecycleView.swift
BurstStream/Playback/UI/StreamPlayerView.swift
```

[← Picture in Picture](picture-in-picture.md) · [Next: Continue Watching →](continue-watching.md)
