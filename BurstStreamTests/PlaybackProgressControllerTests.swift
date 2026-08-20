//
//  PlaybackProgressControllerTests.swift
//  BurstStreamTests
//

import XCTest
@testable import BurstStream

@MainActor
final class PlaybackProgressControllerTests: XCTestCase {
    func testPeriodicSnapshotsAreThrottled() {
        let store = InMemoryProgressStore()
        var now = Date(timeIntervalSince1970: 100)
        let controller = makeController(store: store, now: { now })

        controller.record(makeSnapshot(position: 30))
        now.addTimeInterval(5)
        controller.record(makeSnapshot(position: 40))
        now.addTimeInterval(5)
        controller.record(makeSnapshot(position: 50))

        XCTAssertEqual(store.savedPositions, [30, 50])
    }

    func testForcedSnapshotBypassesSaveInterval() {
        let store = InMemoryProgressStore()
        let controller = makeController(store: store)

        controller.record(makeSnapshot(position: 30))
        controller.record(makeSnapshot(position: 35), force: true)

        XCTAssertEqual(store.savedPositions, [30, 35])
    }

    func testCompletionRemovesSavedProgress() {
        let store = InMemoryProgressStore()
        let controller = makeController(store: store)

        controller.record(makeSnapshot(position: 40), force: true)
        controller.record(makeSnapshot(position: 90), force: true)

        XCTAssertNil(store.progress(for: "episode-1"))
    }

    func testInitialZeroDoesNotErasePendingRestoration() {
        let store = InMemoryProgressStore()
        store.save(makeProgress(position: 60))
        let controller = makeController(store: store)

        controller.record(
            makeSnapshot(position: 0, isPositionRestorationPending: true),
            force: true
        )

        XCTAssertEqual(store.progress(for: "episode-1")?.position, 60)
    }

    private func makeController(
        store: InMemoryProgressStore,
        now: @escaping () -> Date = { Date(timeIntervalSince1970: 100) }
    ) -> PlaybackProgressController {
        PlaybackProgressController(
            source: StreamSource(
                id: "episode-1",
                title: "Episode 1",
                subtitle: "Test stream",
                streamURL: URL(string: "https://example.com/episode-1/master.m3u8")!
            ),
            store: store,
            now: now
        )
    }

    private func makeSnapshot(
        position: TimeInterval,
        isPositionRestorationPending: Bool = false
    ) -> PlaybackProgressSnapshot {
        PlaybackProgressSnapshot(
            position: position,
            duration: 100,
            qualityLimit: .automatic,
            audioLanguageCode: "en",
            subtitlesEnabled: false,
            subtitleLanguageCode: nil,
            isPositionRestorationPending: isPositionRestorationPending
        )
    }

    private func makeProgress(position: TimeInterval) -> PlaybackProgress {
        PlaybackProgress(
            streamID: "episode-1",
            title: "Episode 1",
            subtitle: "Test stream",
            streamURL: URL(string: "https://example.com/episode-1/master.m3u8")!,
            position: position,
            duration: 100,
            qualityLimitRawValue: PlaybackQualityLimit.automatic.rawValue,
            audioLanguageCode: "en",
            subtitlesEnabled: false,
            subtitleLanguageCode: nil,
            updatedAt: Date(timeIntervalSince1970: 90)
        )
    }
}

@MainActor
private final class InMemoryProgressStore: PlaybackProgressStoring {
    private var records: [String: PlaybackProgress] = [:]
    private(set) var savedPositions: [TimeInterval] = []

    func progress(for streamID: String) -> PlaybackProgress? {
        records[streamID]
    }

    func save(_ progress: PlaybackProgress) {
        records[progress.streamID] = progress
        savedPositions.append(progress.position)
    }

    func removeProgress(for streamID: String) {
        records[streamID] = nil
    }
}
