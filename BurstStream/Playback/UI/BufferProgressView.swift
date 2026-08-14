//
//  BufferProgressView.swift
//  BurstStream
//

import SwiftUI

/// Draws downloaded regions in cyan across the total duration.
/// Multiple regions can appear after seeking to separate positions.
struct BufferProgressView: View {
    let ranges: [PlaybackBufferRange]
    let duration: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.18))

                if duration > 0 {
                    ForEach(Array(ranges.enumerated()), id: \.offset) { _, range in
                        Capsule()
                            .fill(.cyan.opacity(0.75))
                            .frame(width: width(for: range, availableWidth: geometry.size.width))
                            .offset(x: offset(for: range, availableWidth: geometry.size.width))
                    }
                }
            }
        }
        .accessibilityLabel("Buffered video progress")
    }

    /// Converts range duration into a width proportional to the control.
    private func width(for range: PlaybackBufferRange, availableWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return availableWidth * (range.duration / duration)
    }

    /// Converts range start into a proportional horizontal position.
    private func offset(for range: PlaybackBufferRange, availableWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return availableWidth * (range.start / duration)
    }
}
