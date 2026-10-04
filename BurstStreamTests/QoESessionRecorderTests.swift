//
//  QoESessionRecorderTests.swift
//  BurstStreamTests
//

import Foundation
import XCTest
@testable import BurstStream

@MainActor
final class QoESessionRecorderTests: XCTestCase {
    func testEachRecorderUsesItsOwnSessionIdentifier() {
        let first = QoESessionRecorder()
        let second = QoESessionRecorder()

        XCTAssertNotEqual(first.summary().id, second.summary().id)
    }

    func testAccessLogStartupTimeTakesPrecedenceOverObservedProgress() {
        let start = Date(timeIntervalSince1970: 100)
        var recorder = QoESessionRecorder(startedAt: start)

        recorder.recordTimeline(currentTime: 0.5, duration: 20, at: start.addingTimeInterval(3))
        recorder.recordMetrics(metrics(startupTime: 1.25))

        XCTAssertEqual(recorder.summary().timeToFirstFrame, 1.25)
    }

    func testRebufferEventsCountOnceAndAccumulateDuration() {
        let start = Date(timeIntervalSince1970: 100)
        var recorder = QoESessionRecorder(startedAt: start)

        recorder.recordTimeline(currentTime: 1, duration: 20, at: start.addingTimeInterval(1))
        recorder.recordState(.buffering, failure: nil, at: start.addingTimeInterval(2))
        recorder.recordState(.buffering, failure: nil, at: start.addingTimeInterval(4))
        recorder.recordState(.playing, failure: nil, at: start.addingTimeInterval(7))
        recorder.recordState(.buffering, failure: nil, at: start.addingTimeInterval(9))

        let summary = recorder.summary(at: start.addingTimeInterval(12))
        XCTAssertEqual(summary.rebufferCount, 2)
        XCTAssertEqual(summary.rebufferDuration, 8, accuracy: 0.001)
    }

    func testStartupBufferingIsNotCountedAsRebuffering() {
        let start = Date(timeIntervalSince1970: 100)
        var recorder = QoESessionRecorder(startedAt: start)

        recorder.recordState(.buffering, failure: nil, at: start.addingTimeInterval(1))
        recorder.recordState(.playing, failure: nil, at: start.addingTimeInterval(3))

        let summary = recorder.summary(at: start.addingTimeInterval(3))
        XCTAssertEqual(summary.rebufferCount, 0)
        XCTAssertEqual(summary.rebufferDuration, 0)
    }

    func testCompletionAndFailureAreRecordedWithoutRawErrorDetails() {
        let start = Date(timeIntervalSince1970: 100)
        var recorder = QoESessionRecorder(startedAt: start)
        let failure = PlaybackFailure(
            category: .serverUnavailable,
            statusCode: 503,
            technicalSummary: "https://private.example/video/master.m3u8"
        )

        recorder.recordMetrics(metrics(durationWatched: 18))
        recorder.recordTimeline(currentTime: 18, duration: 20, at: start.addingTimeInterval(18))
        recorder.recordState(.failed(message: "Private details"), failure: failure)
        recorder.recordState(.ended, failure: nil, at: start.addingTimeInterval(20))

        let summary = recorder.summary()
        XCTAssertEqual(summary.watchedDuration, 18)
        XCTAssertEqual(summary.completionFraction ?? -1, 0.9, accuracy: 0.001)
        XCTAssertTrue(summary.completed)
        XCTAssertNil(summary.startupFailure)
        XCTAssertEqual(summary.playbackFailure?.category, .serverUnavailable)
    }

    func testSeekingNearTheEndDoesNotCountAsWatchedTime() {
        let start = Date(timeIntervalSince1970: 100)
        var recorder = QoESessionRecorder(startedAt: start)

        recorder.recordState(.playing, failure: nil, at: start)
        recorder.recordTimeline(currentTime: 0, duration: 100, at: start)
        recorder.recordTimeline(currentTime: 95, duration: 100, at: start.addingTimeInterval(1))

        let summary = recorder.summary(at: start.addingTimeInterval(1))
        XCTAssertEqual(summary.watchedDuration, 0)
        XCTAssertEqual(summary.completionFraction, 0)
        XCTAssertFalse(summary.completed)
    }

