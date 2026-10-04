//
//  PlaybackAudioView.swift
//  BurstStream
//

import SwiftUI

struct PlaybackAudioView: View {
    @ObservedObject var viewModel: PlayerViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // The HLS currently exposes two languages. Equal flexible columns use the
    // available width and avoid truncating the longer Spanish display name.
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 8),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Audio", systemImage: "waveform")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.audioTracks) { track in
                    Button {
                        viewModel.selectAudioTrack(track)
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.selectedAudioTrackID == track.id {
                                Image(systemName: "checkmark.circle.fill")
                            }

                            Text(localizedTitle(for: track))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.selectedAudioTrackID == track.id ? .purple : .secondary)
                    .accessibilityLabel("Use \(localizedTitle(for: track)) audio")
                    .accessibilityValue(
                        viewModel.selectedAudioTrackID == track.id ? "Selected" : "Not selected"
                    )
                    .accessibilityAddTraits(
                        viewModel.selectedAudioTrackID == track.id ? .isSelected : []
                    )
                }
            }

            Text("Audio changes without restarting the video or losing its current position.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func localizedTitle(for track: AudioTrackOption) -> String {
        switch track.languageCode {
        case "es": String(localized: "Latin American Spanish")
        case "en": String(localized: "English")
        default: track.title
        }
    }
}
