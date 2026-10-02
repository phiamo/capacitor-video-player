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

    /// Fires as soon as the system begins the PiP transition — earlier and more reliable than
    /// `shouldAutomaticallyDismissAtPictureInPictureStart`, and races `UIApplication.didEnterBackgroundNotification`
    /// favorably enough to gate the Epic 45 background handoff before it tears down the player.
    public func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        guard isPIPModeAvailable else { return }
        isInPIPMode = true
        self.notifyPictureInPictureStart()
    }

    public func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        // State already set in willStartPictureInPicture; nothing else to do here.
    }

    public func playerViewController(
        _ playerViewController: AVPlayerViewController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        if isInPIPMode {
            isInPIPMode = false
            self.notifyPictureInPictureStop()
        }
    }

    public func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(_ playerViewController: AVPlayerViewController) -> Bool {
        if isPIPModeAvailable {
            // isInPIPMode is set earlier in playerViewControllerWillStartPictureInPicture; keep as fallback.
            if !isInPIPMode {
                isInPIPMode = true
                self.notifyPictureInPictureStart()
            }
            if let presenter = self.videoPlayerFullScreenView?.fullscreenContainer?
                .presentingViewController {
                presenter.dismiss(animated: true, completion: nil)
            } else {
                self.bridge?.viewController?.dismiss(animated: true, completion: nil)
            }

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
            self.notifyPictureInPictureStop()
            NotificationCenter.default.post(name: .playerFullscreenDismiss, object: nil)
        }
        isPlayerViewRestored = false
    }
    public func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        if isPIPModeAvailable {
            if isInPIPMode && !isVideoEnded {
                isPlayerViewRestored = true
                let toPresent: UIViewController =
                    (playerViewController.parent as? FullscreenPlayerContainerViewController)
                    ?? self.videoPlayerFullScreenView?.fullscreenContainer
                    ?? playerViewController
                self.bridge?.viewController?.present(toPresent, animated: true, completion: nil)
            }
            isInPIPMode = false
            self.notifyPictureInPictureStop()
        }
        completionHandler(true)
    }

    /// User tapped Done/X on native fullscreen — KVO alone is unreliable on modern iOS.
    public func playerViewController(
        _ playerViewController: AVPlayerViewController,
        willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
    ) {
        if self.isPlayerDismissed || isInPIPMode {
            return
        }
        // AVKit often zeros rate before this callback; use sticky recent-play state.
        let wasPlaying = videoPlayerFullScreenView?.wasPlayingForDismiss()
            ?? ((playerViewController.player?.rate ?? 0) > 0)
        NSLog("[CapacitorVideoPlayer] willEndFullScreenPresentation wasPlaying=%@", wasPlaying ? "true" : "false")
        NotificationCenter.default.post(
            name: .playerFullscreenDismiss,
            object: playerViewController,
            userInfo: ["wasPlaying": wasPlaying]
        )
        // iOS 26 second session can show Back (exit-fullscreen) without dismissing the modal.
        if !playerViewController.isBeingDismissed {
            let host = playerViewController.parent as? FullscreenPlayerContainerViewController
            let toDismiss = host ?? playerViewController
            if !toDismiss.isBeingDismissed {
                toDismiss.presentingViewController?.dismiss(animated: true)
            }
        }
    }
}
