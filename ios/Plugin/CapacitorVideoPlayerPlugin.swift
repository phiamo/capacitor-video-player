import Foundation
import Capacitor
import AVKit
import UIKit

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(CapacitorVideoPlayerPlugin)
// swiftlint:disable file_length
// swiftlint:disable type_body_length
public class CapacitorVideoPlayerPlugin: CAPPlugin {
    public var call: CAPPluginCall?
    public var videoPlayer: AVPlayerViewController?
    public var bgPlayer: AVPlayer?
    public let implementation = CapacitorVideoPlayer()
    var videoPlayerFullScreenView: FullScreenVideoPlayerView?
    var audioSession: AVAudioSession?
    var mode: String?
    var exitOnEnd: Bool = true
    var loopOnEnd: Bool = false
    var pipEnabled: Bool = true
    var backModeEnabled: Bool = true
    var showControls: Bool = true
    var displayMode: String = "all"
    var headers: [String: String]?
    var title: String?
    var smallTitle: String?
    var artwork: String?
    var fsPlayerId: String = "fullscreen"
    var videoRate: Float = 1.0
    var playObserver: Any?
    var pauseObserver: Any?
    var endObserver: Any?
    var readyObserver: Any?
    var fsDismissObserver: Any?
    var backgroundObserver: Any?
    var foregroundObserver: Any?
    var vpInternalObserver: Any?
    var isPlayerDismissed: Bool = false
    let rateList: [Float] = [0.25, 0.5, 0.75, 1.0, 2.0, 4.0]

