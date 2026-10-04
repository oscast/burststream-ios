//
//  QoESessionTelemetry.swift
//  BurstStream
//

import Foundation

enum QoEFailureStage: String, Codable, Equatable {
    case startup
    case playback
}

/// A privacy-safe failure snapshot. Raw errors, URLs, server addresses, and
/// request identifiers never enter the persisted QoE history.
struct QoEFailureRecord: Codable, Equatable {
    let stage: QoEFailureStage
    let categoryRawValue: String
    let statusCode: Int?

    var category: PlaybackFailureCategory {
        PlaybackFailureCategory(rawValue: categoryRawValue) ?? .unknown
    }
}

/// A bounded subset of the final AVPlayerItem error-log event.
struct QoEErrorLogDetail: Codable, Equatable {
    let statusCode: Int?
    let domain: String?

    init?(error: PlaybackLogError) {
        let statusCode = error.statusCode > 0 ? error.statusCode : nil
        let domain = Self.privacySafeDomain(error.domain)

        guard statusCode != nil || domain != nil else { return nil }
        self.statusCode = statusCode
        self.domain = domain
    }

    private static func privacySafeDomain(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= 128,
              trimmed.range(
                of: #"^[A-Za-z][A-Za-z0-9.-]*$"#,
                options: .regularExpression
              ) != nil,
              trimmed.hasSuffix("ErrorDomain") || trimmed.hasPrefix("NS") else {
            return nil
        }

        return trimmed
    }
}

/// A privacy-safe, local summary of one playback attempt.
struct QoESessionSummary: Codable, Equatable, Identifiable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let timeToFirstFrame: TimeInterval?
    let rebufferCount: Int
    let rebufferDuration: TimeInterval
    let watchedDuration: TimeInterval
    let mediaDuration: TimeInterval?
    let completed: Bool
    let startupFailure: QoEFailureRecord?
    let playbackFailure: QoEFailureRecord?
    let finalErrorLogDetail: QoEErrorLogDetail?
    let retryCount: Int
    let renditionChangeCount: Int
    let averageObservedBitrate: Double?
    let averageVideoWidth: Int?
    let averageVideoHeight: Int?
    let externalPlaybackCount: Int
    let externalPlaybackDuration: TimeInterval

    var completionFraction: Double? {
        guard let mediaDuration, mediaDuration > 0 else { return nil }
        return min(max(watchedDuration / mediaDuration, 0), 1)
    }
}

/// Accumulates playback events without sending data off the device.
/// Explicit timestamps make transitions deterministic in unit tests.
struct QoESessionRecorder: Equatable {
    private struct Rendition: Equatable {
        let width: Int?
        let height: Int?
        let indicatedBitrate: Int?
    }

    private struct MetricsSample: Equatable {
        let accessLogEntries: Int
        let width: Int?
        let height: Int?
        let observedBitrate: Double?
        let indicatedBitrate: Double?
    }

    private let sessionID: UUID
    private let startedAt: Date
    private var endedAt: Date?
    private var hasPresentedFrame = false
    private var timeToFirstFrame: TimeInterval?
    private var reportedStartupTime: TimeInterval?
    private var activeRebufferStartedAt: Date?
    private var rebufferCount = 0
    private var accumulatedRebufferDuration: TimeInterval = 0
    private var isPlaying = false
    private var lastTimelinePosition: TimeInterval?
    private var lastTimelineDate: Date?
    private var playedDuration: TimeInterval = 0
    private var lastAccessLogWatchedDuration: TimeInterval?
    private var accumulatedAccessLogWatchedDuration: TimeInterval = 0
    private var mediaDuration: TimeInterval?
    private var completed = false
    private var startupFailure: QoEFailureRecord?
    private var playbackFailure: QoEFailureRecord?
    private var finalErrorLogDetail: QoEErrorLogDetail?
    private var lastPlaybackState: PlaybackState?
    private var retryCount = 0
    private var lastRendition: Rendition?
    private var renditionChangeCount = 0
    private var lastMetricsSample: MetricsSample?
    private var observedBitrateTotal: Double = 0
    private var observedBitrateSampleCount = 0
    private var videoWidthTotal = 0
    private var videoHeightTotal = 0
    private var resolutionSampleCount = 0
    private var activeExternalPlaybackStartedAt: Date?
    private var accumulatedExternalPlaybackDuration: TimeInterval = 0
    private var externalPlaybackCount = 0

