//
//  PlayerViewModel.swift
//  BurstStream
//

import AVFoundation
import Combine

/// Owns playback logic so the view only renders data and sends actions.
///
/// `@MainActor` keeps published changes on the main thread, where SwiftUI expects
/// to receive interface updates.
@MainActor
final class PlayerViewModel: ObservableObject {
    /// Simplified state displayed underneath the video.
    @Published private(set) var playbackState: PlaybackState = .loading

    /// Current position and total duration in seconds for convenient Slider use.
    /// AVPlayer works with CMTime internally.
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    /// Intervals AVPlayer has downloaded. Seeking can create multiple ranges.
    @Published private(set) var bufferedRanges: [PlaybackBufferRange] = []

    /// Simple snapshot of access and error logs for the current item.
    @Published private(set) var playbackMetrics: PlaybackMetrics = .empty

    /// User-selected ceiling. Automatic preserves the normal ABR algorithm.
    @Published private(set) var qualityLimit: PlaybackQualityLimit = .automatic

    /// Alternate audio renditions discovered in the current HLS master.
    @Published private(set) var audioTracks: [AudioTrackOption] = []
    @Published private(set) var selectedAudioTrackID: String?

    /// One player instance controls playback for the screen lifetime.
    let player: AVPlayer

    // Dependencies needed to rebuild the item and control retries.
    private let streamURL: URL
    private let retryPolicy: RetryPolicy
    private let retryScheduler: any RetryScheduling

    // KVO delivers AVPlayer and AVPlayerItem property changes.
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlStatusObservation: NSKeyValueObservation?
    private var loadedTimeRangesObservation: NSKeyValueObservation?
    private var presentationSizeObservation: NSKeyValueObservation?

    // Events that are not observable properties arrive as notifications.
    private var playbackEndedObserver: NSObjectProtocol?
    private var playbackFailedObserver: NSObjectProtocol?
    private var accessLogObserver: NSObjectProtocol?
    private var errorLogObserver: NSObjectProtocol?

    // Token required to remove the periodic observer during cleanup.
    private var periodicTimeObserver: Any?

    // Cancelable task that waits before the next retry.
    private var retryTask: Task<Void, Never>?
    private var audioDiscoveryTask: Task<Void, Never>?
    private var retryAttempt = 0
    private var pendingResumeTime: TimeInterval?
    private var shouldPlayWhenReady = false

    // AVFoundation objects stay private while the view receives lightweight
    // AudioTrackOption values.
    private var audioSelectionGroup: AVMediaSelectionGroup?
    private var mediaOptionsByAudioTrackID: [String: AVMediaSelectionOption] = [:]
    private var preferredAudioLanguageCode: String?

    // Notifications report new entries, but fields in the current entry may keep
    // changing. Limit polling to 1 Hz.
    private var lastMetricsRefreshDate = Date.distantPast

    // Internal flags used to distinguish ready, paused, and ended.
    private var hasPlayed = false
    private var reachedEnd = false

    // Every seek receives an identifier so a late completion from an older seek
    // can be ignored without overwriting the newest position.
    private var activeSeekID: UUID?

    /// Also returns true while AVPlayer is waiting for data to continue.
    var isPlaybackActive: Bool {
        player.timeControlStatus != .paused
    }

    /// Downloaded content ahead of the current position. The result is zero when
    /// the current second does not belong to a loaded range.
    var bufferedDurationAhead: TimeInterval {
        guard let currentRange = bufferedRanges.first(where: { $0.contains(currentTime) }) else {
            return 0
        }

        return max(currentRange.end - currentTime, 0)
    }

    convenience init(streamURL: URL) {
        self.init(
            streamURL: streamURL,
            retryPolicy: .playbackDefault,
            retryScheduler: TaskRetryScheduler()
        )
    }

