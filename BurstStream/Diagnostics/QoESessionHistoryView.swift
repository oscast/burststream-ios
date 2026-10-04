import SwiftUI

struct QoESessionHistoryView: View {
    @ObservedObject var store: QoESessionHistoryStore
    @State private var exportURL: URL?
    @State private var exportError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session quality history")
                .font(.headline)
            if store.sessions.isEmpty {
                Text("No playback sessions recorded yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.sessions) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.startedAt, format: .dateTime.day().month().year().hour().minute())
                            .font(.headline)
                        Text("\(session.rebufferCount) rebuffers · \(session.retryCount) retries")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Prepare JSON export") {
                    prepareExport()
                }
                if let exportURL {
                    ShareLink("Share JSON export", item: exportURL)
                }
                Button("Clear session history", role: .destructive) {
                    store.clear()
                    removeExport()
                }
            }

            if let exportError {
                Text(exportError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func prepareExport() {
        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("burststream-qoe-history-\(UUID().uuidString).json")
            try store.exportJSON().write(to: url, options: .atomic)
            removeExport()
            exportURL = url
            exportError = nil
        } catch {
            exportError = "Could not prepare the JSON export."
        }
    }

    private func removeExport() {
        if let exportURL { try? FileManager.default.removeItem(at: exportURL) }
        exportURL = nil
    }
}
