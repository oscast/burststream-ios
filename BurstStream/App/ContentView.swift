//
//  ContentView.swift
//  BurstStream
//

import SwiftUI

struct ContentView: View {
    // One store instance keeps the home card synchronized when playback saves.
    @StateObject private var progressStore = UserDefaultsPlaybackProgressStore()

    // Editable URL text and the request selected for navigation.
    @State private var draftStreamURLText = SampleStreams.teddyRuxpinBilingualHLS.absoluteString
    @State private var playbackRequest: PlaybackRequest?
    @State private var validationMessage: String?

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

                    Button("Play Teddy Ruxpin local stream") {
                        draftStreamURLText = SampleStreams.teddyRuxpinBilingualHLS.absoluteString
                        loadStream(
                            title: "Teddy Ruxpin",
                            subtitle: "Local bilingual HLS stream"
                        )
                    }
                    .buttonStyle(.bordered)

                    Button("Play Teddy Ruxpin over LAN / AirPlay") {
                        draftStreamURLText = SampleStreams.teddyRuxpinBilingualLAN.absoluteString
                        loadStream(
                            title: "Teddy Ruxpin",
                            subtitle: "LAN bilingual HLS stream"
                        )
                    }
                    .buttonStyle(.bordered)

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
                draftStreamURLText = SampleStreams.teddyRuxpinBilingualHLS.absoluteString
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

    private func loadStream(
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
                title: title,
                subtitle: subtitle,
                streamURL: url
            ),
            restoration: nil
        )
    }

    private func continueWatching(_ progress: PlaybackProgress) {
        playbackRequest = PlaybackRequest(
            source: progress.source,
            restoration: progress.restorationState
        )
    }

    private func startOver(_ progress: PlaybackProgress) {
        progressStore.removeProgress(for: progress.streamID)
        playbackRequest = PlaybackRequest(
            source: progress.source,
            restoration: nil
        )
    }
}

#Preview {
    ContentView()
}
