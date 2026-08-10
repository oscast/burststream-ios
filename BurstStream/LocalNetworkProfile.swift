//
//  LocalNetworkProfile.swift
//  BurstStream
//

import Foundation

/// Development-only network conditions exposed by the local HLS server.
enum LocalNetworkProfile: String, CaseIterable, Identifiable {
    case fast
    case fiveMbps = "5mbps"
    case twoMbps = "2mbps"
    case onePointTwoMbps = "1.2mbps"
    case eightHundredKbps = "800kbps"
    case highLatency = "high-latency"
    case offline

    var id: Self { self }

    var title: String {
        switch self {
        case .fast: "Fast"
        case .fiveMbps: "5 Mbps"
        case .twoMbps: "2 Mbps"
        case .onePointTwoMbps: "1.2 Mbps"
        case .eightHundredKbps: "800 Kbps"
        case .highLatency: "Latency"
        case .offline: "Offline"
        }
    }

    var experimentHint: String {
        switch self {
        case .fast: "No artificial limit"
        case .fiveMbps: "Usually favors 720p"
        case .twoMbps: "Usually favors 480p"
        case .onePointTwoMbps: "Usually favors 360p"
        case .eightHundredKbps: "Below the lowest variant"
        case .highLatency: "Adds 1.5 seconds per request"
        case .offline: "Returns HTTP 503"
        }
    }
}
