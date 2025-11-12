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

extension CapacitorVideoPlayerPlugin {

    // MARK: - createVideoPlayerFullScreenView

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
        selectedSubtitleId: String?) {
        DispatchQueue.main.async { [weak self] in
            print("🎬 createVideoPlayerFullscreenView called")
            let playerId: String = self?.fsPlayerId ?? "fullscreen"
            print("   Player ID: \(playerId)")
            print("   Video URL: \(videoUrl.absoluteString)")
            print("   Subtitle tracks count: \(subtitleTracks?.count ?? 0)")
            
            let fullscreenView = self?.implementation
                .createFullscreenPlayer(
                    playerId: playerId, videoUrl: videoUrl,
                    rate: rate, exitOnEnd: exitOnEnd, loopOnEnd: loopOnEnd,
                    pipEnabled: pipEnabled,
                    showControls: showControls,
                    displayMode: displayMode,
                    subTitleUrl: subTitleUrl,
                    language: subTitleLanguage, headers: headers, options: subTitleOptions,
                    title: title, smallTitle: smallTitle, artwork: artwork,
                    subtitleTracks: subtitleTracks,
                    selectedSubtitleId: selectedSubtitleId)
            
            print("   FullscreenView created: \(fullscreenView != nil)")
            
            if let fullscreenView = fullscreenView {
                print("   ✅ FullscreenView is not nil")
                self?.videoPlayerFullScreenView = fullscreenView
                print("   ✅ videoPlayerFullScreenView assigned")
                
                if backModeEnabled {
                    self?.bgPlayer = self?.videoPlayerFullScreenView?
                        .videoPlayer.player
                }
                
                print("   Checking videoPlayer...")
                print("   videoPlayerFullScreenView?.videoPlayer: \(fullscreenView.videoPlayer)")
                
                guard let videoPlayer: AVPlayerViewController =
                        self?.videoPlayerFullScreenView?.videoPlayer else {
                    let error: String = "No videoPlayer available"
                    print("   ❌ ERROR: \(error)")
                    print("   videoPlayerFullScreenView is nil: \(self?.videoPlayerFullScreenView == nil)")
                    print("   videoPlayerFullScreenView?.videoPlayer is nil: \(self?.videoPlayerFullScreenView?.videoPlayer == nil)")
                    call.resolve([ "result": false, "method": "createVideoPlayerFullScreenView",
                                   "message": error])
                    return
                }
                
                print("   ✅ videoPlayer is available")
                print("   ✅ Setting delegate...")
                videoPlayer.delegate = self
                
                print("   ✅ Presenting video player...")
                print("   bridge?.viewController: \(self?.bridge?.viewController != nil)")
                
                guard let viewController = self?.bridge?.viewController else {
                    let error: String = "No view controller available for presentation"
                    print("   ❌ ERROR: \(error)")
                    call.resolve([ "result": false, "method": "createVideoPlayerFullScreenView",
                                   "message": error])
                    return
                }
                
                viewController.present(
                    videoPlayer, animated: true, completion: {
                        print("   ✅ Video player presentation completed")
                        if backModeEnabled {
                            // add audio session
                            self?.audioSession = AVAudioSession.sharedInstance()
                            // Set the audio session category, mode, and options.
                            do {
                                try self?.audioSession?
                                    .setCategory(.playback,
                                                 mode: .moviePlayback,
                                                 options: [])
                                try self?.audioSession?.setActive(true)
                                call.resolve([
                                                "result": true,
                                                "method": "createVideoPlayerFullScreenView",
                                                "value": true])
                                return
                            } catch let error as NSError {
                                print("Unable to activate audio session:  \(error.localizedDescription)")
                                call.resolve([
                                                "result": false,
                                                "method": "createVideoPlayerFullScreenView",
                                                "message": error.localizedDescription])
                                return
                            }
                        } else {
                            call.resolve([
                                            "result": true,
                                            "method": "createVideoPlayerFullScreenView",
                                            "value": true])
                            return
                        }
                    })

            }
        }
    }
    // swiftlint:enable function_parameter_count
    // swiftlint:enable function_body_length

}