    init(id: UUID = UUID(), startedAt: Date = Date()) {
        sessionID = id
        self.startedAt = startedAt
    }

    mutating func recordTimeline(
        currentTime: TimeInterval,
        duration: TimeInterval,
        at date: Date = Date()
    ) {
        guard endedAt == nil else { return }

        if currentTime.isFinite, currentTime >= 0 {
            if isPlaying,
               let lastTimelinePosition,
               let lastTimelineDate {
                let mediaAdvance = currentTime - lastTimelinePosition
                let elapsed = max(date.timeIntervalSince(lastTimelineDate), 0)

                // A jump much larger than elapsed time is a seek. A backward
                // jump can also be an item rebuild; neither counts as watched.
                if mediaAdvance > 0, mediaAdvance <= elapsed + 1 {
                    playedDuration += mediaAdvance
                }
            }

            lastTimelinePosition = currentTime
            lastTimelineDate = date

            if currentTime > 0, timeToFirstFrame == nil {
                timeToFirstFrame = max(date.timeIntervalSince(startedAt), 0)
            }
            if currentTime > 0 {
                hasPresentedFrame = true
            }
        }

        if duration.isFinite, duration > 0 {
            mediaDuration = duration
        }
    }

    mutating func recordMetrics(_ metrics: PlaybackMetrics) {
        guard endedAt == nil else { return }

        if reportedStartupTime == nil,
           let startupTime = metrics.startupTime,
           startupTime.isFinite,
           startupTime >= 0 {
            reportedStartupTime = startupTime
            hasPresentedFrame = true
        }

        if let durationWatched = metrics.durationWatched,
           durationWatched.isFinite,
           durationWatched >= 0 {
            if let previous = lastAccessLogWatchedDuration {
                // AVPlayer starts a new access-log timeline after an item
                // rebuild. Preserve the completed item's contribution.
                accumulatedAccessLogWatchedDuration += durationWatched >= previous
                    ? durationWatched - previous
                    : durationWatched
            } else {
                accumulatedAccessLogWatchedDuration += durationWatched
            }
            lastAccessLogWatchedDuration = durationWatched
        }

        if let latestError = metrics.latestError,
           let safeDetail = QoEErrorLogDetail(error: latestError) {
            finalErrorLogDetail = safeDetail
        }

        let sample = MetricsSample(
            accessLogEntries: metrics.accessLogEntries,
            width: metrics.videoWidth,
            height: metrics.videoHeight,
            observedBitrate: metrics.observedBitrate,
            indicatedBitrate: metrics.indicatedBitrate
        )
        guard sample != lastMetricsSample else { return }
        lastMetricsSample = sample

        if let bitrate = metrics.observedBitrate, bitrate.isFinite, bitrate >= 0 {
            observedBitrateTotal += bitrate
            observedBitrateSampleCount += 1
        }

        if let width = metrics.videoWidth,
           let height = metrics.videoHeight,
           width > 0,
           height > 0 {
            videoWidthTotal += width
            videoHeightTotal += height
            resolutionSampleCount += 1
        }

        let rendition = Rendition(
            width: metrics.videoWidth,
            height: metrics.videoHeight,
            indicatedBitrate: metrics.indicatedBitrate.map { Int($0.rounded()) }
        )
        let hasKnownRendition = rendition.width != nil
            || rendition.height != nil
            || rendition.indicatedBitrate != nil
        guard hasKnownRendition else { return }

        if let lastRendition, lastRendition != rendition {
            renditionChangeCount += 1
        }
        lastRendition = rendition
    }

