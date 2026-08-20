//
//  StreamSource.swift
//  BurstStream
//

import Foundation

/// Describes one HLS source that can be selected and played by the app.
struct StreamSource: Identifiable, Hashable {
    /// A URL is stable across launches, unlike a newly generated UUID. A real
    /// catalog would normally provide its own permanent content identifier.
    let id: String
    let title: String
    let subtitle: String
    let streamURL: URL

    init(
        id: String? = nil,
        title: String,
        subtitle: String,
        streamURL: URL
    ) {
        self.id = id ?? streamURL.absoluteString
        self.title = title
        self.subtitle = subtitle
        self.streamURL = streamURL
    }
}
