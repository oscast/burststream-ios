//
//  PlaybackProgressStore.swift
//  BurstStream
//

import Combine
import Foundation

/// Persistence boundary used by the feature coordinator.
///
/// UserDefaults is the first implementation, but tests can inject an in-memory
/// store and a larger catalog could later use SwiftData without changing the
/// playback code.
@MainActor
protocol PlaybackProgressStoring: AnyObject {
    func progress(for streamID: String) -> PlaybackProgress?
    func save(_ progress: PlaybackProgress)
    func removeProgress(for streamID: String)
}

/// Stores a small collection as one versioned JSON value.
/// This is appropriate for Continue Watching metadata, not downloaded media.
@MainActor
final class UserDefaultsPlaybackProgressStore: ObservableObject, PlaybackProgressStoring {
    @Published private(set) var records: [PlaybackProgress]

    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "burststream.playback-progress.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        records = Self.loadRecords(from: defaults, key: storageKey)
    }

    var mostRecentResumableProgress: PlaybackProgress? {
        let policy = PlaybackProgressPolicy.default
        return records
            .filter { policy.isResumable(position: $0.position, duration: $0.duration) }
            .max(by: { $0.updatedAt < $1.updatedAt })
    }

    func progress(for streamID: String) -> PlaybackProgress? {
        records.first(where: { $0.streamID == streamID })
    }

    func save(_ progress: PlaybackProgress) {
        records.removeAll(where: { $0.streamID == progress.streamID })
        records.append(progress)
        persistRecords()
    }

    func removeProgress(for streamID: String) {
        let originalCount = records.count
        records.removeAll(where: { $0.streamID == streamID })
        guard records.count != originalCount else { return }
        persistRecords()
    }

    private func persistRecords() {
        do {
            defaults.set(try JSONEncoder().encode(records), forKey: storageKey)
        } catch {
            // Persistence is helpful but must never block video playback.
            print("Could not save Continue Watching progress: \(error)")
        }
    }

    private static func loadRecords(
        from defaults: UserDefaults,
        key: String
    ) -> [PlaybackProgress] {
        guard let data = defaults.data(forKey: key) else { return [] }

        do {
            return try JSONDecoder().decode([PlaybackProgress].self, from: data)
        } catch {
            // Keep a corrupt or obsolete value from preventing app startup.
            print("Could not load Continue Watching progress: \(error)")
            return []
        }
    }
}
