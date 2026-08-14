//
//  StreamSource.swift
//  BurstStream
//

import Foundation

/// Describes one HLS source that can be selected and played by the app.
struct StreamSource: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let streamURL: URL
}
