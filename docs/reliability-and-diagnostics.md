---
layout: page
title: Reliability and Diagnostics
---

# Reliability and Diagnostics

[← Playback and buffering](playback-and-buffering.md) · [Documentation home](index.md) · [Next: Adaptive streaming →](adaptive-streaming.md)

Networks fail, servers restart, and individual media requests sometimes arrive
late. A useful streaming app should explain what is happening and recover when
recovery is safe.

BurstStream lets you observe these situations instead of hiding them. You can
see retries, throughput, requested resources, and recent errors while the video
continues playing.

## Automatic retry

Streaming failures may be temporary. BurstStream retries after progressively
longer delays:

```text
Attempt 1 → 1 second
Attempt 2 → 2 seconds
Attempt 3 → 4 seconds
```

This pattern is **exponential backoff**. It gives a server or network time to
recover without creating an aggressive retry loop.

When retrying, the view model remembers:

- the current position;
- whether playback should resume;
- the selected quality ceiling;
- the selected audio language.

It creates a fresh item, reapplies preferences, seeks to the saved second, and
resumes only when appropriate.

## Access log

`AVPlayerItemAccessLog` describes successful media transfer and playback. The
diagnostics panel includes values such as:

- observed throughput;
- indicated/required bitrate;
- average video bitrate;
- downloaded and observed duration;
- request count and transferred bytes;
- stalls;
- server address and current resource URI;
- presentation size.

Observed throughput is measured transfer performance. Indicated bitrate is the
bandwidth advertised for a rendition. When throughput falls below the required
bitrate for too long, the buffer shrinks and ABR may choose a lower rendition.

## Error log

`AVPlayerItemErrorLog` records failed media requests, including status code,
technical comment, failing URI, and server address. Notifications reveal new
entries quickly, while periodic polling keeps mutable access information fresh.

## Metrics mapping

`PlaybackMetricsMapper` converts AVFoundation log objects into an immutable
`PlaybackMetrics` snapshot. This keeps the SwiftUI diagnostics view independent
from log parsing and makes the mapping logic easier to reason about.

## Finding the active rendition

Presentation size can retain an earlier value after an ABR change. For
experiments, the most useful indicators are:

- **Current resource** — the playlist or segment path currently requested;
- **Required bitrate** — the bandwidth associated with that rendition.

## Related files

```text
BurstStream/Playback/Core/RetryPolicy.swift
BurstStream/Playback/Core/PlayerViewModel.swift
BurstStream/Diagnostics/PlaybackMetrics.swift
BurstStream/Diagnostics/PlaybackDiagnosticsView.swift
```

[← Playback and buffering](playback-and-buffering.md) · [Next: Adaptive streaming →](adaptive-streaming.md)
