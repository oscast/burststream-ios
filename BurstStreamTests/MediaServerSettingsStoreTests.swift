//
//  MediaServerSettingsStoreTests.swift
//  BurstStreamTests
//

import XCTest
@testable import BurstStream

@MainActor
final class MediaServerSettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "MediaServerSettingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsToSimulatorLocalhost() {
        let store = MediaServerSettingsStore(defaults: defaults)

        XCTAssertEqual(store.configuration.baseURL, URL(string: "http://localhost:8000"))
        XCTAssertEqual(
            SampleStreams.teddyRuxpinBilingualHLS(mediaServerBaseURL: store.configuration.baseURL),
            URL(string: "http://localhost:8000/hls/teddy-ruxpin-bilingual/master.m3u8")
        )
    }

    func testConfiguredLANAddressSurvivesStoreRecreation() {
        let firstStore = MediaServerSettingsStore(defaults: defaults)

        XCTAssertTrue(firstStore.updateBaseURL(from: "  http://192.168.50.25:8000/  "))

        let restoredStore = MediaServerSettingsStore(defaults: defaults)
        XCTAssertEqual(restoredStore.configuration.baseURL.absoluteString, "http://192.168.50.25:8000/")
        XCTAssertEqual(
            SampleStreams.teddyRuxpinBilingualHLS(mediaServerBaseURL: restoredStore.configuration.baseURL).absoluteString,
            "http://192.168.50.25:8000/hls/teddy-ruxpin-bilingual/master.m3u8"
        )
    }

    func testInvalidAddressDoesNotReplaceSavedConfiguration() {
        let store = MediaServerSettingsStore(defaults: defaults)
        XCTAssertTrue(store.updateBaseURL(from: "https://media.example.com/library"))

        XCTAssertFalse(store.updateBaseURL(from: "media.example.com"))
        XCTAssertEqual(store.configuration.baseURL.absoluteString, "https://media.example.com/library")
    }

    func testKnownStreamIdentifierDoesNotDependOnServerAddress() {
        let firstURL = SampleStreams.teddyRuxpinBilingualHLS(
            mediaServerBaseURL: URL(string: "http://localhost:8000")!
        )
        let secondURL = SampleStreams.teddyRuxpinBilingualHLS(
            mediaServerBaseURL: URL(string: "http://192.168.50.25:8000")!
        )

        let firstSource = StreamSource(
            id: SampleStreams.teddyRuxpinBilingualID,
            title: "Teddy Ruxpin",
            subtitle: "Test",
            streamURL: firstURL
        )
        let secondSource = StreamSource(
            id: SampleStreams.teddyRuxpinBilingualID,
            title: "Teddy Ruxpin",
            subtitle: "Test",
            streamURL: secondURL
        )

        XCTAssertEqual(firstSource.id, secondSource.id)
        XCTAssertEqual(
            firstSource.id,
            "http://localhost:8000/hls/teddy-ruxpin-bilingual/master.m3u8"
        )
    }

    func testKnownStreamProgressResolvesAgainstUpdatedServer() {
        let updatedBaseURL = URL(string: "http://192.168.50.25:8000")!

        let resolvedURL = SampleStreams.configuredURL(
            for: SampleStreams.teddyRuxpinBilingualID,
            mediaServerBaseURL: updatedBaseURL
        )

        XCTAssertEqual(
            resolvedURL?.absoluteString,
            "http://192.168.50.25:8000/hls/teddy-ruxpin-bilingual/master.m3u8"
        )
        XCTAssertNil(
            SampleStreams.configuredURL(
                for: "https://example.com/custom/master.m3u8",
                mediaServerBaseURL: updatedBaseURL
            )
        )
    }
}
