---
layout: page
title: Experiments
---

# Reproducible Experiments

[← WebVTT subtitles](subtitles.md) · [Documentation home](index.md) · [Next: Glossary →](glossary.md)

Use these exercises to connect visible player behavior with AVFoundation state
and server requests.

## Subtitle selection

1. Load the local bilingual stream and confirm subtitles start **Off**.
2. Select **Spanish** and verify that timed text appears over the video.
3. Switch to **English** while playback continues.
4. Confirm that playback position and audio language do not change.
5. Select a different quality limit and verify that the subtitle preference is
   restored after the item reload.
6. Select **Off**, change quality again, and verify that subtitles remain off.
7. Seek across a six-second segment boundary and check that a cue spanning the
   boundary remains synchronized.

## Playback and seeking

1. Play and pause the episode.
2. Use the forward and backward 10-second controls.
3. Drag the timeline to a precise location.
4. Confirm that the slider does not jump backward after release.
5. Seek far ahead and inspect the separated buffer ranges.

## Server failure and retry

1. Start playback normally.
2. Stop the local server.
3. Observe retries after 1, 2, and 4 seconds.
4. Wait for the final failure state.
5. Restart the server.
6. Select **Retry now** and verify position restoration.

## Diagnostics

1. Expand **Streaming diagnostics**.
2. Compare observed throughput and required bitrate.
3. Seek and watch requests and transferred bytes increase.
4. Stop the server and inspect the most recent error-log information.

## Manual quality ceiling

1. Begin with **Automatic**.
2. Note **Current resource** and **Required bitrate**.
3. Choose **360p max**.
4. Confirm that the item resumes near the same second.
5. Verify the requested rendition using diagnostics.
6. Return to **Automatic**.

## Automatic ABR under bandwidth changes

1. Keep quality on **Automatic**.
2. Choose the **Fast** network profile.
3. Wait for a high rendition.
4. Change to **2 Mbps**.
5. Watch the ABR history and current resource.
6. Confirm that playback eventually favors a lower rendition.
7. Return to **Fast** and observe recovery.

Do not force a manual quality during this experiment: the purpose is to watch
`AVPlayer` make the decision.

## Latency and offline behavior

1. Select **Latency** and reload the stream.
2. Compare startup time with **Fast**.
3. Select **Offline** while playing.
4. Observe buffering, retry, and failure states.
5. Return to **Fast** and recover playback.

## Bilingual audio

1. Start with **Latin American Spanish**.
2. Remember the current second.
3. Select **English**.
4. Confirm that playback does not restart.
5. Change the quality ceiling.
6. Confirm that English remains selected after the item reload.
7. Inspect server requests for `audio/es` and `audio/en` paths.

## Questions to answer

- Does a larger buffer delay an ABR downgrade?
- How quickly does the player recover after bandwidth improves?
- Does high latency affect startup differently from low bandwidth?
- Why can presentation size differ from the currently requested resource?
- Which actions discard the buffer, and which preserve it?

[← Bilingual audio](bilingual-audio.md) · [Next: Glossary →](glossary.md)