    /// Explicit initializer for injecting retry policy and scheduler in tests.
    init(
        streamURL: URL,
        retryPolicy: RetryPolicy,
        retryScheduler: any RetryScheduling
    ) {
        self.streamURL = streamURL
        self.retryPolicy = retryPolicy
        self.retryScheduler = retryScheduler

        // AVPlayerItem represents content; AVPlayer represents the playback engine.
        let item = AVPlayerItem(url: streamURL)
        Self.apply(.automatic, to: item)
        player = AVPlayer(playerItem: item)

        observePlayer()
        observe(item: item)
        observeTimeline()
    }

    deinit {
        // Every manually registered observer must be removed to prevent callbacks
        // into a released object and avoid retaining unnecessary resources.
        itemStatusObservation?.invalidate()
        timeControlStatusObservation?.invalidate()
        loadedTimeRangesObservation?.invalidate()
        presentationSizeObservation?.invalidate()

        if let periodicTimeObserver {
            player.removeTimeObserver(periodicTimeObserver)
        }

        retryTask?.cancel()
        audioDiscoveryTask?.cancel()

        if let playbackEndedObserver {
            NotificationCenter.default.removeObserver(playbackEndedObserver)
        }

        if let playbackFailedObserver {
            NotificationCenter.default.removeObserver(playbackFailedObserver)
        }

        if let accessLogObserver {
            NotificationCenter.default.removeObserver(accessLogObserver)
        }

        if let errorLogObserver {
            NotificationCenter.default.removeObserver(errorLogObserver)
        }
    }

    // MARK: - User actions

    func play() {
        if reachedEnd {
            reachedEnd = false

            // Starting playback after the episode ended should restart from zero.
            seek(to: 0)
        }

        player.play()
    }

    func pause() {
        player.pause()
    }

    /// User-requested retry after automatic retries are exhausted.
    /// Reset the counter to begin a new recovery cycle.
    func retry() {
        retryTask?.cancel()
        retryTask = nil
        retryAttempt = 0
        reloadCurrentItem()
    }

    /// Chooses play or pause from the current AVPlayer activity.
    func togglePlayback() {
        isPlaybackActive ? pause() : play()
    }

    /// The ±10 buttons reuse the slider seek mechanism.
    func skip(by seconds: TimeInterval) {
        seek(to: currentTime + seconds)
    }

    /// Changes the ceiling and rebuilds the item while preserving position.
    ///
    /// AVPlayer may have many old-quality segments buffered. Updating preferences
    /// only affects future downloads, so replacing the item discards that buffer
    /// and makes this educational control respond immediately.
    func setQualityLimit(_ limit: PlaybackQualityLimit) {
        guard qualityLimit != limit else { return }

        let shouldResumePlayback = isPlaybackActive
        qualityLimit = limit
        reloadCurrentItem(shouldResumePlayback: shouldResumePlayback)
    }

    /// Selects another HLS audio rendition without replacing the item.
    /// Playback position, buffered video, quality limit, and play/pause state
    /// therefore remain unchanged.
    func selectAudioTrack(_ track: AudioTrackOption) {
        guard selectedAudioTrackID != track.id,
              let item = player.currentItem,
              let group = audioSelectionGroup,
              let mediaOption = mediaOptionsByAudioTrackID[track.id] else {
            return
        }

        item.select(mediaOption, in: group)
        selectedAudioTrackID = track.id
        preferredAudioLanguageCode = track.languageCode
    }

    /// Moves playback to a specific second.
    func seek(to seconds: TimeInterval) {
        guard duration > 0 else { return }

        // Prevent seeking before zero or beyond the end of the video.
        let targetSeconds = min(max(seconds, 0), duration)

        // CMTime needs a timescale; 600 provides good video precision.
        let targetTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)
        let seekID = UUID()

        reachedEnd = false
        activeSeekID = seekID

        // Move the slider immediately so it does not jump back visually while
        // AVPlayer completes the asynchronous seek.
        currentTime = targetSeconds

