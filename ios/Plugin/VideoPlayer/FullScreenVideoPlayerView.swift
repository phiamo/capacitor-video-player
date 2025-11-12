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
    private var _videoHeaders: [String: String]? // Store video headers for subtitle fallback
    private var _videoRate: Float
    private var _showControls: Bool = true
    private var _displayMode: String = "all"
    private var _title: String?
    private var _smallTitle: String?
    private var _artwork: String?
    private var _subtitleTracks: [[String: Any]]?
    private var _selectedSubtitleId: String?

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

    init(url: URL, rate: Float, playerId: String, exitOnEnd: Bool,
         loopOnEnd: Bool, pipEnabled: Bool, showControls: Bool,
         displayMode: String, stUrl: URL?, stLanguage: String?,
         stHeaders: [String: String]?, stOptions: [String: Any]?,
         title: String?, smallTitle: String?, artwork: String?,
         subtitleTracks: [[String: Any]]?,
         selectedSubtitleId: String?) {
        //self._videoPath = videoPath
        self._url = url
        self._subtitleTracks = subtitleTracks
        self._selectedSubtitleId = selectedSubtitleId
        // Handle multiple subtitle tracks or backward compatibility
        if let tracks = subtitleTracks, !tracks.isEmpty {
            // New API: multiple subtitle tracks
            self._subtitleTracks = tracks
            // Set first track URL for backward compatibility with existing code
            if let firstTrack = tracks[0]["url"] as? String {
                self._stUrl = URL(string: firstTrack)
            }
            if let firstLanguage = tracks[0]["language"] as? String {
                self._stLanguage = firstLanguage
            }
        } else {
            // Backward compatibility: single subtitle
            self._stUrl = stUrl
            self._stLanguage = stLanguage
        }
        self._stOptions = stOptions
        self._exitOnEnd = exitOnEnd
        self._loopOnEnd = loopOnEnd
        self._pipEnabled = pipEnabled
        self._videoId = playerId
        self._videoRate = rate
        self._stHeaders = stHeaders // Subtitle-specific headers (if any)
        self._videoHeaders = stHeaders // Video headers (same as subtitle headers for now, but can be separated later)
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

        // Store video headers for potential use with subtitles
        if let headers = self._videoHeaders {
            print("🎬 Video asset created with headers:")
            for (key, value) in headers {
                let maskedValue = (key.lowercased().contains("token") || key.lowercased().contains("auth")) 
                    ? "***\(String(value.suffix(4)))" 
                    : value
                print("   \(key): \(maskedValue)")
            }
            self.videoAsset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        } else {
            print("🎬 Video asset created without headers")
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
          let isHLS = self.isHLSStream(url: self._url)
          
          if isHLS {
              self.loadVideoAssetWithSubtitlesForHLS(subtitleTracks: tracks)
          } else {
              // Non-HLS: Load tracks first, then create composition
              self.videoAsset.loadValuesAsynchronously(forKeys: ["tracks", "duration"]) { [weak self] in
                  guard let self = self else { return }
                  DispatchQueue.main.async {
                      let videoTracks = self.videoAsset.tracks(withMediaType: AVMediaType.video)
                      guard !videoTracks.isEmpty else {
                          self.playerItem = AVPlayerItem(asset: self.videoAsset)
                          self.player = AVPlayer(playerItem: self.playerItem)
                          self.setupPlayer()
                          return
                      }
                      self.createPlayerWithSubtitles(
                          videoTracks: videoTracks,
                          subtitleTracks: tracks
                      )
                  }
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
                self.createPlayerWithSubtitles(subTitleUrl: subTitleUrl, videoTracks: videoTracks)
                }
            }
        }
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
            
            // Create subtitle label that shows/hides based on timing
            let subtitleLabel = UILabel()
            subtitleLabel.textColor = UIColor.white
            subtitleLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            subtitleLabel.textAlignment = .center
            subtitleLabel.font = UIFont.systemFont(ofSize: 16)
            subtitleLabel.numberOfLines = 0
            subtitleLabel.isHidden = true  // Start hidden
            subtitleLabel.alpha = 0.0       // Start transparent
            
            // Add to the video player's content overlay view with delay to ensure proper layout
            if let contentOverlayView = self.videoPlayer.contentOverlayView {
                contentOverlayView.addSubview(subtitleLabel)
                subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
                
                // Wait for the view to have proper dimensions before setting constraints
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Use more flexible constraints to avoid conflicts
                    NSLayoutConstraint.activate([
                        subtitleLabel.centerXAnchor.constraint(equalTo: contentOverlayView.centerXAnchor),
                        subtitleLabel.bottomAnchor.constraint(equalTo: contentOverlayView.bottomAnchor, constant: -50),
                        subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentOverlayView.leadingAnchor, constant: 20),
                        subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentOverlayView.trailingAnchor, constant: -20),
                        subtitleLabel.widthAnchor.constraint(lessThanOrEqualTo: contentOverlayView.widthAnchor, constant: -40)
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
                guard let self = self else { return }
                
                let currentTime = time.seconds
                let currentSubtitle = self.findSubtitleForTime(currentTime, subtitles: subtitles)
                
                // Only update if subtitle text has changed
                let newText = currentSubtitle?.text ?? ""
                if newText != currentDisplayedSubtitle {
                    subtitleLabel.text = newText
                    currentDisplayedSubtitle = newText
                    
                    if !newText.isEmpty {
                        // Show subtitle instantly
                        subtitleLabel.isHidden = false
                        subtitleLabel.alpha = 1.0
                        print("Subtitle: \(newText)")
                    } else {
                        // Hide subtitle instantly
                        subtitleLabel.isHidden = true
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
    
    // MARK: - Multiple Subtitle Tracks Support
    
    private func loadVideoAssetWithSubtitlesForHLS(subtitleTracks: [[String: Any]]) {
        print("🎬 Loading HLS stream with multiple subtitle tracks...")
        print("   Subtitle tracks count: \(subtitleTracks.count)")
        for (index, track) in subtitleTracks.enumerated() {
            print("   Track \(index): id=\(track["id"] ?? "nil"), url=\(track["url"] ?? "nil"), lang=\(track["language"] ?? "nil")")
        }
        
        // Load HLS asset tracks
        self.videoAsset.loadValuesAsynchronously(forKeys: ["tracks", "duration"]) { [weak self] in
            guard let self = self else {
                print("⚠️ loadVideoAssetWithSubtitlesForHLS: self is nil")
                return
            }
            
            DispatchQueue.main.async {
                print("📹 HLS asset loaded, checking tracks...")
                
                // For HLS streams, tracks may not be immediately available
                // We need to wait for the player item to be ready before accessing tracks
                // So we'll create the composition differently for HLS
                
                // First, try to get tracks (they might be available)
                let videoTracks = self.videoAsset.tracks(withMediaType: .video)
                let audioTracks = self.videoAsset.tracks(withMediaType: .audio)
                
                print("   Video tracks: \(videoTracks.count)")
                print("   Audio tracks: \(audioTracks.count)")
                
                // For HLS streams with external subtitles, we need to create a composition
                // that includes both the video/audio tracks AND the external subtitle tracks
                // This allows them to appear in the native iOS subtitle selection menu
                
                if videoTracks.isEmpty {
                    print("   ℹ️ Video tracks not immediately available (common for HLS)")
                    print("   Creating player with original asset, will add subtitles when tracks load")
                    
                    // For HLS, create player item with original asset first
                    // Then observe when tracks become available and add subtitles
                    self.playerItem = AVPlayerItem(asset: self.videoAsset)
                    self.playerItem?.textStyleRules = self.getTextStyleRules()
                    self.player = AVPlayer(playerItem: self.playerItem)
                    self.videoPlayer.player = self.player
                    self.setupPlayer()
                    
                    // For HLS, we need to wait for the player item's tracks to become available
                    // The asset tracks might be empty, but player item tracks will load
                    self.itemStatusObserver = self.playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
                        guard let self = self else { return }
                        if item.status == .readyToPlay {
                            print("📹 Player item is ready, checking for tracks...")
                            
                            // Check player item tracks (these are what actually matter for HLS)
                            let playerItemVideoTracks = item.tracks.filter { $0.assetTrack?.mediaType == .video }
                            let assetVideoTracks = self.videoAsset.tracks(withMediaType: .video)
                            
                            print("   Player item video tracks: \(playerItemVideoTracks.count)")
                            print("   Asset video tracks: \(assetVideoTracks.count)")
                            
                            // For HLS, player item tracks are what matter, not asset tracks
                            // If player item has video tracks, we can create composition
                            if !playerItemVideoTracks.isEmpty {
                                print("📹 Player item has video tracks! Creating composition with all subtitle tracks...")
                                // Use player item tracks to create composition
                                self.createCompositionFromPlayerItemTracks(subtitleTracks: subtitleTracks)
                            } else if !assetVideoTracks.isEmpty {
                                print("📹 Asset has video tracks, creating composition...")
                                self.createAndReplacePlayerItemWithSubtitles(subtitleTracks: subtitleTracks)
                            } else {
                                // Still no tracks - wait a bit more and try again
                                print("⏳ No tracks yet, waiting 2 seconds and retrying...")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                                    guard let self = self else { return }
                                    // Check player item tracks again (they might be available now)
                                    if let item = self.playerItem, item.status == .readyToPlay {
                                        let playerItemVideoTracks = item.tracks.filter { $0.assetTrack?.mediaType == .video }
                                        if !playerItemVideoTracks.isEmpty {
                                            print("📹 Player item tracks available after retry, creating composition...")
                                            self.createCompositionFromPlayerItemTracks(subtitleTracks: subtitleTracks)
                                            return
                                        }
                                    }
                                    
                                    let retryVideoTracks = self.videoAsset.tracks(withMediaType: .video)
                                    if !retryVideoTracks.isEmpty {
                                        print("📹 Asset tracks available after retry, creating composition...")
                                        self.createAndReplacePlayerItemWithSubtitles(subtitleTracks: subtitleTracks)
                                    } else {
                                        print("⚠️ Still no video tracks - HLS may need more time")
                                        print("   Video will continue playing with original player item")
                                        print("   Will keep retrying to add subtitles when tracks become available")
                                        // Keep retrying - don't replace player item yet (would break playback)
                                        self.createCompositionWithSubtitlesEvenIfNoTracks(subtitleTracks: subtitleTracks)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Also try periodically to add subtitles when tracks become available
                    var retryCount = 0
                    let maxRetries = 5
                    func tryAddSubtitles() {
                        guard retryCount < maxRetries else {
                            print("⚠️ Max retries reached, using fallback subtitle method")
                            self.setupMultipleSubtitlesWithAVPlayerViewControllerSubtitles(subtitleTracks: subtitleTracks)
                            return
                        }
                        retryCount += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount) * 0.5) { [weak self] in
                            guard let self = self else { return }
                            let availableVideoTracks = self.videoAsset.tracks(withMediaType: .video)
                            if !availableVideoTracks.isEmpty {
                                print("📹 Video tracks available after retry \(retryCount), creating composition...")
                                self.createAndReplacePlayerItemWithSubtitles(subtitleTracks: subtitleTracks)
                            } else {
                                tryAddSubtitles()
                            }
                        }
                    }
                    tryAddSubtitles()
                } else {
                    // Video tracks are available, create composition with subtitles
                    print("🔨 Creating composition with multiple subtitle tracks...")
                    self.createAndReplacePlayerItemWithSubtitles(subtitleTracks: subtitleTracks)
                }
            }
        }
    }
    
    // MARK: - Create and Replace Player Item with Subtitles
    
    /// Creates a composition using tracks from the player item (for HLS streams)
    /// This is needed because HLS tracks might only be available through player item, not asset
    private func createCompositionFromPlayerItemTracks(subtitleTracks: [[String: Any]]) {
        print("🔨 Creating composition from player item tracks (HLS)...")
        
        guard let playerItem = self.playerItem else {
            print("❌ Player item is nil")
            return
        }
        
        // Get video and audio tracks from player item
        let playerItemVideoTracks = playerItem.tracks.compactMap { $0.assetTrack }.filter { $0.mediaType == .video }
        let playerItemAudioTracks = playerItem.tracks.compactMap { $0.assetTrack }.filter { $0.mediaType == .audio }
        
        print("   Player item video tracks: \(playerItemVideoTracks.count)")
        print("   Player item audio tracks: \(playerItemAudioTracks.count)")
        
        guard !playerItemVideoTracks.isEmpty else {
            print("❌ No video tracks in player item")
            return
        }
        
        // Create composition with video/audio from player item + subtitle tracks
        if let composition = self.createCompositionWithPlayerItemTracks(
            videoTracks: playerItemVideoTracks,
            audioTracks: playerItemAudioTracks,
            subtitleTracks: subtitleTracks
        ) {
            print("✅ Composition created successfully with all tracks")
            
            // Create new player item with composition
            let newPlayerItem = AVPlayerItem(asset: composition)
            newPlayerItem.textStyleRules = self.getTextStyleRules()
            
            // Replace current player item
            if let currentPlayer = self.player {
                currentPlayer.replaceCurrentItem(with: newPlayerItem)
                self.playerItem = newPlayerItem
                
                // Set initial track selection after player item is ready
                self.setInitialSubtitleSelection()
                
                print("✅ Player item replaced with composition containing \(subtitleTracks.count) subtitle tracks")
                print("   Subtitles should now appear in native iOS subtitle selection menu")
            }
        } else {
            print("❌ Failed to create composition from player item tracks")
        }
    }
    
    /// Creates a composition with video/audio tracks + external subtitle tracks
    /// and replaces the current player item. This makes subtitles appear in native iOS menu.
    private func createAndReplacePlayerItemWithSubtitles(subtitleTracks: [[String: Any]]) {
        print("🔨 Creating composition with video/audio + subtitle tracks for native menu...")
        
        // Get available tracks from the asset
        let videoTracks = self.videoAsset.tracks(withMediaType: .video)
        
        guard !videoTracks.isEmpty else {
            print("❌ No video tracks available, cannot create composition")
            return
        }
        
        // Create composition with video/audio + subtitle tracks
        if let composition = self.createCompositionWithMultipleSubtitlesForHLS(
            videoAsset: self.videoAsset,
            subtitleTracks: subtitleTracks
        ) {
            print("✅ Composition created successfully with subtitles")
            
            // Create new player item with composition
            let newPlayerItem = AVPlayerItem(asset: composition)
            newPlayerItem.textStyleRules = self.getTextStyleRules()
            
            // Replace current player item
            if let currentPlayer = self.player {
                currentPlayer.replaceCurrentItem(with: newPlayerItem)
                self.playerItem = newPlayerItem
                
                // Set initial track selection after player item is ready
                self.setInitialSubtitleSelection()
                
                print("✅ Player item replaced with composition containing subtitle tracks")
                print("   Subtitles should now appear in native iOS subtitle selection menu")
            }
        } else {
            print("❌ Failed to create composition with subtitles")
        }
    }
    
    /// Creates a composition with subtitle tracks even when video tracks aren't available yet
    /// For HLS streams, we need to wait for video tracks or the composition won't play
    /// This method will keep retrying until tracks are available
    /// IMPORTANT: Does NOT replace player item until video tracks are available (to keep video playing)
    private func createCompositionWithSubtitlesEvenIfNoTracks(subtitleTracks: [[String: Any]]) {
        print("🔨 Attempting to create composition with subtitle tracks...")
        print("   ⚠️ Video tracks not yet available - will keep retrying")
        print("   ⚠️ Player item will NOT be replaced until video tracks are available (to keep video playing)")
        
        // Keep retrying to get video tracks
        var retryCount = 0
        let maxRetries = 10
        
        func tryCreateComposition() {
            guard retryCount < maxRetries else {
                print("❌ Max retries reached - video tracks never became available")
                print("   Video will continue playing with original player item")
                print("   Using fallback subtitle method (only first track will work)")
                self.setupMultipleSubtitlesWithAVPlayerViewControllerSubtitles(subtitleTracks: subtitleTracks)
                return
            }
            
            retryCount += 1
            let delay = Double(retryCount) * 0.5 // Increasing delay: 0.5s, 1s, 1.5s, etc.
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                
                // Reload asset tracks
                self.videoAsset.loadValuesAsynchronously(forKeys: ["tracks"]) {
                    DispatchQueue.main.async {
                        let videoTracks = self.videoAsset.tracks(withMediaType: .video)
                        print("   Retry \(retryCount)/\(maxRetries): Video tracks: \(videoTracks.count)")
                        
                        if !videoTracks.isEmpty {
                            print("✅ Video tracks now available! Creating composition with all subtitle tracks...")
                            self.createAndReplacePlayerItemWithSubtitles(subtitleTracks: subtitleTracks)
                        } else {
                            // Try again
                            tryCreateComposition()
                        }
                    }
                }
            }
        }
        
        tryCreateComposition()
    }
    
    /// Fallback: Uses AVPlayerViewControllerSubtitles library for external subtitles
    /// when video tracks aren't available (rare case)
    private func setupMultipleSubtitlesWithAVPlayerViewControllerSubtitles(subtitleTracks: [[String: Any]]) {
        print("📝 Setting up multiple subtitles using AVPlayerViewControllerSubtitles...")
        print("   ⚠️ This fallback only supports one subtitle track")
        print("   For multiple tracks, composition method should be used")
        
        // For now, just use the first subtitle track
        // AVPlayerViewControllerSubtitles may need to be extended for multiple tracks
        if let firstTrack = subtitleTracks.first,
           let trackUrlString = firstTrack["url"] as? String {
            
            // Resolve URL
            var trackUrl: URL?
            if trackUrlString.hasPrefix("http://") || trackUrlString.hasPrefix("https://") {
                trackUrl = URL(string: trackUrlString)
            } else if trackUrlString.hasPrefix("file://") {
                trackUrl = URL(string: trackUrlString)
            } else {
                trackUrl = URL(fileURLWithPath: trackUrlString)
            }
            
            if let subtitleUrl = trackUrl {
                print("   Using first subtitle track: \(subtitleUrl.absoluteString)")
                self.addSubtitlesToPlayer(subTitleUrl: subtitleUrl)
            }
        }
        
        // Set initial track selection
        self.setInitialSubtitleSelection()
    }
    
    private func createPlayerWithSubtitles(
        videoTracks: [AVAssetTrack],
        subtitleTracks: [[String: Any]]
    ) {
        let audioTracks = self.videoAsset.tracks(withMediaType: .audio)
        
        if let composition = self.createCompositionWithMultipleSubtitles(
            videoTracks: videoTracks,
            audioTracks: audioTracks,
            subtitleTracks: subtitleTracks
        ) {
            self.playerItem = AVPlayerItem(asset: composition)
            self.playerItem?.textStyleRules = self.getTextStyleRules()
            self.player = AVPlayer(playerItem: self.playerItem)
            self.setupPlayer()
            
            // Set initial track selection
            self.setInitialSubtitleSelection()
        } else {
            // Fallback
            self.playerItem = AVPlayerItem(asset: self.videoAsset)
            self.player = AVPlayer(playerItem: self.playerItem)
            self.setupPlayer()
        }
    }
    
    private func createCompositionWithMultipleSubtitlesForHLS(
        videoAsset: AVURLAsset,
        subtitleTracks: [[String: Any]]
    ) -> AVMutableComposition? {
        print("🔧 createCompositionWithMultipleSubtitlesForHLS called")
        print("   Input: \(subtitleTracks.count) subtitle tracks")
        print("   Video asset URL: \(videoAsset.url.absoluteString)")
        
        // For HLS, we need to use AVMutableCompositionTrack to reference the original asset
        // We can't directly copy tracks from HLS because they load asynchronously
        // Instead, we'll create a composition that references the original asset and adds subtitle tracks
        
        let composition = AVMutableComposition()
        
        // Get available tracks from the asset (may be empty initially for HLS)
        let videoTracks = videoAsset.tracks(withMediaType: .video)
        let audioTracks = videoAsset.tracks(withMediaType: .audio)
        
        print("   Available video tracks: \(videoTracks.count)")
        print("   Available audio tracks: \(audioTracks.count)")
        
        // If tracks are available, add them to composition
        if !videoTracks.isEmpty {
            guard let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                print("❌ Failed to create video track in composition")
                return nil
            }
            
            do {
                let duration = videoAsset.duration
                if duration.isValid && !duration.isIndefinite {
                    try compositionVideoTrack.insertTimeRange(
                        CMTimeRangeMake(start: .zero, duration: duration),
                        of: videoTracks[0],
                        at: .zero
                    )
                    print("✅ Video track added to composition")
                } else {
                    print("⚠️ Video asset duration is invalid, using estimated duration")
                    // For HLS, duration might not be available yet
                    // Use a large time range and let it adjust
                    let estimatedDuration = CMTimeMake(value: 3600, timescale: 1) // 1 hour estimate
                    try compositionVideoTrack.insertTimeRange(
                        CMTimeRangeMake(start: .zero, duration: estimatedDuration),
                        of: videoTracks[0],
                        at: .zero
                    )
                    print("✅ Video track added to composition (estimated duration)")
                }
            } catch {
                print("❌ Failed to insert video track: \(error)")
                return nil
            }
        } else {
            print("⚠️ No video tracks available yet - HLS tracks load asynchronously")
            print("   Will create composition with subtitles only, video will be added when tracks load")
        }
        
        // Add audio track if exists
        if !audioTracks.isEmpty,
           let compositionAudioTrack = composition.addMutableTrack(
               withMediaType: .audio,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            do {
                let duration = videoAsset.duration
                let durationToUse = duration.isValid && !duration.isIndefinite 
                    ? duration 
                    : CMTimeMake(value: 3600, timescale: 1)
                try compositionAudioTrack.insertTimeRange(
                    CMTimeRangeMake(start: .zero, duration: durationToUse),
                    of: audioTracks[0],
                    at: .zero
                )
                print("✅ Audio track added to composition")
            } catch {
                print("⚠️ Failed to insert audio track: \(error)")
            }
        }
            
        // Add all subtitle tracks
        // Load all subtitle assets first, then add to composition
        print("📝 Processing \(subtitleTracks.count) subtitle tracks...")
        let dispatchGroup = DispatchGroup()
        var subtitleAssets: [(asset: AVURLAsset, trackId: String, language: String)] = []
        
        // First, resolve all URLs and create assets
        for (index, trackDict) in subtitleTracks.enumerated() {
            print("   Processing track \(index + 1)/\(subtitleTracks.count)...")
            guard let trackUrlString = trackDict["url"] as? String,
                  let trackId = trackDict["id"] as? String,
                  let language = trackDict["language"] as? String else {
                continue
            }
            
            // Resolve subtitle URL using same logic as video URL resolution
            var trackUrl: URL?
            if trackUrlString.hasPrefix("http://") || trackUrlString.hasPrefix("https://") {
                trackUrl = URL(string: trackUrlString)
            } else if trackUrlString.hasPrefix("public/assets") {
                if let appFolder = Bundle.main.resourceURL {
                    trackUrl = appFolder.appendingPathComponent(trackUrlString)
                }
            } else if trackUrlString.hasPrefix("application") {
                let docPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                let path = String(trackUrlString.dropFirst(12))
                let vPath = docPath.appendingFormat("/\(path)")
                trackUrl = URL(fileURLWithPath: vPath)
            } else if trackUrlString.hasPrefix("file://") {
                trackUrl = URL(string: trackUrlString)
            } else {
                // Try as direct file path
                trackUrl = URL(fileURLWithPath: trackUrlString)
            }
                
            guard let subtitleUrl = trackUrl else {
                print("❌ Failed to resolve subtitle URL for track: \(trackId)")
                continue
            }
            print("   ✅ Resolved URL for track \(trackId): \(subtitleUrl.absoluteString)")
            
            // Check if SRT and convert to VTT if needed, or add language metadata to VTT
            let finalUrl: URL
            if subtitleUrl.pathExtension.lowercased() == "srt" {
                print("   🔄 Converting SRT to VTT for track: \(trackId)")
                if let vttUrl = self.convertSRTToWebVTT(srtURL: subtitleUrl, language: language) {
                    finalUrl = vttUrl
                    print("   ✅ SRT converted to VTT: \(vttUrl.absoluteString)")
                } else {
                    print("❌ Failed to convert SRT to VTT for track: \(trackId)")
                    continue
                }
            } else if subtitleUrl.pathExtension.lowercased() == "vtt" {
                // Ensure VTT file has language metadata
                print("   🔍 Ensuring VTT has language metadata for track: \(trackId)")
                if let vttUrl = self.ensureVTTLanguageMetadata(vttURL: subtitleUrl, language: language) {
                    finalUrl = vttUrl
                    print("   ✅ VTT language metadata ensured: \(vttUrl.absoluteString)")
                } else {
                    finalUrl = subtitleUrl
                    print("   ⚠️ Could not add language metadata, using original VTT")
                }
            } else {
                finalUrl = subtitleUrl
                print("   ℹ️ Using subtitle file as-is (extension: \(subtitleUrl.pathExtension))")
            }
            
            // Create asset with headers if available
            // Use subtitle headers if provided, otherwise fall back to video headers
            // This is important for auth - subtitles often need the same auth headers as video
            let headersToUse: [String: String]?
            if let stHeaders = self._stHeaders {
                headersToUse = stHeaders
                print("   🔐 Using subtitle-specific headers for download:")
            } else if let videoHeaders = self._videoHeaders {
                // Fallback to video headers - subtitles often need same auth
                headersToUse = videoHeaders
                print("   🔐 Using video headers for subtitle download (fallback):")
                print("      Note: Subtitles will use same auth headers as video")
            } else {
                headersToUse = nil
                print("   ⚠️ No headers provided for subtitle download")
                print("      This may cause authentication failures if subtitle server requires auth")
                print("      Subtitle URL: \(finalUrl.absoluteString)")
            }
            
            let subtitleAsset: AVURLAsset
            if let headers = headersToUse {
                for (key, value) in headers {
                    // Mask sensitive tokens in logs
                    let maskedValue = (key.lowercased().contains("token") || key.lowercased().contains("auth")) 
                        ? "***\(String(value.suffix(4)))" 
                        : value
                    print("      \(key): \(maskedValue)")
                }
                subtitleAsset = AVURLAsset(url: finalUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            } else {
                subtitleAsset = AVURLAsset(url: finalUrl)
            }
            
            print("   📥 Created AVURLAsset for track \(trackId)")
            subtitleAssets.append((asset: subtitleAsset, trackId: trackId, language: language))
        }
        
        print("📦 Starting async load for \(subtitleAssets.count) subtitle assets...")
        
        // Load all subtitle assets asynchronously
        for subtitleInfo in subtitleAssets {
            dispatchGroup.enter()
            print("   ⏳ Loading subtitle asset for track: \(subtitleInfo.trackId) from \(subtitleInfo.asset.url.absoluteString)")
            
            // Check if URL is accessible before loading
            if subtitleInfo.asset.url.isFileURL {
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: subtitleInfo.asset.url.path) {
                    print("   ❌ Subtitle file does not exist at path: \(subtitleInfo.asset.url.path)")
                    dispatchGroup.leave()
                    continue
                } else {
                    print("   ✅ Subtitle file exists at path: \(subtitleInfo.asset.url.path)")
                }
            } else {
                print("   🌐 Subtitle is remote URL, will download")
            }
            
            subtitleInfo.asset.loadValuesAsynchronously(forKeys: ["tracks", "duration", "availableMediaCharacteristicsWithMediaSelectionOptions"]) {
                defer { dispatchGroup.leave() }
                
                var error: NSError?
                let tracksStatus = subtitleInfo.asset.statusOfValue(forKey: "tracks", error: &error)
                
                if let loadError = error {
                    print("   ❌ Error loading subtitle asset for track \(subtitleInfo.trackId):")
                    print("      URL: \(subtitleInfo.asset.url.absoluteString)")
                    print("      Error domain: \(loadError.domain)")
                    print("      Error code: \(loadError.code)")
                    print("      Error description: \(loadError.localizedDescription)")
                    
                    // Check for HTTP errors (common auth issues)
                    if let underlyingError = loadError.userInfo[NSUnderlyingErrorKey] as? NSError {
                        print("      Underlying error: \(underlyingError.localizedDescription)")
                        print("      Underlying error domain: \(underlyingError.domain)")
                        print("      Underlying error code: \(underlyingError.code)")
                        
                        // Check for HTTP status codes in underlying error
                        if let httpStatusCode = underlyingError.userInfo["HTTPStatusCode"] as? Int {
                            print("      HTTP Status Code: \(httpStatusCode)")
                            if httpStatusCode == 401 {
                                print("      ⚠️ AUTHENTICATION FAILED (401) - Check if headers/token are correct")
                            } else if httpStatusCode == 403 {
                                print("      ⚠️ FORBIDDEN (403) - Check if headers/token have proper permissions")
                            } else if httpStatusCode == 404 {
                                print("      ⚠️ NOT FOUND (404) - Subtitle file may not exist at this URL")
                            }
                        }
                    }
                    
                    // Check for NSURLErrorDomain errors (network/auth issues)
                    if loadError.domain == NSURLErrorDomain {
                        switch loadError.code {
                        case NSURLErrorUserAuthenticationRequired:
                            print("      ⚠️ AUTHENTICATION REQUIRED - Headers may be missing or invalid")
                        case NSURLErrorUserCancelledAuthentication:
                            print("      ⚠️ AUTHENTICATION CANCELLED - Check credentials in headers")
                        case NSURLErrorNotConnectedToInternet:
                            print("      ⚠️ NO INTERNET CONNECTION")
                        case NSURLErrorTimedOut:
                            print("      ⚠️ REQUEST TIMED OUT")
                        default:
                            print("      Network error code: \(loadError.code)")
                        }
                    }
                    
                    return
                }
                
                guard tracksStatus == .loaded else {
                    print("   ❌ Failed to load subtitle asset for track \(subtitleInfo.trackId): status=\(tracksStatus.rawValue), error=\(error?.localizedDescription ?? "unknown error")")
                    return
                }
                
                print("   ✅ Successfully loaded subtitle asset for track \(subtitleInfo.trackId)")
                
                // Verify asset is actually accessible
                if subtitleInfo.asset.url.isFileURL {
                    let fileManager = FileManager.default
                    let fileSize = (try? fileManager.attributesOfItem(atPath: subtitleInfo.asset.url.path)[.size] as? Int64) ?? 0
                    print("      File size: \(fileSize) bytes")
                    if fileSize == 0 {
                        print("      ⚠️ WARNING: Subtitle file is empty!")
                    }
                } else {
                    // For remote URLs, check if we can get duration (indicates successful download)
                    var durationError: NSError?
                    let durationStatus = subtitleInfo.asset.statusOfValue(forKey: "duration", error: &durationError)
                    if durationStatus == .loaded {
                        print("      Remote subtitle loaded successfully (duration: \(CMTimeGetSeconds(subtitleInfo.asset.duration))s)")
                    } else {
                        print("      ⚠️ Could not verify remote subtitle download status")
                    }
                }
                
                // Check available tracks
                let availableTracks = subtitleInfo.asset.tracks(withMediaType: .text)
                print("      Available text tracks: \(availableTracks.count)")
                if availableTracks.isEmpty {
                    print("      ⚠️ WARNING: No text tracks found in subtitle asset!")
                    print("      This may indicate the file format is not supported or file is corrupted")
                } else {
                    for (idx, track) in availableTracks.enumerated() {
                        print("         Track \(idx): language=\(track.languageCode ?? "nil"), extendedLang=\(track.extendedLanguageTag ?? "nil")")
                    }
                }
            }
        }
        
        // Wait for all assets to load (with timeout)
        print("⏳ Waiting for \(subtitleAssets.count) subtitle assets to load (timeout: 10s)...")
        let timeoutResult = dispatchGroup.wait(timeout: .now() + 10.0)
        if timeoutResult == .timedOut {
            print("⚠️ TIMEOUT: Some subtitle assets may not have finished loading")
            print("   This could indicate network issues or authentication problems")
        } else {
            print("✅ All subtitle asset loading completed")
        }
        
        // Now add all loaded subtitle tracks to composition
        var addedTracksCount = 0
        for subtitleInfo in subtitleAssets {
            let subtitleAssetTracks = subtitleInfo.asset.tracks(withMediaType: .text)
            guard !subtitleAssetTracks.isEmpty else {
                print("⚠️ No text tracks found in subtitle asset for track: \(subtitleInfo.trackId)")
                continue
            }
            
            guard let compositionSubtitleTrack = composition.addMutableTrack(
                withMediaType: .text,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                print("⚠️ Failed to create subtitle track in composition for: \(subtitleInfo.trackId)")
                continue
            }
            
            do {
                // Use video asset duration, or estimated duration for HLS
                let duration = videoAsset.duration
                let durationToUse = duration.isValid && !duration.isIndefinite 
                    ? duration 
                    : CMTimeMake(value: 3600, timescale: 1) // 1 hour estimate for HLS
                
                try compositionSubtitleTrack.insertTimeRange(
                    CMTimeRangeMake(start: .zero, duration: durationToUse),
                    of: subtitleAssetTracks[0],
                    at: .zero
                )
                
                // Note: languageCode and extendedLanguageTag are read-only on composition tracks
                // The language should be preserved from the source track, but we can't set it directly
                // AVFoundation will use the source track's language metadata
                // If the source track doesn't have language, we need to ensure it's set in the source asset
                
                // Try to preserve language from source track if available
                let sourceTrack = subtitleAssetTracks[0]
                if sourceTrack.languageCode == nil || sourceTrack.extendedLanguageTag == nil {
                    print("⚠️ Source subtitle track has no language metadata for: \(subtitleInfo.trackId)")
                    print("   This may cause issues with track identification in media selection")
                } else {
                    print("   Source track language: \(sourceTrack.extendedLanguageTag ?? "nil")")
                }
                
                addedTracksCount += 1
                print("✅ Successfully added subtitle track: \(subtitleInfo.trackId) (\(subtitleInfo.language))")
            } catch {
                print("❌ Failed to insert subtitle track \(subtitleInfo.trackId): \(error)")
            }
        }
            
        print("📊 Total subtitle tracks added to composition: \(addedTracksCount) out of \(subtitleAssets.count)")
        
        // CRITICAL: For HLS, if no video tracks were added, we CANNOT use this composition
        // A composition with only subtitle tracks (no video/audio) will not play
        // We must wait for video tracks to be available before creating the composition
        if videoTracks.isEmpty {
            print("❌ Cannot create composition: No video tracks available")
            print("   A composition with only subtitle tracks will not play")
            print("   Must wait for video tracks before creating composition")
            print("   Subtitle tracks (\(addedTracksCount)) were prepared but composition is invalid")
            
            // Return nil - caller should wait for video tracks
            return nil
        }
        
        return composition
    }
    
    // MARK: - Composition from Player Item Tracks (for HLS)
    
    /// Creates a composition using tracks from player item (needed for HLS where asset tracks might not be available)
    private func createCompositionWithPlayerItemTracks(
        videoTracks: [AVAssetTrack],
        audioTracks: [AVAssetTrack],
        subtitleTracks: [[String: Any]]
    ) -> AVMutableComposition? {
        print("🔧 createCompositionWithPlayerItemTracks called")
        print("   Video tracks: \(videoTracks.count)")
        print("   Audio tracks: \(audioTracks.count)")
        print("   Subtitle tracks: \(subtitleTracks.count)")
        
        let composition = AVMutableComposition()
        
        // Add video track
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            print("❌ Failed to create video track in composition")
            return nil
        }
        
        do {
            let duration = videoTracks[0].timeRange.duration
            try compositionVideoTrack.insertTimeRange(
                CMTimeRangeMake(start: .zero, duration: duration),
                of: videoTracks[0],
                at: .zero
            )
            print("✅ Video track added to composition")
        } catch {
            print("❌ Failed to insert video track: \(error)")
            return nil
        }
        
        // Add audio track if available
        if !audioTracks.isEmpty,
           let compositionAudioTrack = composition.addMutableTrack(
               withMediaType: .audio,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            do {
                let duration = audioTracks[0].timeRange.duration
                try compositionAudioTrack.insertTimeRange(
                    CMTimeRangeMake(start: .zero, duration: duration),
                    of: audioTracks[0],
                    at: .zero
                )
                print("✅ Audio track added to composition")
            } catch {
                print("⚠️ Failed to insert audio track: \(error)")
            }
        }
        
        // Now add subtitle tracks using the existing method
        // We'll reuse the subtitle loading logic from createCompositionWithMultipleSubtitlesForHLS
        return self.addSubtitleTracksToComposition(composition: composition, subtitleTracks: subtitleTracks)
    }
    
    /// Helper method to add subtitle tracks to an existing composition
    private func addSubtitleTracksToComposition(
        composition: AVMutableComposition,
        subtitleTracks: [[String: Any]]
    ) -> AVMutableComposition? {
        print("📝 Adding \(subtitleTracks.count) subtitle tracks to composition...")
        
        // This will reuse the subtitle loading logic from createCompositionWithMultipleSubtitlesForHLS
        // We need to load subtitle assets and add them to the composition
        let dispatchGroup = DispatchGroup()
        var subtitleAssets: [(asset: AVURLAsset, trackId: String, language: String)] = []
        
        // Resolve URLs and create assets (same logic as before)
        for (index, trackDict) in subtitleTracks.enumerated() {
            guard let trackUrlString = trackDict["url"] as? String,
                  let trackId = trackDict["id"] as? String,
                  let language = trackDict["language"] as? String else {
                continue
            }
            
            // Resolve URL (same logic as createCompositionWithMultipleSubtitlesForHLS)
            var trackUrl: URL?
            if trackUrlString.hasPrefix("http://") || trackUrlString.hasPrefix("https://") {
                trackUrl = URL(string: trackUrlString)
            } else if trackUrlString.hasPrefix("file://") {
                trackUrl = URL(string: trackUrlString)
            } else {
                trackUrl = URL(fileURLWithPath: trackUrlString)
            }
            
            guard let subtitleUrl = trackUrl else { continue }
            
            // Ensure VTT has language metadata
            let finalUrl: URL
            if subtitleUrl.pathExtension.lowercased() == "vtt" {
                if let vttUrl = self.ensureVTTLanguageMetadata(vttURL: subtitleUrl, language: language) {
                    finalUrl = vttUrl
                } else {
                    finalUrl = subtitleUrl
                }
            } else {
                finalUrl = subtitleUrl
            }
            
            // Create asset with headers
            let headersToUse = self._stHeaders ?? self._videoHeaders
            let subtitleAsset: AVURLAsset
            if let headers = headersToUse {
                subtitleAsset = AVURLAsset(url: finalUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            } else {
                subtitleAsset = AVURLAsset(url: finalUrl)
            }
            
            subtitleAssets.append((asset: subtitleAsset, trackId: trackId, language: language))
        }
        
        // Load subtitle assets asynchronously and add to composition
        print("📦 Starting async load for \(subtitleAssets.count) subtitle assets...")
        let subtitleDispatchGroup = DispatchGroup()
        var loadedSubtitleAssets: [(asset: AVURLAsset, trackId: String, language: String, textTracks: [AVAssetTrack])] = []
        
        for subtitleInfo in subtitleAssets {
            subtitleDispatchGroup.enter()
            print("   ⏳ Loading subtitle asset for track: \(subtitleInfo.trackId)")
            
            subtitleInfo.asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
                defer { subtitleDispatchGroup.leave() }
                
                var error: NSError?
                let tracksStatus = subtitleInfo.asset.statusOfValue(forKey: "tracks", error: &error)
                
                if let loadError = error {
                    print("   ❌ Error loading subtitle asset for track \(subtitleInfo.trackId): \(loadError.localizedDescription)")
                    return
                }
                
                guard tracksStatus == .loaded else {
                    print("   ❌ Failed to load subtitle asset for track \(subtitleInfo.trackId)")
                    return
                }
                
                let textTracks = subtitleInfo.asset.tracks(withMediaType: .text)
                if !textTracks.isEmpty {
                    loadedSubtitleAssets.append((asset: subtitleInfo.asset, trackId: subtitleInfo.trackId, language: subtitleInfo.language, textTracks: textTracks))
                    print("   ✅ Successfully loaded subtitle asset for track \(subtitleInfo.trackId)")
                } else {
                    print("   ⚠️ No text tracks found in subtitle asset for track: \(subtitleInfo.trackId)")
                }
            }
        }
        
        // Wait for all assets to load (with timeout)
        print("⏳ Waiting for \(subtitleAssets.count) subtitle assets to load (timeout: 10s)...")
        let timeoutResult = subtitleDispatchGroup.wait(timeout: .now() + 10.0)
        if timeoutResult == .timedOut {
            print("⚠️ TIMEOUT: Some subtitle assets may not have finished loading")
        } else {
            print("✅ All subtitle asset loading completed")
        }
        
        // Add loaded subtitle tracks to composition
        var addedTracksCount = 0
        for subtitleInfo in loadedSubtitleAssets {
            guard let compositionSubtitleTrack = composition.addMutableTrack(
                withMediaType: .text,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                print("⚠️ Failed to create subtitle track in composition for: \(subtitleInfo.trackId)")
                continue
            }
            
            do {
                // Use video track duration from composition
                let videoTracks = composition.tracks(withMediaType: .video)
                let duration = videoTracks.isEmpty ? CMTimeMake(value: 3600, timescale: 1) : videoTracks[0].timeRange.duration
                
                try compositionSubtitleTrack.insertTimeRange(
                    CMTimeRangeMake(start: .zero, duration: duration),
                    of: subtitleInfo.textTracks[0],
                    at: .zero
                )
                
                addedTracksCount += 1
                print("✅ Successfully added subtitle track: \(subtitleInfo.trackId) (\(subtitleInfo.language))")
            } catch {
                print("❌ Failed to insert subtitle track \(subtitleInfo.trackId): \(error)")
            }
        }
        
        print("📊 Total subtitle tracks added to composition: \(addedTracksCount) out of \(subtitleAssets.count)")
        
        return composition
    }
    
    // MARK: - Non-HLS Composition (for regular video files with tracks available)
    
    private func createCompositionWithMultipleSubtitles(
        videoTracks: [AVAssetTrack],
        audioTracks: [AVAssetTrack],
        subtitleTracks: [[String: Any]]
    ) -> AVMutableComposition? {
        print("🔧 createCompositionWithMultipleSubtitles called (non-HLS)")
        print("   Input: \(subtitleTracks.count) subtitle tracks")
        let composition = AVMutableComposition()
        
        // Add video track
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            print("❌ Failed to create video track in composition")
            return nil
        }
        print("✅ Video track added to composition")
        
        do {
            // Add video
            try compositionVideoTrack.insertTimeRange(
                CMTimeRangeMake(start: .zero, duration: self.videoAsset.duration),
                of: videoTracks[0],
                at: .zero
            )
            
            // Add audio track if exists
            if !audioTracks.isEmpty,
               let compositionAudioTrack = composition.addMutableTrack(
                   withMediaType: .audio,
                   preferredTrackID: kCMPersistentTrackID_Invalid
               ) {
                try compositionAudioTrack.insertTimeRange(
                    CMTimeRangeMake(start: .zero, duration: self.videoAsset.duration),
                    of: audioTracks[0],
                    at: .zero
                )
            }
            
            // Add all subtitle tracks (same logic as HLS version)
            print("📝 Processing \(subtitleTracks.count) subtitle tracks...")
            var subtitleAssets: [(asset: AVURLAsset, trackId: String, language: String)] = []
            
            // First, resolve all URLs and create assets
            for (index, trackDict) in subtitleTracks.enumerated() {
                print("   Processing track \(index + 1)/\(subtitleTracks.count)...")
                guard let trackUrlString = trackDict["url"] as? String,
                      let trackId = trackDict["id"] as? String,
                      let language = trackDict["language"] as? String else {
                    continue
                }
                
                // Resolve subtitle URL using same logic as video URL resolution
                var trackUrl: URL?
                if trackUrlString.hasPrefix("http://") || trackUrlString.hasPrefix("https://") {
                    trackUrl = URL(string: trackUrlString)
                } else if trackUrlString.hasPrefix("public/assets") {
                    if let appFolder = Bundle.main.resourceURL {
                        trackUrl = appFolder.appendingPathComponent(trackUrlString)
                    }
                } else if trackUrlString.hasPrefix("application") {
                    let docPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                    let path = String(trackUrlString.dropFirst(12))
                    let vPath = docPath.appendingFormat("/\(path)")
                    trackUrl = URL(fileURLWithPath: vPath)
                } else if trackUrlString.hasPrefix("file://") {
                    trackUrl = URL(string: trackUrlString)
                } else {
                    // Try as direct file path
                    trackUrl = URL(fileURLWithPath: trackUrlString)
                }
                
                guard let subtitleUrl = trackUrl else {
                    print("❌ Failed to resolve subtitle URL for track: \(trackId)")
                    continue
                }
                print("   ✅ Resolved URL for track \(trackId): \(subtitleUrl.absoluteString)")
                
                // Check if SRT and convert to VTT if needed, or add language metadata to VTT
                let finalUrl: URL
                if subtitleUrl.pathExtension.lowercased() == "srt" {
                    print("   🔄 Converting SRT to VTT for track: \(trackId)")
                    if let vttUrl = self.convertSRTToWebVTT(srtURL: subtitleUrl, language: language) {
                        finalUrl = vttUrl
                        print("   ✅ SRT converted to VTT: \(vttUrl.absoluteString)")
                    } else {
                        print("❌ Failed to convert SRT to VTT for track: \(trackId)")
                        continue
                    }
                } else if subtitleUrl.pathExtension.lowercased() == "vtt" {
                    // Ensure VTT file has language metadata
                    print("   🔍 Ensuring VTT has language metadata for track: \(trackId)")
                    if let vttUrl = self.ensureVTTLanguageMetadata(vttURL: subtitleUrl, language: language) {
                        finalUrl = vttUrl
                        print("   ✅ VTT language metadata ensured: \(vttUrl.absoluteString)")
                    } else {
                        finalUrl = subtitleUrl
                        print("   ⚠️ Could not add language metadata, using original VTT")
                    }
                } else {
                    finalUrl = subtitleUrl
                    print("   ℹ️ Using subtitle file as-is (extension: \(subtitleUrl.pathExtension))")
                }
                
                // Create asset with headers if available
                let headersToUse: [String: String]?
                if let stHeaders = self._stHeaders {
                    headersToUse = stHeaders
                    print("   🔐 Using subtitle-specific headers for download:")
                } else if let videoHeaders = self._videoHeaders {
                    headersToUse = videoHeaders
                    print("   🔐 Using video headers for subtitle download (fallback):")
                } else {
                    headersToUse = nil
                    print("   ⚠️ No headers provided for subtitle download")
                }
                
                let subtitleAsset: AVURLAsset
                if let headers = headersToUse {
                    subtitleAsset = AVURLAsset(url: finalUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                } else {
                    subtitleAsset = AVURLAsset(url: finalUrl)
                }
                
                print("   📥 Created AVURLAsset for track \(trackId)")
                subtitleAssets.append((asset: subtitleAsset, trackId: trackId, language: language))
            }
            
            // Load and add subtitle tracks (simplified version for non-HLS)
            // For non-HLS, we can use synchronous loading since tracks are already available
            var addedTracksCount = 0
            for subtitleInfo in subtitleAssets {
                // Load tracks synchronously (non-HLS files are typically local or small)
                var error: NSError?
                let status = subtitleInfo.asset.statusOfValue(forKey: "tracks", error: &error)
                
                if status != .loaded {
                    subtitleInfo.asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
                        // Async load for remote files
                    }
                    // Wait a bit for async load
                    Thread.sleep(forTimeInterval: 0.1)
                }
                
                let subtitleAssetTracks = subtitleInfo.asset.tracks(withMediaType: .text)
                guard !subtitleAssetTracks.isEmpty else {
                    print("⚠️ No text tracks found in subtitle asset for track: \(subtitleInfo.trackId)")
                    continue
                }
                
                guard let compositionSubtitleTrack = composition.addMutableTrack(
                    withMediaType: .text,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    print("⚠️ Failed to create subtitle track in composition for: \(subtitleInfo.trackId)")
                    continue
                }
                
                do {
                    try compositionSubtitleTrack.insertTimeRange(
                        CMTimeRangeMake(start: .zero, duration: self.videoAsset.duration),
                        of: subtitleAssetTracks[0],
                        at: .zero
                    )
                    
                    addedTracksCount += 1
                    print("✅ Successfully added subtitle track: \(subtitleInfo.trackId) (\(subtitleInfo.language))")
                } catch {
                    print("❌ Failed to insert subtitle track \(subtitleInfo.trackId): \(error)")
                }
            }
            
            print("📊 Total subtitle tracks added to composition: \(addedTracksCount) out of \(subtitleAssets.count)")
            
            return composition
        } catch {
            print("Failed to create composition with multiple subtitles: \(error)")
            return nil
        }
    }
    
    private func getTextStyleRules() -> [AVTextStyleRule] {
        var textStyle: [AVTextStyleRule] = []
        if let opt = self._stOptions {
            textStyle.append(contentsOf: self.setSubTitleStyle(options: opt))
        }
        return textStyle
    }
    
    private func setInitialSubtitleSelection() {
        guard let playerItem = self.playerItem else { return }
        
        // Wait for player item to be ready before selecting track
        if playerItem.status == .readyToPlay {
            self.selectInitialTrack()
        } else {
            // Observe status and select when ready
            self.itemStatusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
                if item.status == .readyToPlay {
                    self?.selectInitialTrack()
                }
            }
        }
    }
    
    private func selectInitialTrack() {
        guard let playerItem = self.playerItem else {
            print("⚠️ selectInitialTrack: playerItem is nil")
            return
        }
        
        guard let mediaSelectionGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            print("⚠️ selectInitialTrack: No subtitle selection group available")
            print("   Available media characteristics: \(playerItem.asset.availableMediaCharacteristicsWithMediaSelectionOptions)")
            return
        }
        
        print("📋 Available subtitle options: \(mediaSelectionGroup.options.count)")
        for (index, option) in mediaSelectionGroup.options.enumerated() {
            print("   Option \(index): lang=\(option.extendedLanguageTag ?? "nil"), locale=\(option.locale?.identifier ?? "nil"), displayName=\(option.displayName)")
        }
        
        if let selectedId = _selectedSubtitleId {
            print("🎯 Attempting to select track by ID: \(selectedId)")
            // Find matching option by language or track ID
            let options = mediaSelectionGroup.options.filter { option in
                option.extendedLanguageTag == selectedId ||
                option.locale?.languageCode == selectedId ||
                option.displayName.contains(selectedId)
            }
            
            if let option = options.first {
                playerItem.select(option, in: mediaSelectionGroup)
                print("✅ Selected initial subtitle track: \(selectedId) (lang: \(option.extendedLanguageTag ?? "nil"))")
            } else {
                print("❌ Could not find matching subtitle option for track ID: \(selectedId)")
                // Try selecting first available option as fallback
                if let firstOption = mediaSelectionGroup.options.first {
                    playerItem.select(firstOption, in: mediaSelectionGroup)
                    print("🔄 Fallback: Selected first available subtitle option")
                }
            }
        } else if let defaultTrack = _subtitleTracks?.first(where: { ($0["isDefault"] as? Bool) == true }),
                  let defaultId = defaultTrack["id"] as? String,
                  let defaultLanguage = defaultTrack["language"] as? String {
            print("🎯 Attempting to select default track: \(defaultId) (\(defaultLanguage))")
            // Try matching by language first
            let options = mediaSelectionGroup.options.filter { option in
                option.extendedLanguageTag == defaultLanguage ||
                option.locale?.languageCode == defaultLanguage ||
                option.extendedLanguageTag == defaultId ||
                option.locale?.languageCode == defaultId ||
                option.displayName.contains(defaultId)
            }
            
            if let option = options.first {
                playerItem.select(option, in: mediaSelectionGroup)
                print("✅ Selected default subtitle track: \(defaultId) (lang: \(option.extendedLanguageTag ?? "nil"))")
            } else {
                print("❌ Could not find default subtitle option")
                // Try selecting first available option as fallback
                if let firstOption = mediaSelectionGroup.options.first {
                    playerItem.select(firstOption, in: mediaSelectionGroup)
                    print("🔄 Fallback: Selected first available subtitle option")
                }
            }
        } else if let firstTrack = _subtitleTracks?.first,
                  let firstId = firstTrack["id"] as? String,
                  let firstLanguage = firstTrack["language"] as? String {
            print("🎯 Attempting to select first track: \(firstId) (\(firstLanguage))")
            // Try matching by language first
            let options = mediaSelectionGroup.options.filter { option in
                option.extendedLanguageTag == firstLanguage ||
                option.locale?.languageCode == firstLanguage ||
                option.extendedLanguageTag == firstId ||
                option.locale?.languageCode == firstId ||
                option.displayName.contains(firstId)
            }
            
            if let option = options.first {
                playerItem.select(option, in: mediaSelectionGroup)
                print("✅ Selected first subtitle track: \(firstId) (lang: \(option.extendedLanguageTag ?? "nil"))")
            } else {
                print("❌ Could not find first subtitle option")
                // Try selecting first available option as fallback
                if let firstOption = mediaSelectionGroup.options.first {
                    playerItem.select(firstOption, in: mediaSelectionGroup)
                    print("🔄 Fallback: Selected first available subtitle option")
                }
            }
        } else {
            // No specific selection, but try to enable first available track
            if let firstOption = mediaSelectionGroup.options.first {
                playerItem.select(firstOption, in: mediaSelectionGroup)
                print("🔄 Auto-selected first available subtitle option")
            } else {
                print("⚠️ No subtitle options available to select")
            }
        }
    }
    
    private func convertSRTToWebVTT(srtURL: URL, language: String) -> URL? {
        guard let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let vttFileName = UUID().uuidString + ".vtt"
        let vttURL = cachesURL.appendingPathComponent(vttFileName)
        
        do {
            let srtContent = try String(contentsOf: srtURL, encoding: .utf8)
            // Add language metadata to WebVTT header
            let vttContent = "WEBVTT\nLANGUAGE: \(language)\n\n" + srtContent.replacingOccurrences(of: ",", with: ".")
            try vttContent.write(to: vttURL, atomically: true, encoding: .utf8)
            return vttURL
        } catch {
            print("Failed to convert SRT to WebVTT: \(error)")
            return nil
        }
    }
    
    private func ensureVTTLanguageMetadata(vttURL: URL, language: String) -> URL? {
        do {
            let vttContent = try String(contentsOf: vttURL, encoding: .utf8)
            
            // Check if language metadata already exists
            if vttContent.contains("LANGUAGE:") {
                // Already has language, return original
                return vttURL
            }
            
            // Add language metadata after WEBVTT header
            let lines = vttContent.components(separatedBy: .newlines)
            var newLines: [String] = []
            var foundWebVTT = false
            
            for line in lines {
                newLines.append(line)
                if line.trimmingCharacters(in: .whitespaces) == "WEBVTT" && !foundWebVTT {
                    newLines.append("LANGUAGE: \(language)")
                    foundWebVTT = true
                }
            }
            
            // If WEBVTT not found, prepend it
            if !foundWebVTT {
                newLines.insert("WEBVTT", at: 0)
                newLines.insert("LANGUAGE: \(language)", at: 1)
                newLines.insert("", at: 2)
            }
            
            // Write to cache
            guard let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                return nil
            }
            let newVttFileName = UUID().uuidString + ".vtt"
            let newVttURL = cachesURL.appendingPathComponent(newVttFileName)
            
            let newContent = newLines.joined(separator: "\n")
            try newContent.write(to: newVttURL, atomically: true, encoding: .utf8)
            
            return newVttURL
        } catch {
            print("Failed to add language metadata to VTT: \(error)")
            return nil
        }
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

        self._isLoaded.updateValue(false, forKey: self._videoId)
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
        
        // Clean up subtitle time observer (for custom UILabel rendering)
        if let subtitleObserver = self.subtitleTimeObserver {
            self.player?.removeTimeObserver(subtitleObserver)
            self.subtitleTimeObserver = nil
        }
        
        // Clean up subtitle labels from content overlay (for custom UILabel rendering)
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
        self._subtitleTracks = nil
        self._selectedSubtitleId = nil
        
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
}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
