# Source Videos

Place local source files in this directory. Supported inputs depend on the
installed FFmpeg build, but MP4, MKV, and MOV are common choices.

Actual media files are ignored by Git.

## Local AI subtitle transcription

After installing FFmpeg, whisper.cpp, and a multilingual GGML model as
described in the project README, transcribe each spoken language separately:

```bash
Scripts/transcribe-subtitles.sh \
  LocalMedia/sources/episode-spanish.mp4 \
  es \
  episode-bilingual

Scripts/transcribe-subtitles.sh \
  LocalMedia/sources/episode-english.mp4 \
  en \
  episode-bilingual
```

The generated files appear under
`LocalMedia/subtitles/episode-bilingual/{es,en}/`. Always review AI-generated
text against the original audio before publishing it.

## Single-quality HLS

```bash
Scripts/prepare-local-hls.sh \
  LocalMedia/sources/my-video.mp4 \
  my-video
```

## Four-quality adaptive HLS

```bash
Scripts/prepare-adaptive-hls.sh \
  LocalMedia/sources/my-video.mp4 \
  my-video-adaptive
```

## Bilingual adaptive HLS

Use two synchronized source files with the same visual timeline and different
audio languages:

```bash
Scripts/prepare-bilingual-hls.sh \
  LocalMedia/sources/episode-spanish.mp4 \
  LocalMedia/sources/episode-english.mp4 \
  episode-bilingual
```

Generated output will appear under:

```text
LocalMedia/hls/<stream-name>/
```

Do not place source videos inside `LocalMedia/hls/`. That directory is reserved
for generated playlists and segments and may be replaced when a stream is
packaged again.