        player.seek(
            to: targetTime,

            // Zero tolerance requests the most exact position. This can be more
            // expensive than allowing AVPlayer to use a nearby keyframe.
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] finished in
            Task { @MainActor [weak self] in
                guard let self, self.activeSeekID == seekID else { return }
                self.activeSeekID = nil

                if finished {
                    self.currentTime = targetSeconds
                } else {
                    // Return to real player time when the seek is cancelled.
                    self.updateTimeline(currentTime: self.player.currentTime())
                }
            }
        }
    }

    // MARK: - State observation

    private func observePlayer() {
        // This observer belongs to AVPlayer, which remains stable across retries,
        // so it is configured once instead of per AVPlayerItem.
        timeControlStatusObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                self?.handleTimeControlStatus(player.timeControlStatus)
            }
        }
    }

    private func observe(item: AVPlayerItem) {
        // AVPlayerItem.status answers whether content is ready for use.
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                self?.handleItemStatus(item)
            }
        }

        // loadedTimeRanges contains intervals available in memory or on disk that
        // AVPlayer can present without waiting for the network.
        loadedTimeRangesObservation = item.observe(\.loadedTimeRanges, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                self?.bufferedRanges = PlaybackBufferRange.makeRanges(from: item.loadedTimeRanges)
            }
        }

        // Resolution may begin as CGSize.zero and change after AVPlayer discovers
        // the video track dimensions.
        presentationSizeObservation = item.observe(\.presentationSize, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                self?.updatePlaybackMetrics(for: item)
            }
        }

        // NotificationCenter reports the end of the item.
        playbackEndedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reachedEnd = true
                self?.currentTime = self?.duration ?? 0
                self?.playbackState = .ended
            }
        }

        // This event occurs when playback starts but cannot finish.
        playbackFailedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error

            Task { @MainActor [weak self] in
                self?.handlePlaybackFailure(
                    message: error?.localizedDescription ?? "The stream could not finish playing."
                )
            }
        }

        // Log-event properties are not observable. AVFoundation posts these
        // notifications when it adds new information.
        accessLogObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewAccessLogEntry,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePlaybackMetrics(for: item)
            }
        }

        errorLogObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewErrorLogEntry,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePlaybackMetrics(for: item)
            }
        }

        // accessLog() may contain data before the first notification.
        updatePlaybackMetrics(for: item)
    }

    private func updatePlaybackMetrics(for item: AVPlayerItem) {
        playbackMetrics = PlaybackMetricsMapper.makeMetrics(for: item)
    }

    /// Loads the audible media-selection group advertised by the HLS master.
    /// A regular MP4 or a single-audio HLS stream may return no group or only
    /// one option; both cases are valid.
    private func discoverAudioTracks(for item: AVPlayerItem) {
        audioDiscoveryTask?.cancel()

        audioDiscoveryTask = Task { [weak self, weak item] in
            guard let self, let item else { return }

            do {
                let group = try await item.asset.loadMediaSelectionGroup(for: .audible)
                guard !Task.isCancelled, self.player.currentItem === item else { return }

                self.installAudioTracks(from: group, for: item)
            } catch {
                guard !Task.isCancelled, self.player.currentItem === item else { return }

                // Audio selection is optional, so failure to discover a group
                // should not fail otherwise valid video playback.
                self.clearAudioTracks()
            }
        }
    }

    private func installAudioTracks(
        from group: AVMediaSelectionGroup?,
        for item: AVPlayerItem
    ) {
        guard let group else {
            clearAudioTracks()
            return
        }

        var tracks: [AudioTrackOption] = []
        var optionMap: [String: AVMediaSelectionOption] = [:]

        for (index, mediaOption) in group.options.enumerated() {
            let languageCode = normalizedLanguageCode(for: mediaOption)
            let id = "audio-\(index)-\(languageCode ?? "unknown")"
            let track = AudioTrackOption(
                id: id,
                title: audioTrackTitle(
                    languageCode: languageCode,
                    fallback: mediaOption.displayName
                ),
                languageCode: languageCode
            )

            tracks.append(track)
            optionMap[id] = mediaOption
        }

        audioSelectionGroup = group
        mediaOptionsByAudioTrackID = optionMap
        audioTracks = tracks

        // Restore the user's language after a retry or quality-limit reload.
        if let preferredAudioLanguageCode,
           let preferredTrack = tracks.first(where: { $0.languageCode == preferredAudioLanguageCode }),
           let preferredOption = optionMap[preferredTrack.id] {
            item.select(preferredOption, in: group)
            selectedAudioTrackID = preferredTrack.id
            return
        }

        // Explicitly use the HLS DEFAULT option. Otherwise AVPlayer may override
        // it with the Simulator's preferred system language.
        let initialMediaOption = group.defaultOption
            ?? item.currentMediaSelection.selectedMediaOption(in: group)

        if let initialMediaOption {
            item.select(initialMediaOption, in: group)
        }

        selectedAudioTrackID = tracks.first(where: { track in
            optionMap[track.id] === initialMediaOption
        })?.id ?? tracks.first?.id
    }

    private func audioTrackTitle(languageCode: String?, fallback: String) -> String {
        switch languageCode {
        case "es": "Latin American Spanish"
        case "en": "English"
        default: fallback
        }
    }

    private func normalizedLanguageCode(for option: AVMediaSelectionOption) -> String? {
        let rawCode = option.extendedLanguageTag ?? option.locale?.identifier
        guard let rawCode else { return nil }

        // Matching the primary subtag lets "en", "en-US", and "en_US" restore
        // the same language across newly created AVPlayerItem instances.
        return rawCode
            .lowercased()
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first
            .map(String.init)
    }

    private func clearAudioTracks() {
        audioSelectionGroup = nil
        mediaOptionsByAudioTrackID = [:]
        audioTracks = []
        selectedAudioTrackID = nil
    }

    /// Stops only observations associated with the old AVPlayerItem.
    /// The AVPlayer and periodic observers remain active.
    private func stopObservingCurrentItem() {
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        loadedTimeRangesObservation?.invalidate()
        loadedTimeRangesObservation = nil

        presentationSizeObservation?.invalidate()
        presentationSizeObservation = nil

        if let playbackEndedObserver {
            NotificationCenter.default.removeObserver(playbackEndedObserver)
            self.playbackEndedObserver = nil
        }

        if let playbackFailedObserver {
            NotificationCenter.default.removeObserver(playbackFailedObserver)
            self.playbackFailedObserver = nil
        }

        if let accessLogObserver {
            NotificationCenter.default.removeObserver(accessLogObserver)
            self.accessLogObserver = nil
        }

        if let errorLogObserver {
            NotificationCenter.default.removeObserver(errorLogObserver)
            self.errorLogObserver = nil
        }
    }

    // MARK: - Error recovery

    private func handlePlaybackFailure(message: String) {
        guard retryTask == nil else { return }

        guard retryAttempt < retryPolicy.maximumAttempts else {
            playbackState = .failed(
                message: "\(message) Automatic retries were exhausted. Check the server and try again."
            )
            return
        }

        retryAttempt += 1
        let attempt = retryAttempt
        let delay = retryPolicy.delay(forAttempt: attempt)

        playbackState = .retrying(
            attempt: attempt,
            maximumAttempts: retryPolicy.maximumAttempts,
            delay: delay
        )

        // Copy the scheduler so the Task can capture the ViewModel weakly and not
        // prevent the screen and its model from being released.
        let scheduler = retryScheduler
        retryTask = Task { [weak self] in
            do {
                try await scheduler.wait(for: delay)
            } catch {
                return // Task.cancel() interrupts the wait by throwing CancellationError.
            }

            guard !Task.isCancelled else { return }
            self?.performScheduledRetry()
        }
    }

    private func performScheduledRetry() {
        retryTask = nil
        reloadCurrentItem()
    }

    private func reloadCurrentItem(shouldResumePlayback: Bool = true) {
        // If the stream fails mid-episode, resume from the last known second after
        // loading the new AVPlayerItem.
        pendingResumeTime = currentTime > 0 ? currentTime : nil

        player.pause()
        stopObservingCurrentItem()
        audioDiscoveryTask?.cancel()
        audioDiscoveryTask = nil
        clearAudioTracks()

        bufferedRanges = []
        playbackMetrics = .empty
        lastMetricsRefreshDate = .distantPast
        duration = 0
        reachedEnd = false
        activeSeekID = nil
        shouldPlayWhenReady = shouldResumePlayback
        playbackState = .loading

        let newItem = AVPlayerItem(url: streamURL)
        // A retry creates a new item, so reapply the selected ceiling.
        Self.apply(qualityLimit, to: newItem)
        player.replaceCurrentItem(with: newItem)
        observe(item: newItem)
    }

    /// These properties are preferences, not an exact-quality command.
    /// The player may choose a lower variant to avoid buffering.
    private static func apply(_ limit: PlaybackQualityLimit, to item: AVPlayerItem) {
        item.preferredPeakBitRate = limit.preferredPeakBitRate
        item.preferredMaximumResolution = limit.preferredMaximumResolution
    }

    // MARK: - Timeline synchronization

    private func observeTimeline() {
        // Four updates per second keep the slider smooth without requesting one
        // update for every video frame.
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)

        periodicTimeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.updateTimeline(currentTime: time)
            }
        }
    }

    private func updateTimeline(currentTime: CMTime) {
        let currentSeconds = currentTime.seconds

        // Preserve the selected time while a seek is pending so an older callback
        // cannot move the slider backward.
        if activeSeekID == nil, currentSeconds.isFinite {
            self.currentTime = max(currentSeconds, 0)
        }

        // HLS duration may initially be unknown. Update it once AVPlayerItem
        // publishes a valid finite value.
        if let itemDuration = player.currentItem?.duration.seconds,
           itemDuration.isFinite,
           itemDuration > 0 {
            duration = itemDuration
        }

        refreshPlaybackMetricsIfNeeded()
    }

    /// Access-log events are not observable. Reading accessLog() once per second
    /// shows requests, bytes, and observed time increasing.
    private func refreshPlaybackMetricsIfNeeded(now: Date = Date()) {
        guard now.timeIntervalSince(lastMetricsRefreshDate) >= 1,
              let item = player.currentItem else {
            return
        }

        lastMetricsRefreshDate = now
        updatePlaybackMetrics(for: item)
    }

    // MARK: - AVFoundation state to PlaybackState

    private func handleItemStatus(_ item: AVPlayerItem) {
        switch item.status {
        case .unknown:
            playbackState = .loading
        case .readyToPlay:
            updateTimeline(currentTime: player.currentTime())
            updatePlaybackMetrics(for: item)
            discoverAudioTracks(for: item)

            if let pendingResumeTime {
                self.pendingResumeTime = nil
                seek(to: pendingResumeTime)
            }

            if shouldPlayWhenReady {
                shouldPlayWhenReady = false
                player.play()
            }

            updateStateFromTimeControlStatus()
        case .failed:
            handlePlaybackFailure(
                message: item.error?.localizedDescription ?? "AVPlayer could not load this stream."
            )
        @unknown default:
            playbackState = .failed(message: "AVPlayer reported an unknown playback state.")
        }
    }

    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        guard player.currentItem?.status == .readyToPlay else {
            if player.currentItem?.status != .failed {
                playbackState = .loading
            }
            return
        }

        switch status {
        case .paused:
            playbackState = reachedEnd ? .ended : (hasPlayed ? .paused : .ready)
        case .waitingToPlayAtSpecifiedRate:
            playbackState = .buffering
        case .playing:
            reachedEnd = false
            hasPlayed = true
            retryAttempt = 0
            playbackState = .playing
        @unknown default:
            playbackState = .failed(message: "AVPlayer reported an unknown time-control state.")
        }
    }

    private func updateStateFromTimeControlStatus() {
        handleTimeControlStatus(player.timeControlStatus)
    }
}
