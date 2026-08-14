//
//  PlaybackQualityView.swift
//  BurstStream
//

import SwiftUI

struct PlaybackQualityView: View {
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
