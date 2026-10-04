import Foundation

enum OfflineDownloadState: String, Codable {
    case preparing
    case downloading
    case paused
    case completed
    case failed
}

/// Metadata only. AVFoundation owns the downloaded HLS bundle at `localURL`.
struct OfflineHLSDownloadRecord: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let remoteURL: URL
    var localURL: URL?
    var state: OfflineDownloadState
    var progress: Double
    let audioLanguageCode: String?
    let subtitleLanguageCode: String?
    let createdAt: Date

    var playableURL: URL? {
        guard state == .completed,
              let localURL,
              localURL.isFileURL,
              FileManager.default.fileExists(atPath: localURL.path) else {
            return nil
        }
        return localURL
    }
}

struct OfflineHLSMediaChoices {
    let audio: [AudioTrackOption]
    let subtitles: [SubtitleTrackOption]
}

enum OfflineHLSDownloadError: LocalizedError {
    case invalidSource
    case notVideoOnDemand
    case insufficientSpace
    case alreadyExists
    case invalidMediaSelection
    case missingDownload
    case incompleteDownload

    var errorDescription: String? {
        switch self {
        case .invalidSource:
            "Enter a reachable HTTP or HTTPS HLS playlist before downloading."
        case .notVideoOnDemand:
            "Only finished on-demand HLS streams can be downloaded."
        case .insufficientSpace:
            "Not enough free storage is available for this download."
        case .alreadyExists:
            "This stream is already downloaded or being downloaded."
        case .invalidMediaSelection:
            "The selected audio or subtitle track is no longer available."
        case .missingDownload:
            "The downloaded file is no longer available. Delete and download it again."
        case .incompleteDownload:
            "The download finished without a playable offline asset. Try again."
        }
    }
}

enum OfflineHLSStoragePolicy {
    /// The bitrate of a remote HLS variant is not known until selection. Keep a
    /// conservative reserve and let the system report any later disk error.
    static func requiredFreeBytes(for duration: TimeInterval) -> Int64 {
        max(200_000_000, Int64(duration * 1_000_000))
    }

    static func hasEnoughSpace(availableBytes: Int64, duration: TimeInterval) -> Bool {
        availableBytes >= requiredFreeBytes(for: duration)
    }
}
