//
//  RetryPolicy.swift
//  BurstStream
//

import Foundation

/// Decides how many retries to make and how long to wait before each one.
/// This pure value knows nothing about AVPlayer, networking, UI, or concurrency.
struct RetryPolicy: Equatable {
    let maximumAttempts: Int
    let initialDelay: TimeInterval

    static let playbackDefault = RetryPolicy(
        maximumAttempts: 3,
        initialDelay: 1
    )

    /// Exponential backoff: 1, 2, 4, 8... seconds.
    func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        return initialDelay * pow(2, Double(attempt - 1))
    }
}

/// Injectable boundary for waiting before a retry.
///
/// A protocol is useful here: production waits for real time, while tests can
/// inject an implementation that completes immediately.
protocol RetryScheduling: Sendable {
    func wait(for seconds: TimeInterval) async throws
}

/// Production implementation based on the Swift Concurrency clock.
struct TaskRetryScheduler: RetryScheduling {
    func wait(for seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
}
