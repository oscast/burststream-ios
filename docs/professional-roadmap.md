---
layout: page
title: Professional Readiness Roadmap
---

# Professional Readiness Roadmap

[← Documentation home](index.md)

You do not need every item on this page before the project is valuable. Think
of the roadmap as a menu for growing the learning lab into a polished portfolio
app. Complete one priority, test it, document what you learned, and then choose
the next one.

BurstStream already demonstrates the core mechanics of an iOS streaming
client: HLS VOD playback, a four-level adaptive bitrate ladder, custom
controls, buffer visualization, retry with exponential backoff, playback
diagnostics, network experiments, bilingual audio and subtitles, AirPlay,
Picture in Picture, and interruption handling.

AirPlay has also been validated end to end on physical hardware using an
iPhone 14 Pro, Apple TV, and the Mac-hosted bilingual HLS stream over LAN.

This roadmap focuses on the remaining **iOS client responsibilities** needed to
turn the learning lab into a robust portfolio project. Encoding, HLS packaging,
origin-server administration, and CDN operation are intentionally not treated
as iOS responsibilities. The local media tools and server remain part of the
lab so every client behavior can be reproduced without external services.

## Priority 1: Interruptions and lifecycle

The interruption and lifecycle implementation is complete in code. Physical
hardware validation remains because the Simulator cannot faithfully reproduce
every call, route disconnection, or media-server reset.

- [x] Observe `AVAudioSession.interruptionNotification`.
- [x] Pause when an interruption begins.
- [x] Remember whether playback was active before the interruption.
- [x] Resume only when the interruption options allow it and the user had not
      paused manually.
- [x] Observe `AVAudioSession.routeChangeNotification`.
- [x] Pause when headphones are unexpectedly disconnected.
- [x] Keep state synchronized when switching between the device, Bluetooth,
      and AirPlay.
- [x] Handle `mediaServicesWereLostNotification` and
      `mediaServicesWereResetNotification`.
- [x] Restore the item, position, quality limit, audio, and subtitles after a
      media-services reset.
- [x] Define foreground, inactive, and background behavior with SwiftUI
      `scenePhase`.
- [ ] Test calls, Siri, alarms, route changes, device locking, and AirPlay
      disconnection on physical hardware.

### Completion criteria

- Playback never starts unexpectedly after an interruption.
- Disconnecting headphones produces a safe and predictable result.
- The UI and the real `AVPlayer` state remain synchronized after lifecycle
  transitions.
- A media-services reset can recover without losing the viewing position or
  media selections.

## Priority 2: Continue Watching persistence

- [ ] Create a stable identifier for each playable item.
- [ ] Persist the current position and duration periodically and when leaving
      playback.
- [ ] Persist the preferred audio language, subtitle choice, and quality limit.
- [ ] Offer to resume an unfinished item from its saved position.
- [ ] Treat nearly completed items as finished instead of resuming at the end.
- [ ] Remove stale progress when media is deleted or replaced.
- [ ] Unit-test resume thresholds and persistence mapping.

### Completion criteria

- Relaunching the app restores the expected episode, position, and selections.
- Finished content starts from the beginning.
- Persistence failures never prevent playback.

## Priority 3: Error classification and recovery

BurstStream already retries item failures with exponential backoff. The next
step is deciding which failures should be retried and what the user should see.

- [ ] Define user-facing error categories: offline, timeout, server error,
      missing resource, invalid playlist, unsupported media, decoding failure,
      authorization failure, and unknown failure.
- [ ] Separate transient failures from permanent failures.
- [ ] Retry only transient failures.
- [ ] Respect server guidance such as `Retry-After` when available.
- [ ] Stop retrying when the app is intentionally offline or the item is no
      longer active.
- [ ] Preserve position and media selections across every recoverable rebuild.
- [ ] Provide actionable messages and a manual Retry action.
- [ ] Add deterministic fixtures for missing segments, malformed playlists,
      HTTP failures, slow responses, and mid-stream disconnects.

### Completion criteria

- A permanent format or authorization error does not enter a retry loop.
- Temporary network and server errors recover without losing user state.
- Every failure shown in the UI has a useful technical classification in the
  diagnostics panel.

## Priority 4: Quality of Experience telemetry

The existing diagnostics panel and ABR history are an excellent foundation.
Add session-level Quality of Experience (QoE) metrics that can be tested and
exported.

- [ ] Assign a unique identifier to each playback session.
- [ ] Measure time to first frame.
- [ ] Count rebuffering events and their total duration.
- [ ] Track startup failures and playback failures separately.
- [ ] Track rendition changes, average bitrate, and average resolution.
- [ ] Track watch duration, completion percentage, and successful completion.
- [ ] Capture the final error category and relevant `AVPlayerItemErrorLog`
      details.
- [ ] Keep telemetry independent from the diagnostics UI.
- [ ] Add a local session-history screen or JSON export for portfolio demos.
- [ ] Avoid collecting personal data or complete signed media URLs.

### Completion criteria

- One playback session produces a coherent summary from load request through
  completion or failure.
