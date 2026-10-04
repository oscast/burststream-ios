import Foundation
import XCTest
@testable import BurstStream

final class OfflineHLSDownloadRecordTests: XCTestCase {
    func testStoragePolicyKeepsMinimumReserve() {
        XCTAssertEqual(OfflineHLSStoragePolicy.requiredFreeBytes(for: 30), 200_000_000)
        XCTAssertEqual(OfflineHLSStoragePolicy.requiredFreeBytes(for: 300), 300_000_000)
        XCTAssertFalse(OfflineHLSStoragePolicy.hasEnoughSpace(availableBytes: 199_999_999, duration: 30))
    }

    func testOnlyCompletedExistingBundleIsPlayable() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        var record = OfflineHLSDownloadRecord(
            id: "fixture", title: "Fixture", subtitle: "Test",
            remoteURL: URL(string: "http://localhost/fixture.m3u8")!,
            localURL: url, state: .downloading, progress: 1,
            audioLanguageCode: nil, subtitleLanguageCode: nil, createdAt: Date()
        )
        XCTAssertNil(record.playableURL)
        record.state = .completed
        XCTAssertEqual(record.playableURL, url)
        try FileManager.default.removeItem(at: url)
        XCTAssertNil(record.playableURL)
    }
}
