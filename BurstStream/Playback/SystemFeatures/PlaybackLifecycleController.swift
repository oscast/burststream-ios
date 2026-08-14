//
//  PlaybackLifecycleController.swift
//  BurstStream
//

import AVFoundation
import Combine
import SwiftUI

/// The small playback boundary needed by system lifecycle handling.
///
/// Keeping this protocol focused lets notification behavior be tested without
/// constructing a real HLS player or exposing AVFoundation internals.
@MainActor
protocol PlaybackLifecycleControlling: AnyObject {
    var isPlaybackActive: Bool { get }

    func play()
    func pause()
    func recoverAfterMediaServicesReset()
}

extension PlayerViewModel: PlaybackLifecycleControlling {}

/// Translates audio-session and app-lifecycle events into safe player actions.
///
/// AVPlayer handles media delivery, but the app must decide whether playback
/// should pause or resume when another system experience takes control of audio.
@MainActor
final class PlaybackLifecycleController: ObservableObject {
    /// A concise event description is useful while studying notifications and
    /// can later be included in diagnostics without exposing Notification.
    @Published private(set) var lastEventDescription = "Waiting for system events"

    private weak var playback: (any PlaybackLifecycleControlling)?
    private let notificationCenter: NotificationCenter
    private let reactivateAudioSession: @MainActor () -> Bool

    private var notificationObservers: [NSObjectProtocol] = []
    private var wasPlayingBeforeInterruption = false
    private var mediaServicesWereLost = false

    init(
        playback: any PlaybackLifecycleControlling,
        notificationCenter: NotificationCenter = .default,
        reactivateAudioSession: @escaping @MainActor () -> Bool = PlaybackAudioSession.activate
    ) {
        self.playback = playback
        self.notificationCenter = notificationCenter
        self.reactivateAudioSession = reactivateAudioSession
        observeSystemEvents()
    }

    deinit {
        for observer in notificationObservers {
            notificationCenter.removeObserver(observer)
        }
    }

    /// SwiftUI scene changes are intentionally conservative. Entering the
    /// background must not pause a valid PiP or AirPlay session, and returning
    /// to the foreground must never start playback the user had paused.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            lastEventDescription = "App became active"

            // Background playback may have continued through PiP or AirPlay.
            // Reactivate only when playback still has an active user intent.
            if playback?.isPlaybackActive == true {
                _ = reactivateAudioSession()
            }
        case .inactive:
            lastEventDescription = "App became inactive"
        case .background:
            lastEventDescription = "App entered the background"
        @unknown default:
            lastEventDescription = "App entered an unknown scene phase"
        }
    }

    private func observeSystemEvents() {
        observe(AVAudioSession.interruptionNotification, handler: handleInterruption)
        observe(AVAudioSession.routeChangeNotification, handler: handleRouteChange)
        observe(AVAudioSession.mediaServicesWereLostNotification, handler: handleMediaServicesLost)
        observe(AVAudioSession.mediaServicesWereResetNotification, handler: handleMediaServicesReset)
    }

    private func observe(
        _ name: Notification.Name,
        handler: @escaping @MainActor (Notification) -> Void
    ) {
        let observer = notificationCenter.addObserver(
            forName: name,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { notification in
            // queue: .main guarantees this callback runs on the main thread.
            // assumeIsolated avoids sending Foundation's non-Sendable
            // Notification value across an actor boundary.
            MainActor.assumeIsolated {
                handler(notification)
            }
        }

        notificationObservers.append(observer)
    }

    private func handleInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = playback?.isPlaybackActive == true
            playback?.pause()
            lastEventDescription = "Playback paused for an audio interruption"

        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            let shouldResume = wasPlayingBeforeInterruption && options.contains(.shouldResume)
            wasPlayingBeforeInterruption = false

            guard shouldResume, reactivateAudioSession() else {
                lastEventDescription = "Interruption ended; playback remained paused"
                return
            }

            playback?.play()
            lastEventDescription = "Playback resumed after an interruption"

        @unknown default:
            wasPlayingBeforeInterruption = false
            playback?.pause()
            lastEventDescription = "Unknown interruption; playback paused safely"
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else {
            return
        }

        // A disconnected headset, Bluetooth device, car, HDMI display, or
        // AirPlay receiver must not unexpectedly move audio to the speaker.
        if reason == .oldDeviceUnavailable,
           let previousRoute = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey]
                as? AVAudioSessionRouteDescription,
           previousRoute.outputs.contains(where: isExternalOutput) {
            playback?.pause()
            lastEventDescription = "Playback paused because an audio route disconnected"
            return
        }

        lastEventDescription = "Audio route changed: \(routeChangeDescription(reason))"
    }

    private func handleMediaServicesLost(_ notification: Notification) {
        mediaServicesWereLost = true
        playback?.pause()
        lastEventDescription = "System media services became unavailable"
    }

    private func handleMediaServicesReset(_ notification: Notification) {
        // Apple requires recreating audio objects and restoring the session
        // configuration. PlayerViewModel restores position and media choices but
        // intentionally leaves playback paused until the next user action.
        let followedServiceLoss = mediaServicesWereLost
        playback?.recoverAfterMediaServicesReset()
        mediaServicesWereLost = false
        wasPlayingBeforeInterruption = false
        lastEventDescription = followedServiceLoss
            ? "Media services returned; playback restored and paused"
            : "Media services reset; playback restored and paused"
    }

    private func isExternalOutput(_ output: AVAudioSessionPortDescription) -> Bool {
        switch output.portType {
        case .headphones,
             .bluetoothA2DP,
             .bluetoothHFP,
             .bluetoothLE,
             .airPlay,
             .carAudio,
             .HDMI,
             .usbAudio:
            true
        default:
            false
        }
    }

    private func routeChangeDescription(_ reason: AVAudioSession.RouteChangeReason) -> String {
        switch reason {
        case .newDeviceAvailable: "new device available"
        case .oldDeviceUnavailable: "previous device unavailable"
        case .categoryChange: "audio category changed"
        case .override: "route overridden"
        case .wakeFromSleep: "device woke from sleep"
        case .noSuitableRouteForCategory: "no suitable route"
        case .routeConfigurationChange: "route configuration changed"
        case .unknown: "unknown reason"
        @unknown default: "future system reason"
        }
    }
}
