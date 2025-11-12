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
    private var subtitleButton: UIButton?
    private var subtitleButtonHideTimer: Timer?
    private var subtitleButtonVisibilityTimer: Timer?
    private var subtitleButtonTapGesture: UITapGestureRecognizer?
    private var lastInteractionTime: Date?

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
          // But first, load the asset to check for native subtitle tracks
          self.videoAsset.loadValuesAsynchronously(forKeys: ["tracks", "availableMediaCharacteristicsWithMediaSelectionOptions"]) { [weak self] in
              DispatchQueue.main.async {
                  guard let self = self else { return }
                  self.playerItem = AVPlayerItem(asset: self.videoAsset)
                  self.player = AVPlayer(playerItem: self.playerItem)
                  self.setupPlayer()
              }
          }
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
            
            // Load subtitle file with proper headers for authentication
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                // Use URLSession to fetch with headers if available
                let session = URLSession.shared
                var request = URLRequest(url: trackUrl)
                
                // Add headers if they were provided for the video
                if let headers = self._stHeaders {
                    for (key, value) in headers {
                        request.setValue(value, forHTTPHeaderField: key)
                    }
                }
                
                let task = session.dataTask(with: request) { [weak self] data, response, error in
                    guard let self = self else { return }
                    
                    if error != nil {
                        DispatchQueue.main.async {
                            self.subtitleTracksData[trackId] = []
                            loadedCount += 1
                            if loadedCount >= totalTracks {
                                self.finishHLSSubtitleSetup()
                            }
                        }
                        return
                    }
                    
                    guard let data = data, let subtitleContent = String(data: data, encoding: .utf8) else {
                        DispatchQueue.main.async {
                            self.subtitleTracksData[trackId] = []
                            loadedCount += 1
                            if loadedCount >= totalTracks {
                                self.finishHLSSubtitleSetup()
                            }
                        }
                        return
                    }
                    
                    // Check if we got an error response (like 401)
                    if subtitleContent.contains("\"status\":401") || subtitleContent.contains("Unauthorized") {
                        DispatchQueue.main.async {
                            self.subtitleTracksData[trackId] = []
                            loadedCount += 1
                            if loadedCount >= totalTracks {
                                self.finishHLSSubtitleSetup()
                            }
                        }
                        return
                    }
                    
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
                }
                
                task.resume()
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
                    // Show subtitle instantly
                    label.isHidden = false
                    label.alpha = 1.0
                } else {
                    // Hide subtitle instantly
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
                }
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
        
        // Clear native subtitle selection to minimize native button visibility
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            if let playerItem = self.playerItem,
               let mediaSelectionGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
                playerItem.select(nil, in: mediaSelectionGroup)
            }
        }
        
        // Add subtitle selection button if tracks are available
        if let tracks = _subtitleTracks, !tracks.isEmpty {
            self.addSubtitleSelectionButton()
        } else {
            // Check for native subtitle tracks after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                if self.hasNativeSubtitleTracks() {
                    self.addSubtitleSelectionButton()
                }
            }
        }

        self._isLoaded.updateValue(false, forKey: self._videoId)
    }
    
    private func addSubtitleSelectionButton() {
        // Check if button already exists to avoid duplicates
        if let contentOverlayView = self.videoPlayer.contentOverlayView {
            for subview in contentOverlayView.subviews {
                if let button = subview as? UIButton, button.tag == 9999 {
                    return
                }
            }
        }
        
        // Create subtitle button with normal styling
        let button = UIButton(type: .system)
        button.setTitle("CC", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        button.tag = 9999
        
        button.addTarget(self, action: #selector(showSubtitleSelectionMenu), for: .touchUpInside)
        
        self.subtitleButton = button
        
        // Add to content overlay view
        if let contentOverlayView = self.videoPlayer.contentOverlayView {
            contentOverlayView.addSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                button.trailingAnchor.constraint(equalTo: contentOverlayView.trailingAnchor, constant: -20),
                button.centerYAnchor.constraint(equalTo: contentOverlayView.centerYAnchor, constant: -100)
            ])
            
            contentOverlayView.bringSubviewToFront(button)
            
            // Set up auto-hide behavior to match native controls
            self.setupSubtitleButtonAutoHide()
        }
    }
    
    private func setupSubtitleButtonAutoHide() {
        // Show button initially
        self.showSubtitleButton()
        
        // Initialize last interaction time
        self.lastInteractionTime = Date()
        
        // Add tap gesture that works alongside native controls
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleVideoPlayerTap))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.cancelsTouchesInView = false
        tapGesture.requiresExclusiveTouchType = false
        self.videoPlayer.view.addGestureRecognizer(tapGesture)
        self.subtitleButtonTapGesture = tapGesture
        
        // Also add to content overlay view
        if let contentOverlayView = self.videoPlayer.contentOverlayView {
            let overlayTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleVideoPlayerTap))
            overlayTapGesture.numberOfTapsRequired = 1
            overlayTapGesture.cancelsTouchesInView = false
            overlayTapGesture.requiresExclusiveTouchType = false
            contentOverlayView.addGestureRecognizer(overlayTapGesture)
        }
        
        // Start periodic observer to check visibility and handle hide logic
        self.startSubtitleButtonVisibilityObserver()
    }
    
    @objc private func handleVideoPlayerTap() {
        // Show button immediately when user taps (matching native controls)
        self.showSubtitleButton()
        // Update last interaction time
        self.lastInteractionTime = Date()
    }
    
    private func startSubtitleButtonVisibilityObserver() {
        // Cancel any existing visibility timer
        self.subtitleButtonVisibilityTimer?.invalidate()
        
        // Check every 0.2 seconds if controls are visible
        // This acts as a backup to ensure button shows when native controls appear
        self.subtitleButtonVisibilityTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Check if content overlay has visible native controls
            if let contentOverlayView = self.videoPlayer.contentOverlayView {
                // Look for visible control elements
                var hasVisibleControls = false
                
                for subview in contentOverlayView.subviews {
                    // Skip our own button
                    if subview == self.subtitleButton {
                        continue
                    }
                    
                    // Check if this is a visible control element
                    if !subview.isHidden && subview.alpha > 0.1 {
                        let frame = subview.frame
                        let isInControlArea = frame.minY < 150 || frame.maxY > contentOverlayView.bounds.height - 150
                        
                        // If it's a button or in control area, consider it a control
                        if subview is UIButton || isInControlArea {
                            hasVisibleControls = true
                            break
                        }
                    }
                }
                
                // Also check showsPlaybackControls property
                if self.videoPlayer.showsPlaybackControls {
                    let visibleSubviewCount = contentOverlayView.subviews.filter { 
                        $0 != self.subtitleButton && !$0.isHidden && $0.alpha > 0.1 
                    }.count
                    
                    if visibleSubviewCount > 0 {
                        hasVisibleControls = true
                    }
                }
                
                // If controls are visible, show our button and update interaction time
                if hasVisibleControls {
                    if self.subtitleButton?.isHidden == true || self.subtitleButton?.alpha == 0 {
                        self.showSubtitleButton()
                    }
                    // Reset interaction time when controls are visible
                    self.lastInteractionTime = Date()
                } else {
                    // Controls are not visible - check if we should hide
                    if let lastInteraction = self.lastInteractionTime {
                        let timeSinceInteraction = Date().timeIntervalSince(lastInteraction)
                        // Hide button if no interaction for 3 seconds
                        if timeSinceInteraction >= 3.0 {
                            if self.subtitleButton?.isHidden == false && (self.subtitleButton?.alpha ?? 0) > 0.1 {
                                self.hideSubtitleButton()
                            }
                        }
                    } else {
                        // Initialize interaction time if not set
                        self.lastInteractionTime = Date()
                    }
                }
            }
        }
    }
    
    private func showSubtitleButton() {
        guard let button = self.subtitleButton else { return }
        // Ensure button can receive touches
        button.isUserInteractionEnabled = true
        button.isHidden = false
        UIView.animate(withDuration: 0.3) {
            button.alpha = 1.0
        }
    }
    
    private func hideSubtitleButton() {
        guard let button = self.subtitleButton else { return }
        // Keep button in view hierarchy but make it invisible
        // This allows it to be shown again when needed
        UIView.animate(withDuration: 0.3) {
            button.alpha = 0.0
        } completion: { _ in
            button.isHidden = true
            // Ensure button can still receive touches when shown again
            button.isUserInteractionEnabled = false
        }
    }
    
    
    @objc private func showSubtitleSelectionMenu() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Show button when menu is opened
            self.showSubtitleButton()
            
            // If we have manual tracks, show them immediately
            if let manualTracks = self._subtitleTracks, !manualTracks.isEmpty {
                self.showSubtitleMenuAfterLoading()
                return
            }
            
            // Only wait for asset loading if we don't have manual tracks
            let asset = self.playerItem?.asset ?? self.videoAsset
            let status = asset.statusOfValue(forKey: "availableMediaCharacteristicsWithMediaSelectionOptions", error: nil)
            if status == .unknown || status == .loading {
                asset.loadValuesAsynchronously(forKeys: ["availableMediaCharacteristicsWithMediaSelectionOptions", "tracks"]) { [weak self] in
                    DispatchQueue.main.async {
                        self?.showSubtitleMenuAfterLoading()
                    }
                }
                return
            }
            
            self.showSubtitleMenuAfterLoading()
        }
    }
    
    private func showSubtitleMenuAfterLoading() {
        let alertController = UIAlertController(title: "Select Subtitle", message: nil, preferredStyle: .actionSheet)
        
        // Add "Off" option
        let offAction = UIAlertAction(title: "Off", style: .default) { [weak self] _ in
            self?.selectSubtitleTrack(trackId: nil)
        }
        alertController.addAction(offAction)
        
        // Get all available subtitle tracks (manual + native)
        let allTracks = getAllAvailableSubtitleTracks()
        
        if allTracks.isEmpty {
            let noTracksAction = UIAlertAction(title: "No subtitles available", style: .default)
            alertController.addAction(noTracksAction)
        } else {
            // Add track options
            for track in allTracks {
                let trackId = track["id"] as? String ?? ""
                let label = track["label"] as? String ?? track["language"] as? String ?? trackId
                let isSelected = track["isSelected"] as? Bool ?? false
                let isNative = track["isNative"] as? Bool ?? false
                
                let displayLabel = isSelected ? "\(label) ✓" : label
                let action = UIAlertAction(title: displayLabel, style: .default) { [weak self] _ in
                    if isNative {
                        self?.selectNativeSubtitleTrack(localeIdentifier: track["locale"] as? String)
                    } else {
                        self?.selectSubtitleTrack(trackId: trackId)
                    }
                }
                alertController.addAction(action)
            }
        }
        
        // Add cancel
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alertController.addAction(cancelAction)
        
        // Present from the video player view controller
        let presentingVC = self.videoPlayer
        
        // For iPad, set the popover presentation
        if let popover = alertController.popoverPresentationController {
            if let button = self.subtitleButton {
                popover.sourceView = button
                popover.sourceRect = button.bounds
            } else {
                popover.sourceView = self.videoPlayer.view
                popover.sourceRect = CGRect(x: self.videoPlayer.view.bounds.width - 100, y: 20, width: 100, height: 44)
            }
        }
        
        // Present on main thread
        if Thread.isMainThread {
            presentingVC.present(alertController, animated: true)
        } else {
            DispatchQueue.main.async {
                presentingVC.present(alertController, animated: true)
            }
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
        } catch {
            // Fallback configuration
            self.configureAudioSessionFallback()
        }
    }
    
    private func configureAudioSessionFallback() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
        } catch {
            // Ignore fallback errors
        }
    }
    
    private func cleanupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            self.player?.pause()
            Thread.sleep(forTimeInterval: 0.1)
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            try audioSession.setCategory(.ambient, mode: .default, options: [])
        } catch {
            // Force deactivation
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setActive(false)
            } catch {
                // Ignore errors
            }
        }
    }
    
    // MARK: - Auto-play for HLS streams
    
    private func autoPlayIfHLSReady() {
        let isHLSStream = self.isHLSStream(url: self._url)
        
        if isHLSStream {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.player?.play()
                self.player?.rate = self._videoRate
                self.isPlaying = true
                
                let vId: [String: Any] = [
                    "fromPlayerId": self._videoId,
                    "currentTime": self._currentTime,
                    "videoRate": self._videoRate
                ]
                NotificationCenter.default.post(name: .playerItemPlay, object: nil, userInfo: vId)
            }
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
                                
                                // Check for native subtitle tracks and add button if available
                                // Load the asset's media characteristics first
                                let asset = self.playerItem?.asset ?? self.videoAsset
                                asset.loadValuesAsynchronously(forKeys: ["availableMediaCharacteristicsWithMediaSelectionOptions"]) { [weak self] in
                                    DispatchQueue.main.async {
                                        guard let self = self else { return }
                                        // Check again after loading
                                        if self._subtitleTracks == nil || self._subtitleTracks?.isEmpty == true {
                                            if self.hasNativeSubtitleTracks() {
                                                self.addSubtitleSelectionButton()
                                            }
                                        }
                                    }
                                }
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
        // Cancel subtitle button timers
        self.subtitleButtonHideTimer?.invalidate()
        self.subtitleButtonHideTimer = nil
        self.subtitleButtonVisibilityTimer?.invalidate()
        self.subtitleButtonVisibilityTimer = nil
        
        // Remove tap gesture
        if let tapGesture = self.subtitleButtonTapGesture {
            self.videoPlayer.view.removeGestureRecognizer(tapGesture)
        }
        self.subtitleButtonTapGesture = nil
        
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
    }
    
    deinit {
        self.removeObservers()
    }
    
    // MARK: - Public cleanup method for manual disposal
    
    @objc func cleanup() {
        self.removeObservers()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            autoreleasepool {
                // Force garbage collection
            }
        }
    }

    // MARK: - Required init

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    // MARK: - Set-up Public functions

    @objc func play() {
        self.configureAudioSession()
        self.isPlaying = true
        self.player?.play()
        self.player?.rate = _videoRate
    }
    @objc func pause() {
        self.isPlaying = false
        self.player?.pause()
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
    
    private func hasNativeSubtitleTracks() -> Bool {
        guard let playerItem = self.playerItem else { return false }
        let asset = playerItem.asset
        
        // Check if legible tracks are available (this doesn't require loading)
        let availableCharacteristics = asset.availableMediaCharacteristicsWithMediaSelectionOptions
        guard availableCharacteristics.contains(.legible) else { return false }
        
        // Try to get the media selection group (this might return nil if tracks aren't loaded yet)
        guard let mediaSelectionGroup = asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return false
        }
        return !mediaSelectionGroup.options.isEmpty
    }
    
    private func getAllAvailableSubtitleTracks() -> [[String: Any]] {
        var allTracks: [[String: Any]] = []
        
        // Add manually provided tracks FIRST (these take priority)
        if let manualTracks = _subtitleTracks, !manualTracks.isEmpty {
            for track in manualTracks {
                let trackId = track["id"] as? String ?? ""
                let language = track["language"] as? String ?? ""
                let label = track["label"] as? String ?? (language.isEmpty ? trackId : language)
                let trackInfo: [String: Any] = [
                    "id": trackId,
                    "language": language,
                    "label": label,
                    "isSelected": trackId == (_activeSubtitleTrackId ?? _selectedSubtitleId),
                    "isAvailable": true,
                    "isNative": false
                ]
                allTracks.append(trackInfo)
            }
        }
        
        // Add native subtitle tracks from AVFoundation
        // Check the original videoAsset, not the composition
        let asset = self.videoAsset
        let availableCharacteristics = asset.availableMediaCharacteristicsWithMediaSelectionOptions
        
        if availableCharacteristics.contains(.legible),
           let mediaSelectionGroup = asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            
            let currentlySelectedOption = self.playerItem?.currentMediaSelection.selectedMediaOption(in: mediaSelectionGroup)
            
            for option in mediaSelectionGroup.options {
                // Skip closed captions that are marked as containing only forced subtitles
                if option.hasMediaCharacteristic(.containsOnlyForcedSubtitles) && mediaSelectionGroup.options.count > 1 {
                    continue
                }
                
                let localeId = option.locale?.identifier ?? option.extendedLanguageTag ?? ""
                let languageCode = option.locale?.languageCode ?? ""
                let displayName = option.displayName
                
                // Skip if this option is already in manual tracks (avoid duplicates)
                let isDuplicate = allTracks.contains { track in
                    let trackLanguage = track["language"] as? String ?? ""
                    let trackId = track["id"] as? String ?? ""
                    return (track["locale"] as? String) == localeId ||
                           trackId == localeId ||
                           (trackLanguage == languageCode && !languageCode.isEmpty)
                }
                
                if !isDuplicate {
                    let isSelected = option == currentlySelectedOption
                    
                    // Use display name if available, otherwise use language code
                    let label: String
                    if !displayName.isEmpty {
                        label = displayName
                    } else if !languageCode.isEmpty {
                        if let locale = option.locale {
                            label = locale.localizedString(forLanguageCode: languageCode)?.capitalized ?? languageCode.uppercased()
                        } else {
                            label = languageCode.uppercased()
                        }
                    } else if !localeId.isEmpty {
                        label = localeId
                    } else {
                        label = "Unknown"
                    }
                    
                    let trackInfo: [String: Any] = [
                        "id": localeId.isEmpty ? (languageCode.isEmpty ? "native-\(allTracks.count)" : languageCode) : localeId,
                        "language": languageCode,
                        "label": label,
                        "locale": localeId,
                        "isSelected": isSelected,
                        "isAvailable": true,
                        "isNative": true
                    ]
                    allTracks.append(trackInfo)
                }
            }
        }
        
        return allTracks
    }

    func getSubtitleTracks() -> [[String: Any]]? {
        let allTracks = getAllAvailableSubtitleTracks()
        return allTracks.isEmpty ? nil : allTracks
    }

    func selectSubtitleTrack(trackId: String?) {
        _activeSubtitleTrackId = trackId
        
        // For HLS streams, the subtitle display will automatically switch
        // because the time observer uses _activeSubtitleTrackId
        if isHLSStream(url: self._url) {
            if trackId == nil {
                subtitleLabel?.isHidden = true
            } else {
                subtitleLabel?.isHidden = false
            }
        } else {
            // For non-HLS, try to use AVMediaSelectionGroup for native tracks first
            guard let playerItem = self.playerItem else { return }
            
            if let trackId = trackId {
                // First, try to find in native tracks
                if let mediaSelectionGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
                    // Try to find matching option by locale identifier, language code, or display name
                    let options = mediaSelectionGroup.options.filter { option in
                        return option.locale?.identifier == trackId ||
                               option.extendedLanguageTag == trackId ||
                               option.locale?.languageCode == trackId ||
                               option.displayName == trackId
                    }
                    if let option = options.first {
                        playerItem.select(option, in: mediaSelectionGroup)
                        return
                    }
                }
                
                // If not found in native tracks, check manual tracks
                // For manual tracks with custom subtitle files, we use the custom label display
                // This is already handled by the HLS path above for HLS streams
                if _subtitleTracks != nil {
                    // For non-HLS manual tracks, the subtitle is already loaded in the composition
                    // The track switching would require re-creating the composition, which is complex
                    // For now, we'll rely on the initial track selection
                }
            } else {
                // Disable subtitles - try native first, then custom
                if let mediaSelectionGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
                    playerItem.select(nil, in: mediaSelectionGroup)
                }
                subtitleLabel?.isHidden = true
            }
        }
    }
    
    private func selectNativeSubtitleTrack(localeIdentifier: String?) {
        guard let playerItem = self.playerItem,
              let localeIdentifier = localeIdentifier,
              let mediaSelectionGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return
        }
        
        // Find the option matching the locale identifier
        let options = mediaSelectionGroup.options.filter { option in
            return option.locale?.identifier == localeIdentifier
        }
        
        if let option = options.first {
            playerItem.select(option, in: mediaSelectionGroup)
            _activeSubtitleTrackId = localeIdentifier
        }
    }

    func getSelectedSubtitleTrack() -> String? {
        return _activeSubtitleTrackId ?? _selectedSubtitleId
    }
}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
