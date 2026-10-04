import AVFoundation
import Combine
import Foundation

/// Owns AVFoundation's system-managed HLS downloads and their small metadata.
@MainActor
final class OfflineHLSDownloadManager: NSObject, ObservableObject, AVAssetDownloadDelegate {
    static let shared = OfflineHLSDownloadManager()
    static let backgroundSessionIdentifier = "com.oscast.BurstStream.offline-hls.v1"

    @Published private(set) var records: [OfflineHLSDownloadRecord]

    private let defaults: UserDefaults
    private let storageKey = "burststream.offline-hls-records.v1"
    private var tasksByID: [String: AVAssetDownloadTask] = [:]
    private var progressObservations: [Int: NSKeyValueObservation] = [:]
    private var backgroundCompletionHandler: (() -> Void)?

    private lazy var downloadSession: AVAssetDownloadURLSession = {
        let configuration = URLSessionConfiguration.background(
            withIdentifier: Self.backgroundSessionIdentifier
        )
        configuration.isDiscretionary = false
        configuration.waitsForConnectivity = true
        configuration.sessionSendsLaunchEvents = true
        return AVAssetDownloadURLSession(
            configuration: configuration,
            assetDownloadDelegate: self,
            delegateQueue: nil
        )
    }()

    private override init() {
        defaults = .standard
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([OfflineHLSDownloadRecord].self, from: data) {
            records = saved.map { record in
                var current = record
                if current.state == .completed, current.playableURL == nil {
                    current.state = .failed
                }
                return current
            }
        } else {
            records = []
        }
        super.init()
        restoreActiveTasks()
    }

    func record(for id: String) -> OfflineHLSDownloadRecord? {
        records.first { $0.id == id }
    }

    func playableURL(for id: String) -> URL? {
        guard let url = record(for: id)?.playableURL else { return nil }
        let asset = AVURLAsset(url: url)
        return asset.assetCache?.isPlayableOffline == true ? url : nil
    }

    func inspectMedia(at url: URL) async throws -> OfflineHLSMediaChoices {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.pathExtension.lowercased() == "m3u8" else {
            throw OfflineHLSDownloadError.invalidSource
        }

        let asset = AVURLAsset(url: url)
        async let audioGroup = asset.loadMediaSelectionGroup(for: .audible)
        async let subtitleGroup = asset.loadMediaSelectionGroup(for: .legible)
        let (audio, subtitles) = try await (audioGroup, subtitleGroup)

        return OfflineHLSMediaChoices(
            audio: audio?.options.enumerated().map { index, option in
                AudioTrackOption(
                    id: "audio-\(index)",
                    title: option.displayName,
                    languageCode: Self.languageCode(for: option)
                )
            } ?? [],
            subtitles: [.off] + (subtitles?.options.enumerated().map { index, option in
                SubtitleTrackOption(
                    id: "subtitle-\(index)",
                    title: option.displayName,
                    languageCode: Self.languageCode(for: option)
                )
            } ?? [])
        )
    }

    func start(
        source: StreamSource,
        audioTrackID: String?,
        subtitleTrackID: String?
    ) async throws {
        guard ["http", "https"].contains(source.streamURL.scheme?.lowercased() ?? ""),
              source.streamURL.pathExtension.lowercased() == "m3u8" else {
            throw OfflineHLSDownloadError.invalidSource
        }
        if let existing = record(for: source.id), existing.state != .failed {
            throw OfflineHLSDownloadError.alreadyExists
        }

        let asset = AVURLAsset(url: source.streamURL)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else {
            throw OfflineHLSDownloadError.notVideoOnDemand
        }
        if let freeBytes = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        ).volumeAvailableCapacityForImportantUsage,
           !OfflineHLSStoragePolicy.hasEnoughSpace(
               availableBytes: freeBytes,
               duration: duration
           ) {
            throw OfflineHLSDownloadError.insufficientSpace
        }

        let preferred = try await asset.load(.preferredMediaSelection)
        guard let selection = preferred.mutableCopy() as? AVMutableMediaSelection else {
            throw OfflineHLSDownloadError.invalidMediaSelection
        }

        var selectedAudioLanguage: String?
        if let audioTrackID {
            guard let group = try await asset.loadMediaSelectionGroup(for: .audible),
                  let option = Self.option(with: audioTrackID, prefix: "audio", in: group) else {
                throw OfflineHLSDownloadError.invalidMediaSelection
            }
            selection.select(option, in: group)
            selectedAudioLanguage = Self.languageCode(for: option)
        }

        var selectedSubtitleLanguage: String?
        if let subtitleTrackID {
            let group = try await asset.loadMediaSelectionGroup(for: .legible)
            if subtitleTrackID == SubtitleTrackOption.off.id {
                if let group { selection.select(nil, in: group) }
            } else if let group {
                guard let option = Self.option(
                    with: subtitleTrackID,
                    prefix: "subtitle",
                    in: group
                ) else {
                    throw OfflineHLSDownloadError.invalidMediaSelection
                }
                selection.select(option, in: group)
                selectedSubtitleLanguage = Self.languageCode(for: option)
            } else {
                throw OfflineHLSDownloadError.invalidMediaSelection
            }
        }

