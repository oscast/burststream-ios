//
//  PlaybackQualityLimit.swift
//  BurstStream
//

import CoreGraphics

/// Educational limit for studying how AVPlayer chooses an HLS variant.
///
/// This is a ceiling, not a forced quality. AVPlayer may still choose a lower
/// variant when available throughput is insufficient.
enum PlaybackQualityLimit: String, CaseIterable, Identifiable {
    case automatic
    case p1080
    case p720
    case p480
    case p360

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .p1080: "Up to 1080p"
        case .p720: "Up to 720p"
        case .p480: "Up to 480p"
        case .p360: "Up to 360p"
        }
    }

    /// Compact text for buttons displayed at the same time.
    var shortTitle: String {
        switch self {
        case .automatic: "Automatic"
        case .p1080: "1080p max"
        case .p720: "720p max"
        case .p480: "480p max"
        case .p360: "360p max"
        }
    }

    /// Zero means “no limit,” leaving the decision to AVPlayer.
    var preferredPeakBitRate: Double {
        switch self {
        case .automatic: 0
        // Keep a small margin above the master playlist BANDWIDTH. A ceiling
        // below that value would make the desired variant ineligible.
        case .p1080: 6_100_000
        case .p720: 3_500_000
        case .p480: 1_850_000
        case .p360: 1_050_000
        }
    }

    /// CGSize.zero also means “no limit” for AVPlayerItem.
    var preferredMaximumResolution: CGSize {
        switch self {
        case .automatic: .zero
        case .p1080: CGSize(width: 1_440, height: 1_080)
        case .p720: CGSize(width: 960, height: 720)
        case .p480: CGSize(width: 640, height: 480)
        case .p360: CGSize(width: 480, height: 360)
        }
    }
}
