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
    /// Applies the app's audio policy without taking audio focus immediately.
    /// Activation waits until playback starts so opening the player screen does
    /// not unnecessarily interrupt music or audio from another app.
    @discardableResult
    static func configure() -> Bool {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(
                .playback,
                mode: .moviePlayback,
                policy: .longFormVideo
            )
            return true
        } catch {
            // A configuration failure should be visible to developers without
            // crashing the learning app.
            print("Could not configure the playback audio session: \(error)")
            return false
        }
    }

    /// Reactivates the existing configuration after an interruption ends.
    @discardableResult
    static func activate() -> Bool {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            return true
        } catch {
            print("Could not reactivate the playback audio session: \(error)")
            return false
        }
    }
}
