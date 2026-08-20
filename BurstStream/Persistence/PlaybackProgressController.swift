//
//  PlaybackProgressController.swift
//  BurstStream
//

import Combine
import Foundation

/// Lightweight values read from PlayerViewModel without giving persistence
/// ownership of AVPlayer or AVPlayerItem.
struct PlaybackProgressSnapshot {
    let position: TimeInterval
    let duration: TimeInterval
    let qualityLimit: PlaybackQualityLimit
    let audioLanguageCode: String?
    let subtitlesEnabled: Bool?
    let subtitleLanguageCode: String?
    let isPositionRestorationPending: Bool
}

/// Decides when to persist a playback snapshot and merges preferences that may
/// still be loading from a newly created AVPlayerItem.
@MainActor
final class PlaybackProgressController: ObservableObject {
    private let source: StreamSource
    private let store: any PlaybackProgressStoring
    private let policy: PlaybackProgressPolicy
    private let now: () -> Date

    private var lastSaveDate: Date?
    private var latestRecord: PlaybackProgress?
    private var hasReachedResumePosition = false

    init(
        source: StreamSource,
        store: any PlaybackProgressStoring,
        policy: PlaybackProgressPolicy? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.source = source
        self.store = store
        self.policy = policy ?? .default
        self.now = now
        latestRecord = store.progress(for: source.id)
    }

    func record(_ snapshot: PlaybackProgressSnapshot, force: Bool = false) {
        guard policy.isValidDuration(snapshot.duration) else { return }

        // Item reconstruction can temporarily move AVPlayer to zero. That is
        // not a user-initiated restart, so keep the existing bookmark until the
        // pending seek has restored the previous timeline position.
        guard !snapshot.isPositionRestorationPending else { return }

        if policy.isCompleted(position: snapshot.position, duration: snapshot.duration) {
            clear()
            return
        }

        if snapshot.position >= policy.minimumResumePosition {
            hasReachedResumePosition = true
        } else if hasReachedResumePosition {
            // Seeking back near the beginning should remove an older resume card.
            clear()
            return
        } else {
            // During restoration AVPlayer may briefly report zero before the
            // pending seek finishes. Preserve the existing record in that window.
            return
        }

        let currentDate = now()
        if !force,
           let lastSaveDate,
           currentDate.timeIntervalSince(lastSaveDate) < policy.saveInterval {
            return
        }

        let progress = PlaybackProgress(
            streamID: source.id,
            title: source.title,
            subtitle: source.subtitle,
            streamURL: source.streamURL,
            position: min(max(snapshot.position, 0), snapshot.duration),
            duration: snapshot.duration,
            qualityLimitRawValue: snapshot.qualityLimit.rawValue,
            audioLanguageCode: snapshot.audioLanguageCode
                ?? latestRecord?.audioLanguageCode,
            subtitlesEnabled: snapshot.subtitlesEnabled
                ?? latestRecord?.subtitlesEnabled
                ?? false,
            subtitleLanguageCode: snapshot.subtitleLanguageCode
                ?? latestRecord?.subtitleLanguageCode,
            updatedAt: currentDate
        )

        store.save(progress)
        latestRecord = progress
        self.lastSaveDate = currentDate
    }

    func clear() {
        store.removeProgress(for: source.id)
        latestRecord = nil
        lastSaveDate = nil
    }
}
