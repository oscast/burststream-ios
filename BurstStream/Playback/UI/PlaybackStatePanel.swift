//
//  PlaybackStatePanel.swift
//  BurstStream
//

import SwiftUI

struct PlaybackStatePanel: View {
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
