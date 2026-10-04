import AVFoundation
import Foundation
import XCTest
@testable import BurstStream

@MainActor
final class OfflineHLSDownloadIntegrationTests: XCTestCase {
    func testLocalVODDownloadAndLocalAssetPlayback() async throws {
        let url = URL(string: "http://127.0.0.1:8000/hls/bilingual-with-subs-smoke/master.m3u8")!
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
        } catch {
            throw XCTSkip("Start the local HLS server and create the bilingual smoke fixture to run this test.")
        }
        let source = StreamSource(
            id: "offline-smoke-\(UUID().uuidString)",
            title: "Offline smoke",
            subtitle: "Local fixture",
            streamURL: url
        )
        let manager = OfflineHLSDownloadManager.shared
        defer { try? manager.delete(id: source.id) }

        try await manager.start(
            source: source,
            audioTrackID: "audio-0",
            subtitleTrackID: SubtitleTrackOption.off.id
        )

        for _ in 0..<120 {
            if manager.record(for: source.id)?.state == .completed { break }
            if manager.record(for: source.id)?.state == .failed {
                XCTFail("AVFoundation failed to download local VOD")
                return
            }
            try await Task.sleep(for: .milliseconds(500))
        }

        let playableURL = try XCTUnwrap(manager.playableURL(for: source.id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: playableURL.path))

        let player = AVPlayer(url: playableURL)
        player.play()
        defer { player.pause() }
        var didAdvance = false
        for _ in 0..<30 {
            if player.currentTime().seconds > 1 {
                didAdvance = true
                break
            }
            try await Task.sleep(for: .milliseconds(500))
        }
        XCTAssertTrue(didAdvance, "Downloaded HLS did not advance from its local asset")
        player.pause()
        player.replaceCurrentItem(with: nil)
        try manager.delete(id: source.id)
        XCTAssertNil(manager.record(for: source.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: playableURL.path))
    }
}