    func testNormalPlaybackAdvanceCountsAsWatchedTime() {
        let start = Date(timeIntervalSince1970: 100)
        var recorder = QoESessionRecorder(startedAt: start)

        recorder.recordState(.playing, failure: nil, at: start)
        recorder.recordTimeline(currentTime: 0, duration: 100, at: start)
        recorder.recordTimeline(currentTime: 5, duration: 100, at: start.addingTimeInterval(5))

        XCTAssertEqual(recorder.summary().watchedDuration, 5)
    }

    func testRenditionChangesAverageBitrateAndAverageResolution() {
        var recorder = QoESessionRecorder()

        recorder.recordMetrics(metrics(width: 640, height: 360, bitrate: 1_000_000))
        recorder.recordMetrics(metrics(width: 640, height: 360, bitrate: 2_000_000))
        recorder.recordMetrics(metrics(width: 1280, height: 720, bitrate: 3_000_000))

        let summary = recorder.summary()
        XCTAssertEqual(summary.renditionChangeCount, 2)
        XCTAssertEqual(summary.averageObservedBitrate, 2_000_000)
        XCTAssertEqual(summary.averageVideoWidth, 853)
        XCTAssertEqual(summary.averageVideoHeight, 480)
    }

    func testDuplicateMetricsSnapshotDoesNotBiasAverages() {
        var recorder = QoESessionRecorder()
        let duplicate = metrics(
            width: 640,
            height: 360,
            bitrate: 1_000_000,
            accessLogEntries: 1
        )

        recorder.recordMetrics(duplicate)
        recorder.recordMetrics(duplicate)
        recorder.recordMetrics(metrics(
            width: 1280,
            height: 720,
            bitrate: 3_000_000,
            accessLogEntries: 2
        ))

        let summary = recorder.summary()
        XCTAssertEqual(summary.averageObservedBitrate, 2_000_000)
        XCTAssertEqual(summary.averageVideoWidth, 960)
        XCTAssertEqual(summary.averageVideoHeight, 540)
    }

    func testAccessLogDurationContinuesAcrossItemRebuild() {
        var recorder = QoESessionRecorder()

        recorder.recordMetrics(metrics(durationWatched: 4, accessLogEntries: 1))
        recorder.recordMetrics(metrics(durationWatched: 6, accessLogEntries: 1))
        recorder.recordMetrics(metrics(durationWatched: 1, accessLogEntries: 1))
        recorder.recordMetrics(metrics(durationWatched: 3, accessLogEntries: 1))

        XCTAssertEqual(recorder.summary().watchedDuration, 9)
    }

    func testSeparatesStartupAndPlaybackFailures() {
        let start = Date(timeIntervalSince1970: 100)
        var recorder = QoESessionRecorder(startedAt: start)

        recorder.recordState(
            .retrying(attempt: 1, maximumAttempts: 3, delay: 1),
            failure: failure(.timeout),
            at: start.addingTimeInterval(1)
        )
        recorder.recordTimeline(
            currentTime: 1,
            duration: 20,
            at: start.addingTimeInterval(2)
        )
        recorder.recordState(
            .failed(message: "Stopped"),
            failure: failure(.decoding),
            at: start.addingTimeInterval(3)
        )

        let summary = recorder.summary()
        XCTAssertEqual(summary.startupFailure?.category, .timeout)
        XCTAssertEqual(summary.startupFailure?.stage, .startup)
        XCTAssertEqual(summary.playbackFailure?.category, .decoding)
        XCTAssertEqual(summary.playbackFailure?.stage, .playback)
    }

    func testRetriesCountDistinctAutomaticTransitionsAndManualRetry() {
        var recorder = QoESessionRecorder()
        let retrying = PlaybackState.retrying(
            attempt: 1,
            maximumAttempts: 3,
            delay: 1
        )

        recorder.recordState(retrying, failure: failure(.timeout))
        recorder.recordState(retrying, failure: failure(.timeout))
        recorder.recordState(.loading, failure: nil)
        recorder.recordState(retrying, failure: failure(.timeout))
        recorder.recordManualRetry()

        XCTAssertEqual(recorder.summary().retryCount, 3)
    }

