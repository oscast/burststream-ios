//
//  PlaybackQualityView.swift
//  BurstStream
//

import SwiftUI

struct PlaybackQualityView: View {
    @ObservedObject var viewModel: PlayerViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // Large buttons are easier to tap than a menu Picker and keep every option
    // visible without opening another floating interface.
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 240 : 120), spacing: 8)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Quality limit", systemImage: "dial.medium")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(PlaybackQualityLimit.allCases) { limit in
                    Button {
                        viewModel.setQualityLimit(limit)
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.qualityLimit == limit {
                                Image(systemName: "checkmark.circle.fill")
                            }

                            Text(localizedShortTitle(for: limit))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.qualityLimit == limit ? .blue : .secondary)
                    .accessibilityLabel("Limit quality to \(localizedTitle(for: limit))")
                    .accessibilityValue(
                        viewModel.qualityLimit == limit ? "Selected" : "Not selected"
                    )
                    .accessibilityAddTraits(
                        viewModel.qualityLimit == limit ? .isSelected : []
                    )
                }
            }

            Text("Changing this limit reloads at the same position so old buffered segments do not hide the difference.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func localizedTitle(for limit: PlaybackQualityLimit) -> String {
        switch limit {
        case .automatic: String(localized: "Automatic")
        case .p1080: String(localized: "Up to 1080p")
        case .p720: String(localized: "Up to 720p")
        case .p480: String(localized: "Up to 480p")
        case .p360: String(localized: "Up to 360p")
        }
    }

    private func localizedShortTitle(for limit: PlaybackQualityLimit) -> String {
        switch limit {
        case .automatic: String(localized: "Automatic")
        case .p1080: String(localized: "1080p max")
        case .p720: String(localized: "720p max")
        case .p480: String(localized: "480p max")
        case .p360: String(localized: "360p max")
        }
    }
}
