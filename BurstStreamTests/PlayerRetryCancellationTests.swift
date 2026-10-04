//
//  PlayerRetryCancellationTests.swift
//  BurstStreamTests
//

import Foundation
import XCTest
@testable import BurstStream

final class PlayerRetryCancellationTests: XCTestCase {
    @MainActor
    func testPauseCancelsPendingAutomaticRetry() async {
        let waitStarted = expectation(description: "Retry wait started")
        let waitCancelled = expectation(description: "Retry wait cancelled")
        let scheduler = CancellationRecordingScheduler(
            waitStarted: waitStarted,
            waitCancelled: waitCancelled
        )
        let model = PlayerViewModel(
            streamURL: URL(string: "http://localhost:8000/master.m3u8")!,
            retryPolicy: RetryPolicy(maximumAttempts: 3, initialDelay: 60),
            retryScheduler: scheduler
        )
        let timeout = NSError(
            domain: NSURLErrorDomain,
            code: URLError.Code.timedOut.rawValue
        )

        model.handlePlaybackFailure(error: timeout)
        await fulfillment(of: [waitStarted], timeout: 1)

        model.pause()
        await fulfillment(of: [waitCancelled], timeout: 1)

        XCTAssertEqual(model.playbackState, .paused)
    }
}

private final class CancellationRecordingScheduler: RetryScheduling, @unchecked Sendable {
    private let waitStarted: XCTestExpectation
    private let waitCancelled: XCTestExpectation

    init(
        waitStarted: XCTestExpectation,
        waitCancelled: XCTestExpectation
    ) {
        self.waitStarted = waitStarted
        self.waitCancelled = waitCancelled
    }

    func wait(for seconds: TimeInterval) async throws {
        waitStarted.fulfill()

        do {
            try await Task.sleep(for: .seconds(seconds))
        } catch {
            waitCancelled.fulfill()
            throw error
        }
    }
}
