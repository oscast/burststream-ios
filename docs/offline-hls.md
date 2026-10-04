# Offline HLS

BurstStream uses `AVAssetDownloadURLSession` for on-demand HLS. The home screen
lets you inspect available audio and subtitle tracks, start a download, pause,
resume, cancel, delete, and play the completed local asset. Download metadata
is persisted; AVFoundation owns the `.movpkg` bundle. Only HTTP(S) `.m3u8` VOD
streams are accepted. A storage reserve is checked before starting.

A signed iPad Air iOS 27 Simulator build downloaded the local bilingual smoke
fixture, selected an audio track, and advanced AVPlayer from the downloaded
asset. **Do not pass `CODE_SIGNING_ALLOWED=NO`** when testing background asset
downloads: `nsurlsessiond` then cannot resolve the app container and reports an
uninformative `NSURLErrorDomain -1`. Ordinary unit tests can still run unsigned.

Start the local server and create the fixture described in
[`getting-started.md`](getting-started.md), then run the
`OfflineHLSDownloadIntegrationTests` test with normal local signing. The test
skips when the optional fixture is absent.

Still to verify on a physical device: background completion after process
suspension/relaunch, storage pressure, network loss and recovery, download
cleanup, and genuinely server-off playback. These are not claimed as
Simulator-verified.