    func testAirPlayTransitionsAccumulateDuration() {
        let start = Date(timeIntervalSince1970: 100)
        var recorder = QoESessionRecorder(startedAt: start)

        recorder.recordExternalPlayback(isActive: true, at: start.addingTimeInterval(1))
        recorder.recordExternalPlayback(isActive: true, at: start.addingTimeInterval(2))
        recorder.recordExternalPlayback(isActive: false, at: start.addingTimeInterval(6))

        let summary = recorder.summary(at: start.addingTimeInterval(8))
        XCTAssertEqual(summary.externalPlaybackCount, 1)
        XCTAssertEqual(summary.externalPlaybackDuration, 5)
    }

    func testFinalErrorLogKeepsOnlyPrivacySafeFields() {
        var recorder = QoESessionRecorder()
        recorder.recordMetrics(metrics(
            latestError: PlaybackLogError(
                statusCode: 503,
                domain: "CoreMediaErrorDomain",
                comment: "Service unavailable",
                uri: "https://private.example/master.m3u8"
            )
        ))

        XCTAssertEqual(
            recorder.summary().finalErrorLogDetail,
            QoEErrorLogDetail(
                error: PlaybackLogError(
                    statusCode: 503,
                    domain: "CoreMediaErrorDomain",
                    comment: "Service unavailable",
                    uri: nil
                )
            )
        )

        recorder.recordMetrics(metrics(
            latestError: PlaybackLogError(
                statusCode: 404,
                domain: "10.0.0.5",
                comment: "https://private.example/user@example.com/master.m3u8",
                uri: "https://private.example/master.m3u8"
            )
        ))

        let detail = recorder.summary().finalErrorLogDetail
        XCTAssertEqual(detail?.statusCode, 404)
        XCTAssertNil(detail?.domain)
    }

    func testHistoryIsBoundedPersistentAndExportsPrivacySafeJSON() throws {
        let suiteName = "QoESessionRecorderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = "history"
        let store = QoESessionHistoryStore(
            defaults: defaults,
            storageKey: key,
            maximumSessionCount: 1
        )

        store.record(completedSummary(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            endedAt: Date(timeIntervalSince1970: 100)
        ))
        let newest = completedSummary(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            endedAt: Date(timeIntervalSince1970: 200)
        )
        store.record(newest)

        let restored = QoESessionHistoryStore(
            defaults: defaults,
            storageKey: key,
            maximumSessionCount: 1
        )
        XCTAssertEqual(restored.sessions, [newest])

        let exportedText = String(
            decoding: try restored.exportJSON(),
            as: UTF8.self
        )
        XCTAssertTrue(exportedText.contains("\"schemaVersion\" : 1"))
        XCTAssertFalse(exportedText.contains("http"))
        XCTAssertFalse(exportedText.contains("private.example"))
    }

    private func metrics(
        width: Int? = nil,
        height: Int? = nil,
        bitrate: Double? = nil,
        startupTime: TimeInterval? = nil,
        durationWatched: TimeInterval? = nil,
        accessLogEntries: Int = 1,
        latestError: PlaybackLogError? = nil
    ) -> PlaybackMetrics {
        PlaybackMetrics(
            videoWidth: width,
            videoHeight: height,
            playbackType: nil,
            observedBitrate: bitrate,
            indicatedBitrate: bitrate,
            switchBitrate: nil,
            averageVideoBitrate: nil,
            mediaRequests: nil,
            downloadedDuration: nil,
            durationWatched: durationWatched,
            bytesTransferred: nil,
            stalls: nil,
            droppedVideoFrames: nil,
            startupTime: startupTime,
            serverAddress: "10.0.0.5",
            uri: "https://private.example/video/master.m3u8",
            accessLogEntries: accessLogEntries,
            errorLogEntries: latestError == nil ? 0 : 1,
            latestError: latestError
        )
    }

    private func failure(_ category: PlaybackFailureCategory) -> PlaybackFailure {
        PlaybackFailure(
            category: category,
            statusCode: nil,
            technicalSummary: "Not persisted"
        )
    }

    private func completedSummary(id: UUID, endedAt: Date) -> QoESessionSummary {
        var recorder = QoESessionRecorder(
            id: id,
            startedAt: endedAt.addingTimeInterval(-10)
        )
        recorder.recordTimeline(
            currentTime: 10,
            duration: 10,
            at: endedAt
        )
        recorder.recordState(.ended, failure: nil, at: endedAt)
        return recorder.summary(at: endedAt)
    }
}
