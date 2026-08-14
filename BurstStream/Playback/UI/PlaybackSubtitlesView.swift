//
//  PlaybackSubtitlesView.swift
//  BurstStream
//

import SwiftUI

struct PlaybackSubtitlesView: View {
    @ObservedObject var viewModel: PlayerViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 90), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Subtitles", systemImage: "captions.bubble")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.subtitleTracks) { track in
                    Button {
                        viewModel.selectSubtitleTrack(track)
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.selectedSubtitleTrackID == track.id {
                                Image(systemName: "checkmark.circle.fill")
                            }

                            Text(track.title)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.bordered)
                    .tint(
                        viewModel.selectedSubtitleTrackID == track.id
                            ? .teal
                            : .secondary
                    )
                    .accessibilityLabel(
                        track.isOff
                            ? "Turn subtitles off"
                            : "Use \(track.title) subtitles"
                    )
                }
            }

            Text("Subtitle changes keep the current playback position and selected quality.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
