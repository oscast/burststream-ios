//
//  ContentView.swift
//  BurstStream
//

import SwiftUI

struct ContentView: View {
    // One store instance keeps the home card synchronized when playback saves.
    @StateObject private var progressStore = UserDefaultsPlaybackProgressStore()
    @StateObject private var mediaServerStore = MediaServerSettingsStore()
    @StateObject private var offlineManager = OfflineHLSDownloadManager.shared
    @StateObject private var qoeHistory = QoESessionHistoryStore.shared

    // Editable URL text and the request selected for navigation.
    @State private var draftStreamURLText = SampleStreams.teddyRuxpinBilingualHLS.absoluteString
    @State private var draftMediaServerBaseURLText = ""
    @State private var playbackRequest: PlaybackRequest?
    @State private var validationMessage: String?
    @State private var mediaServerValidationMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let progress = progressStore.mostRecentResumableProgress {
                    ContinueWatchingView(
                        progress: progress,
                        onContinue: { continueWatching(progress) },
                        onStartOver: { startOver(progress) }
                    )
                }

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

                    Button("Use sample HLS stream") {
                        draftStreamURLText = SampleStreams.bigBuckBunnyHLS.absoluteString
                        loadStream(
                            title: "Big Buck Bunny",
                            subtitle: "Public adaptive HLS sample"
                        )
                    }
                    .buttonStyle(.bordered)

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Media server") {
                    TextField("http://localhost:8000", text: $draftMediaServerBaseURLText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Button("Save media server address") {
                        saveMediaServerAddress()
                    }
                    .buttonStyle(.bordered)

                    Button("Play Teddy Ruxpin from media server") {
                        playTeddyRuxpinFromMediaServer()
                    }
                    .buttonStyle(.borderedProminent)

                    if let mediaServerValidationMessage {
                        Text(mediaServerValidationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                OfflineHLSDownloadsView(
                    manager: offlineManager,
                    source: offlineDownloadSource,
                    onPlay: playOffline
                )

                QoESessionHistoryView(store: qoeHistory)

                Section("Local streaming steps") {
                    Label("Create the bilingual ladder with Scripts/prepare-bilingual-hls.sh.", systemImage: "film.stack")
                    Label("Keep Scripts/serve-local-hls.sh running while testing.", systemImage: "network")
                    Label("Keep localhost for Simulator, or enter your Mac address for LAN playback.", systemImage: "iphone")
                }

                Section("What this step teaches") {
                    Label("AVPlayer can play HLS .m3u8 streams directly.", systemImage: "play.rectangle")
                    Label("The local stream URL is preconfigured for Simulator testing.", systemImage: "externaldrive")
                    Label("Player state and custom controls come from AVPlayer observations.", systemImage: "waveform.path")
                }
            }
            .navigationTitle("BurstStream")
            .onAppear {
                if draftMediaServerBaseURLText.isEmpty {
                    draftMediaServerBaseURLText = mediaServerStore.configuration.baseURL.absoluteString
                    draftStreamURLText = configuredTeddyRuxpinURL.absoluteString
                }
            }
            .navigationDestination(item: $playbackRequest) { request in
                StreamPlayerView(
                    video: request.source,
                    restoration: request.restoration,
                    progressStore: progressStore
                )
            }
        }
    }

    private var configuredTeddyRuxpinURL: URL {
        SampleStreams.teddyRuxpinBilingualHLS(
            mediaServerBaseURL: mediaServerStore.configuration.baseURL
        )
    }

    private var offlineDownloadSource: StreamSource? {
        let text = draftStreamURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: text),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.pathExtension.lowercased() == "m3u8" else { return nil }

        if url == configuredTeddyRuxpinURL {
            return StreamSource(
                id: SampleStreams.teddyRuxpinBilingualID,
                title: "Teddy Ruxpin",
                subtitle: "Bilingual HLS stream",
                streamURL: url
            )
        }
        return StreamSource(
            title: "My HLS Stream",
            subtitle: "Downloaded HLS stream",
            streamURL: url
        )
    }

    private func saveMediaServerAddress() {
        guard mediaServerStore.updateBaseURL(from: draftMediaServerBaseURLText) else {
            mediaServerValidationMessage = "Enter a valid http or https server address."
            return
        }

        mediaServerValidationMessage = nil
        draftMediaServerBaseURLText = mediaServerStore.configuration.baseURL.absoluteString
        draftStreamURLText = configuredTeddyRuxpinURL.absoluteString
    }

    private func playTeddyRuxpinFromMediaServer() {
        guard mediaServerStore.updateBaseURL(from: draftMediaServerBaseURLText) else {
            mediaServerValidationMessage = "Enter a valid http or https server address."
            return
        }

        mediaServerValidationMessage = nil
        draftMediaServerBaseURLText = mediaServerStore.configuration.baseURL.absoluteString
        draftStreamURLText = configuredTeddyRuxpinURL.absoluteString
        loadStream(
            id: SampleStreams.teddyRuxpinBilingualID,
            title: "Teddy Ruxpin",
            subtitle: "Configured bilingual HLS stream"
        )
    }

    private func loadStream(
        id: String? = nil,
        title: String = "My HLS Stream",
        subtitle: String = "User-provided .m3u8 stream"
    ) {
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
        playbackRequest = PlaybackRequest(
            source: StreamSource(
                id: id,
                title: title,
                subtitle: subtitle,
                streamURL: url
            ),
            restoration: nil
        )
    }

    private func continueWatching(_ progress: PlaybackProgress) {
        playbackRequest = PlaybackRequest(
            source: sourceUsingCurrentMediaServer(progress.source),
            restoration: progress.restorationState
        )
    }

    private func startOver(_ progress: PlaybackProgress) {
        progressStore.removeProgress(for: progress.streamID)
        playbackRequest = PlaybackRequest(
            source: sourceUsingCurrentMediaServer(progress.source),
            restoration: nil
        )
    }

    private func sourceUsingCurrentMediaServer(_ source: StreamSource) -> StreamSource {
        if let offlineURL = offlineManager.playableURL(for: source.id) {
            return StreamSource(
                id: source.id,
                title: source.title,
                subtitle: source.subtitle,
                streamURL: offlineURL
            )
        }
        guard let configuredURL = SampleStreams.configuredURL(
            for: source.id,
            mediaServerBaseURL: mediaServerStore.configuration.baseURL
        ) else {
            return source
        }

        return StreamSource(
            id: source.id,
            title: source.title,
            subtitle: source.subtitle,
            streamURL: configuredURL
        )
    }

    private func playOffline(_ record: OfflineHLSDownloadRecord) {
        guard let localURL = offlineManager.playableURL(for: record.id) else { return }
        playbackRequest = PlaybackRequest(
            source: StreamSource(
                id: record.id,
                title: record.title,
                subtitle: "Downloaded for offline playback",
                streamURL: localURL
            ),
            restoration: progressStore.progress(for: record.id)?.restorationState
        )
    }
}

#Preview {
    ContentView()
}
