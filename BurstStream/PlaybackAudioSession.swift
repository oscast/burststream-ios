//
//  PlaybackAudioSession.swift
//  BurstStream
//

import AVFoundation

/// Configures the process audio session for long-form video playback.
///
/// AVPlayer performs the actual AirPlay routing. The audio session describes
/// the app's playback intent to iOS and enables expected media behavior when
/// the Ring/Silent switch is enabled.
enum PlaybackAudioSession {
    static func configure() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(
                .playback,
                mode: .moviePlayback,
                policy: .longFormVideo
            )
            try session.setActive(true)
        } catch {
            // Playback may still work if another system condition temporarily
            // prevents activation, so log the problem instead of crashing.
            print("Could not configure the playback audio session: \(error)")
        }
    }
}
