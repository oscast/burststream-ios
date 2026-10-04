//
//  PlaybackFailure.swift
//  BurstStream
//

import AVFoundation
import Foundation

/// A product-level explanation of why AVPlayer could not continue.
///
/// AVFoundation errors are often technical and inconsistent across a playlist,
/// a segment, and different server implementations. The UI receives this small
/// value instead of showing a raw NSError directly to the viewer.
struct PlaybackFailure: Equatable {
    let category: PlaybackFailureCategory
    let statusCode: Int?
    let technicalSummary: String
    let retryAfter: TimeInterval?

    init(
        category: PlaybackFailureCategory,
        statusCode: Int?,
        technicalSummary: String,
        retryAfter: TimeInterval? = nil
    ) {
        self.category = category
        self.statusCode = statusCode
        self.technicalSummary = technicalSummary
        self.retryAfter = retryAfter
    }

    var title: String { category.title }
    var message: String { category.message }
    var recoverySuggestion: String { category.recoverySuggestion }
    var shouldRetryAutomatically: Bool { category.shouldRetryAutomatically }
}

/// Categories are intentionally broad. They explain the next useful action
/// without pretending the client can always diagnose every server detail.
enum PlaybackFailureCategory: String, Equatable {
    case offline
    case timeout
    case serverUnavailable
    case missingResource
    case authorization
    case invalidStream
    case unsupportedMedia
    case decoding
    case unknown

    var title: String {
        switch self {
        case .offline: "No connection"
        case .timeout: "Request timed out"
        case .serverUnavailable: "Server unavailable"
        case .missingResource: "Stream not found"
        case .authorization: "Access denied"
        case .invalidStream: "Invalid stream"
        case .unsupportedMedia: "Unsupported media"
        case .decoding: "Playback decoding failed"
        case .unknown: "Playback problem"
        }
    }

    var message: String {
        switch self {
        case .offline: "BurstStream could not reach the network."
        case .timeout: "The server took too long to respond."
        case .serverUnavailable: "The streaming server is temporarily unavailable."
        case .missingResource: "The playlist or one of its media files could not be found."
        case .authorization: "This stream requires access that the app does not have."
        case .invalidStream: "The server returned media that is not a valid playable HLS stream."
        case .unsupportedMedia: "This device cannot play the stream's media format."
        case .decoding: "The downloaded media could not be decoded."
        case .unknown: "AVPlayer could not continue with this stream."
        }
    }

    var recoverySuggestion: String {
        switch self {
        case .offline: "Check your connection, then try again."
        case .timeout, .serverUnavailable: "BurstStream will retry automatically. You can also try again later."
        case .missingResource: "Check the HLS URL and confirm the local server is still serving this package."
        case .authorization: "Check the stream credentials or server access policy."
        case .invalidStream: "Check the master playlist and its referenced media playlists."
        case .unsupportedMedia: "Use an iOS-supported HLS codec and container combination."
        case .decoding: "Repackage or re-encode the affected rendition, then try again."
        case .unknown: "Check the diagnostics panel, server logs, and stream URL before retrying."
        }
    }

    /// Only failures that are normally temporary enter automatic backoff.
    var shouldRetryAutomatically: Bool {
        switch self {
        case .offline, .timeout, .serverUnavailable:
            true
        case .missingResource, .authorization, .invalidStream, .unsupportedMedia, .decoding, .unknown:
            false
        }
    }
}

/// Converts error-log status codes and NSError domains into one stable product
/// category. This is a pure mapping, so it is inexpensive and easy to test.
enum PlaybackFailureClassifier {
    static func classify(
        error: Error?,
        errorLog: PlaybackLogError?,
        now: Date = Date()
    ) -> PlaybackFailure {
        let response = httpResponse(from: error)
        let loggedStatusCode = errorLog?.statusCode ?? 0
        let statusCode = loggedStatusCode > 0 ? loggedStatusCode : response?.statusCode

        if let statusCode, statusCode > 0 {
            return classifyHTTPStatus(
                statusCode,
                technicalSummary: errorLog?.comment ?? errorLog?.domain ?? "HTTP status \(statusCode)",
                retryAfter: response.flatMap { retryAfter(from: $0, now: now) }
            )
        }

        guard let error else {
            return PlaybackFailure(
                category: .unknown,
                statusCode: nil,
                technicalSummary: errorLog?.comment ?? "No NSError was supplied by AVFoundation."
            )
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return classifyURLFailure(nsError)
        }

        if nsError.domain == AVFoundationErrorDomain {
            return classifyAVFoundationFailure(nsError)
        }

        return PlaybackFailure(
            category: .unknown,
            statusCode: nil,
            technicalSummary: "\(nsError.domain) (\(nsError.code)): \(nsError.localizedDescription)"
        )
    }

    private static func classifyHTTPStatus(
        _ statusCode: Int,
        technicalSummary: String,
        retryAfter: TimeInterval?
    ) -> PlaybackFailure {
        let category: PlaybackFailureCategory

        switch statusCode {
        case 401, 403:
            category = .authorization
        case 404, 410:
            category = .missingResource
        case 408:
            category = .timeout
        case 429, 500...599:
            category = .serverUnavailable
        case 400, 415, 422:
            category = .invalidStream
        default:
            category = .unknown
        }

        return PlaybackFailure(
            category: category,
            statusCode: statusCode,
            technicalSummary: technicalSummary,
            retryAfter: retryAfter
        )
    }

    private static func httpResponse(from error: Error?) -> HTTPURLResponse? {
        guard let error else { return nil }

        var pending = [error as NSError]
        var visited = Set<ObjectIdentifier>()

        while let current = pending.popLast(), visited.insert(ObjectIdentifier(current)).inserted {
            for value in current.userInfo.values {
                if let response = value as? HTTPURLResponse {
                    return response
                }

                if let nestedError = value as? NSError {
                    pending.append(nestedError)
                }
            }
        }

        return nil
    }

    private static func retryAfter(
        from response: HTTPURLResponse,
        now: Date
    ) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        if let seconds = TimeInterval(value), seconds.isFinite, seconds >= 0 {
            return seconds
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"

        guard let date = formatter.date(from: value) else { return nil }
        return max(date.timeIntervalSince(now), 0)
    }

    private static func classifyURLFailure(_ error: NSError) -> PlaybackFailure {
        let category: PlaybackFailureCategory

        switch URLError.Code(rawValue: error.code) {
        case .timedOut:
            category = .timeout
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed, .dataNotAllowed,
             .internationalRoamingOff, .callIsActive:
            category = .offline
        case .badServerResponse, .resourceUnavailable:
            category = .serverUnavailable
        default:
            category = .unknown
        }

        return PlaybackFailure(
            category: category,
            statusCode: nil,
            technicalSummary: "\(error.domain) (\(error.code)): \(error.localizedDescription)"
        )
    }

    private static func classifyAVFoundationFailure(_ error: NSError) -> PlaybackFailure {
        // AVError.Code values are used as raw values here because AVFoundation
        // may wrap them in NSError when playback fails through notifications.
        let category: PlaybackFailureCategory

        switch error.code {
        case -11835: // contentIsNotAuthorized
            category = .authorization
        case -11828: // fileFormatNotRecognized
            category = .invalidStream
        case -11833, -11838: // decoderNotFound, operationNotSupportedForAsset
            category = .unsupportedMedia
        case -11821: // decodeFailed
            category = .decoding
        default:
            category = .unknown
        }

        return PlaybackFailure(
            category: category,
            statusCode: nil,
            technicalSummary: "\(error.domain) (\(error.code)): \(error.localizedDescription)"
        )
    }
}
