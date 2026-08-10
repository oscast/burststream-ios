//
//  ContentView.swift
//  BurstStream
//
//  Created by Oscar Castillo on 10/8/26.
//

import SwiftUI

struct ContentView: View {
    // Editable URL text and the stream selected for navigation.
    @State private var draftStreamURLText = LocalStreams.teddyRuxpinBilingualHLS.absoluteString
    @State private var selectedStream: StreamVideo?
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Your HLS stream") {
                    TextField("https://example.com/video/master.m3u8", text: $draftStreamURLText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .lineLimit(2...4)

                    Button("Load stream") {
                        loadStream()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Play Teddy Ruxpin local stream") {
                        draftStreamURLText = LocalStreams.teddyRuxpinBilingualHLS.absoluteString
                        loadStream()
                    }
                    .buttonStyle(.bordered)

                    Button("Use sample HLS stream") {
                        draftStreamURLText = SampleStreams.bigBuckBunnyHLS.absoluteString
                        loadStream()
                    }
                    .buttonStyle(.bordered)

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Local streaming steps") {
                    Label("Create the bilingual ladder with Scripts/prepare-bilingual-hls.sh.", systemImage: "film.stack")
                    Label("Keep Scripts/serve-local-hls.sh running while testing.", systemImage: "network")
                    Label("Use localhost in Simulator; use your Mac IP on a real iPhone.", systemImage: "iphone")
                }

                Section("What this step teaches") {
                    Label("AVPlayer can play HLS .m3u8 streams directly.", systemImage: "play.rectangle")
                    Label("The local stream URL is preconfigured for Simulator testing.", systemImage: "externaldrive")
                    Label("Player state and custom controls come from AVPlayer observations.", systemImage: "waveform.path")
                }
            }
            .navigationTitle("BurstStream")
            .onAppear {
                draftStreamURLText = LocalStreams.teddyRuxpinBilingualHLS.absoluteString
            }
            .navigationDestination(item: $selectedStream) { stream in
                StreamPlayerView(video: stream)
            }
        }
    }

    private func loadStream() {
        // Validate the HTTP URL before creating AVPlayer.
        let trimmedURL = draftStreamURLText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmedURL), let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) else {
            validationMessage = "Enter a valid http or https stream URL."
            return
        }

        guard url.pathExtension.lowercased() == "m3u8" else {
            validationMessage = "For streaming practice, use an HLS playlist URL ending in .m3u8."
            return
        }

        validationMessage = nil
        selectedStream = StreamVideo(
            title: "My HLS Stream",
            subtitle: "User-provided .m3u8 stream",
            streamURL: url
        )
    }
}

struct StreamVideo: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let streamURL: URL
}

struct StreamPlayerView: View {
    let video: StreamVideo

    // StateObject keeps these objects alive when SwiftUI recalculates the body.
    // Creating another AVPlayer on every render would break playback.
    @StateObject private var viewModel: PlayerViewModel
    @StateObject private var networkConditioner: LocalNetworkConditioner
    @StateObject private var abrHistory = ABRHistoryRecorder()

    init(video: StreamVideo) {
        self.video = video
        _viewModel = StateObject(wrappedValue: PlayerViewModel(streamURL: video.streamURL))
        _networkConditioner = StateObject(
            wrappedValue: LocalNetworkConditioner(streamURL: video.streamURL)
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
        }
        .onDisappear {
            viewModel.pause()
        }
        .onChange(of: viewModel.playbackMetrics) { _, metrics in
            recordABRSample(metrics: metrics)
        }
        .onChange(of: networkConditioner.selectedProfile) { _, _ in
            recordABRSample(metrics: viewModel.playbackMetrics, forceTransition: true)
        }
        .onChange(of: viewModel.playbackState) { _, _ in
            recordABRSample(metrics: viewModel.playbackMetrics)
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
            PlayerSurface(player: viewModel.player)
                .aspectRatio(videoAspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            PlayerControlsView(viewModel: viewModel)
        }
    }

    private var informationColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            PlaybackStatePanel(
                state: viewModel.playbackState,
                onRetry: viewModel.retry
            )

            if viewModel.audioTracks.count > 1 {
                PlaybackAudioView(viewModel: viewModel)
            }

            PlaybackQualityView(viewModel: viewModel)

            if networkConditioner.isAvailable {
                LocalNetworkConditionView(conditioner: networkConditioner)
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
}

private struct PlaybackAudioView: View {
    @ObservedObject var viewModel: PlayerViewModel

    // The HLS currently exposes two languages. Equal flexible columns use the
    // available width and avoid truncating the longer Spanish display name.
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Audio", systemImage: "waveform")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.audioTracks) { track in
                    Button {
                        viewModel.selectAudioTrack(track)
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.selectedAudioTrackID == track.id {
                                Image(systemName: "checkmark.circle.fill")
                            }

                            Text(track.title)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.selectedAudioTrackID == track.id ? .purple : .secondary)
                    .accessibilityLabel("Use \(track.title) audio")
                }
            }

