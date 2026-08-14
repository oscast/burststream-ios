//
//  PlaybackBufferRange.swift
//  BurstStream
//

import AVFoundation

/// A video interval AVPlayer has already downloaded and can present.
///
/// The UI uses seconds (`TimeInterval`) because they are easier to display and
/// compare. AVFoundation originally provides these values as CMTime.
struct PlaybackBufferRange: Equatable {
    let start: TimeInterval
    let end: TimeInterval

    var duration: TimeInterval {
        max(end - start, 0)
    }

    func contains(_ time: TimeInterval) -> Bool {
        start <= time && time <= end
    }

    /// Converts AVPlayerItem `loadedTimeRanges` into UI-safe values.
    ///
    /// This calculation does not need a protocol because it is pure,
    /// deterministic, and has no external dependency to replace.
    static func makeRanges(from values: [NSValue]) -> [PlaybackBufferRange] {
        values.compactMap { value in
            let range = value.timeRangeValue
            let start = range.start.seconds
            let duration = range.duration.seconds
            let end = start + duration

            guard start.isFinite,
                  duration.isFinite,
                  duration > 0,
                  end.isFinite else {
                return nil
            }

            return PlaybackBufferRange(start: max(start, 0), end: max(end, 0))
        }
        .sorted { $0.start < $1.start }
    }
}
