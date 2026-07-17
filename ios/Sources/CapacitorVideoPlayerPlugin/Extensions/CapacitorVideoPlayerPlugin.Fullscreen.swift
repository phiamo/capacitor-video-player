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

    // MARK: - topmostViewController

    /// Walks the bridge hierarchy to find the VC that should receive `present()`.
    private func topmostViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
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

        if bridgeRoot.presentedViewController != nil {
            print("[CapacitorVideoPlayer] Dismissing stale modal before new fullscreen player")
            Self.logger.debug("Dismissing stale presented view controller before new fullscreen player")
            bridgeRoot.dismiss(animated: false) {
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
                    positionUpdateInterval: positionUpdateInterval)
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
                isOpeningNativeFullscreen = true
                print("[CapacitorVideoPlayer] About to present AVPlayerViewController playerId=\(playerId)")
                Self.logger.debug(
                    "About to present AVPlayerViewController for playerId=\(playerId, privacy: .public)")
                viewController.present(videoPlayer, animated: true, completion: {
                    print("[CapacitorVideoPlayer] AVPlayerViewController present completion fired")
                    Self.logger.debug("AVPlayerViewController present completion fired")
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                            guard let self = self else { return }
                            if (self.videoPlayerFullScreenView?.player?.rate ?? 0) == 0 {
                                self.initialFullscreenPlaybackStarted = false
                                self.videoPlayerFullScreenView?.markPresentAudioSessionActive()
                                self.startFullscreenPlaybackIfNeeded()
                            }
                        }
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
