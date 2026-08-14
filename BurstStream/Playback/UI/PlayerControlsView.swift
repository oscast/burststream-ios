//
//  PlayerControlsView.swift
//  BurstStream
//

import SwiftUI
import AVKit

struct PlayerControlsView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject var pictureInPicture: PictureInPictureController

    // Scrubbing needs an independent local position. Reading currentTime
    // directly would let AVPlayer move the slider underneath the finger.
    @State private var scrubberValue: TimeInterval = 0
    @State private var isScrubbing = false

    private var sliderUpperBound: TimeInterval {
        // Slider does not accept 0...0, so use 1 until duration is available.
        max(viewModel.duration, 1)
    }

    private var displayedTime: TimeInterval {
        isScrubbing ? scrubberValue : viewModel.currentTime
    }

    var body: some View {
        VStack(spacing: 10) {
            Slider(
                // Read real playback time normally and the finger position while
                // the user is dragging the control.
                value: Binding(
                    get: { min(displayedTime, sliderUpperBound) },
                    set: { scrubberValue = $0 }
                ),
                in: 0...sliderUpperBound,
                onEditingChanged: handleScrubbing
            )
            .disabled(viewModel.duration <= 0)

            BufferProgressView(
                ranges: viewModel.bufferedRanges,
                duration: viewModel.duration
            )
            .frame(height: 6)

            HStack {
                Text(formatTime(displayedTime))
                    .monospacedDigit()

                Spacer()

                Label(
                    "\(formatTime(viewModel.bufferedDurationAhead)) buffered",
                    systemImage: "arrow.down.circle"
                )
                .foregroundStyle(.cyan)

                Spacer()

                Text(formatTime(viewModel.duration))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            HStack(spacing: 36) {
                Button {
                    viewModel.skip(by: -10)
                } label: {
                    Image(systemName: "gobackward.10")
                }
                .disabled(viewModel.duration <= 0)
                .accessibilityLabel("Go back 10 seconds")

                Button {
                    viewModel.togglePlayback()
                } label: {
                    Image(systemName: viewModel.isPlaybackActive ? "pause.fill" : "play.fill")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .accessibilityLabel(viewModel.isPlaybackActive ? "Pause" : "Play")

                Button {
                    viewModel.skip(by: 10)
                } label: {
                    Image(systemName: "goforward.10")
                }
                .disabled(viewModel.duration <= 0)
                .accessibilityLabel("Go forward 10 seconds")

                if pictureInPicture.isSupported {
                    Button {
                        pictureInPicture.toggle()
                    } label: {
                        Image(
                            uiImage: pictureInPicture.isActive
                                ? AVPictureInPictureController.pictureInPictureButtonStopImage
                                : AVPictureInPictureController.pictureInPictureButtonStartImage
                        )
                        .frame(width: 28, height: 28)
                    }
                    .disabled(!pictureInPicture.isPossible && !pictureInPicture.isActive)
                    .accessibilityLabel(
                        pictureInPicture.isActive
                            ? "Stop Picture in Picture"
                            : "Start Picture in Picture"
                    )
                    .accessibilityHint("Keeps the video visible in a floating window")
                }
            }
            .font(.title2)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onChange(of: viewModel.currentTime) { _, newValue in
            // Synchronize the slider only while the user is not dragging it.
            guard !isScrubbing else { return }
            scrubberValue = newValue
        }
    }

    private func handleScrubbing(_ editing: Bool) {
        if editing {
            // Freeze player-driven visual updates when scrubbing begins.
            isScrubbing = true
        } else {
            // Perform one real seek when the finger is released. Seeking on every
            // movement would create many requests and cancellations.
            viewModel.seek(to: scrubberValue)
            isScrubbing = false
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "--:--" }

        let totalSeconds = Int(time)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}
