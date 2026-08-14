//
//  PlaybackAudioView.swift
//  BurstStream
//

import SwiftUI

struct PlaybackAudioView: View {
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
