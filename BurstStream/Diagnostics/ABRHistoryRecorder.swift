//
//  ABRHistoryRecorder.swift
//  BurstStream
//

import Combine
import Foundation

/// Keeps a bounded in-memory history for one playback experiment.
///
/// This object is intentionally independent from AVPlayer. It receives simple
/// snapshots, which keeps recording logic testable and the player model focused.
@MainActor
final class ABRHistoryRecorder: ObservableObject {
    @Published private(set) var samples: [ABRHistorySample] = []

    private let maximumSamples: Int
    private var experimentStart = Date()

    init(maximumSamples: Int = 600) {
        self.maximumSamples = maximumSamples
    }

    var latestSample: ABRHistorySample? {
        samples.last
    }

    var transitions: [ABRHistorySample] {
        samples.filter(\.isTransition)
    }

    func record(
        metrics: PlaybackMetrics,
        playbackTime: TimeInterval,
        bufferAhead: TimeInterval,
        networkProfile: NetworkProfile?,
        playbackState: PlaybackState,
        forceTransition: Bool = false
    ) {
        guard metrics.accessLogEntries > 0 || forceTransition else { return }

        let variant = Self.variantName(from: metrics)
        let profile = networkProfile?.title ?? "Unknown"
        let previous = samples.last
        let stateChanged = previous?.playbackState != playbackState.title
        let notableStateChange = stateChanged && (
            Self.isNotableState(playbackState.title)
                || Self.isNotableState(previous?.playbackState)
        )
        let isTransition = forceTransition
            || previous?.variant != variant
            || previous?.networkProfile != profile
            || notableStateChange

        // Periodic metric refreshes can produce identical snapshots. Keep those
        // only when at least one second has passed to avoid noisy chart data.
        if !isTransition,
           let previous,
           Date().timeIntervalSince(experimentStart) - previous.elapsedTime < 1 {
            return
        }

        samples.append(
            ABRHistorySample(
                elapsedTime: Date().timeIntervalSince(experimentStart),
                playbackTime: playbackTime,
                variant: variant,
                observedBitrate: metrics.observedBitrate,
                requiredBitrate: metrics.indicatedBitrate,
                bufferAhead: bufferAhead,
                networkProfile: profile,
                playbackState: playbackState.title,
                isTransition: isTransition
            )
        )

        if samples.count > maximumSamples {
            samples.removeFirst(samples.count - maximumSamples)
        }
    }

    func clear() {
        samples.removeAll(keepingCapacity: true)
        experimentStart = Date()
    }

    private static func variantName(from metrics: PlaybackMetrics) -> String {
        if let uri = metrics.uri?.lowercased() {
            for variant in ["1080p", "720p", "480p", "360p"] where uri.contains("/\(variant)/") {
                return variant
            }
        }

        if let height = metrics.videoHeight, height > 0 {
            return "\(height)p"
        }

        return "Unknown"
    }

    private static func isNotableState(_ state: String?) -> Bool {
        ["Buffering", "Retrying", "Playback failed"].contains(state)
    }
}
