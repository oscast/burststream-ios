//
//  PlaybackProgressStoreTests.swift
//  BurstStreamTests
//

import XCTest
@testable import BurstStream

@MainActor
final class PlaybackProgressStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "PlaybackProgressStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSavedProgressSurvivesStoreRecreation() {
        let firstStore = UserDefaultsPlaybackProgressStore(defaults: defaults)
        firstStore.save(makeProgress(position: 42))

        let restoredStore = UserDefaultsPlaybackProgressStore(defaults: defaults)

        XCTAssertEqual(restoredStore.progress(for: "episode-1")?.position, 42)
    }

    func testStableIdentifierReplacesOlderRecordForSameItem() {
        let store = UserDefaultsPlaybackProgressStore(defaults: defaults)
        store.save(makeProgress(position: 42))
        store.save(makeProgress(position: 84))

        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.progress(for: "episode-1")?.position, 84)
    }

    func testCorruptPersistenceDoesNotPreventStoreCreation() {
        defaults.set(Data("not-json".utf8), forKey: "burststream.playback-progress.v1")

        let store = UserDefaultsPlaybackProgressStore(defaults: defaults)

        XCTAssertTrue(store.records.isEmpty)
    }

    private func makeProgress(position: TimeInterval) -> PlaybackProgress {
        PlaybackProgress(
            streamID: "episode-1",
            title: "Episode 1",
            subtitle: "Test stream",
            streamURL: URL(string: "https://example.com/episode-1/master.m3u8")!,
            position: position,
            duration: 120,
            qualityLimitRawValue: PlaybackQualityLimit.automatic.rawValue,
            audioLanguageCode: "en",
            subtitlesEnabled: false,
            subtitleLanguageCode: nil,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
    }
}
