---
layout: page
title: HLS Fundamentals
---

# HLS Fundamentals

[← Getting started](getting-started.md) · [Documentation home](index.md) · [Next: Architecture →](architecture.md)

## Container and codec are different concepts

An MKV or MP4 file is a **container**. It can hold video, one or more audio
tracks, subtitles, and metadata. A **codec** describes how an individual video
or audio stream is compressed and decoded, such as H.264 or AAC.

Changing a filename from `.mkv` to `.mp4` does not convert its codecs. FFmpeg
must decode, encode, or remux the actual streams.

## What FFmpeg does

The packaging scripts use FFmpeg to:

1. Read the source container.
2. Decode the source video when a new resolution is required.
3. Encode Apple-compatible H.264 video and AAC audio.
4. Insert regularly spaced keyframes.
5. Divide the timeline into short segments.
6. Write media playlists and a master playlist.

## HLS playlists and segments

HLS stands for **HTTP Live Streaming**, but it supports both live streams and
complete video-on-demand content.

A media playlist is a text file:

```m3u8
#EXTM3U
#EXT-X-TARGETDURATION:6
#EXTINF:6.006,
segment_0000.ts
#EXTINF:6.006,
segment_0001.ts
#EXT-X-ENDLIST
```

The playlist describes segment order and duration. The `.ts` files contain the
compressed media. `AVPlayer` requests upcoming segments as playback advances
instead of downloading the entire episode first.

## Master playlists

A master playlist advertises alternative renditions:

```m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3365343,RESOLUTION=960x720
video/720p/playlist.m3u8

#EXT-X-STREAM-INF:BANDWIDTH=962349,RESOLUTION=480x360
video/360p/playlist.m3u8
```

This information gives the player enough context to choose a quality based on
network throughput, buffer health, device size, and other playback conditions.

## Why segments matter

Segments enable:

- playback before the complete video is downloaded;
- seeking to a later part of the timeline;
- recovery from individual request failures;
- switching between aligned quality renditions;
- live playlists that continuously add new media.

## Keyframes and accurate switching

Most compressed frames depend on earlier frames. A keyframe is independently
decodable and provides a safe point to begin playback or switch rendition.

BurstStream's adaptive packaging script forces identical keyframe intervals on
every quality. Segment boundaries therefore represent the same time ranges,
allowing `AVPlayer` to move from one quality to another without losing position.

## The local server's responsibility

The development server maps HTTP paths to generated files:

```text
/hls/my-video/master.m3u8
        ↓
LocalMedia/hls/my-video/master.m3u8
```

It does not transcode media or choose the quality. FFmpeg packages the content;
the server delivers files; `AVPlayer` makes playback decisions.

## Key takeaways

- A container holds streams; a codec compresses a stream.
- A playlist describes media rather than containing the complete movie.
- Short segments make streaming, seeking, retry, and ABR possible.
- Aligned keyframes are essential for clean quality switching.

[← Getting started](getting-started.md) · [Next: Architecture →](architecture.md)
