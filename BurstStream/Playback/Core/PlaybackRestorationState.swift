//
//  PlaybackRestorationState.swift
//  BurstStream
//

import Foundation

/// Playback values that can be restored without making PlayerViewModel depend
/// on a particular persistence technology.
struct PlaybackRestorationState: Hashable {
    let position: TimeInterval
    let qualityLimit: PlaybackQualityLimit
    let audioLanguageCode: String?
    let subtitlesEnabled: Bool
    let subtitleLanguageCode: String?
}
