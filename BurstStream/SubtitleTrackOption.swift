//
//  SubtitleTrackOption.swift
//  BurstStream
//

import Foundation

/// View-friendly information about one subtitle rendition or the Off choice.
///
/// AVMediaSelectionOption stays inside PlayerViewModel. A nil language code
/// represents disabling the legible media-selection group.
struct SubtitleTrackOption: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let languageCode: String?

    var isOff: Bool {
        id == Self.off.id
    }

    static let off = SubtitleTrackOption(
        id: "subtitle-off",
        title: "Off",
        languageCode: nil
    )
}
