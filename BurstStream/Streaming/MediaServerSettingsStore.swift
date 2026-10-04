//
//  MediaServerSettingsStore.swift
//  BurstStream
//

import Combine
import Foundation

struct MediaServerConfiguration: Equatable {
    let baseURL: URL

    init?(baseURLText: String) {
        let trimmedText = baseURLText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard var components = URLComponents(string: trimmedText),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            return nil
        }

        components.scheme = scheme
        while components.path.count > 1 && components.path.hasSuffix("/") {
            components.path.removeLast()
        }

        guard let baseURL = components.url else { return nil }
        self.baseURL = baseURL
    }

    func streamURL(relativePath: String) -> URL {
        baseURL.appending(path: relativePath)
    }
}

@MainActor
final class MediaServerSettingsStore: ObservableObject {
    @Published private(set) var configuration: MediaServerConfiguration

    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "burststream.media-server-base-url.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey

        let savedConfiguration = defaults.string(forKey: storageKey)
            .flatMap(MediaServerConfiguration.init(baseURLText:))
        configuration = savedConfiguration ?? MediaServerConfiguration(
            baseURLText: SampleStreams.defaultMediaServerBaseURL.absoluteString
        )!
    }

    @discardableResult
    func updateBaseURL(from text: String) -> Bool {
        guard let configuration = MediaServerConfiguration(baseURLText: text) else {
            return false
        }

        self.configuration = configuration
        defaults.set(configuration.baseURL.absoluteString, forKey: storageKey)
        return true
    }
}
