//
//  CapacitorVideoPlayerPlugin.AVPlayerViewController.swift
//  CapacitorVideoPlayer
//
//  Created by  Quéau Jean Pierre on 10/12/2021.
//

import AVFoundation
import AVKit

var isInPIPMode: Bool = false
var isInBackgroundMode: Bool = false
var isPIPModeAvailable: Bool = false
var isVideoEnded: Bool = false
var isRateZero: Bool = false
var isPlayerViewRestored: Bool = false
/** Suppress spurious fullscreen dismiss KVO while AVPlayerViewController is presenting. */
var isOpeningNativeFullscreen: Bool = false

extension CapacitorVideoPlayerPlugin: AVPlayerViewControllerDelegate {

    public func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(_ playerViewController: AVPlayerViewController) -> Bool {
        if isPIPModeAvailable {

            isInPIPMode = true
            self.bridge?.viewController?.dismiss(animated: true, completion: nil)

            return true
        } else {
            return false
        }
    }
    public func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        isRateZero = false
    }
    public func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        // if !isPlayerViewRestored then the user closed the PIP
        if isPIPModeAvailable && ((isRateZero || isVideoEnded) || !isPlayerViewRestored) {
            isInPIPMode = false
            NotificationCenter.default.post(name: .playerFullscreenDismiss, object: nil)
        }
        isPlayerViewRestored = false
    }
    public func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        if isPIPModeAvailable {
            if isInPIPMode && !isVideoEnded {
                isPlayerViewRestored = true
                self.bridge?.viewController?.present(playerViewController, animated: true, completion: nil)
            }
            isInPIPMode = false
        }

    }

    /// User tapped Done/X on native fullscreen — KVO alone is unreliable on modern iOS.
    public func playerViewController(
        _ playerViewController: AVPlayerViewController,
        willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
    ) {
        if isOpeningNativeFullscreen || isVideoEnded || self.isPlayerDismissed {
            return
        }
        print("[CapacitorVideoPlayer] willEndFullScreenPresentation — user closed native fullscreen")
        NotificationCenter.default.post(name: .playerFullscreenDismiss, object: nil)
    }
}
