//
//  QoESessionHistoryStore.swift
//  BurstStream
//

import Combine
import Foundation

/// A small, bounded local history. It stores only the privacy-safe summary,
/// never stream URLs, request URIs, server addresses, or raw AVFoundation errors.
@MainActor
final class QoESessionHistoryStore: ObservableObject {
    static let shared = QoESessionHistoryStore()
    @Published private(set) var sessions: [QoESessionSummary]

    private let defaults: UserDefaults
    private let storageKey: String
    private let maximumSessionCount: Int

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "burststream.qoe-session-history.v1",
        maximumSessionCount: Int = 20
    ) {
        let sessionLimit = max(maximumSessionCount, 1)
        self.defaults = defaults
        self.storageKey = storageKey
        self.maximumSessionCount = sessionLimit
        sessions = Self.loadSessions(from: defaults, key: storageKey)
            .sorted(by: Self.isNewer)
            .prefix(sessionLimit)
            .map { $0 }
    }

    func record(_ summary: QoESessionSummary) {
        sessions.removeAll(where: { $0.id == summary.id })
        sessions.append(summary)
        sessions.sort(by: Self.isNewer)
        if sessions.count > maximumSessionCount {
            sessions.removeLast(sessions.count - maximumSessionCount)
        }
        persistSessions()
    }

    func exportJSON(prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try encoder.encode(
            QoESessionHistoryExport(schemaVersion: 1, sessions: sessions)
        )
    }

    func clear() {
        sessions = []
        defaults.removeObject(forKey: storageKey)
    }

    private func persistSessions() {
        do {
            defaults.set(try JSONEncoder().encode(sessions), forKey: storageKey)
        } catch {
            // Diagnostics persistence must never block or alter playback.
            print("Could not save QoE session history: \(error)")
        }
    }

    private static func loadSessions(
        from defaults: UserDefaults,
        key: String
    ) -> [QoESessionSummary] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([QoESessionSummary].self, from: data)) ?? []
    }

    private static func isNewer(
        _ lhs: QoESessionSummary,
        _ rhs: QoESessionSummary
    ) -> Bool {
        (lhs.endedAt ?? lhs.startedAt) > (rhs.endedAt ?? rhs.startedAt)
    }
}

private struct QoESessionHistoryExport: Codable {
    let schemaVersion: Int
    let sessions: [QoESessionSummary]
}
