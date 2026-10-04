//
//  PlaybackFailureClassifierTests.swift
//  BurstStreamTests
//

import AVFoundation
import Foundation
import XCTest
@testable import BurstStream

final class PlaybackFailureClassifierTests: XCTestCase {
    func testUnauthorizedHTTPStatusDoesNotRetryAutomatically() {
        let failure = classify(statusCode: 403)

        XCTAssertEqual(failure.category, .authorization)
        XCTAssertFalse(failure.shouldRetryAutomatically)
    }

    func testMissingHTTPResourceDoesNotRetryAutomatically() {
        let failure = classify(statusCode: 404)

        XCTAssertEqual(failure.category, .missingResource)
        XCTAssertFalse(failure.shouldRetryAutomatically)
    }

    func testServerFailureRetriesAutomatically() {
        let failure = classify(statusCode: 503)

        XCTAssertEqual(failure.category, .serverUnavailable)
        XCTAssertTrue(failure.shouldRetryAutomatically)
    }

    func testRateLimitedResponseRetriesAutomatically() {
        let failure = classify(statusCode: 429)

        XCTAssertEqual(failure.category, .serverUnavailable)
        XCTAssertTrue(failure.shouldRetryAutomatically)
    }

    func testInvalidPlaylistResponseDoesNotRetryAutomatically() {
        let failure = classify(statusCode: 400)

        XCTAssertEqual(failure.category, .invalidStream)
        XCTAssertFalse(failure.shouldRetryAutomatically)
    }

    func testHTTPStatusTakesPrecedenceOverGenericNetworkError() {
        let timeout = NSError(
            domain: NSURLErrorDomain,
            code: URLError.Code.timedOut.rawValue
        )
        let failure = PlaybackFailureClassifier.classify(
            error: timeout,
            errorLog: PlaybackLogError(
                statusCode: 404,
                domain: "HTTP",
                comment: nil,
                uri: nil
            )
        )

        XCTAssertEqual(failure.category, .missingResource)
        XCTAssertFalse(failure.shouldRetryAutomatically)
    }

    func testRetryAfterDeltaSecondsIsReadFromExposedHTTPResponse() throws {
        let error = try httpError(statusCode: 503, retryAfter: "7")

        let failure = PlaybackFailureClassifier.classify(error: error, errorLog: nil)

        XCTAssertEqual(failure.category, .serverUnavailable)
        XCTAssertEqual(failure.statusCode, 503)
        XCTAssertEqual(failure.retryAfter, 7)
    }

    func testRetryAfterHTTPDateIsConvertedToDelay() throws {
        let now = Date(timeIntervalSince1970: 784_111_777)
        let error = try httpError(
            statusCode: 503,
            retryAfter: "Sun, 06 Nov 1994 08:49:47 GMT"
        )

        let failure = PlaybackFailureClassifier.classify(
            error: error,
            errorLog: nil,
            now: now
        )

        XCTAssertEqual(failure.retryAfter, 10)
    }

    func testInvalidRetryAfterIsIgnored() throws {
        let error = try httpError(statusCode: 503, retryAfter: "later")

        let failure = PlaybackFailureClassifier.classify(error: error, errorLog: nil)

        XCTAssertNil(failure.retryAfter)
    }

    func testRetryAfterIsFoundInWrappedNetworkError() throws {
        let networkError = try httpError(statusCode: 429, retryAfter: "5")
        let avFoundationError = NSError(
            domain: AVFoundationErrorDomain,
            code: -11800,
            userInfo: [NSUnderlyingErrorKey: networkError]
        )

        let failure = PlaybackFailureClassifier.classify(
            error: avFoundationError,
            errorLog: nil
        )

        XCTAssertEqual(failure.category, .serverUnavailable)
        XCTAssertEqual(failure.statusCode, 429)
        XCTAssertEqual(failure.retryAfter, 5)
    }

    func testTimeoutRetriesAutomatically() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: URLError.Code.timedOut.rawValue
        )
        let failure = PlaybackFailureClassifier.classify(error: error, errorLog: nil)

        XCTAssertEqual(failure.category, .timeout)
        XCTAssertTrue(failure.shouldRetryAutomatically)
    }

    func testOfflineErrorRetriesAutomatically() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: URLError.Code.notConnectedToInternet.rawValue
        )
        let failure = PlaybackFailureClassifier.classify(error: error, errorLog: nil)

        XCTAssertEqual(failure.category, .offline)
        XCTAssertTrue(failure.shouldRetryAutomatically)
    }

    func testDecoderFailureDoesNotRetryAutomatically() {
        let error = NSError(domain: AVFoundationErrorDomain, code: -11821)
        let failure = PlaybackFailureClassifier.classify(error: error, errorLog: nil)

        XCTAssertEqual(failure.category, .decoding)
        XCTAssertFalse(failure.shouldRetryAutomatically)
    }

    private func classify(statusCode: Int) -> PlaybackFailure {
        PlaybackFailureClassifier.classify(
            error: nil,
            errorLog: PlaybackLogError(
                statusCode: statusCode,
                domain: "HTTP",
                comment: nil,
                uri: nil
            )
        )
    }

    private func httpError(statusCode: Int, retryAfter: String) throws -> NSError {
        let url = try XCTUnwrap(URL(string: "http://localhost:8000/master.m3u8"))
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Retry-After": retryAfter]
            )
        )

        return NSError(
            domain: NSURLErrorDomain,
            code: URLError.Code.badServerResponse.rawValue,
            userInfo: ["HTTPResponse": response]
        )
    }
}
