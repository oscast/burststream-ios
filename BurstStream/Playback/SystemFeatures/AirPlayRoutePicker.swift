//
//  AirPlayRoutePicker.swift
//  BurstStream
//

import AVKit
import SwiftUI

/// Wraps Apple's system route picker for use in SwiftUI.
///
/// The system owns route discovery, authorization, and the device-selection
/// interface. Reimplementing that behavior with a custom menu would be both
/// fragile and unnecessary.
struct AirPlayRoutePicker: UIViewRepresentable {
    let isActive: Bool

    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePicker = AVRoutePickerView()

        // Prefer televisions and other video-capable receivers because this app
        // plays video rather than audio-only content.
        routePicker.prioritizesVideoDevices = true
        return routePicker
    }

    func updateUIView(_ routePicker: AVRoutePickerView, context: Context) {
        routePicker.tintColor = .secondaryLabel
        routePicker.activeTintColor = isActive ? .systemBlue : .secondaryLabel
    }
}
