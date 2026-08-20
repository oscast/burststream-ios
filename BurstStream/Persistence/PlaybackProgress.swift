//
//  PlaybackProgress.swift
//  BurstStream
//

import Foundation

/// A durable Continue Watching record.
///
/// Store user-facing metadata with the URL so the home screen can reconstruct
/// the card after the original StreamSource value has left memory.
struct PlaybackProgress: Codable, Equatable, Identifiable {
    var id: String { streamID }

    let streamID: String
    let title: String
    let subtitle: String
    let streamURL: URL
    let position: TimeInterval
    let duration: TimeInterval
    let qualityLimitRawValue: String
    let audioLanguageCode: String?
    let subtitlesEnabled: Bool
    let subtitleLanguageCode: String?
    let updatedAt: Date

    var source: StreamSource {
        StreamSource(
            id: streamID,
            title: title,
            subtitle: subtitle,
            streamURL: streamURL
        )
    }

    var restorationState: PlaybackRestorationState {
        PlaybackRestorationState(
            position: position,
            qualityLimit: PlaybackQualityLimit(rawValue: qualityLimitRawValue) ?? .automatic,
            audioLanguageCode: audioLanguageCode,
            subtitlesEnabled: subtitlesEnabled,
            subtitleLanguageCode: subtitleLanguageCode
        )
    }
}
