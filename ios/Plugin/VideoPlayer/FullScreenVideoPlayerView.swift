//
//  FullScreenVideoPlayerView.swift
//  Plugin
//
//  Created by  Quéau Jean Pierre on 13/01/2020.
//  Copyright © 2021 Max Lynch. All rights reserved.
//

import UIKit
import AVKit
import MediaPlayer
import AVPlayerViewControllerSubtitles

// swiftlint:disable file_length
// swiftlint:disable type_body_length
open class FullScreenVideoPlayerView: UIView {
    private var _url: URL
    private var _isReadyToPlay: Bool = false
    private var _videoId: String = "fullscreen"
    private var _currentTime: Double = 0
    private var _duration: Double = 0
    private var _isLoaded: [String: Bool] = [:]
    private var _isBufferEmpty: [String: Bool] = [:]
    private var _exitOnEnd: Bool = true
    private var _loopOnEnd: Bool = false
    private var _pipEnabled: Bool = true
    private var _firstReadyToPlay: Bool = true
    private var _stUrl: URL?
    private var _stLanguage: String?
    private var _stHeaders: [String: String]?
    private var _stOptions: [String: Any]?
    private var _videoRate: Float
    private var _showControls: Bool = true
    private var _displayMode: String = "all"
    private var _title: String?
    private var _smallTitle: String?
    private var _artwork: String?

    var player: AVPlayer?
    var videoPlayer: AVPlayerViewController
    var videoAsset: AVURLAsset
    var playerItem: AVPlayerItem?
    var isPlaying: Bool
    var itemBufferObserver: NSKeyValueObservation?
    var itemStatusObserver: NSKeyValueObservation?
    var playerRateObserver: NSKeyValueObservation?
    var videoPlayerFrameObserver: NSKeyValueObservation?
    var videoPlayerMoveObserver: NSKeyValueObservation?
    var periodicTimeObserver: Any?
    var subtitleTimeObserver: Any?

    private var _subtitleTracks: [[String: Any]]?
    private var _selectedSubtitleId: String?
    private var _activeSubtitleTrackId: String?
    private var subtitleTracksData: [String: [(start: Double, end: Double, text: String)]] = [:]
    private var subtitleLabel: UILabel?

    init(url: URL, rate: Float, playerId: String, exitOnEnd: Bool,
         loopOnEnd: Bool, pipEnabled: Bool, showControls: Bool,
         displayMode: String, stUrl: URL?, stLanguage: String?,
         stHeaders: [String: String]?, stOptions: [String: Any]?,
         title: String?, smallTitle: String?, artwork: String?,
         subtitleTracks: [[String: Any]]?,
         selectedSubtitleId: String?) {
        //self._videoPath = videoPath
        self._url = url
        // Handle multiple subtitle tracks or backward compatibility
        if let tracks = subtitleTracks, !tracks.isEmpty {
            self._subtitleTracks = tracks
            self._selectedSubtitleId = selectedSubtitleId
            // Set first track URL for backward compatibility
            if let firstTrack = tracks[0]["url"] as? String {
                self._stUrl = URL(string: firstTrack)
            }
            if let firstLanguage = tracks[0]["language"] as? String {
                self._stLanguage = firstLanguage
            }
        } else {
            self._stUrl = stUrl
            self._stLanguage = stLanguage
        }
        self._stOptions = stOptions
        self._exitOnEnd = exitOnEnd
        self._loopOnEnd = loopOnEnd
        self._pipEnabled = pipEnabled
        self._videoId = playerId
        self._videoRate = rate
        self._stHeaders = stHeaders
        self._displayMode = displayMode
        self.videoPlayer = AllOrientationAVPlayerController()
        if displayMode == "landscape" {
            self.videoPlayer = LandscapeAVPlayerController()
        }
        if displayMode == "portrait" {
            self.videoPlayer = PortraitAVPlayerController()
        }
        self._showControls = showControls
        self._title = title
        self._smallTitle = smallTitle
        self._artwork = artwork

        if let headers = self._stHeaders {
            self.videoAsset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        } else {
            self.videoAsset = AVURLAsset(url: url)
        }

        self.isPlaying = false
        super.init(frame: .zero)
        self.initialize()
        self.addObservers()
    }

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
  private func initialize() {
      // Handle multiple subtitle tracks or single subtitle
      if let tracks = _subtitleTracks, !tracks.isEmpty {
          // New API: multiple subtitle tracks
          let isHLSStream = self.isHLSStream(url: self._url)
          if isHLSStream {
              // For HLS, load all tracks and set up player
              self.loadAllSubtitleTracksForHLS()
          } else {
              // For non-HLS, use first track for backward compatibility
              if let firstTrackUrl = tracks[0]["url"] as? String,
                 let url = URL(string: firstTrackUrl) {
                  self.loadVideoAssetWithSubtitles(subTitleUrl: url)
              } else {
                  // No valid subtitle URL, use simple player
                  self.playerItem = AVPlayerItem(asset: self.videoAsset)
                  self.player = AVPlayer(playerItem: self.playerItem)
                  self.setupPlayer()
              }
          }
      } else if let subTitleUrl = self._stUrl {
          // Backward compatibility: single subtitle
          // For HLS streams, we need to load the asset asynchronously
          print("Loading HLS stream: \(self._url)")
          
          // Load the asset asynchronously first
          self.videoAsset.loadValuesAsynchronously(forKeys: ["tracks", "duration"]) {
              DispatchQueue.main.async {
                  print("HLS stream loaded. Tracks count: \(self.videoAsset.tracks.count)")
                  
                  // For HLS streams, tracks might not be immediately available
                  // Check if this is an HLS stream by URL extension or content type
                  let isHLSStream = self.isHLSStream(url: self._url)
                  
                  if isHLSStream {
                      print("HLS stream detected - proceeding with player setup")
                      print("HLS stream URL: \(self._url.absoluteString)")
                      print("HLS stream tracks available: \(self.videoAsset.tracks.count)")
                      // For HLS streams, proceed with player setup even if tracks aren't immediately available
                      // The tracks will be loaded when the player item becomes ready
                      self.loadVideoAssetWithSubtitles(subTitleUrl: subTitleUrl)
                  } else {
                      // For non-HLS streams, check for video tracks
                  let videoTracks = self.videoAsset.tracks(withMediaType: AVMediaType.video)
                  guard !videoTracks.isEmpty else {
                          print("No video tracks found in non-HLS stream - using simple player")
                      self.playerItem = AVPlayerItem(asset: self.videoAsset)
                      self.player = AVPlayer(playerItem: self.playerItem)
                      self.setupPlayer()
                      return
                  }
                  
                  // Continue with subtitle logic only after HLS is loaded
                  self.loadVideoAssetWithSubtitles(subTitleUrl: subTitleUrl)
                  }
              }
          }
      } else {
          // No subtitles, use simple player
          self.playerItem = AVPlayerItem(asset: self.videoAsset)
          self.player = AVPlayer(playerItem: self.playerItem)
          self.setupPlayer()
      }
  }
    
