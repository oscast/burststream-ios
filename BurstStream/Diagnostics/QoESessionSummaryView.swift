//
//  QoESessionSummaryView.swift
//  BurstStream
//

import SwiftUI

struct QoESessionSummaryView: View {
    let summary: QoESessionSummary
    let savedSessionCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Session Quality", systemImage: "waveform.path.ecg")
                .font(.headline)

            metric("Session", summary.id.uuidString.prefix(8).uppercased())
            metric("First frame", formattedDuration(summary.timeToFirstFrame))
            metric(
                "Rebuffering",
                "\(summary.rebufferCount) · \(formattedDuration(summary.rebufferDuration))"
            )
            metric("Watched", formattedDuration(summary.watchedDuration))
            metric("Completion", formattedCompletion)
            metric("Retries", "\(summary.retryCount)")
            metric("Rendition changes", "\(summary.renditionChangeCount)")
            metric("Average bitrate", formattedBitrate(summary.averageObservedBitrate))
            metric("Average resolution", formattedResolution)
            metric(
                "AirPlay",
                "\(summary.externalPlaybackCount) · \(formattedDuration(summary.externalPlaybackDuration))"
            )
            metric("Saved sessions", "\(savedSessionCount)")

            if let failure = summary.startupFailure {
                metric("Startup failure", failure.category.title)
            }

            if let failure = summary.playbackFailure {
                metric("Playback failure", failure.category.title)
            }

            if let error = summary.finalErrorLogDetail {
                metric("Final error", formattedError(error))
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
    }

    private var formattedCompletion: String {
        if summary.completed { return "Completed" }
        guard let completionFraction = summary.completionFraction else { return "In progress" }
        return "\(completionFraction.formatted(.percent.precision(.fractionLength(0)))) watched"
    }

    private var formattedResolution: String {
        guard let width = summary.averageVideoWidth,
              let height = summary.averageVideoHeight else {
            return "—"
        }
        return "\(width) × \(height)"
    }

    private func formattedError(_ error: QoEErrorLogDetail) -> String {
        if let statusCode = error.statusCode {
            return "HTTP \(statusCode)"
        }
        if let domain = error.domain {
            return domain
        }
        return "Recorded"
    }

    private func formattedDuration(_ duration: TimeInterval?) -> String {
        guard let duration else { return "—" }
        return duration.formatted(.number.precision(.fractionLength(1))) + " s"
    }

    private func formattedBitrate(_ bitrate: Double?) -> String {
        guard let bitrate else { return "—" }
        return (bitrate / 1_000_000).formatted(
            .number.precision(.fractionLength(2))
        ) + " Mbps"
    }

    private func metric(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .font(.caption)
    }
}
