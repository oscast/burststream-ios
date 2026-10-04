import AVFoundation
import Foundation
import XCTest
@testable import BurstStream

@MainActor
final class OfflineHLSDownloadIntegrationTests: XCTestCase {
    func testLocalVODPlaysWhileMediaServerIsOffline() async throws {
        let url = URL(string: "http://127.0.0.1:8000/hls/bilingual-with-subs-smoke/master.m3u8")!
        try await requireLocalFixture(at: url)
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
            audioTrackID: "audio-1",
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

        try await withServerProfile("offline") {
            var probe = URLRequest(url: url.appending(queryItems: [URLQueryItem(name: "probe", value: UUID().uuidString)]))
            probe.cachePolicy = .reloadIgnoringLocalCacheData
            let (_, response) = try await URLSession.shared.data(for: probe)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 503)

            let model = PlayerViewModel(
                streamURL: playableURL,
                restoration: PlaybackRestorationState(
                    position: 0,
                    qualityLimit: .automatic,
                    audioLanguageCode: "en",
                    subtitlesEnabled: false,
                    subtitleLanguageCode: nil
                )
            )
            model.play()
            defer { model.pause() }
            var didAdvance = false
            for _ in 0..<30 {
                if model.currentTime > 1 {
                    didAdvance = true
                    break
                }
                try await Task.sleep(for: .milliseconds(500))
            }
            XCTAssertTrue(
                didAdvance,
                "Downloaded HLS did not advance while the server was offline; "
                    + "item status: \(String(describing: model.player.currentItem?.status)), "
                    + "item error: \(String(describing: model.player.currentItem?.error)), "
                    + "offline cache: \(String(describing: AVURLAsset(url: playableURL).assetCache?.isPlayableOffline))"
            )
            model.pause()
            model.player.replaceCurrentItem(with: nil)
        }

        try manager.delete(id: source.id)
        XCTAssertNil(manager.record(for: source.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: playableURL.path))
    }

    func testDownloadCanPauseResumeAndCancel() async throws {
        let url = URL(string: "http://127.0.0.1:8000/hls/bilingual-with-subs-smoke/master.m3u8")!
        try await requireLocalFixture(at: url)
        let source = StreamSource(
            id: "offline-controls-\(UUID().uuidString)",
            title: "Offline controls",
            subtitle: "Local fixture",
            streamURL: url
        )
        let manager = OfflineHLSDownloadManager.shared
        defer { try? manager.delete(id: source.id) }

        try await withServerProfile("800kbps") {
            try await manager.start(source: source, audioTrackID: nil, subtitleTrackID: nil)
            XCTAssertEqual(manager.record(for: source.id)?.state, .downloading)
            manager.pause(id: source.id)
            XCTAssertEqual(manager.record(for: source.id)?.state, .paused)
            manager.resume(id: source.id)
            XCTAssertEqual(manager.record(for: source.id)?.state, .downloading)
            manager.cancel(id: source.id)
            XCTAssertNil(manager.record(for: source.id))
        }
    }

    private func requireLocalFixture(at url: URL) async throws {
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
        } catch {
            throw XCTSkip("Start the local HLS server and create the bilingual smoke fixture to run this test.")
        }
    }

    private func withServerProfile(
        _ profile: String,
        operation: () async throws -> Void
    ) async throws {
        let original = try await currentServerProfile()
        try await setServerProfile(profile)
        do {
            try await operation()
            try await setServerProfile(original)
        } catch {
            try? await setServerProfile(original)
            throw error
        }
    }

    private func currentServerProfile() async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: profileURL)
        return try JSONDecoder().decode(ServerProfile.self, from: data).profile
    }

    private func setServerProfile(_ profile: String) async throws {
        var request = URLRequest(url: profileURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["profile": profile])
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }

    private var profileURL: URL {
        URL(string: "http://127.0.0.1:8000/__burststream/profile")!
    }
}

private struct ServerProfile: Decodable {
    let profile: String
}
