//
//  PlaybackSubtitlesView.swift
//  BurstStream
//

import SwiftUI

struct PlaybackSubtitlesView: View {
    @ObservedObject var viewModel: PlayerViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 240 : 90), spacing: 8)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Subtitles", systemImage: "captions.bubble")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.subtitleTracks) { track in
                    Button {
                        viewModel.selectSubtitleTrack(track)
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.selectedSubtitleTrackID == track.id {
                                Image(systemName: "checkmark.circle.fill")
                            }

                            Text(localizedTitle(for: track))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
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
                            : "Use \(localizedTitle(for: track)) subtitles"
                    )
                    .accessibilityValue(
                        viewModel.selectedSubtitleTrackID == track.id ? "Selected" : "Not selected"
                    )
                    .accessibilityAddTraits(
                        viewModel.selectedSubtitleTrackID == track.id ? .isSelected : []
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

    private func localizedTitle(for track: SubtitleTrackOption) -> String {
        if track.isOff {
            return String(localized: "Off")
        }

        switch track.languageCode {
        case "es": return String(localized: "Spanish")
        case "en": return String(localized: "English")
        default: return track.title
        }
    }
}
