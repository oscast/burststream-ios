//
//  PlayerSurface.swift
//  BurstStream
//

import AVFoundation
import SwiftUI
import UIKit

/// Bridge between SwiftUI and AVPlayerLayer.
///
/// SwiftUI includes `VideoPlayer`, but Apple manages its controls and they cannot
/// be fully customized. AVPlayerLayer presents only the video while the app
/// builds its controls separately.
struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    /// SwiftUI calls this method once to create the UIKit view.
    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.player = player
        return view
    }

    /// SwiftUI calls this method when a view input changes.
    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.player = player
    }
}

/// UIView whose backing layer is an AVPlayerLayer.
/// AVPlayer controls time and audio; AVPlayerLayer presents video frames.
final class PlayerLayerView: UIView {
    /// UIKit normally creates CALayer; this view requests AVPlayerLayer.
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    /// Convenience property for assigning AVPlayer without exposing casts.
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black

        // Preserve the source aspect ratio and add black bars when the view has
        // a different aspect ratio.
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
    }
}
