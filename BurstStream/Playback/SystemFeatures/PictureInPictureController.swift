//
//  PictureInPictureController.swift
//  BurstStream
//

import AVFoundation
import AVKit
import Combine

/// Coordinates Picture in Picture for the AVPlayerLayer used by PlayerSurface.
///
/// The manager owns the AVPictureInPictureController strongly because PiP stops
/// working if the system controller is released. SwiftUI receives only simple
/// published state and user actions.
@MainActor
final class PictureInPictureController: NSObject, ObservableObject {
    @Published private(set) var isPossible = false
    @Published private(set) var isActive = false
    @Published private(set) var errorMessage: String?

    let isSupported = AVPictureInPictureController.isPictureInPictureSupported()

    private var systemController: AVPictureInPictureController?
    private var possibilityObservation: NSKeyValueObservation?
    private weak var sourceLayer: AVPlayerLayer?

    /// Creates the system PiP controller once the UIKit player layer exists.
    func attach(to playerLayer: AVPlayerLayer) {
        guard isSupported else { return }
        guard sourceLayer !== playerLayer else { return }

        possibilityObservation?.invalidate()
        sourceLayer = playerLayer

        guard let controller = AVPictureInPictureController(playerLayer: playerLayer) else {
            isPossible = false
            return
        }
        controller.delegate = self

        // The video is the primary content on this screen, so iOS may enter PiP
        // automatically when the user sends the app to the background.
        controller.canStartPictureInPictureAutomaticallyFromInline = true

        possibilityObservation = controller.observe(
            \.isPictureInPicturePossible,
            options: [.initial, .new]
        ) { [weak self] controller, _ in
            Task { @MainActor [weak self] in
                self?.isPossible = controller.isPictureInPicturePossible
            }
        }

        systemController = controller
    }

    /// Manual PiP starts only from this user-initiated button action.
    func toggle() {
        guard let systemController else { return }
        errorMessage = nil

        if systemController.isPictureInPictureActive {
            systemController.stopPictureInPicture()
        } else if systemController.isPictureInPicturePossible {
            systemController.startPictureInPicture()
        }
    }

    deinit {
        possibilityObservation?.invalidate()
    }
}

extension PictureInPictureController: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor [weak self] in
            self?.isActive = true
            self?.errorMessage = nil
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor [weak self] in
            self?.isActive = false
        }
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.isActive = false
            self?.errorMessage = error.localizedDescription
        }
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        // The player screen remains in the navigation stack while the app is in
        // the background, so foregrounding the app restores the existing UI.
        completionHandler(true)
    }
}
