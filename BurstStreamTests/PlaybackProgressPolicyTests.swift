//
//  PlaybackProgressPolicyTests.swift
//  BurstStreamTests
//

import XCTest
@testable import BurstStream

final class PlaybackProgressPolicyTests: XCTestCase {
    private let policy = PlaybackProgressPolicy.default

    func testShortViewingSessionDoesNotCreateResumeProgress() {
        XCTAssertFalse(policy.isResumable(position: 29, duration: 100))
        XCTAssertTrue(policy.isResumable(position: 30, duration: 100))
    }

    func testNearlyCompletedItemIsTreatedAsFinished() {
        XCTAssertFalse(policy.isCompleted(position: 89, duration: 100))
        XCTAssertTrue(policy.isCompleted(position: 90, duration: 100))
        XCTAssertFalse(policy.isResumable(position: 90, duration: 100))
    }

    func testInvalidDurationCannotBeResumedOrCompleted() {
        XCTAssertFalse(policy.isResumable(position: 60, duration: 0))
        XCTAssertFalse(policy.isResumable(position: 60, duration: .infinity))
        XCTAssertFalse(policy.isCompleted(position: 60, duration: .nan))
    }
}
