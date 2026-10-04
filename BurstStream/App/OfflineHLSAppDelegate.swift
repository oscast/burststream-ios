import UIKit

/// Reconnects the stable AVFoundation background session after a system relaunch.
final class OfflineHLSAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            OfflineHLSDownloadManager.shared.attachBackgroundCompletionHandler(
                identifier: identifier,
                handler: completionHandler
            )
        }
    }
}
