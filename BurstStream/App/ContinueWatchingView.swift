//
//  ContinueWatchingView.swift
//  BurstStream
//

import SwiftUI

/// Home-screen card for the most recently updated resumable item.
struct ContinueWatchingView: View {
    let progress: PlaybackProgress
    let onContinue: () -> Void
    let onStartOver: () -> Void

    var body: some View {
        Section("Continue Watching") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(progress.title)
                        .font(.headline)

                    Text("Continue from \(formatTime(progress.position))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progress.position, total: progress.duration)
                    .accessibilityLabel("Viewing progress")
                    .accessibilityValue(progressAccessibilityValue)

                HStack {
                    Text(formatTime(progress.position))
                    Spacer()
                    Text(formatTime(progress.duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

                HStack {
                    Button("Continue", action: onContinue)
                        .buttonStyle(.borderedProminent)

                    Button("Start Over", action: onStartOver)
                        .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var progressAccessibilityValue: String {
        guard progress.duration > 0 else { return "Unknown duration" }
        return "\(Int((progress.position / progress.duration) * 100)) percent watched"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "--:--" }

        let totalSeconds = Int(time)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }
}
