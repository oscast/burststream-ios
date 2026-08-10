# Local Media Workspace

This directory is the local, ignored workspace used by BurstStream's packaging
and server scripts.

```text
LocalMedia/
├── sources/   Place source MP4, MKV, or MOV files here
└── hls/       Generated automatically by the packaging scripts
```

Only this README and `sources/README.md` are committed. Source videos, HLS
playlists, and media segments remain local and are ignored by Git.

## Recommended workflow

1. Copy or move media you have permission to use into `LocalMedia/sources/`.
2. Run one of the scripts documented in the source-folder README.
3. Find generated streaming packages under `LocalMedia/hls/`.
4. Start the server with `Scripts/serve-local-hls.sh 8000`.

The scripts also accept absolute paths, so copying a large source into this
repository is optional.
