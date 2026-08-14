//
//  ABRHistorySample.swift
//  BurstStream
//

import Foundation

/// One point in an adaptive-bitrate experiment.
struct ABRHistorySample: Identifiable, Equatable {
    let id = UUID()
    let elapsedTime: TimeInterval
    let playbackTime: TimeInterval
    let variant: String
    let observedBitrate: Double?
    let requiredBitrate: Double?
    let bufferAhead: TimeInterval
    let networkProfile: String
    let playbackState: String
    let isTransition: Bool
}
