//
//  PlaybackState.swift
//  BurstStream
//

import Foundation

/// Represents playback states displayed by the UI.
///
/// AVPlayer exposes state through several APIs. This enum maps them into one
/// simple model SwiftUI can understand and present.
enum PlaybackState: Equatable {
    /// AVPlayer is still reading the playlist or preparing content.
    case loading

    /// Content is ready but playback has not started.
    case ready

    /// The player clock is advancing and video is being presented.
    case playing

    /// Playback was intentionally paused.
    case paused

    /// AVPlayer wants to play but is waiting for more stream data.
    case buffering

    /// A recoverable error occurred and the next reload is delayed.
    case retrying(attempt: Int, maximumAttempts: Int, delay: TimeInterval)

    /// The player reached the end of the content.
    case ended

    /// An error occurred; its message is retained for the UI.
    case failed(message: String)

    /// Short user-facing state title.
    var title: String {
        switch self {
        case .loading:
            "Loading"
        case .ready:
            "Ready to play"
        case .playing:
            "Playing"
        case .paused:
            "Paused"
        case .buffering:
            "Buffering"
        case .retrying:
            "Retrying"
        case .ended:
            "Finished"
        case .failed:
            "Playback failed"
        }
    }

    /// SF Symbol associated with each state.
    var systemImage: String {
        switch self {
        case .loading:
            "arrow.down.circle"
        case .ready:
            "checkmark.circle"
        case .playing:
            "play.circle.fill"
        case .paused:
            "pause.circle.fill"
        case .buffering:
            "hourglass.circle"
        case .retrying:
            "arrow.clockwise.circle"
        case .ended:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    /// Educational explanation of what AVPlayer is doing internally.
    var explanation: String {
        switch self {
        case .loading:
            "AVPlayer is reading the HLS playlist and preparing the first segments."
        case .ready:
            "The stream is prepared and can begin playback."
        case .playing:
            "AVPlayer is presenting the video while downloading upcoming segments."
        case .paused:
            "Playback is paused, but the stream remains loaded."
        case .buffering:
            "Playback is waiting for enough video data to continue."
        case let .retrying(attempt, maximumAttempts, delay):
            "Attempt \(attempt) of \(maximumAttempts) will start in \(formattedDelay(delay))."
        case .ended:
            "AVPlayer reached the end of the stream."
        case let .failed(message):
            message
        }
    }

    /// Lets the UI style errors differently.
    var isFailure: Bool {
        if case .failed = self {
            return true
        }
        return false
    }

    private func formattedDelay(_ delay: TimeInterval) -> String {
        String(format: "%.0f second%@", delay, delay == 1 ? "" : "s")
    }
}