    mutating func recordState(
        _ state: PlaybackState,
        failure: PlaybackFailure?,
        at date: Date = Date()
    ) {
        guard endedAt == nil else { return }

        if state == .buffering, hasPresentedFrame {
            if activeRebufferStartedAt == nil {
                activeRebufferStartedAt = date
                rebufferCount += 1
            }
        } else if state != .buffering {
            finishActiveRebuffer(at: date)
        }

        if case .retrying = state, lastPlaybackState != state {
            retryCount += 1
        }

        if let failure {
            let record = QoEFailureRecord(
                stage: hasPresentedFrame ? .playback : .startup,
                categoryRawValue: failure.category.rawValue,
                statusCode: failure.statusCode
            )
            if record.stage == .startup {
                startupFailure = record
            } else {
                playbackFailure = record
            }
        }

        lastPlaybackState = state
        isPlaying = state == .playing

        if state == .ended {
            completed = true
            finishActiveExternalPlayback(at: date)
            endedAt = date
        }
    }

    mutating func recordManualRetry() {
        guard endedAt == nil else { return }
        retryCount += 1
    }

    mutating func recordExternalPlayback(
        isActive: Bool,
        at date: Date = Date()
    ) {
        guard endedAt == nil else { return }

        if isActive {
            guard activeExternalPlaybackStartedAt == nil else { return }
            activeExternalPlaybackStartedAt = date
            externalPlaybackCount += 1
        } else {
            finishActiveExternalPlayback(at: date)
        }
    }

    mutating func finish(at date: Date = Date()) {
        guard endedAt == nil else { return }
        finishActiveRebuffer(at: date)
        finishActiveExternalPlayback(at: date)
        endedAt = date
    }

    func summary(at date: Date = Date()) -> QoESessionSummary {
        let activeRebufferDuration = activeRebufferStartedAt.map {
            max(date.timeIntervalSince($0), 0)
        } ?? 0
        let activeExternalPlaybackDuration = activeExternalPlaybackStartedAt.map {
            max(date.timeIntervalSince($0), 0)
        } ?? 0

        return QoESessionSummary(
            id: sessionID,
            startedAt: startedAt,
            endedAt: endedAt,
            timeToFirstFrame: reportedStartupTime ?? timeToFirstFrame,
            rebufferCount: rebufferCount,
            rebufferDuration: accumulatedRebufferDuration + activeRebufferDuration,
            watchedDuration: max(playedDuration, accumulatedAccessLogWatchedDuration),
            mediaDuration: mediaDuration,
            completed: completed,
            startupFailure: startupFailure,
            playbackFailure: playbackFailure,
            finalErrorLogDetail: finalErrorLogDetail,
            retryCount: retryCount,
            renditionChangeCount: renditionChangeCount,
            averageObservedBitrate: observedBitrateSampleCount > 0
                ? observedBitrateTotal / Double(observedBitrateSampleCount)
                : nil,
            averageVideoWidth: resolutionSampleCount > 0
                ? Int((Double(videoWidthTotal) / Double(resolutionSampleCount)).rounded())
                : nil,
            averageVideoHeight: resolutionSampleCount > 0
                ? Int((Double(videoHeightTotal) / Double(resolutionSampleCount)).rounded())
                : nil,
            externalPlaybackCount: externalPlaybackCount,
            externalPlaybackDuration: accumulatedExternalPlaybackDuration
                + activeExternalPlaybackDuration
        )
    }

    private mutating func finishActiveRebuffer(at date: Date) {
        guard let activeRebufferStartedAt else { return }
        accumulatedRebufferDuration += max(
            date.timeIntervalSince(activeRebufferStartedAt),
            0
        )
        self.activeRebufferStartedAt = nil
    }

    private mutating func finishActiveExternalPlayback(at date: Date) {
        guard let activeExternalPlaybackStartedAt else { return }
        accumulatedExternalPlaybackDuration += max(
            date.timeIntervalSince(activeExternalPlaybackStartedAt),
            0
        )
        self.activeExternalPlaybackStartedAt = nil
    }
}
