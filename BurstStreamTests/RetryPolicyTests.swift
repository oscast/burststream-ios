//
//  RetryPolicyTests.swift
//  BurstStreamTests
//

import XCTest
@testable import BurstStream

final class RetryPolicyTests: XCTestCase {
    func testDelayUsesExponentialBackoff() {
        let policy = RetryPolicy(maximumAttempts: 4, initialDelay: 1)

        XCTAssertEqual(policy.delay(forAttempt: 0), 0)
        XCTAssertEqual(policy.delay(forAttempt: 1), 1)
        XCTAssertEqual(policy.delay(forAttempt: 2), 2)
        XCTAssertEqual(policy.delay(forAttempt: 3), 4)
        XCTAssertEqual(policy.delay(forAttempt: 4), 8)
    }

    func testRetryAfterCanExtendButNotShortenBackoff() {
        let policy = RetryPolicy(maximumAttempts: 3, initialDelay: 2)

        XCTAssertEqual(policy.delay(forAttempt: 2, retryAfter: 10), 10)
        XCTAssertEqual(policy.delay(forAttempt: 2, retryAfter: 1), 4)
    }

    func testInvalidRetryAfterFallsBackToClientBackoff() {
        let policy = RetryPolicy(maximumAttempts: 3, initialDelay: 2)

        XCTAssertEqual(policy.delay(forAttempt: 2, retryAfter: -.infinity), 4)
        XCTAssertEqual(policy.delay(forAttempt: 2, retryAfter: .nan), 4)
    }

    func testTaskSchedulerWaitIsCancellationAware() async {
        let task = Task {
            try await TaskRetryScheduler().wait(for: 60)
        }

        task.cancel()

        do {
            try await task.value
            XCTFail("A cancelled retry wait should throw CancellationError.")
        } catch is CancellationError {
            // Expected cancellation path.
        } catch {
            XCTFail("Unexpected cancellation error: \(error)")
        }
    }
}
