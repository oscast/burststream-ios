//
//  SampleStreams.swift
//  BurstStream
//

import Foundation

/// Known streams used by the learning project and its local test environment.
enum SampleStreams {
    // The local master references four video qualities and two audio renditions.
    static let teddyRuxpinBilingualHLS = URL(
        string: "http://localhost:8000/hls/teddy-ruxpin-bilingual/master.m3u8"
    )!

    // Physical devices and AirPlay receivers cannot reach the Mac through localhost.
    // Update this address if the router assigns a different LAN IP to the Mac.
    static let teddyRuxpinBilingualLAN = URL(
        string: "http://192.168.1.117:8000/hls/teddy-ruxpin-bilingual/master.m3u8"
    )!

    static let bigBuckBunnyHLS = URL(
        string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
    )!
}
