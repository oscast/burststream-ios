//
//  AirPlayPanel.swift
//  BurstStream
//

import SwiftUI

struct AirPlayPanel: View {
    let isExternalPlaybackActive: Bool
    let streamURL: URL

    private var usesLoopbackHost: Bool {
        guard let host = streamURL.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AirPlayRoutePicker(isActive: isExternalPlaybackActive)
                .frame(width: 44, height: 44)
                .accessibilityLabel("Choose an AirPlay device")

            VStack(alignment: .leading, spacing: 4) {
                Text(isExternalPlaybackActive ? "Playing with AirPlay" : "AirPlay")
                    .font(.headline)

                Text(
                    isExternalPlaybackActive
                        ? "Playback is external. These controls still operate the same AVPlayer."
                        : "Tap the AirPlay button to choose an available video receiver."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

                if usesLoopbackHost {
                    Text("localhost cannot be reached by Apple TV. For real AirPlay, load the stream using your Mac's LAN IP address.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