    override public func load() {
        self.addObserversToNotificationCenter()
        if (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad),
           #available(iOS 13.0, *) {
            isPIPModeAvailable = true
        } else if #available(iOS 14.0, *) {
            isPIPModeAvailable = true
        }
    }
    deinit {
        print("🗑️ CapacitorVideoPlayerPlugin deinit called")
        
        // Clean up video player references
        self.videoPlayerFullScreenView = nil
        self.videoPlayer = nil
        self.bgPlayer = nil
        self.audioSession = nil
        
        // Clean up notification observers
        NotificationCenter.default.removeObserver(playObserver as Any)
        NotificationCenter.default.removeObserver(pauseObserver as Any)
        NotificationCenter.default.removeObserver(endObserver as Any)
        NotificationCenter.default.removeObserver(readyObserver as Any)
        NotificationCenter.default.removeObserver(fsDismissObserver as Any)
        NotificationCenter.default.removeObserver(backgroundObserver as Any)
        NotificationCenter.default.removeObserver(foregroundObserver as Any)
        NotificationCenter.default.removeObserver(vpInternalObserver as Any)
        
        // Clear observer references
        self.playObserver = nil
        self.pauseObserver = nil
        self.endObserver = nil
        self.readyObserver = nil
        self.fsDismissObserver = nil
        self.backgroundObserver = nil
        self.foregroundObserver = nil
        self.vpInternalObserver = nil
        
        print("✅ Plugin cleanup completed")
    }

    @objc func echo(_ call: CAPPluginCall) {
        let value = call.getString("value") ?? ""
        call.resolve([
            "value": implementation.echo(value)
        ])
    }

    // MARK: - Init player(s)

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    @objc func initPlayer(_ call: CAPPluginCall) {
        self.call = call
        
        // Reset dismissal state for new player
        self.isPlayerDismissed = false
        
        guard let mode = call.options["mode"] as? String else {
            let error: String = "Must provide a Mode " +
                "(fullscreen/embedded)"
            call.resolve([ "result": false, "method": "initPlayer",
                           "message": error])

            return
        }
        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a PlayerId"
            call.resolve([ "result": false, "method": "initPlayer",
                           "message": error])
            return
        }
        var mRate: Float = 1.0
        if let sRate = call.options["rate"] as? Float {
            if rateList.contains(sRate) {
                mRate = sRate
            }
        }
        var exitOnEnd: Bool = true
        if let sexitOnEnd = call.options["exitOnEnd"] as? Bool {
            exitOnEnd = sexitOnEnd
        }
        var loopOnEnd: Bool = false
        if let sloopOnEnd = call.options["loopOnEnd"] as? Bool {
            if !exitOnEnd {
                loopOnEnd = sloopOnEnd
            }
        }
        var headers: [String: String]?
        if let sheaders = call.options["headers"] as? [String: String] {
            headers = sheaders
        }
        var pipEnabled: Bool = true
        if let spipEnabled = call.options["pipEnabled"] as? Bool {
            pipEnabled = spipEnabled
        }
        var bkModeEnabled: Bool = true
        if let sbkModeEnabled = call.options["bkmodeEnabled"] as? Bool {
            bkModeEnabled = sbkModeEnabled
        }
        var shControls: Bool = true
        if let shoControls = call.options["showControls"] as? Bool {
            shControls = shoControls
        }
        var disMode: String = "all"
        if let dispMode = call.options["displayMode"] as? String {
            disMode = dispMode
        }
        var title: String?
        if let stitle = call.options["title"] as? String {
            title = stitle
        }
        var smallTitle: String?
        if let ssmallTitle = call.options["smallTitle"] as? String {
            smallTitle = ssmallTitle
        }
        var artwork: String?
        if let sartwork = call.options["artwork"] as? String {
            artwork = sartwork
        }
        self.fsPlayerId = playerId
        self.mode = mode
        self.videoRate = mRate
        self.exitOnEnd = exitOnEnd
        self.loopOnEnd = loopOnEnd
        self.pipEnabled = pipEnabled
        self.headers = headers
        if !self.pipEnabled {isPIPModeAvailable = false}
        self.backModeEnabled = bkModeEnabled
        self.showControls = shControls
        self.displayMode = disMode
        self.title = title
        self.smallTitle = smallTitle
        self.artwork = artwork
        if mode == "fullscreen" {
            guard let videoPath = call.options["url"] as? String else {
                let error: String = "Must provide a video url"
                print(error)
                call.resolve([ "result": false, "method": "initPlayer", "message": error])
                return
            }
            // Handle subtitle tracks (new API with backward compatibility)
            var subtitleTracks: [[String: Any]] = []
            var selectedSubtitleId: String? = nil
            
            if let subtitlesArray = call.options["subtitles"] as? [[String: Any]] {
                // New API: multiple subtitle tracks
                subtitleTracks = subtitlesArray
            } else if let stPath = call.options["subtitle"] as? String {
                // Backward compatibility: single subtitle
                print("[CapacitorVideoPlayer] The 'subtitle' option is deprecated. Use 'subtitles' array instead.")
                let stLanguage = call.options["language"] as? String ?? "en"
                let track: [String: Any] = [
                    "id": stLanguage,
                    "url": stPath,
                    "language": stLanguage,
                    "label": stLanguage,
                    "isDefault": true
                ]
                subtitleTracks = [track]
            }
            
            // Get selected subtitle ID
            if let selectedId = call.options["selectedSubtitleId"] as? String {
                selectedSubtitleId = selectedId
            } else if !subtitleTracks.isEmpty {
                // Find default track or use first track
                for track in subtitleTracks {
                    if let isDefault = track["isDefault"] as? Bool, isDefault {
                        selectedSubtitleId = track["id"] as? String
                        break
                    }
                }
                if selectedSubtitleId == nil {
                    selectedSubtitleId = subtitleTracks[0]["id"] as? String
                }
            }
            
            // Legacy single subtitle for backward compatibility
            var subTitlePath: String = ""
            var subTitleLanguage: String = ""
            if !subtitleTracks.isEmpty {
                let firstTrack = subtitleTracks[0]
                subTitlePath = firstTrack["url"] as? String ?? ""
                subTitleLanguage = firstTrack["language"] as? String ?? ""
            }

            let subTitleOptions: [String: Any] = call.getObject("subtitleOptions") ?? [:]

            if videoPath == "internal" {
                DispatchQueue.main.async { [weak self] in
                    if let videoPickerViewController =
                        self?.implementation.pickVideoFromInternal(
                            rate: self?.videoRate ?? 1.0,
                            exitOnEnd: self?.exitOnEnd ?? true,
                            loopOnEnd: self?.loopOnEnd ?? false,
                            pipEnabled: self?.pipEnabled ?? true,
                            backModeEnabled: self?.backModeEnabled ?? true,
                            showControls: self?.showControls ?? true,
                            displayMode: self?.displayMode ?? "all") {
                        self?.bridge?.viewController?.present(
                            videoPickerViewController,
                            animated: true, completion: {return})
                    }
                }

            } else {
                let dictUrl: [String: Any] =
                    getURLFromFilePath(filePath: videoPath)
                if let message = dictUrl["message"] as? String {
                    if message.count > 0 {
                        call.resolve([ "result": false, "method": "initPlayer",
                                       "message": message])
                        return
                    }
                }
                guard let url = dictUrl["url"] as? URL else {
                    call.resolve([ "result": false, "method": "initPlayer",
                                   "message": "url not defined"])
                    return
                }
                var subTitle: URL?
                if subTitlePath.count > 0 {

                    let dictSubTitle: [String: Any] =
                        getURLFromFilePath(filePath: subTitlePath)
                    if let message = dictSubTitle["message"] as? String {
                        if message.count > 0 {
                            call.resolve([ "result": false, "method": "initPlayer",
                                           "message": message])
                            return
                        }
                    }
                    guard let sturl = dictSubTitle["url"] as? URL else {
                        call.resolve([ "result": false, "method": "initPlayer",
                                       "message": "subtitle url not defined"])
                        return
                    }
                    subTitle = sturl
                }
                guard let call = self.call else { return }
                self.createVideoPlayerFullscreenView(
                    call: call, videoUrl: url, rate: videoRate,
                    exitOnEnd: exitOnEnd, loopOnEnd: loopOnEnd,
                    pipEnabled: pipEnabled,
                    backModeEnabled: backModeEnabled,
                    showControls: showControls,
                    displayMode: displayMode,
                    subTitleUrl: subTitle,
                    subTitleLanguage: subTitleLanguage,
                    subTitleOptions: subTitleOptions,
                    headers: headers,
                    title: title,
                    smallTitle: smallTitle,
                    artwork: artwork,
                    subtitleTracks: subtitleTracks,
                    selectedSubtitleId: selectedSubtitleId)

            }
        } else {
            call.resolve([ "result": false,
                           "method": "initPlayer",
                           "message": "Not implemented"])
            return
        }
    }
    // swiftlint:enable function_body_length
    // swiftlint:enable cyclomatic_complexity

    // MARK: - Play the given player

    @objc func isPlaying(_ call: CAPPluginCall) {
        self.call = call
        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a playerId"
            print(error)
            call.resolve([ "result": false, "method": "isPlaying", "message": error])
            return
        }
        if self.mode == "fullscreen" && self.fsPlayerId == playerId {

            if let playerView = self.videoPlayerFullScreenView {
                DispatchQueue.main.async {
                    let isPlaying: Bool = playerView.isPlaying
                    call.resolve([ "result": true, "method": "isPlaying", "value": isPlaying])
                    return
                }
            } else {
                let error: String = "Fullscreen player not found"
                print(error)
                call.resolve([ "result": false, "method": "isPlaying", "message": error])
                return
            }
        }
    }
    // MARK: - Play the given player

    @objc func play(_ call: CAPPluginCall) {
        self.call = call
        
        // Check if player has been dismissed
        if self.isPlayerDismissed {
            let error: String = "Player has been dismissed"
            print("⚠️ \(error) - ignoring play call")
            call.resolve([ "result": false, "method": "play", "message": error])
            return
        }
        
        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a playerId"
            print(error)
            call.resolve([ "result": false, "method": "play", "message": error])
            return
        }
        if self.mode == "fullscreen" && self.fsPlayerId == playerId {

            if let playerView = self.videoPlayerFullScreenView {
                DispatchQueue.main.async {
                    playerView.play()
                    call.resolve([ "result": true, "method": "play", "value": true])
                    return
                }
            } else {
                let error: String = "Fullscreen player not found"
                print(error)
                call.resolve([ "result": false, "method": "play", "message": error])
                return
            }
        }
    }

    // MARK: - Pause the given player

    @objc func pause(_ call: CAPPluginCall) {
        self.call = call
        
        // Check if player has been dismissed
        if self.isPlayerDismissed {
            let error: String = "Player has been dismissed"
            print("⚠️ \(error) - ignoring pause call")
            call.resolve([ "result": false, "method": "pause", "message": error])
            return
        }

        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a playerId"
            print(error)
            call.resolve([ "result": false, "method": "pause", "message": error])
            return
        }
        if self.mode == "fullscreen" && self.fsPlayerId == playerId {
            if let playerView = self.videoPlayerFullScreenView {
                DispatchQueue.main.async {
                    playerView.pause()
                    call.resolve([ "result": true, "method": "pause", "value": true])
                    return
                }
            } else {
                let error: String = "Fullscreen player not found"
                print(error)
                call.resolve([ "result": false, "method": "pause", "message": error])
                return
            }
        }
    }

    // MARK: - get Duration for the given player

    @objc func getDuration(_ call: CAPPluginCall) {
        self.call = call

        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a playerId"
            print(error)
            call.resolve([ "result": false, "method": "getDuration", "message": error])
            return
        }
        if self.mode == "fullscreen" && self.fsPlayerId == playerId {
            if let playerView = self.videoPlayerFullScreenView {
                DispatchQueue.main.async {
                    let duration: Double = playerView.getDuration()
                    call.resolve([ "result": true, "method": "getDuration", "value": duration])
                    return
                }
            } else {
                let error: String = "Fullscreen playerId not found"
                print(error)
                call.resolve([ "result": false, "method": "getDuration", "message": error])
                return
            }
        }
    }

    // MARK: - get CurrentTime for the given player

    @objc func getCurrentTime(_ call: CAPPluginCall) {
        self.call = call

        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a playerId"
            print(error)
            call.resolve([ "result": false, "method": "getCurrentTime", "message": error])
            return
        }
        
        // Check if player has been dismissed
        if self.isPlayerDismissed {
            let error: String = "Player has been dismissed"
            print("⚠️ \(error) - ignoring getCurrentTime call")
            call.resolve([ "result": false, "method": "getCurrentTime", "message": error])
            return
        }
        
        if self.mode == "fullscreen" && self.fsPlayerId == playerId {
            if let playerView = self.videoPlayerFullScreenView {
                DispatchQueue.main.async {
                    let currentTime: Double = playerView.getCurrentTime()
                    call.resolve([ "result": true, "method": "getCurrentTime",
                                   "value": currentTime])
                    return
                }
            } else {
                let error: String = "Fullscreen playerId not found"
                print("⚠️ \(error) - player may have been dismissed")
                call.resolve([ "result": false, "method": "getCurrentTime", "message": error])
                return
            }

        }
    }

    // MARK: - set CurrentTime for the given player

    @objc func setCurrentTime(_ call: CAPPluginCall) {
        self.call = call
        
        // Check if player has been dismissed
        if self.isPlayerDismissed {
            let error: String = "Player has been dismissed"
            print("⚠️ \(error) - ignoring setCurrentTime call")
            call.resolve([ "result": false, "method": "setCurrentTime", "message": error])
            return
        }

        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a playerId"
            print(error)
            call.resolve([ "result": false, "method": "setCurrentTime", "message": error])
            return
        }
        guard let seekTime = call.options["seektime"] as? Double else {
            let error: String = "Must provide a time in second"
            print(error)
            call.resolve([ "result": false, "method": "setCurrentTime", "message": error])
            return
        }
        if self.mode == "fullscreen" && self.fsPlayerId == playerId {
            if let playerView = self.videoPlayerFullScreenView {
                DispatchQueue.main.async {
                    playerView.setCurrentTime(time: seekTime)
                    call.resolve([ "result": true, "method": "setCurrentTime",
                                   "value": seekTime])
                    return
                }
            } else {
                let error: String = "Fullscreen playerId not found"
                print(error)
                call.resolve([ "result": false, "method": "setCurrentTime", "message": error])
                return
            }
        }
    }

    // MARK: - get Volume for the given player

    @objc func getVolume(_ call: CAPPluginCall) {
        self.call = call

        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a playerId"
            print(error)
            call.resolve([ "result": false, "method": "getVolume", "message": error])
            return
        }
        if self.mode == "fullscreen" && self.fsPlayerId == playerId {
            if let playerView = self.videoPlayerFullScreenView {
                DispatchQueue.main.async {
                    let volume: Float = playerView.getVolume()
                    call.resolve([ "result": true, "method": "getVolume", "value": volume])
                    return
                }
            } else {
                let error: String = "Fullscreen playerId not found"
                print(error)
                call.resolve([ "result": false, "method": "getVolume", "message": error])
                return
            }
        }
    }

    // MARK: - set Volume for the given player

    @objc func setVolume(_ call: CAPPluginCall) {
        self.call = call

        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a playerId"
            print(error)
            call.resolve([ "result": false, "method": "setVolume", "message": error])
            return
        }
        guard let volume = call.options["volume"] as? Float else {
            let error: String = "Must provide a volume value"
            print(error)
            call.resolve([ "result": false, "method": "setVolume", "message": error])

            return
        }
        if self.mode == "fullscreen" && self.fsPlayerId == playerId {
            if let playerView = self.videoPlayerFullScreenView {
                DispatchQueue.main.async {
                    playerView.setVolume(volume: volume)
                    call.resolve([ "result": true, "method": "setVolume", "value": volume])
                    return
                }
            } else {
                let error: String = "Fullscreen playerId not found"
                print(error)
                call.resolve([ "result": false, "method": "setVolume", "message": error])
                return
            }
        }

    }

    // MARK: - get Muted for the given player

    @objc func getMuted(_ call: CAPPluginCall) {
        self.call = call

        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a playerId"
            print(error)
            call.resolve([ "result": false, "method": "getMuted", "message": error])
            return
        }
        if self.mode == "fullscreen" && self.fsPlayerId == playerId {
            if let playerView = self.videoPlayerFullScreenView {
                DispatchQueue.main.async {
                    let muted: Bool = playerView.getMuted()
                    call.resolve([ "result": true, "method": "getMuted", "value": muted])
                    return
                }
            } else {
                let error: String = "Fullscreen playerId not found"
                print(error)
                call.resolve([ "result": false, "method": "getMuted", "message": error])
                return
            }
        }
    }

    // MARK: - set Muted for the given player

    @objc func setMuted(_ call: CAPPluginCall) {
        self.call = call

        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a playerId"
            print(error)
            call.resolve([ "result": false, "method": "setMuted", "message": error])
            return
        }
        guard let muted = call.options["muted"] as? Bool else {
            let error: String = "Must provide a boolean true/false"
            print(error)
            call.resolve([ "result": false, "method": "setMuted", "message": error])
            return
        }
        if self.mode == "fullscreen" && self.fsPlayerId == playerId {
            if let playerView = self.videoPlayerFullScreenView {
                DispatchQueue.main.async {
                    playerView.setMuted(muted: muted)
                    call.resolve([ "result": true, "method": "setMuted", "value": muted])
                    return
                }
            } else {
                let error: String = "Fullscreen playerId not found"
                print(error)
                call.resolve([ "result": false, "method": "setMuted", "message": error])
                return
            }
        }
    }

    // MARK: - Stop all player(s) playing

    @objc func stopAllPlayers(_ call: CAPPluginCall) {
        self.call = call
        if self.mode == "fullscreen" {
            if let playerView = self.videoPlayerFullScreenView {
                DispatchQueue.main.async {
                    if playerView.isPlaying {
                        playerView.pause()
                    }
                    call.resolve([ "result": true, "method": "stopAllPlayers", "value": true])
                    return
                }
            } else {
                let error: String = "Fullscreen player not found"
                print(error)
                call.resolve([ "result": false, "method": "stopAllPlayers", "message": error])
                return
            }

        }
    }

    // MARK: - get Rate for the given player

    @objc func getRate(_ call: CAPPluginCall) {
        self.call = call

        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a playerId"
            print(error)
            call.resolve([ "result": false, "method": "getRate", "message": error])
            return
        }
        if self.mode == "fullscreen" && self.fsPlayerId == playerId {
            if let playerView = self.videoPlayerFullScreenView {
                DispatchQueue.main.async {
                    let rate: Float = playerView.getRate()
                    call.resolve([ "result": true, "method": "getRate", "value": rate])
                    return
                }
            } else {
                let error: String = "Fullscreen playerId not found"
                print(error)
                call.resolve([ "result": false, "method": "getRate", "message": error])
                return
            }
        }
    }

    // MARK: - set Rate for the given player

    @objc func setRate(_ call: CAPPluginCall) {
        self.call = call

        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a playerId"
            print(error)
            call.resolve([ "result": false, "method": "setRate", "message": error])
            return
        }
        guard let rate = call.options["rate"] as? Float else {
            let error: String = "Must provide a rate value"
            print(error)
            call.resolve([ "result": false, "method": "setRate", "message": error])

            return
        }
        self.videoRate = rateList.contains(rate) ? rate : 1.0

        if self.mode == "fullscreen" && self.fsPlayerId == playerId {
            if let playerView = self.videoPlayerFullScreenView {
                //34567890123456789012345678901234567890
                DispatchQueue.main.async {
                    playerView.setRate(rate: self.videoRate)
                    call.resolve([ "result": true, "method": "setRate",
                                   "value": self.videoRate])
                    return
                }
            } else {
                let error: String = "Fullscreen playerId not found"
                print(error)
                call.resolve([ "result": false, "method": "setRate", "message": error])
                return
            }
        }

    }

    @objc func exitFullScreen(_ call: CAPPluginCall) {
        self.call = call
        
        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a playerId"
            print(error)
            call.resolve([ "result": false, "method": "exitFullScreen", "message": error])
            return
        }
        
        if self.mode == "fullscreen" && self.fsPlayerId == playerId {
            if let playerView = self.videoPlayerFullScreenView {
                DispatchQueue.main.async {
                    // Pause the video if it's playing
                    if playerView.isPlaying {
                        playerView.pause()
                    }
                    
                    // Use the existing notification system to trigger proper cleanup
                    NotificationCenter.default.post(name: .playerFullscreenDismiss, object: nil)
                    
                    // Resolve the call with success
                    call.resolve([ "result": true, "method": "exitFullScreen", "value": true])
                }
            } else {
                let error: String = "Fullscreen player not found"
                print(error)
                call.resolve([ "result": false, "method": "exitFullScreen", "message": error])
                return
            }
        } else {
            let error: String = "Invalid player mode or playerId mismatch"
            print(error)
            call.resolve([ "result": false, "method": "exitFullScreen", "message": error])
            return
        }
    }

    // MARK: - Subtitle Track Management

    @objc func getSubtitleTracks(_ call: CAPPluginCall) {
        self.call = call
        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a playerId"
            print(error)
            call.resolve([ "result": false, "method": "getSubtitleTracks", "message": error])
            return
        }
        if self.mode == "fullscreen" && self.fsPlayerId == playerId {
            if let playerView = self.videoPlayerFullScreenView {
                DispatchQueue.main.async {
                    if let tracks = playerView.getSubtitleTracks() {
                        call.resolve([ "result": true, "method": "getSubtitleTracks", "value": tracks])
                    } else {
                        call.resolve([ "result": false, "method": "getSubtitleTracks", "message": "No tracks available"])
                    }
                }
            } else {
                call.resolve([ "result": false, "method": "getSubtitleTracks", "message": "Fullscreen player not found"])
            }
        } else {
            call.resolve([ "result": false, "method": "getSubtitleTracks", "message": "Invalid player mode or playerId mismatch"])
        }
    }

    @objc func selectSubtitleTrack(_ call: CAPPluginCall) {
        self.call = call
        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a playerId"
            print(error)
            call.resolve([ "result": false, "method": "selectSubtitleTrack", "message": error])
            return
        }
        let trackId = call.options["trackId"] as? String
        if self.mode == "fullscreen" && self.fsPlayerId == playerId {
            if let playerView = self.videoPlayerFullScreenView {
                DispatchQueue.main.async {
                    playerView.selectSubtitleTrack(trackId: trackId)
                    call.resolve([ "result": true, "method": "selectSubtitleTrack", "value": trackId ?? NSNull()])
                }
            } else {
                call.resolve([ "result": false, "method": "selectSubtitleTrack", "message": "Fullscreen player not found"])
            }
        } else {
            call.resolve([ "result": false, "method": "selectSubtitleTrack", "message": "Invalid player mode or playerId mismatch"])
        }
    }

    @objc func disableSubtitles(_ call: CAPPluginCall) {
        selectSubtitleTrack(call)
    }

    @objc func getSelectedSubtitleTrack(_ call: CAPPluginCall) {
        self.call = call
        guard let playerId = call.options["playerId"] as? String else {
            let error: String = "Must provide a playerId"
            print(error)
            call.resolve([ "result": false, "method": "getSelectedSubtitleTrack", "message": error])
            return
        }
        if self.mode == "fullscreen" && self.fsPlayerId == playerId {
            if let playerView = self.videoPlayerFullScreenView {
                DispatchQueue.main.async {
                    let trackId = playerView.getSelectedSubtitleTrack()
                    call.resolve([ "result": true, "method": "getSelectedSubtitleTrack", "value": trackId ?? NSNull()])
                }
            } else {
                call.resolve([ "result": false, "method": "getSelectedSubtitleTrack", "message": "Fullscreen player not found"])
            }
        } else {
            call.resolve([ "result": false, "method": "getSelectedSubtitleTrack", "message": "Invalid player mode or playerId mismatch"])
        }
    }
}

// swiftlint:enable type_body_length
// swiftlint:enable file_length