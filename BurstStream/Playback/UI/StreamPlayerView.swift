//
//  StreamPlayerView.swift
//  BurstStream
//

import SwiftUI

struct StreamPlayerView: View {
    let video: StreamSource

    @Environment(\.scenePhase) private var scenePhase

    // StateObject keeps these objects alive when SwiftUI recalculates the body.
    // Creating another AVPlayer on every render would break playback.
    @StateObject private var viewModel: PlayerViewModel
    @StateObject private var networkConditioner: NetworkConditionerClient
    @StateObject private var abrHistory = ABRHistoryRecorder()
    @StateObject private var pictureInPicture = PictureInPictureController()
    @StateObject private var playbackLifecycle: PlaybackLifecycleController
    @StateObject private var progressController: PlaybackProgressController

    init(
        video: StreamSource,
        restoration: PlaybackRestorationState? = nil,
        progressStore: UserDefaultsPlaybackProgressStore
    ) {
        self.video = video
        let viewModel = PlayerViewModel(
            streamURL: video.streamURL,
            restoration: restoration
        )
        _viewModel = StateObject(wrappedValue: viewModel)
        _playbackLifecycle = StateObject(
            wrappedValue: PlaybackLifecycleController(playback: viewModel)
        )
        _networkConditioner = StateObject(
            wrappedValue: NetworkConditionerClient(streamURL: video.streamURL)
        )
        _progressController = StateObject(
            wrappedValue: PlaybackProgressController(
                source: video,
                store: progressStore
            )
        )
    }

    var body: some View {
        // GeometryReader reacts to rotation without UIKit notifications or a
        // separate piece of orientation state.
        GeometryReader { geometry in
            ScrollView {
                if geometry.size.width > geometry.size.height {
                    landscapeContent
                } else {
                    portraitContent
                }
            }
            .contentMargins(16, for: .scrollContent)
        }
        .navigationTitle("Now Playing")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.play()
            networkConditioner.refresh()
            playbackLifecycle.handleScenePhase(scenePhase)
        }
        .onDisappear {
            recordProgress(force: true)
            viewModel.pause()
        }
        .onChange(of: viewModel.currentTime) { _, _ in
            recordProgress()
        }
        .onChange(of: viewModel.playbackMetrics) { _, metrics in
            recordABRSample(metrics: metrics)
        }
        .onChange(of: networkConditioner.selectedProfile) { _, _ in
            recordABRSample(metrics: viewModel.playbackMetrics, forceTransition: true)
        }
        .onChange(of: viewModel.playbackState) { _, _ in
            recordABRSample(metrics: viewModel.playbackMetrics)

            if viewModel.playbackState == .ended {
                progressController.clear()
            }
        }
        .onChange(of: viewModel.qualityLimit) { _, _ in
            recordProgress(force: true)
        }
        .onChange(of: viewModel.selectedAudioTrackID) { _, _ in
            recordProgress(force: true)
        }
        .onChange(of: viewModel.selectedSubtitleTrackID) { _, _ in
            recordProgress(force: true)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                recordProgress(force: true)
            }
            playbackLifecycle.handleScenePhase(newPhase)
        }
    }

    /// Portrait uses one column because horizontal space is limited.
    private var portraitContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            videoColumn
            informationColumn
        }
    }

    /// Landscape puts video and controls on the left while quality and
    /// diagnostics use the remaining space on the right.
    private var landscapeContent: some View {
        HStack(alignment: .top, spacing: 20) {
            videoColumn
                .frame(maxWidth: .infinity)

            informationColumn
                .frame(width: 340)
        }
    }

    private var videoColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Use the detected media aspect ratio. Teddy is 4:3, but this same
            // screen can also present a 16:9 stream.
            PlayerSurface(
                player: viewModel.player,
                pictureInPicture: pictureInPicture
            )
                .aspectRatio(videoAspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            PlayerControlsView(
                viewModel: viewModel,
                pictureInPicture: pictureInPicture
            )

            if let errorMessage = pictureInPicture.errorMessage {
                Text("Picture in Picture could not start: \(errorMessage)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var informationColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            PlaybackStatePanel(
                state: viewModel.playbackState,
                onRetry: viewModel.retry
            )

            AirPlayPanel(
                isExternalPlaybackActive: viewModel.isExternalPlaybackActive,
                streamURL: video.streamURL
            )

            PlaybackLifecycleView(
                eventDescription: playbackLifecycle.lastEventDescription
            )

            if viewModel.audioTracks.count > 1 {
                PlaybackAudioView(viewModel: viewModel)
            }

            if viewModel.subtitleTracks.count > 1 {
                PlaybackSubtitlesView(viewModel: viewModel)
            }

            PlaybackQualityView(viewModel: viewModel)

            if networkConditioner.isAvailable {
                NetworkConditionView(conditioner: networkConditioner)
            }

            PlaybackDiagnosticsView(metrics: viewModel.playbackMetrics)

            ABRHistorySummaryView(recorder: abrHistory)

            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.title2.bold())

                Text(video.subtitle)
                    .foregroundStyle(.secondary)

                Text(video.streamURL.absoluteString)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var videoAspectRatio: CGFloat {
        guard let width = viewModel.playbackMetrics.videoWidth,
              let height = viewModel.playbackMetrics.videoHeight,
              height > 0 else {
            return 16 / 9
        }

        return CGFloat(width) / CGFloat(height)
    }

    private func recordABRSample(
        metrics: PlaybackMetrics,
        forceTransition: Bool = false
    ) {
        abrHistory.record(
            metrics: metrics,
            playbackTime: viewModel.currentTime,
            bufferAhead: viewModel.bufferedDurationAhead,
            networkProfile: networkConditioner.selectedProfile,
            playbackState: viewModel.playbackState,
            forceTransition: forceTransition
        )
    }

    private func recordProgress(force: Bool = false) {
        progressController.record(
            PlaybackProgressSnapshot(
                position: viewModel.currentTime,
                duration: viewModel.duration,
                qualityLimit: viewModel.qualityLimit,
                audioLanguageCode: viewModel.selectedAudioLanguageCode,
                subtitlesEnabled: viewModel.areSubtitlesEnabledForPersistence,
                subtitleLanguageCode: viewModel.selectedSubtitleLanguageCode,
                isPositionRestorationPending: viewModel.isPositionRestorationPending
            ),
            force: force
        )
    }
}