    private func loadVideoAssetWithSubtitles(subTitleUrl: URL) {
        print("Loading video asset with subtitles...")
        
        // Check if this is an HLS stream
        let isHLSStream = self.isHLSStream(url: self._url)
        
        if isHLSStream {
            print("HLS stream detected - setting up player with subtitles")
            print("HLS URL: \(self._url.absoluteString)")
            // For HLS streams, set up subtitles first, then create player
            self.setupSubtitlesForHLS(subTitleUrl: subTitleUrl)
        } else {
            // For non-HLS streams, load tracks asynchronously
        self.videoAsset.loadValuesAsynchronously(forKeys: ["tracks", "duration"]) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                print("Video asset loaded. Tracks count: \(self.videoAsset.tracks.count)")
                print("Video asset duration: \(self.videoAsset.duration)")
                
                let videoTracks = self.videoAsset.tracks(withMediaType: AVMediaType.video)
                print("Video tracks count: \(videoTracks.count)")
                
                if videoTracks.isEmpty {
                    print("No video tracks found after loading - falling back to simple player")
                    self.playerItem = AVPlayerItem(asset: self.videoAsset)
                    self.player = AVPlayer(playerItem: self.playerItem)
                    self.setupPlayer()
                    return
                }
                
                // Now proceed with subtitle composition
                // For multiple tracks, use first track for backward compatibility
                // Multiple track switching will use AVMediaSelectionGroup
                if let tracks = self._subtitleTracks, !tracks.isEmpty,
                   let firstTrackUrl = tracks[0]["url"] as? String,
                   let url = URL(string: firstTrackUrl) {
                    self.createPlayerWithSubtitles(subTitleUrl: url, videoTracks: videoTracks)
                } else {
                    self.createPlayerWithSubtitles(subTitleUrl: subTitleUrl, videoTracks: videoTracks)
                }
                }
            }
        }
    }
    
    private func loadAllSubtitleTracksForHLS() {
        guard let tracks = _subtitleTracks, !tracks.isEmpty else { return }
        
        // Create player item with the original HLS asset
        self.playerItem = AVPlayerItem(asset: self.videoAsset)
        self.player = AVPlayer(playerItem: self.playerItem)
        
        // CRITICAL: Assign player to videoPlayer BEFORE setting up subtitles
        self.videoPlayer.player = self.player
        
        // Set up the player first
        self.setupPlayer()
        
        // Load all subtitle tracks asynchronously
        var loadedCount = 0
        let totalTracks = tracks.count
        
        for track in tracks {
            guard let trackUrlString = track["url"] as? String,
                  let trackUrl = URL(string: trackUrlString),
                  let trackId = track["id"] as? String else {
                loadedCount += 1
                if loadedCount >= totalTracks {
                    self.finishHLSSubtitleSetup()
                }
                continue
            }
            
            // Load subtitle file
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                do {
                    let subtitleContent = try String(contentsOf: trackUrl, encoding: .utf8)
                    let isVTT = subtitleContent.hasPrefix("WEBVTT")
                    let subtitles: [(start: Double, end: Double, text: String)]
                    if isVTT {
                        subtitles = self.parseVTTContent(subtitleContent)
                    } else {
                        subtitles = self.parseSRTContent(subtitleContent)
                    }
                    
                    DispatchQueue.main.async {
                        self.subtitleTracksData[trackId] = subtitles
                        loadedCount += 1
                        if loadedCount >= totalTracks {
                            self.finishHLSSubtitleSetup()
                        }
                    }
                } catch {
                    print("Failed to load subtitle track \(trackId): \(error)")
                    DispatchQueue.main.async {
                        loadedCount += 1
                        if loadedCount >= totalTracks {
                            self.finishHLSSubtitleSetup()
                        }
                    }
                }
            }
        }
    }
    
    private func finishHLSSubtitleSetup() {
        // Set initial active track
        if let selectedId = _selectedSubtitleId ?? _subtitleTracks?.first?["id"] as? String {
            _activeSubtitleTrackId = selectedId
        }
        
        // Wait for player to be ready before adding subtitles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            // Setup subtitle display for HLS
            self.setupHLSSubtitleDisplay()
            
            // Auto-play for HLS streams with subtitles
            self.autoPlayIfHLSReady()
        }
    }
    
    private func setupHLSSubtitleDisplay() {
        // Create subtitle label that shows/hides based on timing
        let label = UILabel()
        label.textColor = UIColor.white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16)
        label.numberOfLines = 0
        label.isHidden = true
        label.alpha = 0.0
        
        // Apply styling from options if available
        if let options = _stOptions {
            if let fontSize = options["fontSize"] as? CGFloat {
                label.font = UIFont.systemFont(ofSize: fontSize)
            }
            if let fgColor = options["foregroundColor"] as? String {
                label.textColor = parseRGBA(fgColor) ?? UIColor.white
            }
            if let bgColor = options["backgroundColor"] as? String {
                label.backgroundColor = parseRGBA(bgColor)?.withAlphaComponent(0.7) ?? UIColor.black.withAlphaComponent(0.7)
            }
        }
        
        self.subtitleLabel = label
        
        // Add to the video player's content overlay view
        if let contentOverlayView = self.videoPlayer.contentOverlayView {
            contentOverlayView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSLayoutConstraint.activate([
                    label.centerXAnchor.constraint(equalTo: contentOverlayView.centerXAnchor),
                    label.bottomAnchor.constraint(equalTo: contentOverlayView.bottomAnchor, constant: -50),
                    label.leadingAnchor.constraint(greaterThanOrEqualTo: contentOverlayView.leadingAnchor, constant: 20),
                    label.trailingAnchor.constraint(lessThanOrEqualTo: contentOverlayView.trailingAnchor, constant: -20),
                    label.widthAnchor.constraint(lessThanOrEqualTo: contentOverlayView.widthAnchor, constant: -40)
                ])
            }
        }
        
        // Store current subtitle to avoid unnecessary updates
        var currentDisplayedSubtitle: String? = nil
        
        // Set up subtitle timing with player time observer
        let timeObserver = self.player?.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 1), queue: .main) { [weak self] time in
            guard let self = self, let label = self.subtitleLabel else { return }
            
            let currentTime = time.seconds
            
            // Find subtitle from active track
            var currentSubtitle: (start: Double, end: Double, text: String)? = nil
            if let activeTrackId = self._activeSubtitleTrackId,
               let subtitles = self.subtitleTracksData[activeTrackId] {
                currentSubtitle = self.findSubtitleForTime(currentTime, subtitles: subtitles)
            }
            
            // Only update if subtitle text has changed
            let newText = currentSubtitle?.text ?? ""
            if newText != currentDisplayedSubtitle {
                label.text = newText
                currentDisplayedSubtitle = newText
                
                if !newText.isEmpty {
                    label.isHidden = false
                    label.alpha = 1.0
                } else {
                    label.isHidden = true
                }
            }
        }
        
        // Store the observer for cleanup later
        self.subtitleTimeObserver = timeObserver
    }
    
    private func parseRGBA(_ rgba: String) -> UIColor? {
        // Parse RGBA string in format "rgba(r, g, b, a)" or "rgb(r, g, b)"
        if let oPar = rgba.firstIndex(of: "(") {
            if let cPar = rgba.firstIndex(of: ")") {
                let strColor = rgba[rgba.index(after: oPar)..<cPar]
                let array = strColor.components(separatedBy: ",")
                if array.count >= 3 {
                    let r = (array[0].trimmingCharacters(in: .whitespaces) as NSString).floatValue / 255.0
                    let g = (array[1].trimmingCharacters(in: .whitespaces) as NSString).floatValue / 255.0
                    let b = (array[2].trimmingCharacters(in: .whitespaces) as NSString).floatValue / 255.0
                    let a = array.count >= 4 ? (array[3].trimmingCharacters(in: .whitespaces) as NSString).floatValue : 1.0
                    return UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
                }
            }
        }
        return nil
    }
    
    private func setupSubtitlesForHLS(subTitleUrl: URL) {
        print("Setting up subtitles for HLS stream using AVPlayerViewController-Subtitles...")
        
        // Create player item with the original HLS asset
        self.playerItem = AVPlayerItem(asset: self.videoAsset)
        self.player = AVPlayer(playerItem: self.playerItem)
        
        // CRITICAL: Assign player to videoPlayer BEFORE setting up subtitles
        self.videoPlayer.player = self.player
        
        // Set up the player first
        self.setupPlayer()
        
        // Wait for player to be ready before adding subtitles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.addSubtitlesToPlayer(subTitleUrl: subTitleUrl)
            
            // Auto-play for HLS streams with subtitles
            self.autoPlayIfHLSReady()
        }
    }
    
    private func addSubtitlesToPlayer(subTitleUrl: URL) {
        print("Setting up custom subtitle display...")
        
        // Read and parse subtitle content
        do {
            let subtitleContent = try String(contentsOf: subTitleUrl, encoding: .utf8)
            let isVTT = subtitleContent.hasPrefix("WEBVTT")
            print("Subtitle format detected: \(isVTT ? "VTT" : "SRT")")
            
            // Parse subtitles based on format
            let subtitles: [(start: Double, end: Double, text: String)]
            if isVTT {
                subtitles = parseVTTContent(subtitleContent)
            } else {
                subtitles = parseSRTContent(subtitleContent)
            }
            
            print("Parsed \(subtitles.count) subtitle entries")
            
            // Store in tracks data for backward compatibility
            subtitleTracksData["default"] = subtitles
            
            // Create subtitle label that shows/hides based on timing
            let label = UILabel()
            label.textColor = UIColor.white
            label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 16)
            label.numberOfLines = 0
            label.isHidden = true  // Start hidden
            label.alpha = 0.0       // Start transparent
            
            // Apply styling from options if available
            if let options = _stOptions {
                if let fontSize = options["fontSize"] as? CGFloat {
                    label.font = UIFont.systemFont(ofSize: fontSize)
                }
                if let fgColor = options["foregroundColor"] as? String {
                    label.textColor = parseRGBA(fgColor) ?? UIColor.white
                }
                if let bgColor = options["backgroundColor"] as? String {
                    label.backgroundColor = parseRGBA(bgColor)?.withAlphaComponent(0.7) ?? UIColor.black.withAlphaComponent(0.7)
                }
            }
            
            self.subtitleLabel = label
            
            // Add to the video player's content overlay view with delay to ensure proper layout
            if let contentOverlayView = self.videoPlayer.contentOverlayView {
                contentOverlayView.addSubview(label)
                label.translatesAutoresizingMaskIntoConstraints = false
                
                // Wait for the view to have proper dimensions before setting constraints
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Use more flexible constraints to avoid conflicts
                    NSLayoutConstraint.activate([
                        label.centerXAnchor.constraint(equalTo: contentOverlayView.centerXAnchor),
                        label.bottomAnchor.constraint(equalTo: contentOverlayView.bottomAnchor, constant: -50),
                        label.leadingAnchor.constraint(greaterThanOrEqualTo: contentOverlayView.leadingAnchor, constant: 20),
                        label.trailingAnchor.constraint(lessThanOrEqualTo: contentOverlayView.trailingAnchor, constant: -20),
                        label.widthAnchor.constraint(lessThanOrEqualTo: contentOverlayView.widthAnchor, constant: -40)
                    ])
                    print("Added subtitle label constraints after layout")
                }
                print("Added subtitle label to content overlay view")
            } else {
                print("Content overlay view is nil!")
            }
            
            // Store current subtitle to avoid unnecessary updates
            var currentDisplayedSubtitle: String? = nil
            
            // Set up subtitle timing with player time observer (reduced frequency to prevent overload)
            let timeObserver = self.player?.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 1), queue: .main) { [weak self] time in
                guard let self = self, let label = self.subtitleLabel else { return }
                
                let currentTime = time.seconds
                let currentSubtitle = self.findSubtitleForTime(currentTime, subtitles: subtitles)
                
                // Only update if subtitle text has changed
                let newText = currentSubtitle?.text ?? ""
                if newText != currentDisplayedSubtitle {
                    label.text = newText
                    currentDisplayedSubtitle = newText
                    
                    if !newText.isEmpty {
                        // Show subtitle instantly
                        label.isHidden = false
                        label.alpha = 1.0
                        print("Subtitle: \(newText)")
                    } else {
                        // Hide subtitle instantly
                        label.isHidden = true
                        print("Subtitle cleared")
                    }
                }
            }
            
            // Store the observer for cleanup later
            self.subtitleTimeObserver = timeObserver
            
        } catch {
            print("Failed to read subtitle file: \(error)")
        }
    }
    
    private func parseSRTContent(_ content: String) -> [(start: Double, end: Double, text: String)] {
        var subtitles: [(start: Double, end: Double, text: String)] = []
        
        let lines = content.components(separatedBy: .newlines)
        var i = 0
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and sequence numbers
            if line.isEmpty || Int(line) != nil {
                i += 1
                continue
            }
            
            // Check if this is a timestamp line
            if line.contains("-->") {
                let timeParts = line.components(separatedBy: " --> ")
                if timeParts.count == 2 {
                    let startTime = parseTimeString(timeParts[0])
                    let endTime = parseTimeString(timeParts[1])
                    
                    // Get the subtitle text (next non-empty lines)
                    var subtitleText = ""
                    i += 1
                    while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                        if !subtitleText.isEmpty {
                            subtitleText += "\n"
                        }
                        subtitleText += lines[i].trimmingCharacters(in: .whitespaces)
                        i += 1
                    }
                    
                    if !subtitleText.isEmpty {
                        subtitles.append((start: startTime, end: endTime, text: subtitleText))
                    }
                }
            }
            i += 1
        }
        
        return subtitles
    }
    
    private func parseVTTContent(_ content: String) -> [(start: Double, end: Double, text: String)] {
        var subtitles: [(start: Double, end: Double, text: String)] = []
        
        let lines = content.components(separatedBy: .newlines)
        var i = 0
        
        // Skip WEBVTT header
        while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
            if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("WEBVTT") {
                i += 1
                break
            }
            i += 1
        }
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if line.isEmpty {
                i += 1
                continue
            }
            
            // Check if this is a timestamp line (VTT format: 00:00:00.000 --> 00:00:20.000)
            if line.contains("-->") {
                let timeParts = line.components(separatedBy: " --> ")
                if timeParts.count == 2 {
                    let startTime = parseVTTTimeString(timeParts[0])
                    let endTime = parseVTTTimeString(timeParts[1])
                    
                    // Get the subtitle text (next non-empty lines)
                    var subtitleText = ""
                    i += 1
                    while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                        if !subtitleText.isEmpty {
                            subtitleText += "\n"
                        }
                        subtitleText += lines[i].trimmingCharacters(in: .whitespaces)
                        i += 1
                    }
                    
                    if !subtitleText.isEmpty {
                        subtitles.append((start: startTime, end: endTime, text: subtitleText))
                    }
                }
            }
            i += 1
        }
        
        return subtitles
    }
    
    private func parseVTTTimeString(_ timeString: String) -> Double {
        // VTT format: 00:00:00.000 or 00:00:00,000
        let cleanTime = timeString.replacingOccurrences(of: ",", with: ".")
        let components = cleanTime.components(separatedBy: ":")
        if components.count == 3 {
            let hours = Double(components[0]) ?? 0
            let minutes = Double(components[1]) ?? 0
            let seconds = Double(components[2]) ?? 0
            return hours * 3600 + minutes * 60 + seconds
        }
        return 0
    }
    
    private func parseTimeString(_ timeString: String) -> Double {
        let components = timeString.components(separatedBy: ":")
        if components.count == 3 {
            let hours = Double(components[0]) ?? 0
            let minutes = Double(components[1]) ?? 0
            let seconds = Double(components[2]) ?? 0
            return hours * 3600 + minutes * 60 + seconds
        }
        return 0
    }
    
    private func findSubtitleForTime(_ time: Double, subtitles: [(start: Double, end: Double, text: String)]) -> (start: Double, end: Double, text: String)? {
        return subtitles.first { subtitle in
            time >= subtitle.start && time <= subtitle.end
        }
    }
    
    private func isHLSStream(url: URL) -> Bool {
        let urlString = url.absoluteString.lowercased()
        return urlString.contains(".m3u8") || urlString.contains("m3u8")
    }
    
    private func createPlayerWithSubtitles(subTitleUrl: URL, videoTracks: [AVAssetTrack]) {
        print("Creating player with subtitles...")
        
        var textStyle: [AVTextStyleRule] = []
        if let opt = self._stOptions {
            textStyle.append(contentsOf: self.setSubTitleStyle(options: opt))
        }

        let subTitleAsset = AVAsset(url: subTitleUrl)
        print("Subtitle asset duration: \(subTitleAsset.duration)")
        let composition = AVMutableComposition()

        if let videoTrack = composition.addMutableTrack(
            withMediaType: AVMediaType.video,
            preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) {
            
            // Check if video has audio tracks
            let audioTracks = self.videoAsset.tracks(withMediaType: AVMediaType.audio)
            let audioTrack = composition.addMutableTrack(
                withMediaType: AVMediaType.audio,
                preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            
            do {
                try videoTrack.insertTimeRange(
                    CMTimeRangeMake(start: CMTime.zero,
                                    duration: self.videoAsset.duration),
                    of: videoTracks[0],
                    at: CMTime.zero)
                
                // Add audio track if it exists
                if !audioTracks.isEmpty, let audioTrack = audioTrack {
                    try audioTrack.insertTimeRange(CMTimeRangeMake(
                                                    start: CMTime.zero,
                                                    duration: self.videoAsset.duration),
                                                   of: audioTracks[0], at: CMTime.zero)
                }
                
                // Handle multiple subtitle tracks if available
                if let tracks = _subtitleTracks, tracks.count > 1 {
                    // For multiple tracks, add the first one to composition
                    // Track switching will be handled via AVMediaSelectionGroup or custom logic
                    print("Multiple subtitle tracks detected, adding first track to composition")
                }
                
                // Check if subtitle asset has text tracks
                let subtitleTracks = subTitleAsset.tracks(withMediaType: .text)
                if !subtitleTracks.isEmpty {
                    if let subtitleTrack = composition.addMutableTrack(
                        withMediaType: .text,
                        preferredTrackID: kCMPersistentTrackID_Invalid) {
                        do {
                            let duration = self.videoAsset.duration
                            try subtitleTrack.insertTimeRange(
                                CMTimeRangeMake(start: CMTime.zero,
                                                duration: duration),
                                of: subtitleTracks[0],
                                at: CMTime.zero)

                            self.playerItem = AVPlayerItem(asset: composition)
                            self.playerItem?.textStyleRules = textStyle
                            
                            // Set initial selected track
                            if let selectedId = _selectedSubtitleId ?? _subtitleTracks?.first?["id"] as? String {
                                _activeSubtitleTrackId = selectedId
                            }
                            
                            print("Successfully added subtitle track")

                        } catch {
                            print("Failed to insert subtitle track: \(error)")
                            self.playerItem = AVPlayerItem(asset: self.videoAsset)
                        }
                    } else {
                        print("Failed to create subtitle track")
                        self.playerItem = AVPlayerItem(asset: self.videoAsset)
                    }
                } else {
                    print("No subtitle tracks found in subtitle asset")
                    self.playerItem = AVPlayerItem(asset: self.videoAsset)
                }
            } catch {
                print("Failed to insert video/audio tracks: \(error)")
                self.playerItem = AVPlayerItem(asset: self.videoAsset)
            }
        } else {
            print("Failed to create video track")
            self.playerItem = AVPlayerItem(asset: self.videoAsset)
        }
        
        self.player = AVPlayer(playerItem: self.playerItem)
        self.setupPlayer()
    }
    
    private func setupPlayer() {
        // Configure audio session to prevent HALC overload
        self.configureAudioSession()
        
        // Optimize audio processing to prevent HALC overload
        self.player?.currentItem?.audioTimePitchAlgorithm = .timeDomain
        self.player?.currentItem?.preferredForwardBufferDuration = 5.0
        self.player?.currentItem?.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        
        // Disable audio enhancement features that cause errors
        if #available(iOS 15.0, *) {
            self.player?.currentItem?.preferredPeakBitRate = 0
        }
        
        // Additional optimizations to prevent HAL errors
        self.player?.currentItem?.preferredMaximumResolution = CGSize(width: 1920, height: 1080)
        self.player?.currentItem?.preferredForwardBufferDuration = 3.0
        if !self._showControls {
            self.videoPlayer.showsPlaybackControls = false
        }
        self.videoPlayer.player = self.player
        self.videoPlayer.updatesNowPlayingInfoCenter = false
        if #available(iOS 13.0, *) {
            self.videoPlayer.isModalInPresentation = true
        } else {
            // Fallback on earlier versions
        }
        self.videoPlayer.allowsPictureInPicturePlayback = false
        if isPIPModeAvailable && self._pipEnabled {
            self.videoPlayer.allowsPictureInPicturePlayback = true
        }
        
        // Add subtitle selection button if multiple tracks are available
        if let tracks = _subtitleTracks, tracks.count > 1 {
            self.addSubtitleSelectionButton()
        }

        self._isLoaded.updateValue(false, forKey: self._videoId)
    }
    
    private func addSubtitleSelectionButton() {
        // Create subtitle button
        let subtitleButton = UIButton(type: .system)
        subtitleButton.setTitle("CC", for: .normal)
        subtitleButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        subtitleButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        subtitleButton.setTitleColor(.white, for: .normal)
        subtitleButton.layer.cornerRadius = 8
        subtitleButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        
        subtitleButton.addTarget(self, action: #selector(showSubtitleSelectionMenu), for: .touchUpInside)
        
        // Add to content overlay view
        if let contentOverlayView = self.videoPlayer.contentOverlayView {
            contentOverlayView.addSubview(subtitleButton)
            subtitleButton.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                subtitleButton.trailingAnchor.constraint(equalTo: contentOverlayView.trailingAnchor, constant: -20),
                subtitleButton.topAnchor.constraint(equalTo: contentOverlayView.topAnchor, constant: 20)
            ])
        }
    }
    
    @objc private func showSubtitleSelectionMenu() {
        guard let tracks = _subtitleTracks, !tracks.isEmpty else { return }
        
        let alertController = UIAlertController(title: "Select Subtitle", message: nil, preferredStyle: .actionSheet)
        
        // Add "Off" option
        let offAction = UIAlertAction(title: "Off", style: .default) { [weak self] _ in
            self?.selectSubtitleTrack(trackId: nil)
        }
        alertController.addAction(offAction)
        
        // Add track options
        for track in tracks {
            let trackId = track["id"] as? String ?? ""
            let label = track["label"] as? String ?? track["language"] as? String ?? trackId
            let isSelected = trackId == (_activeSubtitleTrackId ?? _selectedSubtitleId)
            
            let action = UIAlertAction(title: isSelected ? "\(label) ✓" : label, style: .default) { [weak self] _ in
                self?.selectSubtitleTrack(trackId: trackId)
            }
            alertController.addAction(action)
        }
        
        // Add cancel
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alertController.addAction(cancelAction)
        
        // Present from the video player view controller
        var presentingVC: UIViewController?
        if let presenting = self.videoPlayer.presentingViewController {
            presentingVC = presenting
        } else {
            // Get root view controller from window scene (iOS 13+)
            if #available(iOS 13.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    presentingVC = window.rootViewController
                }
            } else {
                // Fallback for iOS 12 and earlier
                presentingVC = UIApplication.shared.keyWindow?.rootViewController
            }
        }
        
        if let presentingVC = presentingVC {
            // For iPad, we need to set the popover presentation
            if let popover = alertController.popoverPresentationController {
                popover.sourceView = self.videoPlayer.view
                popover.sourceRect = CGRect(x: self.videoPlayer.view.bounds.width - 100, y: 20, width: 100, height: 44)
            }
            presentingVC.present(alertController, animated: true)
        }
    }
    
    // MARK: - Audio Session Configuration
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Deactivate any existing session first to prevent conflicts
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Wait a moment for deactivation to complete
            Thread.sleep(forTimeInterval: 0.1)
            
            // Configure for video playback to prevent HAL errors
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetoothHFP, .mixWithOthers])
            
            // Set preferred sample rate to reduce processing load
            try audioSession.setPreferredSampleRate(44100.0)
            
            // Set preferred buffer duration to reduce latency and prevent HAL errors
            try audioSession.setPreferredIOBufferDuration(0.02)
            
            // Disable audio enhancement features that cause errors
            if #available(iOS 15.0, *) {
                try audioSession.setPrefersNoInterruptionsFromSystemAlerts(true)
            }
            
            // Activate the session with proper options
            try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
            
            print("✅ Audio session configured for video playback")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
            // Fallback configuration
            self.configureAudioSessionFallback()
        }
    }
    
    private func configureAudioSessionFallback() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Simple fallback configuration
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            
            print("✅ Audio session fallback configured")
        } catch {
            print("❌ Failed to configure audio session fallback: \(error)")
        }
    }
    
    private func cleanupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Pause the player first to prevent HAL errors
            self.player?.pause()
            
            // Wait a moment for audio to stop
            Thread.sleep(forTimeInterval: 0.1)
            
            // Deactivate the session with proper options
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Reset to default category to prevent conflicts
            try audioSession.setCategory(.ambient, mode: .default, options: [])
            
            print("✅ Audio session deactivated and reset")
        } catch {
            print("❌ Failed to deactivate audio session: \(error)")
            // Force deactivation
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setActive(false)
                print("✅ Audio session force deactivated")
            } catch {
                print("❌ Failed to force deactivate audio session: \(error)")
            }
        }
    }
    
    // MARK: - Auto-play for HLS streams
    
    private func autoPlayIfHLSReady() {
        // Check if this is an HLS stream
        let isHLSStream = self.isHLSStream(url: self._url)
        
        print("🔍 autoPlayIfHLSReady called - isHLSStream: \(isHLSStream), player exists: \(self.player != nil)")
        
        if isHLSStream {
            print("🎬 HLS stream ready - starting auto-play")
            
            // Small delay to ensure everything is properly set up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                
                // Start playing the HLS stream
                self.player?.play()
                self.player?.rate = self._videoRate
                self.isPlaying = true
                
                print("✅ HLS stream auto-play started")
                
                // Notify that playback has started
                let vId: [String: Any] = [
                    "fromPlayerId": self._videoId,
                    "currentTime": self._currentTime,
                    "videoRate": self._videoRate
                ]
                NotificationCenter.default.post(name: .playerItemPlay, object: nil, userInfo: vId)
            }
        } else {
            print("📹 Non-HLS stream - no auto-play")
        }
    }
    
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

    private func setSubTitleStyle(options: [String: Any]) -> [AVTextStyleRule] {
        var styles: [AVTextStyleRule] = []
        var backColor: [Float] = [1.0, 0.0, 0.0, 0.0]
        if let bckCol = options["backgroundColor"] as? String {
            let color = self.getColorFromRGBA(rgba: bckCol)
            backColor = color.count > 0 ? color : backColor
        }
        if let textStyle: AVTextStyleRule = AVTextStyleRule(textMarkupAttributes: [
            kCMTextMarkupAttribute_CharacterBackgroundColorARGB as String:
                backColor
        ]) {
            styles.append(textStyle)
        }

        var foreColor: [Float] = [1.0, 1.0, 1.0, 1.0]
        if let foreCol = options["foregroundColor"] as? String {
            let color = self.getColorFromRGBA(rgba: foreCol)
            foreColor = color.count > 0 ? color : foreColor
        }
        if let textStyle1: AVTextStyleRule = AVTextStyleRule(textMarkupAttributes: [
            kCMTextMarkupAttribute_ForegroundColorARGB as String: foreColor
        ]) {
            styles.append(textStyle1)
        }
        var ftSize = 160
        if let pixSize = options["fontSize"] as? Int {
            ftSize = pixSize * 10
        }
        if let textStyle2: AVTextStyleRule = AVTextStyleRule(textMarkupAttributes: [
            kCMTextMarkupAttribute_RelativeFontSize as String: ftSize,
            kCMTextMarkupAttribute_CharacterEdgeStyle as String: kCMTextMarkupCharacterEdgeStyle_None
        ]) {
            styles.append(textStyle2)
        }
        return styles
    }
    // MARK: - Add Observers

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    private func addObservers() {

        self.itemStatusObserver = self.playerItem?
            .observe(\.status, options: [.new, .old],
                     changeHandler: {[weak self] (playerItem, _) in
                        guard let self = self else { return }
                        // Switch over the status
                        switch playerItem.status {
                        case .readyToPlay:
                            // Player item is ready to play.
                            if self._firstReadyToPlay {
                                self._isLoaded.updateValue(true, forKey: self._videoId)
                                self._isReadyToPlay = true
                                isVideoEnded = false
                                if let item = self.playerItem {
                                    self._currentTime = CMTimeGetSeconds(item.currentTime())
                                }
                                let vId: [String: Any] = ["fromPlayerId": self._videoId, "currentTime": self._currentTime,
                                                          "videoRate": self._videoRate]
                                NotificationCenter.default.post(name: .playerItemReady, object: nil, userInfo: vId)
                                self._firstReadyToPlay = false
                                
                                self.setNowPlayingInfo()
                                self.setRemoteCommandCenter()
                                self.setNowPlayingImage()
                            }
                        case .failed:
                            print("failing to load")
                            self._isLoaded.updateValue(false, forKey: self._videoId)
                        case .unknown:
                            // Player item is not yet ready.
                            print("playerItem not yet ready")

                        @unknown default:
                            print("playerItem Error \(String(describing: self.playerItem?.error))")
                        }

                     })

        self.itemBufferObserver = self.playerItem?
            .observe(\.isPlaybackBufferEmpty,
                     options: [.new, .old], changeHandler: {[weak self] (playerItem, _) in
                        guard let self = self else { return }
                        let empty: Bool = ((self.playerItem?.isPlaybackBufferEmpty) != nil)
                        if empty {
                            self._isBufferEmpty.updateValue(true, forKey: self._videoId)
                        } else {
                            self._isBufferEmpty.updateValue(false, forKey: self._videoId)
                        }
                     })
        self.playerRateObserver = self.player?
            .observe(\.rate, options: [.new, .old], changeHandler: {[weak self] (player, _) in
                guard let self = self else { return }
                let rate: Float = player.rate
                if let item = self.playerItem {
                    self._currentTime = CMTimeGetSeconds(item.currentTime())
                    self._duration = CMTimeGetSeconds(item.duration)
                }
                let vId: [String: Any] = [
                    "fromPlayerId": self._videoId,
                    "currentTime": self._currentTime,
                    "videoRate": self._videoRate
                ]

                if !(self._isLoaded[self._videoId] ?? true) {
                    print("AVPlayer Rate for player \(self._videoId): Loading")
                } else if rate > 0 && self._isReadyToPlay {
                    if rate != self._videoRate {
                        player.rate = self._videoRate
                    }

                    self.isPlaying = true
                    NotificationCenter.default.post(name: .playerItemPlay, object: nil, userInfo: vId)
                } else if rate == 0 && !isVideoEnded && abs(self._currentTime - self._duration) < 0.2 {
                    self.isPlaying = false
                    player.seek(to: CMTime.zero)
                    self._currentTime = 0
                    if /*!isInPIPMode && */self._exitOnEnd {
                        isVideoEnded = true
                        NotificationCenter.default.post(name: .playerItemEnd, object: nil, userInfo: vId)
                    } else {
                        if self._loopOnEnd {
                            self.play()
                        }
                    }
                } else if rate == 0 {
                    if !isInPIPMode && !isInBackgroundMode && !isRateZero {
                        self.isPlaying = false
                        if !self.videoPlayer.isBeingDismissed {
                            print("AVPlayer Rate for player \(self._videoId): Paused")
                            NotificationCenter.default.post(name: .playerItemPause, object: nil, userInfo: vId)
                        }
                    } else {
                        isRateZero = true
                    }
                } else if self._isBufferEmpty[self._videoId] ?? true {
                    print("AVPlayer Rate for player \(self._videoId): Buffer Empty Loading")
                }
            })
        self.videoPlayerFrameObserver = self.videoPlayer
            .observe(\.view.frame, options: [.new, .old],
                     changeHandler: {[weak self] (_, _) in
                        guard let self = self else { return }
                        if !isInPIPMode {
                            if self.videoPlayer.isBeingDismissed && !isVideoEnded {
                                NotificationCenter.default.post(name: .playerFullscreenDismiss, object: nil)
                            }
                        }

                     })
        self.videoPlayerMoveObserver = self.videoPlayer
            .observe(\.view.center, options: [.new, .old],
                     changeHandler: {[weak self] (_, _) in
                        guard let self = self else { return }
                        if !isInPIPMode {
                            if self.videoPlayer.isBeingDismissed && !isVideoEnded {
                                NotificationCenter.default.post(name: .playerFullscreenDismiss, object: nil)
                            }

                        }

                     })
    }

    // swiftlint:enable function_body_length
    // swiftlint:enable cyclomatic_complexity

    // MARK: - Remove Observers

    func removeObservers() {
        print("🧹 Cleaning up observers...")
        
        // Remove KVO observers
        self.itemStatusObserver?.invalidate()
        self.itemBufferObserver?.invalidate()
        self.playerRateObserver?.invalidate()
        self.videoPlayerFrameObserver?.invalidate()
        self.videoPlayerMoveObserver?.invalidate()
        
        // Set observers to nil to break any potential retain cycles
        self.itemStatusObserver = nil
        self.itemBufferObserver = nil
        self.playerRateObserver = nil
        self.videoPlayerFrameObserver = nil
        self.videoPlayerMoveObserver = nil
        
        // Remove time observers
        if let periodicObserver = self.periodicTimeObserver {
            self.player?.removeTimeObserver(periodicObserver)
            self.periodicTimeObserver = nil
        }
        
        if let subtitleObserver = self.subtitleTimeObserver {
            self.player?.removeTimeObserver(subtitleObserver)
            self.subtitleTimeObserver = nil
        }
        
        // Clean up player
        self.player?.pause()
        self.player?.replaceCurrentItem(with: nil)
        self.player = nil
        self.playerItem = nil
        
        // Clean up video asset
        self.videoAsset.cancelLoading()
        
        // Clean up audio session
        self.cleanupAudioSession()
        
        // Clean up video player
        self.videoPlayer.player = nil
        
        // Clean up subtitle labels from content overlay
        if let contentOverlayView = self.videoPlayer.contentOverlayView {
            for subview in contentOverlayView.subviews {
                if subview is UILabel {
                    subview.removeFromSuperview()
                }
            }
        }
        
        // Clear any cached data
        self._isLoaded.removeAll()
        self._isBufferEmpty.removeAll()
        
        // Clear subtitle-related data
        self._stUrl = nil
        self._stLanguage = nil
        self._stHeaders = nil
        self._stOptions = nil
        
        // Clear video asset reference completely
        self.videoAsset = AVURLAsset(url: URL(string: "about:blank")!)
        
        // Force garbage collection to help with memory cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            autoreleasepool {
                // This helps with memory cleanup
            }
        }
        
        print("✅ Observers cleaned up")
    }
    
    deinit {
        print("🗑️ FullScreenVideoPlayerView deinit called")
        self.removeObservers()
    }
    
    // MARK: - Public cleanup method for manual disposal
    
    @objc func cleanup() {
        print("🧹 Manual cleanup called")
        self.removeObservers()
        
        // Force immediate memory cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            autoreleasepool {
                // Force garbage collection
                print("🔄 Forcing memory cleanup...")
            }
        }
    }

    // MARK: - Required init

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    // MARK: - Set-up Public functions

    @objc func play() {
        // Ensure audio session is properly configured before playing
        self.configureAudioSession()
        
        self.isPlaying = true
        self.player?.play()
        self.player?.rate = _videoRate
        
        print("▶️ Video playback started")
    }
    @objc func pause() {
        self.isPlaying = false
        self.player?.pause()
        
        print("⏸️ Video playback paused")
    }
    @objc func didFinishPlaying() -> Bool {
        return isVideoEnded
    }
    @objc func getDuration() -> Double {
        return Double(CMTimeGetSeconds(self.videoAsset.duration))
    }
    @objc func getCurrentTime() -> Double {
        return self.player?.currentTime().seconds ?? 0.0
    }
    // This func will return the updated currentTime of player item
    // getCurrentTime() is only updated when player plays, pauses, seek, etc
    // the function is only used in playerFullscreenDismiss() Notification
    public func getRealCurrentTime() -> Double {
        if let item = self.playerItem {
            let currentTime = CMTimeGetSeconds(item.currentTime())
            return currentTime
        } else {
            return 0
        }
    }
    @objc func setCurrentTime(time: Double) {
        let seekTime: CMTime = CMTimeMake(value: Int64(time*1000), timescale: 1000)
        self.player?.seek(to: seekTime)
        self._currentTime = time
    }
    @objc func getVolume() -> Float {
        if let player = self.player {
            return player.volume
        } else {
            return 1.0
        }
    }
    @objc func setVolume(volume: Float) {
        self.player?.volume = volume
    }
    @objc func getRate() -> Float {
        return _videoRate
    }

    @objc func setRate(rate: Float) {
        _videoRate = rate
    }
    @objc func getMuted() -> Bool {
        return ((self.player?.isMuted) != nil)
    }
    @objc func setMuted(muted: Bool) {
        self.player?.isMuted = muted
    }

    private func getColorFromRGBA(rgba: String) -> [Float] {
        if let oPar = rgba.firstIndex(of: "(") {
            if let cPar = rgba.firstIndex(of: ")") {
                let strColor = rgba[rgba.index(after: oPar)..<cPar]
                let array = strColor.components(separatedBy: ",")
                if array.count == 4 {
                    var retArray: [Float] = []
                    retArray.append((array[3]
                                        .trimmingCharacters(in: .whitespaces) as NSString)
                                        .floatValue)
                    retArray.append((array[0]
                                        .trimmingCharacters(in: .whitespaces) as NSString)
                                        .floatValue / 255)
                    retArray.append((array[1]
                                        .trimmingCharacters(in: .whitespaces) as NSString)
                                        .floatValue / 255)
                    retArray.append((array[2]
                                        .trimmingCharacters(in: .whitespaces) as NSString)
                                        .floatValue / 255)
                    return retArray
                } else {
                    return []
                }
            } else {
                return []
            }
        } else {
            return []
        }
    }

    private func srtSubtitleToVtt(srtURL: URL) -> URL {
        guard let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            fatalError("Couldn't get caches directory")
        }
        let vttFileName = UUID().uuidString + ".vtt"
        let vttURL = cachesURL.appendingPathComponent(vttFileName)
        let session = URLSession(configuration: .default)
        let vttFolderURL = vttURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: vttFolderURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error {
            print("Creating folder error: ", error)
        }
        let task = session.dataTask(with: srtURL) { (data, _, error) in
            guard let data = data, error == nil else {
                print("Download failed: \(error?.localizedDescription ?? "ukn")")
                return
            }
            do {
                let tempSRTURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("subtitulos.srt")
                try data.write(to: tempSRTURL)
                let srtContent = try String(contentsOf: tempSRTURL, encoding: .utf8)
                let vttContent = srtContent.replacingOccurrences(of: ",", with: ".")
                let vttString = "WEBVTT\n\n" + vttContent
                try vttString.write(toFile: vttURL.path, atomically: true, encoding: .utf8)
                try FileManager.default.removeItem(at: tempSRTURL)

            } catch let error {
                print("Processing subs error: \(error)")
                // Log error and continue - the VTT file may not be created
                // but the function will still return the VTT URL path
            }

        }

        task.resume()
        return vttURL
    }
    
    func setRemoteCommandCenter() {
        let rcc = MPRemoteCommandCenter.shared()
        
        rcc.playCommand.isEnabled = true
        rcc.playCommand.addTarget {event in
            self.play()
            return .success
        }
        rcc.pauseCommand.isEnabled = true
        rcc.pauseCommand.addTarget {event in
            self.pause()
            return .success
        }
        rcc.changePlaybackPositionCommand.isEnabled = true
        rcc.changePlaybackPositionCommand.addTarget {event in
            let seconds = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime ?? 0
            let time = CMTime(seconds: seconds, preferredTimescale: 1)
            self.player?.seek(to: time)
            return .success
        }
        rcc.skipForwardCommand.isEnabled = true
        rcc.skipForwardCommand.addTarget {event in
            if let player = self.player, let currentItem = player.currentItem {
                let currentTime = CMTimeGetSeconds(currentItem.currentTime()) + 10
                self.player?.seek(to: CMTimeMakeWithSeconds(currentTime, preferredTimescale: 1))
                return .success
            } else {
                return .commandFailed
            }
        }
        rcc.skipBackwardCommand.isEnabled = true
        rcc.skipBackwardCommand.addTarget {event in
            if let player = self.player, let currentItem = player.currentItem {
                let currentTime = CMTimeGetSeconds(currentItem.currentTime()) - 10
                self.player?.seek(to: CMTimeMakeWithSeconds(currentTime, preferredTimescale: 1))
                return .success
            } else {
                return .commandFailed
            }
        }
        
        // Next and previous track buttons are disabled because we don't have more than 1 video
        rcc.nextTrackCommand.isEnabled = false
        rcc.previousTrackCommand.isEnabled = false
    }
    
    func setNowPlayingImage() {
        if let artwork = self._artwork {
            let session = URLSession(configuration: .default)
            let image = URL(string: artwork)!
            let task = session.dataTask(with: image) { (data, response, error) in
                guard let imageData = data, error == nil else {
                    print("Error while downloading the image: \(error?.localizedDescription ?? "")")
                    return
                }
                
                let image = UIImage(data: imageData)
                DispatchQueue.main.async {
                    var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image?.size ?? CGSize.zero, requestHandler: { _ in
                        return image ?? UIImage()
                    })
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                }
            }
            task.resume()
        }
    }
    
    func setNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        
        if let title = self._title {
            nowPlayingInfo[MPMediaItemPropertyTitle] = title
        }
        if let smalltitle = self._smallTitle {
            nowPlayingInfo[MPMediaItemPropertyArtist] = smalltitle
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = NSNumber(value: MPNowPlayingInfoMediaType.video.rawValue)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        UIApplication.shared.beginReceivingRemoteControlEvents()
        periodicTimeObserver = self.player?.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 1), queue: DispatchQueue.main) { [weak self] time in
            guard let self = self else { return }
            
            var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
            if let currentItem = self.player?.currentItem,
               let currentTime = self.player?.currentTime(),
               currentItem.status == .readyToPlay {
                
                let elapsedTime = CMTimeGetSeconds(currentTime)
                if currentItem.isPlaybackLikelyToKeepUp {
                    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.player?.rate
                } else {
                    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0
                }
                
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Float(elapsedTime)
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = currentItem.duration.seconds
                
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            }
        }
    }

    // MARK: - Subtitle Track Management

    func getSubtitleTracks() -> [[String: Any]]? {
        guard let tracks = _subtitleTracks else { return nil }
        var result: [[String: Any]] = []
        for track in tracks {
            let trackInfo: [String: Any] = [
                "id": track["id"] as? String ?? "",
                "language": track["language"] as? String ?? "",
                "label": track["label"] as? String ?? track["language"] as? String ?? "",
                "isSelected": (track["id"] as? String) == _activeSubtitleTrackId,
                "isAvailable": true
            ]
            result.append(trackInfo)
        }
        return result
    }

    func selectSubtitleTrack(trackId: String?) {
        _activeSubtitleTrackId = trackId
        
        // For HLS streams, the subtitle display will automatically switch
        // because the time observer uses _activeSubtitleTrackId
        if isHLSStream(url: self._url) {
            // The subtitle display is already set up to use _activeSubtitleTrackId
            // Just hide the label if trackId is nil
            if trackId == nil {
                subtitleLabel?.isHidden = true
            }
        } else {
            // For non-HLS, use AVMediaSelectionGroup
            guard let playerItem = self.playerItem else { return }
            guard let mediaSelectionGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return }
            
            if let trackId = trackId {
                // Try to find matching option by language or track ID
                let options = mediaSelectionGroup.options.filter { option in
                    return option.extendedLanguageTag == trackId || 
                           option.locale?.languageCode == trackId ||
                           option.displayName == trackId
                }
                if let option = options.first {
                    playerItem.select(option, in: mediaSelectionGroup)
                } else if _subtitleTracks != nil {
                    // If no matching option, try to create composition with selected track
                    // This would require re-creating the player item with the selected track
                    // For now, just log a warning
                    print("Could not find matching subtitle option for track ID: \(trackId)")
                }
            } else {
                // Disable subtitles
                playerItem.select(nil, in: mediaSelectionGroup)
                subtitleLabel?.isHidden = true
            }
        }
    }

    func getSelectedSubtitleTrack() -> String? {
        return _activeSubtitleTrackId ?? _selectedSubtitleId
    }
}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
