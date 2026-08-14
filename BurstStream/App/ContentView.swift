//
//  ContentView.swift
//  BurstStream
//

import SwiftUI

struct ContentView: View {
    // Editable URL text and the stream selected for navigation.
    @State private var draftStreamURLText = SampleStreams.teddyRuxpinBilingualHLS.absoluteString
    @State private var selectedStream: StreamSource?
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
                        draftStreamURLText = SampleStreams.teddyRuxpinBilingualHLS.absoluteString
                        loadStream()
                    }
                    .buttonStyle(.bordered)

                    Button("Play Teddy Ruxpin over LAN / AirPlay") {
                        draftStreamURLText = SampleStreams.teddyRuxpinBilingualLAN.absoluteString
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
                draftStreamURLText = SampleStreams.teddyRuxpinBilingualHLS.absoluteString
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
        selectedStream = StreamSource(
            title: "My HLS Stream",
            subtitle: "User-provided .m3u8 stream",
            streamURL: url
        )
    }
}

#Preview {
    ContentView()
}
