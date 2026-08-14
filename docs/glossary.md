---
layout: page
title: Glossary
---

# Glossary

[← Experiments](experiments.md) · [Documentation home](index.md)

Streaming terminology can feel like a second language. Use this page as a quick
reference whenever a chapter introduces an unfamiliar word; you are not
expected to memorize the table.

| Term | Meaning |
|---|---|
| HLS | HTTP-based streaming protocol built around playlists and media segments |
| `.m3u8` | UTF-8 playlist that describes media, renditions, or both |
| Segment | Short portion of audio or video requested over HTTP |
| Master playlist | Playlist that advertises alternative qualities, audio, or subtitles |
| Media playlist | Playlist that lists the segments for one rendition |
| WebVTT | Text subtitle format used by HLS subtitle renditions |
| `X-TIMESTAMP-MAP` | WebVTT header that maps local cue time to the MPEG-TS presentation clock |
| Legible group | AVFoundation media-selection group containing subtitles or captions |
| Codec | Algorithm and format used to encode/decode audio or video |
| Container | File structure that holds video, audio, subtitles, and metadata |
| Bitrate | Number of encoded bits consumed per second |
| Throughput | Transfer speed actually observed over the network |
| Buffer | Downloaded media that has not yet been presented |
| Buffer ahead | Downloaded playable time following the current position |
| Seek | Move playback to another time |
| Scrubbing | Drag the timeline interactively |
| Keyframe | Independently decodable video frame used as a safe starting point |
| VOD | Video on demand; a complete, finite presentation |
| ABR | Adaptive bitrate selection based on playback conditions |
| Rendition | One encoded version of the same content |
| Quality ceiling | Maximum quality preference, not an exact rendition command |
| Alternate audio | Selectable audio rendition that shares the same video |
| Media selection group | AVFoundation group containing related selectable options |
| Exponential backoff | Progressively longer delays between retry attempts |
| Network throttling | Artificial bandwidth or latency restriction used for testing |
| Access log | AVPlayer record of transfer and playback performance |
| Error log | AVPlayer record of failed media requests |
| Sample | Metrics snapshot captured during an experiment |
| Transition | Important change in rendition, network profile, or player state |
| Dependency injection | Providing a dependency externally rather than constructing it internally |
| AirPlay | Apple's system for routing media playback to a compatible receiver |
| Playback route | The local or external destination that presents the player's media |
| External playback | AVPlayer presentation performed by a route such as Apple TV |
| Picture in Picture (PiP) | System-managed floating video window that continues outside the app's main interface |
| Background mode | Declared capability that permits specific work, such as media playback, while an app is not foregrounded |
| LAN | Local area network shared by nearby devices, usually through the same router |

[← Experiments](experiments.md) · [Documentation home](index.md)
