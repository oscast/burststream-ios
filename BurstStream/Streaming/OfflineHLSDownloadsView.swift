import SwiftUI

struct OfflineHLSDownloadsView: View {
    @ObservedObject var manager: OfflineHLSDownloadManager
    let source: StreamSource?
    let onPlay: (OfflineHLSDownloadRecord) -> Void

    @State private var choices: OfflineHLSMediaChoices?
    @State private var inspectedSourceID: String?
    @State private var audioTrackID = "automatic"
    @State private var subtitleTrackID = SubtitleTrackOption.off.id
    @State private var isPreparing = false
    @State private var errorMessage: String?

    var body: some View {
        Section("Offline HLS") {
            Text("Download a VOD stream to play it without the media server. Choose the tracks before starting.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Choose download tracks") {
                inspectTracks()
            }
            .disabled(source == nil || isPreparing)

            if isPreparing {
                ProgressView("Inspecting HLS tracks")
            }

            if let choices, inspectedSourceID == source?.id {
                Picker("Audio to download", selection: $audioTrackID) {
                    Text("Automatic").tag("automatic")
                    ForEach(choices.audio) { track in
                        Text(track.title).tag(track.id)
                    }
                }

                Picker("Subtitles to download", selection: $subtitleTrackID) {
                    ForEach(choices.subtitles) { track in
                        Text(track.title).tag(track.id)
                    }
                }

                Button("Download selected stream") {
                    startDownload()
                }
                .disabled(isPreparing || manager.record(for: source?.id ?? "") != nil)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Offline download error: \(errorMessage)")
            }

            ForEach(manager.records) { record in
                downloadRow(record)
            }
        }
        .onChange(of: source?.id) { _, _ in
            choices = nil
            inspectedSourceID = nil
            errorMessage = nil
        }
    }

    private func downloadRow(_ record: OfflineHLSDownloadRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(record.title)
                .font(.headline)
            Text(statusText(for: record))
                .font(.caption)
                .foregroundStyle(.secondary)

            if record.state == .downloading || record.state == .paused {
                ProgressView(value: record.progress)
                    .accessibilityLabel("Download progress")
                    .accessibilityValue(record.progress.formatted(.percent))
            }

            HStack {
                switch record.state {
                case .downloading:
                    Button("Pause") { manager.pause(id: record.id) }
                    Button("Cancel", role: .destructive) { manager.cancel(id: record.id) }
                case .paused:
                    Button("Resume") { manager.resume(id: record.id) }
                    Button("Cancel", role: .destructive) { manager.cancel(id: record.id) }
                case .completed:
                    if manager.playableURL(for: record.id) != nil {
                        Button("Play offline") { onPlay(record) }
                    }
                    Button("Delete", role: .destructive) { delete(record) }
                case .failed:
                    Button("Delete", role: .destructive) { delete(record) }
                case .preparing:
                    ProgressView()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }

    private func statusText(for record: OfflineHLSDownloadRecord) -> String {
        switch record.state {
        case .preparing: "Preparing"
        case .downloading: "Downloading"
        case .paused: "Paused"
        case .completed: "Ready for offline playback"
        case .failed: "Download unavailable; delete and try again"
        }
    }

    private func inspectTracks() {
        guard let source else {
            errorMessage = "Enter a valid HLS stream URL first."
            return
        }
        isPreparing = true
        errorMessage = nil
        Task {
            defer { isPreparing = false }
            do {
                choices = try await manager.inspectMedia(at: source.streamURL)
                inspectedSourceID = source.id
                audioTrackID = "automatic"
                subtitleTrackID = SubtitleTrackOption.off.id
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func startDownload() {
        guard let source else { return }
        isPreparing = true
        errorMessage = nil
        Task {
            defer { isPreparing = false }
            do {
                try await manager.start(
                    source: source,
                    audioTrackID: audioTrackID == "automatic" ? nil : audioTrackID,
                    subtitleTrackID: subtitleTrackID
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func delete(_ record: OfflineHLSDownloadRecord) {
        do {
            try manager.delete(id: record.id)
        } catch {
            errorMessage = "Could not delete the offline download: \(error.localizedDescription)"
        }
    }
}
