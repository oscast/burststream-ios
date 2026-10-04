//
//  PlaybackStatePanel.swift
//  BurstStream
//

import SwiftUI

struct PlaybackStatePanel: View {
    let state: PlaybackState
    let failure: PlaybackFailure?
    let onRetry: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        stateLayout {
            Image(systemName: state.systemImage)
                .font(.title2)
                .foregroundStyle(stateColor)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(panelTitle)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Text(panelExplanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let failure, state.isFailure || isRetrying {
                    Text(localizedRecoverySuggestion(for: failure.category))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if state.isFailure {
                    Button("Retry now", action: onRetry)
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                        .padding(.top, 6)
                        .accessibilityHint("Attempts to load the stream again")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var stateLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
    }

    private var stateColor: Color {
        if state.isFailure {
            return .red
        }

        if case .retrying = state {
            return .orange
        }

        return .blue
    }

    private var isRetrying: Bool {
        if case .retrying = state {
            return true
        }
        return false
    }

    private var panelExplanation: LocalizedStringResource {
        if let failure, state.isFailure {
            return localizedMessage(for: failure.category)
        }

        switch state {
        case .loading: return "AVPlayer is reading the HLS playlist and preparing the first segments."
        case .ready: return "The stream is prepared and can begin playback."
        case .playing: return "AVPlayer is presenting the video while downloading upcoming segments."
        case .paused: return "Playback is paused, but the stream remains loaded."
        case .buffering: return "Playback is waiting for enough video data to continue."
        case let .retrying(attempt, maximumAttempts, _):
            return "Waiting before automatic retry \(attempt) of \(maximumAttempts)."
        case .ended: return "AVPlayer reached the end of the stream."
        case .failed: return "AVPlayer could not continue with this stream."
        }
    }

    private var panelTitle: LocalizedStringResource {
        if let failure, state.isFailure {
            return localizedTitle(for: failure.category)
        }

        switch state {
        case .loading: return "Loading"
        case .ready: return "Ready to play"
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .buffering: return "Buffering"
        case .retrying: return "Retrying"
        case .ended: return "Finished"
        case .failed: return "Playback failed"
        }
    }

    private func localizedTitle(for category: PlaybackFailureCategory) -> LocalizedStringResource {
        switch category {
        case .offline: "No connection"
        case .timeout: "Request timed out"
        case .serverUnavailable: "Server unavailable"
        case .missingResource: "Stream not found"
        case .authorization: "Access denied"
        case .invalidStream: "Invalid stream"
        case .unsupportedMedia: "Unsupported media"
        case .decoding: "Playback decoding failed"
        case .unknown: "Playback problem"
        }
    }

    private func localizedMessage(for category: PlaybackFailureCategory) -> LocalizedStringResource {
        switch category {
        case .offline: "BurstStream could not reach the network."
        case .timeout: "The server took too long to respond."
        case .serverUnavailable: "The streaming server is temporarily unavailable."
        case .missingResource: "The playlist or one of its media files could not be found."
        case .authorization: "This stream requires access that the app does not have."
        case .invalidStream: "The server returned media that is not a valid playable HLS stream."
        case .unsupportedMedia: "This device cannot play the stream's media format."
        case .decoding: "The downloaded media could not be decoded."
        case .unknown: "AVPlayer could not continue with this stream."
        }
    }

    private func localizedRecoverySuggestion(
        for category: PlaybackFailureCategory
    ) -> LocalizedStringResource {
        switch category {
        case .offline: "Check your connection, then try again."
        case .timeout, .serverUnavailable:
            "BurstStream will retry automatically. You can also try again later."
        case .missingResource:
            "Check the HLS URL and confirm the local server is still serving this package."
        case .authorization: "Check the stream credentials or server access policy."
        case .invalidStream: "Check the master playlist and its referenced media playlists."
        case .unsupportedMedia: "Use an iOS-supported HLS codec and container combination."
        case .decoding: "Repackage or re-encode the affected rendition, then try again."
        case .unknown: "Check the diagnostics panel, server logs, and stream URL before retrying."
        }
    }
}