- Metrics remain correct across seeking, retrying, AirPlay, and item rebuilds.
- Automated tests validate duration and counter calculations.

## Priority 5: Automated testing

### Unit tests

- [ ] Playback-state mapping.
- [ ] Retry policy and cancellation.
- [ ] Error classification.
- [ ] Buffer-range conversion.
- [ ] QoE calculations.
- [ ] Continue Watching thresholds.
- [ ] Audio and subtitle preference restoration.

### Integration tests

- [ ] Successful VOD playback from a deterministic local fixture.
- [ ] Delayed playlist and segment responses.
- [ ] Temporary server failure followed by recovery.
- [ ] Missing or malformed playlist and segment responses.
- [ ] Alternate audio and subtitle discovery.
- [ ] Item reconstruction without losing position or preferences.

### UI tests

- [ ] Play, pause, seek, and skip controls.
- [ ] Manual quality limit changes.
- [ ] Audio and subtitle selection.
- [ ] Retry and error presentation.
- [ ] Continue Watching.
- [ ] iPhone and iPad layouts in portrait and landscape.

### Completion criteria

- Tests run without real-time retry delays.
- Media fixtures are small, deterministic, and legal to store in the test
  target.
- The main suite runs from a clean checkout in continuous integration.

## Priority 6: Accessibility and localization

- [ ] Add meaningful VoiceOver labels, values, and hints to every control.
- [ ] Give controls adequate touch targets.
- [ ] Support Dynamic Type without covering the video or controls.
- [ ] Verify focus order in portrait, landscape, and diagnostics screens.
- [ ] Do not communicate playback state or quality using color alone.
- [ ] Respect Reduce Motion where custom animation is used.
- [ ] Preserve closed-caption and subtitle accessibility metadata.
- [ ] Localize user-facing strings instead of embedding them in views.
- [ ] Test with VoiceOver on a physical device.

## Priority 7: Picture in Picture

AirPlay is complete, and the first Picture in Picture implementation is now
ready for physical-device validation.

- [x] Add `AVPictureInPictureController` around the existing player layer.
- [x] Observe PiP availability and active state.
- [x] Keep custom controls synchronized with PiP controls.
- [x] Restore the app interface when PiP stops.
- [x] Handle background and foreground transitions without rebuilding the item.
- [ ] Test PiP together with alternate audio, subtitles, retry, and AirPlay.

## Priority 8: Offline HLS

- [ ] Download HLS assets with AVFoundation's asset-download APIs.
- [ ] Display download progress and state.
- [ ] Pause, resume, cancel, and delete downloads.
- [ ] Persist download records across launches.
- [ ] Select which audio and subtitle renditions to download.
- [ ] Check free space and handle incomplete or corrupt downloads.
- [ ] Play a downloaded asset while the local server is unavailable.
- [ ] Define cleanup and expiration policies.

## Priority 9: Configuration and project operations

- [ ] Replace the hardcoded stream URL with an explicit development
      configuration.
- [ ] Support Simulator localhost and physical-device LAN endpoints without
      editing source code.
- [ ] Validate endpoint configuration and present clear setup errors.
- [ ] Add Debug and Release configuration checks.
- [ ] Add continuous integration for build and test.
- [ ] Add a consistent formatting or linting check.
- [ ] Run Instruments for leaks, allocations, CPU, energy, and network usage.
- [ ] Confirm Swift concurrency and main-actor correctness under Thread
      Sanitizer.
- [ ] Keep the README, documentation feature table, and screenshots current.
- [ ] Record a short portfolio demo covering normal playback, ABR adaptation,
      recovery, alternate tracks, subtitles, and AirPlay.

## Optional specialization tracks

These features are valuable specializations, but they are not required before
BurstStream can be presented as a professional iOS streaming portfolio project.

### FairPlay client integration

- Handle content-key requests in the app.
- Communicate with a development license service.
- Support persistent keys for offline playback.
- Classify authorization, certificate, and key-expiration failures.

### Live and Low-Latency HLS

- Follow a moving live window.
- Expose a Go Live action and live-edge status.
- Recover after falling behind the available window.
- Study latency, clock synchronization, discontinuities, and reconnects.

### Advertising

- Model ad breaks and playback restrictions.
- Transition between content and ads without corrupting the timeline.
- Measure ad start, completion, skip eligibility, and failure.

### Google Cast

- Add Google's iOS Sender SDK as a separate remote-playback path.
- Keep the local `AVPlayer` state distinct from the Cast session.
- Synchronize remote position, media selections, and connection state.

## Recommended implementation order

1. Interruptions and lifecycle.
2. Continue Watching persistence.
3. Error classification and recovery.
4. QoE telemetry.
5. Automated tests.
6. Accessibility and localization.
7. Picture in Picture.
8. Offline HLS.
9. Configuration, CI, and performance validation.
10. Choose one optional specialization track.

Completing priorities 1 through 5 would make BurstStream a strong and credible
portfolio project. Priorities 6 through 9 would make it feel like a polished
application rather than only a technical demonstration.

[← Documentation home](index.md)