        let configuration = AVAssetDownloadConfiguration(asset: asset, title: source.title)
        // AVFoundation uses the asset's preferred selection when no explicit
        // alternative track was chosen.
        if audioTrackID != nil || selectedSubtitleLanguage != nil {
            configuration.primaryContentConfiguration.mediaSelections = [selection]
        }
        configuration.auxiliaryContentConfigurations = []
        let task = downloadSession.makeAssetDownloadTask(
            downloadConfiguration: configuration
        )
        task.taskDescription = source.id
        tasksByID[source.id] = task

        let newRecord = OfflineHLSDownloadRecord(
            id: source.id,
            title: source.title,
            subtitle: source.subtitle,
            remoteURL: source.streamURL,
            localURL: nil,
            state: .downloading,
            progress: 0,
            audioLanguageCode: selectedAudioLanguage,
            subtitleLanguageCode: selectedSubtitleLanguage,
            createdAt: Date()
        )
        upsert(newRecord, persist: true)
        observeProgress(of: task, for: source.id)
        task.resume()
    }

    func pause(id: String) {
        guard let task = tasksByID[id], var record = record(for: id),
              record.state == .downloading else { return }
        task.suspend()
        record.state = .paused
        upsert(record, persist: true)
    }

    func resume(id: String) {
        guard let task = tasksByID[id], var record = record(for: id),
              record.state == .paused else { return }
        task.resume()
        record.state = .downloading
        upsert(record, persist: true)
    }

    func cancel(id: String) {
        tasksByID.removeValue(forKey: id)?.cancel()
        removeRecord(id: id)
    }

    func delete(id: String) throws {
        guard let record = record(for: id) else { return }
        tasksByID.removeValue(forKey: id)?.cancel()
        if let localURL = record.localURL,
           localURL.isFileURL,
           FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }
        removeRecord(id: id)
    }

    func attachBackgroundCompletionHandler(
        identifier: String,
        handler: @escaping () -> Void
    ) {
        guard identifier == Self.backgroundSessionIdentifier else {
            handler()
            return
        }
        backgroundCompletionHandler = handler
        restoreActiveTasks()
    }

    nonisolated func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        willDownloadTo location: URL
    ) {
        guard let id = assetDownloadTask.taskDescription else { return }
        Task { @MainActor in
            guard var record = self.record(for: id) else { return }
            record.localURL = location
            self.upsert(record, persist: true)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let id = task.taskDescription else { return }
        Task { @MainActor in
            self.finish(id: id, error: error)
        }
    }

    nonisolated func urlSessionDidFinishEvents(
        forBackgroundURLSession session: URLSession
    ) {
        Task { @MainActor in
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }

    private func restoreActiveTasks() {
        downloadSession.getAllTasks { [weak self] tasks in
            Task { @MainActor in
                guard let self else { return }
                let activeTasks = tasks.compactMap { $0 as? AVAssetDownloadTask }
                let activeIDs = Set(activeTasks.compactMap(\.taskDescription))
                for task in activeTasks {
                    guard let id = task.taskDescription,
                          var record = self.record(for: id) else { continue }
                    self.tasksByID[id] = task
                    self.observeProgress(of: task, for: id)
                    record.state = task.state == .suspended ? .paused : .downloading
                    self.upsert(record, persist: false)
                }
                for var record in self.records where
                    (record.state == .downloading || record.state == .paused)
                        && !activeIDs.contains(record.id) {
                    let available = record.localURL.map { localURL in
                        FileManager.default.fileExists(atPath: localURL.path)
                            && AVURLAsset(url: localURL).assetCache?.isPlayableOffline == true
                    } ?? false
                    record.state = available ? .completed : .failed
                    self.upsert(record, persist: false)
                }
                self.persist()
            }
        }
    }

    private func observeProgress(of task: AVAssetDownloadTask, for id: String) {
        progressObservations[task.taskIdentifier] = task.progress.observe(
            \.fractionCompleted,
            options: [.initial, .new]
        ) { [weak self] progress, _ in
            Task { @MainActor in
                guard let self, var record = self.record(for: id) else { return }
                record.progress = min(max(progress.fractionCompleted, 0), 1)
                self.upsert(record, persist: false)
            }
        }
    }

    private func finish(id: String, error: Error?) {
        if let task = tasksByID.removeValue(forKey: id) {
            progressObservations[task.taskIdentifier] = nil
        }
        guard var record = record(for: id) else { return }
        if error != nil {
            record.state = .failed
            // Do not persist raw AVFoundation errors or signed request URLs.
        } else if let localURL = record.localURL,
                  FileManager.default.fileExists(atPath: localURL.path),
                  AVURLAsset(url: localURL).assetCache?.isPlayableOffline == true {
            record.state = .completed
            record.progress = 1
        } else {
            record.state = .failed
        }
        upsert(record, persist: true)
    }

    private func upsert(_ record: OfflineHLSDownloadRecord, persist shouldPersist: Bool) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.insert(record, at: 0)
        }
        if shouldPersist { persist() }
    }

    private func removeRecord(id: String) {
        records.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func option(
        with id: String,
        prefix: String,
        in group: AVMediaSelectionGroup
    ) -> AVMediaSelectionOption? {
        guard id.hasPrefix("\(prefix)-"),
              let index = Int(id.dropFirst(prefix.count + 1)),
              group.options.indices.contains(index) else { return nil }
        return group.options[index]
    }

    private static func languageCode(for option: AVMediaSelectionOption) -> String? {
        let value = option.extendedLanguageTag ?? option.locale?.identifier
        return value?.lowercased()
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first.map(String.init)
    }
}
