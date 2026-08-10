//
//  LocalNetworkConditioner.swift
//  BurstStream
//

import Foundation
import Combine

/// Controls the development-only endpoint exposed by throttled_hls_server.py.
/// Remote production streams never show these controls.
@MainActor
final class LocalNetworkConditioner: ObservableObject {
    @Published private(set) var selectedProfile: LocalNetworkProfile?
    @Published private(set) var isUpdating = false
    @Published private(set) var errorMessage: String?

    private let endpointURL: URL?

    var isAvailable: Bool {
        endpointURL != nil
    }

    init(streamURL: URL) {
        guard let host = streamURL.host?.lowercased(),
              ["localhost", "127.0.0.1", "::1"].contains(host),
              var components = URLComponents(url: streamURL, resolvingAgainstBaseURL: false) else {
            endpointURL = nil
            return
        }

        components.path = "/__burststream/profile"
        components.query = nil
        components.fragment = nil
        endpointURL = components.url
    }

    /// Reads the server profile when the player screen first appears.
    func refresh() {
        guard let endpointURL else { return }

        Task {
            await performRequest(URLRequest(url: endpointURL))
        }
    }

    /// Changes the server profile without restarting playback or the server.
    func select(_ profile: LocalNetworkProfile) {
        guard let endpointURL, profile != selectedProfile else { return }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(ProfileRequest(profile: profile.rawValue))

        Task {
            await performRequest(request)
        }
    }

    private func performRequest(_ request: URLRequest) async {
        isUpdating = true
        errorMessage = nil

        defer { isUpdating = false }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw NetworkConditionerError.invalidResponse
            }

            let serverResponse = try JSONDecoder().decode(ProfileResponse.self, from: data)

            guard let profile = LocalNetworkProfile(rawValue: serverResponse.profile) else {
                throw NetworkConditionerError.unknownProfile
            }

            selectedProfile = profile
        } catch {
            errorMessage = "Could not update the local server: \(error.localizedDescription)"
        }
    }
}

private struct ProfileRequest: Encodable {
    let profile: String
}

private struct ProfileResponse: Decodable {
    let profile: String
}

private enum NetworkConditionerError: LocalizedError {
    case invalidResponse
    case unknownProfile

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The local server returned an invalid response."
        case .unknownProfile: "The local server selected an unknown profile."
        }
    }
}
