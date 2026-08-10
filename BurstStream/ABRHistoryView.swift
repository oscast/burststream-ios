//
//  ABRHistoryView.swift
//  BurstStream
//

import Charts
import SwiftUI


/// Compact sidebar summary. The full chart lives on a separate screen so the
/// Now Playing layout stays readable on iPad landscape.
struct ABRHistorySummaryView: View {
    @ObservedObject var recorder: ABRHistoryRecorder

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                if let latest = recorder.latestSample {
                    LabeledContent("Current variant", value: latest.variant)
                    LabeledContent("Network", value: latest.networkProfile)
                    LabeledContent("Throughput", value: formatBitrate(latest.observedBitrate))
                    LabeledContent("Required", value: formatBitrate(latest.requiredBitrate))
                    LabeledContent("Buffer", value: String(format: "%.0f s", latest.bufferAhead))
                } else {
                    Text("History will appear after AVPlayer reports its first access log.")
                        .foregroundStyle(.secondary)
                }

                recentTransitions

                NavigationLink {
                    ABRHistoryDetailView(recorder: recorder)
                } label: {
                    Label("Open full experiment", systemImage: "chart.xyaxis.line")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(recorder.samples.isEmpty)
            }
            .font(.footnote)
            .padding(.top, 12)
        } label: {
            HStack {
                Label("ABR history", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)

                Spacer()

                Text("\(recorder.samples.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var recentTransitions: some View {
        let transitions = recorder.transitions.suffix(3)

        if !transitions.isEmpty {
            Divider()

            Text("Recent changes")
                .font(.caption.weight(.semibold))

            ForEach(Array(transitions)) { sample in
                HStack(spacing: 6) {
                    Circle()
                        .fill(variantColor(sample.variant))
                        .frame(width: 7, height: 7)

                    Text(formatClock(sample.elapsedTime))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)

                    Text(sample.networkProfile)
                        .lineLimit(1)

                    Spacer()

                    Text(sample.variant)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct ABRHistoryDetailView: View {
    @ObservedObject var recorder: ABRHistoryRecorder

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                bitrateChart
                variantTimeline

                Button(role: .destructive) {
                    recorder.clear()
                } label: {
                    Label("Clear history", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(recorder.samples.isEmpty)
            }
            .padding()
        }
        .navigationTitle("ABR Experiment")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var bitrateChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Throughput vs. required bitrate")
                .font(.headline)

            Chart(recorder.samples) { sample in
                if let observedBitrate = sample.observedBitrate {
                    LineMark(
                        x: .value("Elapsed", sample.elapsedTime),
                        y: .value("Mbps", observedBitrate / 1_000_000),
                        series: .value("Metric", "Throughput")
                    )
                    .foregroundStyle(.cyan)
                }

                if let requiredBitrate = sample.requiredBitrate {
                    LineMark(
                        x: .value("Elapsed", sample.elapsedTime),
                        y: .value("Mbps", requiredBitrate / 1_000_000),
                        series: .value("Metric", "Required")
                    )
                    .foregroundStyle(.orange)
                }
            }
            .chartForegroundStyleScale([
                "Throughput": Color.cyan,
                "Required": Color.orange
            ])
            .chartXAxisLabel("Experiment time (seconds)")
            .chartYAxisLabel("Mbps")
            .frame(minHeight: 280)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var variantTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Variant changes")
                .font(.headline)

            if recorder.transitions.isEmpty {
                Text("No transitions recorded yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recorder.transitions.reversed()) { sample in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Circle()
                            .fill(variantColor(sample.variant))
                            .frame(width: 9, height: 9)

                        Text(formatClock(sample.elapsedTime))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Text(sample.networkProfile)
                            .frame(width: 90, alignment: .leading)

                        Text(sample.variant)
                            .fontWeight(.semibold)

                        Spacer()

                        Text(formatBitrate(sample.requiredBitrate))
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private func variantColor(_ variant: String) -> Color {
    switch variant {
    case "1080p": .purple
    case "720p": .blue
    case "480p": .green
    case "360p": .orange
    default: .secondary
    }
}

private func formatBitrate(_ bitsPerSecond: Double?) -> String {
    guard let bitsPerSecond else { return "—" }
    return String(format: "%.2f Mbps", bitsPerSecond / 1_000_000)
}

private func formatClock(_ seconds: TimeInterval) -> String {
    let totalSeconds = max(Int(seconds), 0)
    return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
}
