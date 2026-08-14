//
//  NetworkConditionView.swift
//  BurstStream
//

import SwiftUI

struct NetworkConditionView: View {
    @ObservedObject var conditioner: NetworkConditionerClient

    private let columns = [
        GridItem(.adaptive(minimum: 105), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Local network", systemImage: "network")
                    .font(.headline)

                Spacer()

                if conditioner.isUpdating {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(NetworkProfile.allCases) { profile in
                    Button {
                        conditioner.select(profile)
                    } label: {
                        HStack(spacing: 5) {
                            if conditioner.selectedProfile == profile {
                                Image(systemName: "checkmark.circle.fill")
                            }

                            Text(profile.title)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.bordered)
                    .tint(conditioner.selectedProfile == profile ? .orange : .secondary)
                    .disabled(conditioner.isUpdating)
                    .accessibilityLabel("Simulate \(profile.title)")
                    .accessibilityHint(profile.experimentHint)
                }
            }

            if let selectedProfile = conditioner.selectedProfile {
                Text(selectedProfile.experimentHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Start the throttled local server to enable network experiments.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = conditioner.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
