//
//  PlaybackRequest.swift
//  BurstStream
//

import Foundation

/// One navigation request into the player.
///
/// The request receives a fresh identity so selecting the same stream again can
/// still create a new navigation event. StreamSource keeps the stable media ID
/// used for persistence.
struct PlaybackRequest: Identifiable, Hashable {
    let id = UUID()
    let source: StreamSource
    let restoration: PlaybackRestorationState?
}
