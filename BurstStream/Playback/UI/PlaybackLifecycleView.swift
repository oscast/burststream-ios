//
//  PlaybackLifecycleView.swift
//  BurstStream
//

import SwiftUI

/// Shows the latest lifecycle decision so interruption experiments are visible
/// without opening Xcode's console.
struct PlaybackLifecycleView: View {
    let eventDescription: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "waveform.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.indigo)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text("System lifecycle")
                    .font(.headline)

                Text(eventDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
