---
layout: page
title: Network and ABR Experiments
---

# Network and ABR Experiments

[← Adaptive streaming](adaptive-streaming.md) · [Documentation home](index.md) · [Next: Bilingual audio →](bilingual-audio.md)

You should not have to wait for bad Wi-Fi to study bad Wi-Fi. BurstStream's
local server can intentionally slow requests, add delay, or behave as if it is
offline while the app is running.

These controls are experiments, not production networking features. They give
you a repeatable way to watch buffering and ABR decisions on your own Mac.

## Why simulate the network?

ABR cannot be studied reliably when every request uses an unrestricted local
connection. BurstStream's development server can limit bandwidth, add latency,
or return failures while playback is active.

## Available profiles

| Profile | Condition | Likely observation |
|---|---|---|
| Fast | No artificial limit | 1080p or 720p |
| 5 Mbps | Moderate connection | Often 720p |
| 2 Mbps | Restricted connection | Often 480p |
| 1.2 Mbps | Low bandwidth | Often 360p |
| 800 Kbps | Below the lowest aggregate requirement | Buffer pressure |
| High latency | 1.5 seconds added per request | Slow startup/requests |
| Offline | HTTP 503 responses | Retry and failure states |

These are expected outcomes, not guarantees. Existing buffer, recent
throughput, and player history also influence the decision.

## Runtime profile endpoint

The server exposes a development-only endpoint:

```text
GET  /__burststream/profile
POST /__burststream/profile
```

`NetworkConditionerClient` calls it only for local stream URLs. A production
streaming server would not expose this testing interface.

## Throttling behavior

The server sends static files in small chunks. Between chunks it waits long
enough to respect the selected bitrate. A profile can change while a segment is
being transferred, allowing experiments without restarting the server or player.

## ABR history

The current diagnostics are a snapshot. `ABRHistoryRecorder` keeps a bounded
sequence of samples so an experiment can show how conditions evolved.

It stores at most 600 samples and normally records about one sample per second.
Important transitions—such as a rendition, network, or buffering change—are
retained for the timeline.

The full experiment screen compares:

```text
Cyan line   = observed throughput
Orange line = bitrate required by the active rendition
```

When observed throughput remains below the required bitrate, the player is more
likely to consume its buffer, stall, or move down the ladder.

## Related files

```text
Scripts/throttled_hls_server.py
Scripts/serve-local-hls.sh
BurstStream/NetworkSimulation/NetworkProfile.swift
BurstStream/NetworkSimulation/NetworkConditionerClient.swift
BurstStream/Diagnostics/ABRHistorySample.swift
BurstStream/Diagnostics/ABRHistoryRecorder.swift
BurstStream/Diagnostics/ABRHistoryView.swift
```

[← Adaptive streaming](adaptive-streaming.md) · [Next: Bilingual audio →](bilingual-audio.md)
