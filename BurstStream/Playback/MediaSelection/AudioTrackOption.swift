//
//  AudioTrackOption.swift
//  BurstStream
//

import Foundation

/// View-friendly information about one selectable audio rendition.
///
/// AVMediaSelectionOption remains inside PlayerViewModel because SwiftUI only
/// needs a stable identifier and the text presented to the user.
struct AudioTrackOption: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let languageCode: String?
}
