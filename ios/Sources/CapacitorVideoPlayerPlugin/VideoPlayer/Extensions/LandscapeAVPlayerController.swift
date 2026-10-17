//
//  LandscapeAVPlayerController.swift
//  CapacitorVideoPlayer
//
//  Created by  Quéau Jean Pierre on 23/05/2023.
//

import AVKit
class LandscapeAVPlayerController: AVPlayerViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscapeRight
    }
}