            Text("Audio changes without restarting the video or losing its current position.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct LocalNetworkConditionView: View {
    @ObservedObject var conditioner: LocalNetworkConditioner

    private let columns = [
        GridItem(.adaptive(minimum: 105), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Local network", systemImage: "network")
                    .font(.headline)

                Spacer()

                if conditioner.isUpdating {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(LocalNetworkProfile.allCases) { profile in
                    Button {
                        conditioner.select(profile)
                    } label: {
                        HStack(spacing: 5) {
                            if conditioner.selectedProfile == profile {
                                Image(systemName: "checkmark.circle.fill")
                            }

                            Text(profile.title)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.bordered)
                    .tint(conditioner.selectedProfile == profile ? .orange : .secondary)
                    .disabled(conditioner.isUpdating)
                    .accessibilityLabel("Simulate \(profile.title)")
                    .accessibilityHint(profile.experimentHint)
                }
            }

            if let selectedProfile = conditioner.selectedProfile {
                Text(selectedProfile.experimentHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Start the throttled local server to enable network experiments.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = conditioner.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct PlaybackQualityView: View {
    @ObservedObject var viewModel: PlayerViewModel

    // Large buttons are easier to tap than a menu Picker and keep every option
    // visible without opening another floating interface.
    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Quality limit", systemImage: "dial.medium")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(PlaybackQualityLimit.allCases) { limit in
                    Button {
                        viewModel.setQualityLimit(limit)
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.qualityLimit == limit {
                                Image(systemName: "checkmark.circle.fill")
                            }

                            Text(limit.shortTitle)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.qualityLimit == limit ? .blue : .secondary)
                    .accessibilityLabel("Limit quality to \(limit.title)")
                }
            }

            Text("Changing this limit reloads at the same position so old buffered segments do not hide the difference.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct PlayerControlsView: View {
    @ObservedObject var viewModel: PlayerViewModel

    // Scrubbing needs an independent local position. Reading currentTime
    // directly would let AVPlayer move the slider underneath the finger.
    @State private var scrubberValue: TimeInterval = 0
    @State private var isScrubbing = false

    private var sliderUpperBound: TimeInterval {
        // Slider does not accept 0...0, so use 1 until duration is available.
        max(viewModel.duration, 1)
    }

    private var displayedTime: TimeInterval {
        isScrubbing ? scrubberValue : viewModel.currentTime
    }

    var body: some View {
        VStack(spacing: 10) {
            Slider(
                // Read real playback time normally and the finger position while
                // the user is dragging the control.
                value: Binding(
                    get: { min(displayedTime, sliderUpperBound) },
                    set: { scrubberValue = $0 }
                ),
                in: 0...sliderUpperBound,
                onEditingChanged: handleScrubbing
            )
            .disabled(viewModel.duration <= 0)

            BufferProgressView(
                ranges: viewModel.bufferedRanges,
                duration: viewModel.duration
            )
            .frame(height: 6)

            HStack {
                Text(formatTime(displayedTime))
                    .monospacedDigit()

                Spacer()

                Label(
                    "\(formatTime(viewModel.bufferedDurationAhead)) buffered",
                    systemImage: "arrow.down.circle"
                )
                .foregroundStyle(.cyan)

                Spacer()

                Text(formatTime(viewModel.duration))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            HStack(spacing: 36) {
                Button {
                    viewModel.skip(by: -10)
                } label: {
                    Image(systemName: "gobackward.10")
                }
                .disabled(viewModel.duration <= 0)
                .accessibilityLabel("Go back 10 seconds")

                Button {
                    viewModel.togglePlayback()
                } label: {
                    Image(systemName: viewModel.isPlaybackActive ? "pause.fill" : "play.fill")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .accessibilityLabel(viewModel.isPlaybackActive ? "Pause" : "Play")

                Button {
                    viewModel.skip(by: 10)
                } label: {
                    Image(systemName: "goforward.10")
                }
                .disabled(viewModel.duration <= 0)
                .accessibilityLabel("Go forward 10 seconds")
            }
            .font(.title2)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onChange(of: viewModel.currentTime) { _, newValue in
            // Synchronize the slider only while the user is not dragging it.
            guard !isScrubbing else { return }
            scrubberValue = newValue
        }
    }

    private func handleScrubbing(_ editing: Bool) {
        if editing {
            // Freeze player-driven visual updates when scrubbing begins.
            isScrubbing = true
        } else {
            // Perform one real seek when the finger is released. Seeking on every
            // movement would create many requests and cancellations.
            viewModel.seek(to: scrubberValue)
            isScrubbing = false
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "--:--" }

        let totalSeconds = Int(time)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// Draws downloaded regions in cyan across the total duration.
/// Multiple regions can appear after seeking to separate positions.
private struct BufferProgressView: View {
    let ranges: [PlaybackBufferRange]
    let duration: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.18))

                if duration > 0 {
                    ForEach(Array(ranges.enumerated()), id: \.offset) { _, range in
                        Capsule()
                            .fill(.cyan.opacity(0.75))
                            .frame(width: width(for: range, availableWidth: geometry.size.width))
                            .offset(x: offset(for: range, availableWidth: geometry.size.width))
                    }
                }
            }
        }
        .accessibilityLabel("Buffered video progress")
    }

    /// Converts range duration into a width proportional to the control.
    private func width(for range: PlaybackBufferRange, availableWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return availableWidth * (range.duration / duration)
    }

    /// Converts range start into a proportional horizontal position.
    private func offset(for range: PlaybackBufferRange, availableWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return availableWidth * (range.start / duration)
    }
}

private struct PlaybackStatePanel: View {
    let state: PlaybackState
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: state.systemImage)
                .font(.title2)
                .foregroundStyle(stateColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(state.title)
                    .font(.headline)

                Text(state.explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if state.isFailure {
                    Button("Retry now", action: onRetry)
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 6)
                }
            }

            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var stateColor: Color {
        if state.isFailure {
            return .red
        }

        if case .retrying = state {
            return .orange
        }

        return .blue
    }
}

enum LocalStreams {
    // The master references four video qualities and two alternate audio renditions.
    static let teddyRuxpinBilingualHLS = URL(
        string: "http://localhost:8000/hls/teddy-ruxpin-bilingual/master.m3u8"
    )!
}

enum SampleStreams {
    static let bigBuckBunnyHLS = URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!
}

#Preview {
    ContentView()
}
