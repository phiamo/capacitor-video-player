//
//  CapacitorVideoPlayerPlugin.Fullscreen.swift
//  Plugin
//
//  Created by  Quéau Jean Pierre on 30/05/2021.
//  Copyright © 2021 Max Lynch. All rights reserved.
//

import Foundation
import Capacitor
import AVKit
import os

extension CapacitorVideoPlayerPlugin {

    /// Duration to suppress spurious KVO dismiss while AVPlayerViewController is presenting (matches app grace).
    private static let nativeFullscreenOpenHoldSeconds: TimeInterval = 2.0
    /// Poll interval/attempt count for `retryFullscreenPlaybackIfStalled` -- ~8s total, generous
    /// for a FairPlay SPC/CKC round trip (observed 2-11s for protected content with multiple keys).
    private static let fullscreenPlaybackRetryIntervalSeconds: TimeInterval = 0.8
    private static let fullscreenPlaybackRetryAttempts = 10

    // MARK: - initial playback (present + ready gate)

    func resetInitialFullscreenPlaybackState() {
        self.isFullscreenPresentCompleted = false
        self.isPlayerItemReadyForInitialPlayback = false
        self.initialFullscreenPlaybackStarted = false
    }

    /// Starts first play once item is ready and present completion ran.
    func startFullscreenPlaybackIfNeeded() {
        guard self.mode == "fullscreen" else { return }
        guard self.isFullscreenPresentCompleted else { return }
        guard !self.initialFullscreenPlaybackStarted else { return }
        guard let vPFSV = self.videoPlayerFullScreenView else { return }

        let itemReady = self.isPlayerItemReadyForInitialPlayback || vPFSV.isPlayerItemReadyForPlayback()
        guard itemReady else { return }

        self.initialFullscreenPlaybackStarted = true
        self.isPlayerItemReadyForInitialPlayback = false
        vPFSV.markPresentAudioSessionActive()
        let startAt = self.initialSeekSeconds
        if startAt > 0 {
            vPFSV.setCurrentTimeThenPlay(time: startAt)
            self.initialSeekSeconds = 0
        } else {
            vPFSV.play()
        }
    }

