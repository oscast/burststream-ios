---
layout: page
title: WebVTT Subtitles
---

# WebVTT Subtitles

[← Bilingual audio](bilingual-audio.md) · [Documentation home](index.md) · [Next: Experiments →](experiments.md)

BurstStream supports optional Spanish and English subtitles delivered as HLS
WebVTT renditions. The player starts with subtitles off and lets the viewer
switch languages without replacing the current `AVPlayerItem`.

## From speech to subtitle cues

A DVD may contain bitmap subtitle images, text captions, or no subtitles at
all. When no subtitle track exists, `Scripts/transcribe-subtitles.sh` extracts
mono 16 kHz audio and runs whisper.cpp locally:

```text
Dubbed video
    ↓ FFmpeg
Mono WAV
    ↓ whisper.cpp
Timestamped WebVTT + editable SRT + review JSON
```

Each dub is transcribed independently. This preserves the actual wording and
localized names spoken in that language instead of translating one track and
assuming both scripts are identical.

AI output must be reviewed. Proper names, invented vocabulary, songs,
overlapping dialogue, and sound descriptions are common error sources.

## Normalizing generated timestamps

Whisper can split a sentence exactly on a cue boundary and create a fragment
whose start and end are equal:

```vtt
00:01:54.000 --> 00:01:54.000
Grubby
```

`Scripts/normalize_webvtt.py` merges such a fragment into the preceding
contiguous cue. A subtitle parser may accept a zero-duration cue even though it
can never be displayed, so parsing alone is not enough validation.

## Packaging WebVTT for HLS

The bilingual packager accepts two optional reviewed WebVTT files. It creates
one subtitle playlist per language and reuses the video playlist's segment
boundaries:

```text
subtitles/
├── es/
│   ├── playlist.m3u8
│   └── segment_0000.vtt ...
└── en/
    ├── playlist.m3u8
    └── segment_0000.vtt ...
```

Every WebVTT segment includes an `X-TIMESTAMP-MAP` header:

```vtt
WEBVTT
X-TIMESTAMP-MAP=LOCAL:00:00:00.000,MPEGTS:132006
```

WebVTT uses readable local timestamps, while MPEG-TS video uses a 90 kHz
presentation clock. The map tells the player which MPEG-TS timestamp
corresponds to WebVTT time zero. BurstStream reads the first encoded video
segment's presentation timestamp and converts it to the 90 kHz clock instead
of hardcoding a value.

## Advertising subtitle renditions

The multivariant playlist declares a subtitle group:

```text
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subtitles",NAME="Spanish",LANGUAGE="es",AUTOSELECT=YES,DEFAULT=NO,FORCED=NO,URI="subtitles/es/playlist.m3u8"
```

Each video variant references that group with `SUBTITLES="subtitles"`. Its
`CODECS` attribute also identifies `wvtt`, the WebVTT sample type. The subtitle
playlists span the full video timeline even when individual segments contain
no dialogue.

## Discovering subtitles in AVFoundation

Audio uses the `.audible` media characteristic. Subtitles use `.legible`:

```swift
let group = try await item.asset.loadMediaSelectionGroup(for: .legible)
```

The view model converts each `AVMediaSelectionOption` into a lightweight
`SubtitleTrackOption`. The UI also adds an explicit Off option.

```swift
item.select(mediaOption, in: group) // Select one language.
item.select(nil, in: group)         // Turn subtitles off.
```

Selection occurs on the existing item, so position, buffered video, play/pause
state, and the quality ceiling remain unchanged. The preference is restored
after retrying or rebuilding the item for a quality-limit change. Off is also
remembered as an intentional user choice.

## Related files

```text
Scripts/transcribe-subtitles.sh
Scripts/normalize_webvtt.py
Scripts/package_webvtt_hls.py
Scripts/prepare-bilingual-hls.sh
BurstStream/SubtitleTrackOption.swift
BurstStream/PlayerViewModel.swift
BurstStream/ContentView.swift
```

[← Bilingual audio](bilingual-audio.md) · [Next: Experiments →](experiments.md)
