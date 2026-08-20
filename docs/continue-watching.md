---
layout: page
title: Continue Watching
---

# Continue Watching

[← Interruptions and lifecycle](interruptions-and-lifecycle.md) · [Documentation home](index.md) · [Next: Professional roadmap →](professional-roadmap.md)

Closing a player should not make the viewer remember where they stopped. A
Continue Watching feature stores a small playback bookmark and offers to
restore it later—even after the app has been terminated.

This sounds like “save the current second,” but a useful bookmark also needs
an identity, sensible completion rules, media preferences, and safe timing.
This chapter builds that mental model from the beginning.

## What BurstStream remembers

For each unfinished stream, BurstStream stores:

- a stable stream identifier, title, subtitle, and URL;
- the current position and duration;
- the selected quality ceiling;
- the preferred audio language;
- whether subtitles are on and their language;
- the date of the most recent update.

It stores metadata only. Video segments, encryption keys, and decoded frames
do not belong in `UserDefaults`.

## Identity must survive relaunches

A fresh `UUID()` is excellent for identifying one navigation request, but it
is the wrong identity for persisted content. After relaunch, a new UUID would
make the same episode look unrelated to its old bookmark.

`StreamSource` therefore has a stable ID. BurstStream uses the stream URL as a
practical default because the app does not yet have a catalog backend. A real
service should use a permanent content ID supplied by its catalog because a
signed or migrated URL can change while the episode remains the same.

Navigation still needs a fresh identity. `PlaybackRequest` owns that temporary
UUID so SwiftUI can open the same stream again after **Start Over** without
changing the stream's durable identity.

```text
StreamSource.id     stable media identity → persistence
PlaybackRequest.id  one navigation action → SwiftUI routing
```

## Why there are resume and completion thresholds

BurstStream does not create a card while the playback position is below **30
seconds**. Very short visits are often accidental starts, previews, or setup
checks. Saving them would make the home screen noisy.

This rule checks the position on the timeline, not the amount of real time the
viewer has spent watching. Seeking directly to `01:00` is enough to test the
feature. Measuring true watch time would be a different metric because it
would need to exclude pauses, buffering, and skipped content.

An item is considered finished at **90 percent**. Resuming a movie with only
credits or a few seconds remaining usually feels worse than starting it from
the beginning.

These values are product decisions, not AVPlayer requirements. Keeping them in
`PlaybackProgressPolicy` makes them visible, explainable, and independently
testable.

## Why progress is not written on every time update

`PlayerViewModel` publishes time frequently so the timeline can look smooth.
Writing persistence on every update would create unnecessary encoding and
storage work. BurstStream saves regular progress at most once every **10
seconds**, then forces an additional save when:

- the viewer changes quality, audio, or subtitles;
- the app enters the background;
- the player screen disappears.

This combines efficient periodic checkpoints with saves at moments when state
is especially likely to be lost.

## A subtle restoration race

A newly created HLS item may briefly report position zero or an unknown
duration before its playlist is ready. If persistence treated that temporary
zero as a deliberate restart, it could erase the bookmark before the resume
seek finishes.

BurstStream therefore waits for a finite duration before saving and preserves
the previous record during the initial restoration window. `PlayerViewModel`
also keeps the requested seek pending until the HLS duration is usable.

Audio and subtitle options have a similar loading window. A missing selection
during discovery means “not loaded yet,” not necessarily “the viewer selected
Off.” The progress controller merges those temporarily unavailable values with
the last saved record.

## Continue versus Start Over

The home card presents two explicit choices:

- **Continue** creates a player with the saved restoration state.
- **Start Over** deletes the bookmark and creates a fresh player request.

Restoration sets position and preferences, but it does not force playback to
begin. The viewer remains in control, consistent with BurstStream's
conservative lifecycle behavior.

When playback reaches the completion threshold or AVPlayer reports that the
item ended, the saved record is removed automatically.

## Why UserDefaults is enough here

The first implementation stores a small, versioned JSON array inside
`UserDefaults`. That is appropriate for a learning app with a few lightweight
bookmarks. The `PlaybackProgressStoring` protocol forms a real boundary, so a
larger catalog could later use SwiftData or a server-backed account without
coupling the player to either choice.

Persistence errors are logged and ignored. Continue Watching is useful, but a
corrupt bookmark must never prevent the video from opening.

## Common mistakes

### Saving a random UUID

The bookmark cannot be found after relaunch. Use a stable catalog identity.

### Saving every timeline tick

This performs work much more frequently than the feature requires. Throttle
periodic saves and force them at lifecycle boundaries.

### Saving before duration is valid

Unknown HLS duration can produce invalid percentages or erase a pending
restoration. Wait for a finite positive duration.

### Always resuming near the end

The viewer returns to credits or an almost-finished frame. Define and test a
completion threshold.

### Letting persistence block playback

A damaged local value becomes a playback outage. Treat restoration as a
best-effort enhancement and fall back safely.

## Test it without a LAN

The public sample button is enough for this experiment. The button remains on
the home screen so you can always start the sample manually; Continue Watching
appears as a separate section above it once eligible progress exists.

1. Open BurstStream and tap **Use sample HLS stream**.
2. Play or seek until the timeline is beyond `00:30`.
3. Optionally choose a manual quality ceiling.
4. Go back to the home screen.
5. Confirm that **Continue Watching** shows the saved time and progress.
6. Tap **Continue** and verify the restored position and quality.
7. Leave again, terminate the app, relaunch it, and confirm the card remains.
8. Tap **Start Over** and confirm the card disappears and playback begins at
   the start.
9. As a final experiment, seek beyond 90 percent and leave the player. The
   item should no longer be offered for resume.

The local bilingual stream is still the better test for audio and subtitle
restoration once LAN or localhost media is available.

## Automated coverage

The `BurstStreamTests` target verifies:

- the 30-second resume boundary;
- the 90-percent completion boundary;
- invalid-duration handling;
- periodic throttling and forced saves;
- preservation of a bookmark during the initial zero-time window;
- replacement by stable ID, disk restoration, and corrupt-data fallback.

## Related files

```text
BurstStream/Streaming/StreamSource.swift
BurstStream/Streaming/PlaybackRequest.swift
BurstStream/Persistence/PlaybackProgress.swift
BurstStream/Persistence/PlaybackProgressPolicy.swift
BurstStream/Persistence/PlaybackProgressStore.swift
BurstStream/Persistence/PlaybackProgressController.swift
BurstStream/Playback/Core/PlaybackRestorationState.swift
BurstStream/Playback/Core/PlayerViewModel.swift
BurstStream/App/ContinueWatchingView.swift
BurstStream/App/ContentView.swift
BurstStreamTests/
```

[← Interruptions and lifecycle](interruptions-and-lifecycle.md) · [Next: Professional roadmap →](professional-roadmap.md)
