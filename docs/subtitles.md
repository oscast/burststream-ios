---
layout: page
title: WebVTT Subtitles
---

# WebVTT Subtitles

[← Bilingual audio](bilingual-audio.md) · [Documentation home](index.md) · [Next: AirPlay →](airplay.md)

Would you like to add subtitles even though your video does not include any?
Do not worry—BurstStream includes a local script that can create a useful first
draft from the spoken audio. Nothing is uploaded to an online transcription
service.

BurstStream currently supports optional Spanish and English subtitle tracks.
Subtitles start turned off, and the viewer can switch languages without
restarting the video or losing the current position.

## Why BurstStream uses WebVTT

WebVTT is a text format for timed captions. A small example looks like this:

```vtt
WEBVTT

00:00:04.000 --> 00:00:07.000
Welcome to Grundo.
```

WebVTT is not the only subtitle format in the world. You may already know SRT,
and DVDs often store subtitles as images instead of text. BurstStream uses
WebVTT because it works especially well for this project:

- HLS can advertise WebVTT as a selectable subtitle rendition;
- `AVPlayer` can discover and display it through its legible media group;
- the text remains readable and editable without special software; and
- it can be divided into short files that follow the HLS video timeline.

The transcription script also creates an SRT copy because many subtitle
editors support it. The reviewed WebVTT file is the version that the HLS
packaging workflow uses.

## No subtitles? Create a first draft locally

If the video you want to use does not have subtitles, run
`Scripts/transcribe-subtitles.sh`, located in the `Scripts/` directory. The
script extracts the first audio track as a mono 16 kHz WAV file and runs
whisper.cpp locally:

```text
Dubbed video
    ↓ FFmpeg
Mono WAV
    ↓ whisper.cpp
Timestamped WebVTT + editable SRT + review JSON
```

Why convert the audio first? Speech recognition does not need the original
stereo soundtrack or its full sample rate. A mono 16 kHz WAV gives Whisper a
small, predictable input while leaving your original video untouched.

Before using the script, install its local tools:

```bash
brew install ffmpeg whisper-cpp
```

You also need a multilingual whisper.cpp GGML model. By default, BurstStream
looks for:

```text
~/Library/Caches/BurstStream/Whisper/ggml-small.bin
```

If the script reports that the model is missing, follow the Whisper model setup
in the main project README and then run the command again.

The command needs three values:

```text
video path       The video containing the spoken audio
language code    For example, es for Spanish or en for English
stream name      The folder name shared by the subtitle languages
```

For a Spanish version:

```bash
Scripts/transcribe-subtitles.sh \
  LocalMedia/sources/episode-spanish.mp4 \
  es \
  my-episode
```

For an English version of the same episode:

```bash
Scripts/transcribe-subtitles.sh \
  LocalMedia/sources/episode-english.mp4 \
  en \
  my-episode
```

Run the script once for each dubbed-language video. Transcribing both versions
independently preserves what the actors actually say. It also preserves
localized names and phrases that may not match a direct translation.

The generated files appear here:

```text
LocalMedia/subtitles/my-episode/
├── es/
│   ├── subtitles.vtt
│   ├── subtitles.srt
│   └── transcription.json
└── en/
    ├── subtitles.vtt
    ├── subtitles.srt
    └── transcription.json
```

Your original videos are not modified. The temporary mono WAV is deleted after
the transcription finishes.

## Please review AI-generated subtitles

Whisper gives you a first draft, not a finished subtitle track. Watch the video
with the generated text and correct mistakes before packaging or publishing
it. Proper names, invented vocabulary, songs, overlapping dialogue, and sound
descriptions are especially easy for speech recognition to misunderstand.

For example, a fictional place name may sound like a normal word. The correct
subtitle should match the term actually spoken in that dub, not whatever an
automatic translator expects.

## Normalizing generated timestamps

Most generated timestamps are ready to use, but an occasional Whisper fragment
can begin and end at exactly the same moment:

```vtt
00:01:54.000 --> 00:01:54.000
Grubby
```

That cue has no time to appear onscreen. The transcription workflow runs
`Scripts/normalize_webvtt.py`, which safely merges the fragment into the
previous cue. This is why BurstStream validates more than whether a parser can
open the file.

## Packaging WebVTT for HLS

After reviewing both WebVTT files, you can pass them to the bilingual HLS
packager. The packager creates one subtitle playlist per language and follows
the same segment boundaries as the video:

```text
subtitles/
├── es/
│   ├── playlist.m3u8
│   └── segment_0000.vtt ...
└── en/
    ├── playlist.m3u8
    └── segment_0000.vtt ...
```

At this point, the rest becomes more technical. Every WebVTT segment includes
an `X-TIMESTAMP-MAP` header:

```vtt
WEBVTT
X-TIMESTAMP-MAP=LOCAL:00:00:00.000,MPEGTS:132006
```

WebVTT and MPEG-TS count time differently. This map tells the player how their
two clocks line up so a subtitle does not appear too early or too late.
BurstStream calculates the value from the first video segment instead of
hardcoding a number that may be wrong for another video.

## Advertising subtitle renditions

How does `AVPlayer` learn that two subtitle languages exist? The main HLS
playlist declares a subtitle group:

```text
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subtitles",NAME="Spanish",LANGUAGE="es",AUTOSELECT=YES,DEFAULT=NO,FORCED=NO,URI="subtitles/es/playlist.m3u8"
```

Each video variant references that group with `SUBTITLES="subtitles"`. Its
`CODECS` attribute also identifies `wvtt`, the WebVTT sample type. The subtitle
playlists span the full video timeline even when individual segments contain
no dialogue.

## Discovering subtitles in AVFoundation

Once the HLS playlist advertises the tracks, the app asks AVFoundation for the
`.legible` media group. Audio uses a similar group named `.audible`:

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
BurstStream/Playback/MediaSelection/SubtitleTrackOption.swift
BurstStream/Playback/Core/PlayerViewModel.swift
BurstStream/App/ContentView.swift
```

[← Bilingual audio](bilingual-audio.md) · [Next: AirPlay →](airplay.md)
