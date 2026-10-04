import Combine
import Foundation
import XCTest
@testable import BurstStream

/// Runs against the optional Mac-hosted Teddy fixture. CI skips this test when
/// the untracked local media server is unavailable.
@MainActor
final class LocalHLSPlaybackIntegrationTests: XCTestCase {
    func testTeddyHLSAdvancesPlaybackOnSimulator() throws {
        let streamURL = SampleStreams.teddyRuxpinBilingualHLS
        let preflight = expectation(description: "Local HLS playlist responds")
        var responseStatus: Int?
        var connectionError: Error?
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        let session = URLSession(configuration: configuration)
        let request = session.dataTask(with: streamURL) { _, response, error in
            responseStatus = (response as? HTTPURLResponse)?.statusCode
            connectionError = error
            preflight.fulfill()
        }
        request.resume()
        wait(for: [preflight], timeout: 5)
        session.invalidateAndCancel()

        if connectionError != nil {
            throw XCTSkip("Start Scripts/serve-local-hls.sh 8000 with the local Teddy fixture to run this test.")
        }
        XCTAssertEqual(responseStatus, 200, "The local media server must serve the Teddy HLS playlist.")
        guard responseStatus == 200 else { return }

        let viewModel = PlayerViewModel(streamURL: streamURL)
        let playbackAdvanced = expectation(description: "Teddy playback advances beyond one second")
        var fulfilled = false
        let observation = viewModel.$currentTime.sink { currentTime in
            if currentTime > 1, !fulfilled {
                fulfilled = true
                playbackAdvanced.fulfill()
            }
        }

        viewModel.play()
        wait(for: [playbackAdvanced], timeout: 30)

        XCTAssertGreaterThan(viewModel.currentTime, 1)
        XCTAssertEqual(viewModel.playbackState, .playing)
        XCTAssertNil(viewModel.playbackFailure)
        XCTAssertGreaterThan(viewModel.duration, 0)
        viewModel.pause()
        withExtendedLifetime(observation) {}
    }
}