    /// A single one-shot readiness check previously left playback stuck at rate 0 forever if the
    /// player item became ready only after that check fired -- plausible for protected content,
    /// where FairPlay SPC/CKC key negotiation can take several seconds (observed 2-11s here).
    /// Poll instead, re-arming `startFullscreenPlaybackIfNeeded()` each tick, until playback
    /// actually starts (rate > 0) or attempts run out.
    func retryFullscreenPlaybackIfStalled(attemptsRemaining: Int) {
        guard attemptsRemaining > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fullscreenPlaybackRetryIntervalSeconds) { [weak self] in
            guard let self = self, self.mode == "fullscreen" else { return }
            if (self.videoPlayerFullScreenView?.player?.rate ?? 0) > 0 {
                return
            }
            self.initialFullscreenPlaybackStarted = false
            self.videoPlayerFullScreenView?.markPresentAudioSessionActive()
            self.startFullscreenPlaybackIfNeeded()
            self.retryFullscreenPlaybackIfStalled(attemptsRemaining: attemptsRemaining - 1)
        }
    }

    // MARK: - topmostViewController

    private static func isPlayerPresentation(_ vc: UIViewController) -> Bool {
        if vc is FullscreenPlayerContainerViewController || vc is AVPlayerViewController {
            return true
        }
        if let nav = vc as? UINavigationController,
           nav.viewControllers.contains(where: {
               $0 is FullscreenPlayerContainerViewController || $0 is AVPlayerViewController
           }) {
            return true
        }
        return false
    }

    /// Walks the bridge hierarchy to find a VC that can present. Never returns a leftover
    /// player container or `AVPlayerViewController` — presenting from those nests a second session.
    private func topmostViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            if Self.isPlayerPresentation(presented) {
                return root
            }
            return topmostViewController(from: presented)
        }
        if let nav = root as? UINavigationController,
           let visible = nav.visibleViewController {
            return topmostViewController(from: visible)
        }
        if let tab = root as? UITabBarController,
           let selected = tab.selectedViewController {
            return topmostViewController(from: selected)
        }
        return root
    }

    /// Presenter of the first leftover `AVPlayerViewController` in the tree, if any.
    private func presenterOfLeftoverPlayer(from root: UIViewController) -> UIViewController? {
        if let presented = root.presentedViewController {
            if Self.isPlayerPresentation(presented) {
                return root
            }
            return presenterOfLeftoverPlayer(from: presented)
        }
        if let nav = root as? UINavigationController,
           let visible = nav.visibleViewController {
            return presenterOfLeftoverPlayer(from: visible)
        }
        if let tab = root as? UITabBarController,
           let selected = tab.selectedViewController {
            return presenterOfLeftoverPlayer(from: selected)
        }
        return nil
    }

    // MARK: - clearStaleFullscreenPresentation

    /// Clears retained fullscreen state and dismisses a stuck modal before a new `initPlayer` presentation.
    func clearStaleFullscreenPresentation(completion: @escaping () -> Void) {
        self.resetInitialFullscreenPlaybackState()
        if let vPFSV = self.videoPlayerFullScreenView {
            Self.logger.debug("Clearing stale fullscreen view before new presentation")
            vPFSV.pause()
            vPFSV.cleanup()
            vPFSV.videoPlayer.player = nil
            self.videoPlayerFullScreenView = nil
            self.bgPlayer = nil
            self.videoPlayer = nil
        }

        guard let bridgeRoot = self.bridge?.viewController else {
            completion()
            return
        }

        self.dismissLeftoverPlayers(from: bridgeRoot, completion: completion)
    }

    private func dismissLeftoverPlayers(from root: UIViewController, completion: @escaping () -> Void) {
        if let presenter = presenterOfLeftoverPlayer(from: root) {
            print("[CapacitorVideoPlayer] Dismissing leftover AVPlayerViewController before new fullscreen player")
            Self.logger.debug("Dismissing leftover AVPlayerViewController before new fullscreen player")
            presenter.dismiss(animated: false) { [weak self] in
                guard let self = self else {
                    completion()
                    return
                }
                self.dismissLeftoverPlayers(from: root, completion: completion)
            }
            return
        }
        if root.presentedViewController != nil {
            print("[CapacitorVideoPlayer] Dismissing stale modal before new fullscreen player")
            Self.logger.debug("Dismissing stale presented view controller before new fullscreen player")
            root.dismiss(animated: false) {
                completion()
            }
            return
        }
        completion()
    }

    // MARK: - createVideoPlayerFullScreenView

    /// Activates movie-playback audio session after AVPlayerViewController is presented.
    /// Required for both legacy background mode and Epic 45 handoff (`backModeEnabled=false`).
    private func activateFullscreenAudioSessionAfterPresent() -> String? {
        self.audioSession = AVAudioSession.sharedInstance()
        do {
            try self.audioSession?
                .setCategory(.playback,
                             mode: .moviePlayback,
                             options: [])
            try self.audioSession?.setActive(true)
            return nil
        } catch let error as NSError {
            Self.logger.error(
                "Unable to activate audio session: \(error.localizedDescription, privacy: .public)")
            return error.localizedDescription
        }
    }

    // swiftlint:disable function_body_length
    // swiftlint:disable function_parameter_count
    func createVideoPlayerFullscreenView(
        call: CAPPluginCall, videoUrl: URL, rate: Float,
        exitOnEnd: Bool, loopOnEnd: Bool, pipEnabled: Bool,
        backModeEnabled: Bool, showControls: Bool,
        displayMode: String,
        subTitleUrl: URL?, subTitleLanguage: String?,
        subTitleOptions: [String: Any]?,
        headers: [String: String]?, title: String?,
        smallTitle: String?, artwork: String?,
        subtitleTracks: [[String: Any]]?,
        selectedSubtitleId: String?, positionUpdateInterval: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let playerId: String = self.fsPlayerId

            self.clearStaleFullscreenPresentation { [weak self] in
                guard let self = self else { return }

                guard let bridgeRoot = self.bridge?.viewController else {
                    let error: String = "No Capacitor bridge viewController available"
                    print("[CapacitorVideoPlayer] \(error)")
                    Self.logger.error("\(error, privacy: .public)")
                    call.resolve([
                        "result": false,
                        "method": "createVideoPlayerFullScreenView",
                        "message": error
                    ])
                    return
                }

                let viewController = self.topmostViewController(from: bridgeRoot)

                if Self.isPlayerPresentation(viewController) {
                    let error: String =
                        "Cannot present fullscreen player: leftover player is still presenting"
                    print("[CapacitorVideoPlayer] \(error)")
                    Self.logger.error("\(error, privacy: .public)")
                    call.resolve([
                        "result": false,
                        "method": "createVideoPlayerFullScreenView",
                        "message": error
                    ])
                    return
                }

                if viewController.presentedViewController != nil {
                    let error: String =
                        "Cannot present fullscreen player: another view controller is already presented"
                    print("[CapacitorVideoPlayer] \(error)")
                    Self.logger.error("\(error, privacy: .public)")
                    call.resolve([
                        "result": false,
                        "method": "createVideoPlayerFullScreenView",
                        "message": error
                    ])
                    return
                }

                self.resetInitialFullscreenPlaybackState()

                let errorPlayerId = playerId
                let drmAttempt = VideoDrm.open(self.drmOptions) { [weak self] error in
                    self?.notifyListeners(
                        "jeepCapVideoPlayerError",
                        data: VideoDrm.errorListenerData(fromPlayerId: errorPlayerId, error: error),
                        retainUntilConsumed: true
                    )
                }
                if drmAttempt.failureCode == VideoDrm.codeNoProvider {
                    call.resolve([
                        "result": false,
                        "method": "createVideoPlayerFullScreenView",
                        "code": VideoDrm.codeNoProvider
                    ])
                    return
                }
                let drmSession = drmAttempt.session

                let fullscreenView = self.implementation.createFullscreenPlayer(
                    playerId: playerId, videoUrl: videoUrl,
                    rate: rate, exitOnEnd: exitOnEnd, loopOnEnd: loopOnEnd,
                    pipEnabled: pipEnabled,
                    showControls: showControls,
                    displayMode: displayMode,
                    subTitleUrl: subTitleUrl,
                    language: subTitleLanguage, headers: headers, options: subTitleOptions,
                    title: title, smallTitle: smallTitle, artwork: artwork,
                    subtitleTracks: subtitleTracks,
                    selectedSubtitleId: selectedSubtitleId,
                    positionUpdateInterval: positionUpdateInterval,
                    drmSession: drmSession)
                self.videoPlayerFullScreenView = fullscreenView
                if backModeEnabled {
                    self.bgPlayer = self.videoPlayerFullScreenView?.videoPlayer.player
                }
                guard let videoPlayer: AVPlayerViewController =
                        self.videoPlayerFullScreenView?.videoPlayer else {
                    let error: String = "No videoPlayer available"
                    Self.logger.error("\(error, privacy: .public)")
                    call.resolve([
                        "result": false,
                        "method": "createVideoPlayerFullScreenView",
                        "message": error
                    ])
                    return
                }
                videoPlayer.delegate = self
                videoPlayer.entersFullScreenWhenPlaybackBegins = false
                let container = FullscreenPlayerContainerViewController(
                    playerViewController: videoPlayer)
                fullscreenView.fullscreenContainer = container
                isOpeningNativeFullscreen = true
                print("[CapacitorVideoPlayer] About to present fullscreen container playerId=\(playerId)")
                Self.logger.debug(
                    "About to present fullscreen container for playerId=\(playerId, privacy: .public)")
                viewController.present(container, animated: true, completion: {
                    print("[CapacitorVideoPlayer] fullscreen container present completion fired")
                    Self.logger.debug("fullscreen container present completion fired")
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + Self.nativeFullscreenOpenHoldSeconds) {
                        isOpeningNativeFullscreen = false
                    }
                    if let errorMessage = self.activateFullscreenAudioSessionAfterPresent() {
                        call.resolve([
                            "result": false,
                            "method": "createVideoPlayerFullScreenView",
                            "message": errorMessage
                        ])
                    } else {
                        self.videoPlayerFullScreenView?.markPresentAudioSessionActive()
                        self.isFullscreenPresentCompleted = true
                        self.startFullscreenPlaybackIfNeeded()
                        self.retryFullscreenPlaybackIfStalled(attemptsRemaining: Self.fullscreenPlaybackRetryAttempts)
                        call.resolve([
                            "result": true,
                            "method": "createVideoPlayerFullScreenView",
                            "value": true
                        ])
                    }
                })
            }
        }
    }
    // swiftlint:enable function_parameter_count
    // swiftlint:enable function_body_length

}
