//
//  SampleStreams.swift
//  BurstStream
//

import Foundation

/// Known streams used by the learning project and its local test environment.
enum SampleStreams {
    static let defaultMediaServerBaseURL = URL(string: "http://localhost:8000")!

    private static let teddyRuxpinBilingualPath = "hls/teddy-ruxpin-bilingual/master.m3u8"

    // The local master references four video qualities and two audio renditions.
    static let teddyRuxpinBilingualHLS = teddyRuxpinBilingualHLS(
        mediaServerBaseURL: defaultMediaServerBaseURL
    )
    static let teddyRuxpinBilingualID = teddyRuxpinBilingualHLS.absoluteString

    static func teddyRuxpinBilingualHLS(mediaServerBaseURL: URL) -> URL {
        mediaServerBaseURL.appending(path: teddyRuxpinBilingualPath)
    }

    static func configuredURL(for streamID: String, mediaServerBaseURL: URL) -> URL? {
        guard streamID == teddyRuxpinBilingualID else { return nil }
        return teddyRuxpinBilingualHLS(mediaServerBaseURL: mediaServerBaseURL)
    }

    static let bigBuckBunnyHLS = URL(
        string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
    )!
}
