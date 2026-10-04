---
layout: page
title: Error Classification and Recovery
---

# Error Classification and Recovery

[← Continue Watching](continue-watching.md) · [Documentation home](index.md) · [Next: Professional roadmap →](professional-roadmap.md)

“The video failed” is not enough information to choose the next action. A
temporary server outage deserves a retry; a missing playlist or denied access
does not. Treating every error the same creates frustrating retry loops and
unhelpful messages.

BurstStream now converts AVFoundation errors and HLS error-log status codes
into a small set of viewer-friendly categories.

## What the viewer sees

Instead of an opaque system error, the playback panel can say:

```text
Server unavailable
The streaming server is temporarily unavailable.
BurstStream will retry automatically. You can also try again later.
```

For a problem that is unlikely to change by waiting, it stops and gives a
specific next step:

```text
Stream not found
The playlist or one of its media files could not be found.
Check the HLS URL and confirm the local server is still serving this package.
[ Retry now ]
```

The manual button remains useful after every terminal error because a server or
URL may be corrected while the app is still open.

## Which failures retry automatically?

| Category | Typical example | Automatic retry? |
|---|---|---|
| No connection | Wi-Fi disappears | Yes |
| Request timed out | Server is too slow | Yes |
| Server unavailable | HTTP 429 or 5xx | Yes |
| Stream not found | HTTP 404 | No |
| Access denied | HTTP 401 or 403 | No |
| Invalid stream | malformed or unsupported playlist response | No |
| Unsupported media / decoding | codec cannot be played | No |
| Unknown | insufficient information | No |

The important idea is not that the app can diagnose every streaming failure
perfectly. It cannot. HLS failures can originate from the master playlist, a
video segment, an alternate audio segment, a subtitle segment, or a network
layer that hides the original HTTP response. The goal is to make the best safe
decision from the information AVFoundation provides.

## What happens behind the scenes

`AVPlayerItem` can provide an `NSError` when it fails. It can also publish an
HLS error-log entry with an HTTP status code. BurstStream checks the HTTP status
first because `401`, `404`, and `503` are much clearer than a generic player
error. If no status is available, it looks at the NSError domain and code.

```text
AVPlayerItem failure or error log
            ↓
PlaybackFailureClassifier
            ↓
PlaybackFailure category + recovery advice
            ↓
Retry with backoff, or stop and show Retry now
```

The classifier is deliberately a pure Swift mapping. It does not own
`AVPlayer`, start network requests, or update SwiftUI. That keeps the rules
easy to unit-test and prevents error handling from becoming scattered through
the player.

## Why not retry every error?

Imagine the HLS URL has a typo and the server responds with `404 Not Found`.
Retrying after 1, 2, and 4 seconds asks the same broken URL three more times.
It wastes time and still cannot fix the typo.

On the other hand, a `503 Service Unavailable` may be caused by a temporary
server restart. Backoff gives that server a chance to recover without making
the viewer repeatedly press a button.

## Test it later with the local server

When your local HLS server is available again:

1. Start normal playback.
2. Change the server network profile to **Offline**. It returns HTTP 503.
3. Observe the classified server message and the 1, 2, and 4 second retries.
4. Return the profile to **Fast** and use **Retry now** if the automatic cycle
   already ended.
5. Enter a deliberately incorrect `.m3u8` URL. It should become **Stream not
   found** instead of retrying forever.

The public sample is still useful for normal playback, but it cannot reproduce
your local server's controlled 503/offline experiment without a LAN server.

## A useful limitation

The current HLS server does not send `Retry-After` headers, so BurstStream uses
its existing 1, 2, and 4 second exponential backoff. A production client
should respect server retry guidance when it is available and should record the
final category in session-quality telemetry.

## Related files

```text
BurstStream/Playback/Core/PlaybackFailure.swift
BurstStream/Playback/Core/PlayerViewModel.swift
BurstStream/Playback/Core/RetryPolicy.swift
BurstStream/Playback/UI/PlaybackStatePanel.swift
BurstStream/Diagnostics/PlaybackMetrics.swift
BurstStreamTests/PlaybackFailureClassifierTests.swift
```

[← Continue Watching](continue-watching.md) · [Next: Professional roadmap →](professional-roadmap.md)
