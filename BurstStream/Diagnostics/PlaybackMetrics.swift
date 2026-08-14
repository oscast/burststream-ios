//
//  PlaybackMetrics.swift
//  BurstStream
//

import AVFoundation

/// Simple technical values the UI can display without knowing complex
/// AVFoundation objects.
struct PlaybackMetrics: Equatable {
    let videoWidth: Int?
    let videoHeight: Int?
    let playbackType: String?
    let observedBitrate: Double?
    let indicatedBitrate: Double?
    let switchBitrate: Double?
    let averageVideoBitrate: Double?
    let mediaRequests: Int?
    let downloadedDuration: TimeInterval?
    let durationWatched: TimeInterval?
    let bytesTransferred: Int64?
    let stalls: Int?
    let droppedVideoFrames: Int?
    let startupTime: TimeInterval?
    let serverAddress: String?
    let uri: String?
    let accessLogEntries: Int
    let errorLogEntries: Int
    let latestError: PlaybackLogError?

    static let empty = PlaybackMetrics(
        videoWidth: nil,
        videoHeight: nil,
        playbackType: nil,
        observedBitrate: nil,
        indicatedBitrate: nil,
        switchBitrate: nil,
        averageVideoBitrate: nil,
        mediaRequests: nil,
        downloadedDuration: nil,
        durationWatched: nil,
        bytesTransferred: nil,
        stalls: nil,
        droppedVideoFrames: nil,
        startupTime: nil,
        serverAddress: nil,
        uri: nil,
        accessLogEntries: 0,
        errorLogEntries: 0,
        latestError: nil
    )
}

/// Copies only the error fields needed by the UI.
struct PlaybackLogError: Equatable {
    let statusCode: Int
    let domain: String
    let comment: String?
    let uri: String?
}

/// Maps AVFoundation access and error logs into the app model.
///
/// This does not need a protocol because it is a pure transformation with one
/// rule. Sending metrics to an external provider would be an appropriate future
/// boundary for `PlaybackAnalyticsTracking`.
enum PlaybackMetricsMapper {
    static func makeMetrics(for item: AVPlayerItem) -> PlaybackMetrics {
        let accessEvents = item.accessLog()?.events ?? []
        let errorEvents = item.errorLog()?.events ?? []
        let accessEvent = accessEvents.last
        let errorEvent = errorEvents.last
        let presentationSize = item.presentationSize

        return PlaybackMetrics(
            videoWidth: positiveDimension(presentationSize.width),
            videoHeight: positiveDimension(presentationSize.height),
            playbackType: accessEvent?.playbackType,
            observedBitrate: knownDouble(accessEvent?.observedBitrate),
            indicatedBitrate: knownDouble(accessEvent?.indicatedBitrate),
            switchBitrate: knownDouble(accessEvent?.switchBitrate),
            averageVideoBitrate: knownDouble(accessEvent?.averageVideoBitrate),
            mediaRequests: knownInteger(accessEvent?.numberOfMediaRequests),
            downloadedDuration: knownDouble(accessEvent?.segmentsDownloadedDuration),
            durationWatched: knownDouble(accessEvent?.durationWatched),
            bytesTransferred: knownInteger64(accessEvent?.numberOfBytesTransferred),
            stalls: knownInteger(accessEvent?.numberOfStalls),
            droppedVideoFrames: knownInteger(accessEvent?.numberOfDroppedVideoFrames),
            startupTime: knownDouble(accessEvent?.startupTime),
            serverAddress: accessEvent?.serverAddress,
            uri: accessEvent?.uri,
            accessLogEntries: accessEvents.count,
            errorLogEntries: errorEvents.count,
            latestError: errorEvent.map {
                PlaybackLogError(
                    statusCode: $0.errorStatusCode,
                    domain: $0.errorDomain,
                    comment: $0.errorComment,
                    uri: $0.uri
                )
            }
        )
    }

    /// AVFoundation uses negative values for “unknown.” Convert them to nil so
    /// the UI can display a dash.
    private static func knownDouble(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }

    private static func knownInteger(_ value: Int?) -> Int? {
        guard let value, value >= 0 else { return nil }
        return value
    }

    private static func knownInteger64(_ value: Int64?) -> Int64? {
        guard let value, value >= 0 else { return nil }
        return value
    }

    private static func positiveDimension(_ value: CGFloat) -> Int? {
        guard value.isFinite, value > 0 else { return nil }
        return Int(value.rounded())
    }
}
