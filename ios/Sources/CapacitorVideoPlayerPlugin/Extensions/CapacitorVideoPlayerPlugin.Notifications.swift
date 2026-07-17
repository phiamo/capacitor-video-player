//
//  CapacitorVideoPlayerPlugin.Notifications.swift
//  Plugin
//
//  Created by  Quéau Jean Pierre on 30/05/2021.
//  Copyright © 2021 Max Lynch. All rights reserved.
//

import Foundation
import MediaPlayer
import os

// MARK: - Handle Notifications

extension CapacitorVideoPlayerPlugin {

    // MARK: - playerItemPlay

    @objc func playerItemPlay(notification: Notification) {
        guard let info = notification.userInfo as? [String: Any] else { return }
        DispatchQueue.main.async {
            self.notifyListeners("jeepCapVideoPlayerPlay", data: info, retainUntilConsumed: true)
            return
        }
    }

    // MARK: - playerItemPause

    @objc func playerItemPause(notification: Notification) {
        guard let info = notification.userInfo as? [String: Any] else { return }
        DispatchQueue.main.async {
            self.notifyListeners("jeepCapVideoPlayerPause", data: info, retainUntilConsumed: true)
            return
        }
    }

    // MARK: - playerItemEnd

    @objc func playerItemEnd(notification: Notification) {
        guard let info = notification.userInfo as? [String: Any] else { return }
        DispatchQueue.main.async {
            self.notifyListeners("jeepCapVideoPlayerEnded", data: info, retainUntilConsumed: true)
            if self.mode == "fullscreen" {
                self.playerFullscreenExit()
            }

            return
        }
    }

    // MARK: - playerItemReady

    @objc func playerItemReady(notification: Notification) {
        guard let info = notification.userInfo as? [String: Any] else { return }
        guard let playerId = info["fromPlayerId"] as? String else { return}
        DispatchQueue.main.async {
            self.notifyListeners("jeepCapVideoPlayerReady", data: info, retainUntilConsumed: true)
            if self.mode == "fullscreen" && playerId == self.fsPlayerId {
                self.isPlayerItemReadyForInitialPlayback = true
                self.startFullscreenPlaybackIfNeeded()
            }
            return
        }
    }

    // MARK: - playerItemPositionUpdate

    @objc func playerItemPositionUpdate(notification: Notification) {
        guard let info = notification.userInfo as? [String: Any] else { return }
        if let playerId = info["fromPlayerId"] as? String {
            let ct = info["currentTime"]
            var seconds: Double = 0
            if let d = ct as? Double {
                seconds = d
            } else if let f = ct as? Float {
                seconds = Double(f)
            } else if let i = ct as? Int {
                seconds = Double(i)
            }
            let key = CapacitorVideoPlayerPlugin.lastKnownPositionKeyPrefix + playerId
            UserDefaults.standard.set(seconds, forKey: key)
        }
        DispatchQueue.main.async {
            self.notifyListeners("jeepCapVideoPlayerPositionUpdate", data: info, retainUntilConsumed: false)
            return
        }
    }

    // MARK: - playerItemSeekCompleted

    @objc func playerItemSeekCompleted(notification: Notification) {
        guard let info = notification.userInfo as? [String: Any] else { return }
        DispatchQueue.main.async {
            self.notifyListeners("jeepCapVideoPlayerSeek", data: info, retainUntilConsumed: true)
        }
    }

    // MARK: - playerItemSubtitleChange

    @objc func playerItemSubtitleChange(notification: Notification) {
        guard let info = notification.userInfo as? [String: Any] else { return }
        DispatchQueue.main.async {
            self.notifyListeners("jeepCapVideoPlayerSubtitleChange", data: info, retainUntilConsumed: true)
        }
    }

    // MARK: - Picture-in-Picture bridge events

    func notifyPictureInPictureStart() {
        var currentTime: Double = 0.0
        if let playerView = self.videoPlayerFullScreenView {
            currentTime = playerView.getRealCurrentTime()
        }
        let info: [String: Any] = [
            "fromPlayerId": self.fsPlayerId,
            "currentTime": currentTime
        ]
        DispatchQueue.main.async {
            self.notifyListeners("jeepCapVideoPlayerPipStart", data: info, retainUntilConsumed: true)
        }
    }

    func notifyPictureInPictureStop() {
        var currentTime: Double = 0.0
        if let playerView = self.videoPlayerFullScreenView {
            currentTime = playerView.getRealCurrentTime()
        }
        let info: [String: Any] = [
            "fromPlayerId": self.fsPlayerId,
            "currentTime": currentTime
        ]
        DispatchQueue.main.async {
            self.notifyListeners("jeepCapVideoPlayerPipStop", data: info, retainUntilConsumed: true)
        }
    }

    // MARK: - playerFullscreenDismiss

    @objc func playerFullscreenDismiss(notification: Notification) {
        if self.isPlayerDismissed {
            return
        }

        var currentTime: Double = 0.0
        if let playerView = self.videoPlayerFullScreenView {
            currentTime = playerView.getRealCurrentTime()
        }
        let info: [String: Any] = ["dismiss": true, "currentTime": currentTime]
        DispatchQueue.main.async {
            if self.mode == "fullscreen" {
                if let vPFSV = self.videoPlayerFullScreenView {
                    vPFSV.pause()
                }
                self.playerFullscreenExit()
            }
            self.notifyListeners("jeepCapVideoPlayerExit", data: info, retainUntilConsumed: true)
            return
        }
    }

    // MARK: - playerFullscreenExit

    func playerFullscreenExit() {
        // Mark player as dismissed to prevent further calls
        self.isPlayerDismissed = true
        
        if let vPFSV = self.videoPlayerFullScreenView {
            Self.logger.debug("Cleaning up video player on exit")
            
            // Comprehensive cleanup
            vPFSV.cleanup()
            self.terminateNowPlayingInfo()
            
            // Additional cleanup
            vPFSV.videoPlayer.player = nil
            vPFSV.player = nil
            vPFSV.playerItem = nil
            
            // Clear the reference
            self.videoPlayerFullScreenView = nil
            
            // Force memory cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                autoreleasepool {
                    // This helps with memory cleanup
                }
            }
            
            Self.logger.debug("Video player cleanup completed")
        }
        if let viewController = self.bridge?.viewController {
            viewController.dismiss(animated: true, completion: {
                if self.backModeEnabled {
                    if let audioSession = self.audioSession {
                        do {
                            try audioSession.setActive(false)
                            self.audioSession = nil
                        } catch {
                            let error: String = "playerFullscreenExit: Failed to deactivate audio session category"
                            Self.logger.error("\(error, privacy: .public)")
                        }
                    }
                }
            })
        }
    }

    private func terminateNowPlayingInfo() {
        if let vPFSV = self.videoPlayerFullScreenView {
            if let token = vPFSV.periodicTimeObserver {
                vPFSV.player?.removeTimeObserver(token)
                vPFSV.periodicTimeObserver = nil
            }
            let rcc = MPRemoteCommandCenter.shared()
            rcc.changePlaybackPositionCommand.isEnabled = false
            rcc.playCommand.isEnabled = false
            rcc.pauseCommand.isEnabled = false
            rcc.skipForwardCommand.isEnabled = false
            rcc.skipBackwardCommand.isEnabled = false
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
    }

}
