# Offline HLS

BurstStream uses `AVAssetDownloadURLSession` for on-demand HLS. The home screen
lets you inspect available audio and subtitle tracks, start a download, pause,
resume, cancel, delete, and play the completed local asset. Download metadata
is persisted; AVFoundation owns the `.movpkg` bundle. Only HTTP(S) `.m3u8` VOD
streams are accepted. A storage reserve is checked before starting.

A signed iPad Air and iPhone iOS 27 Simulator build downloaded the local
bilingual smoke fixture, selected the English audio track, and advanced the
app's player from the downloaded asset while the media server returned HTTP
503. Simulator tests also exercised pause, resume, cancel, and deletion.
Offline playback must select the downloaded media before attaching its item
to AVPlayer; otherwise AVPlayer may request the undownloaded default-language
playlist from the server. **Do not pass `CODE_SIGNING_ALLOWED=NO`** when testing
background asset downloads: `nsurlsessiond` then cannot resolve the app
container and reports an
uninformative `NSURLErrorDomain -1`. Ordinary unit tests can still run unsigned.

Start the local server and create the fixture described in
[`getting-started.md`](getting-started.md), then run the
`OfflineHLSDownloadIntegrationTests` test with normal local signing. The test
skips when the optional fixture is absent.

Still to verify on a physical device: background completion after process
suspension/relaunch, low-storage behavior, actual radio disconnection and
recovery, and download cleanup after an OS eviction. Simulator HTTP-503
playback is verified; a real-network-off device check remains.
