//
//  PlaybackProgressPolicy.swift
//  BurstStream
//

import Foundation

/// Pure product rules for deciding whether progress belongs in Continue
/// Watching. Keeping the math separate makes the thresholds easy to test.
struct PlaybackProgressPolicy: Equatable {
    let minimumResumePosition: TimeInterval
    let completionRatio: Double
    let saveInterval: TimeInterval

    static let `default` = PlaybackProgressPolicy(
        minimumResumePosition: 30,
        completionRatio: 0.90,
        saveInterval: 10
    )

    func isValidDuration(_ duration: TimeInterval) -> Bool {
        duration.isFinite && duration > 0
    }

    func isResumable(position: TimeInterval, duration: TimeInterval) -> Bool {
        guard isValidDuration(duration), position.isFinite else { return false }
        let clampedPosition = min(max(position, 0), duration)
        return clampedPosition >= minimumResumePosition
            && clampedPosition / duration < completionRatio
    }

    func isCompleted(position: TimeInterval, duration: TimeInterval) -> Bool {
        guard isValidDuration(duration), position.isFinite else { return false }
        return min(max(position, 0), duration) / duration >= completionRatio
    }
}
