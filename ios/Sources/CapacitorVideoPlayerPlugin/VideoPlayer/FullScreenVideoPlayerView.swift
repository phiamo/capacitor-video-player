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
import os

// swiftlint:disable file_length
// swiftlint:disable type_body_length
open class FullScreenVideoPlayerView: UIView {
    // Logger for this class
    static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "org.dwbn.awareness",
        category: String(describing: FullScreenVideoPlayerView.self)
    )
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
    private var _activeSubtitleTrackId: String?
    // Store parsed subtitle data for custom display (fallback when composition fails)
    private var subtitleTracksData: [String: [(start: Double, end: Double, text: String)]] = [:]
    private var subtitleLabel: UILabel?
    private var subtitleRetryInProgress: Bool = false // Prevent duplicate retry mechanisms
    // Resource loader delegate for HLS subtitle injection
    private var hlsSubtitleResourceLoader: HLSSubtitleResourceLoaderDelegate?
    
    // Custom URLSession delegate to handle redirects with authentication
    private class SubtitleURLSessionDelegate: NSObject, URLSessionTaskDelegate {
        let headers: [String: String]
        var redirectCount: Int = 0
        var originalURL: URL?
        var redirectHistory: [URL] = []
        let maxRedirects = 10
        
        init(headers: [String: String]) {
            self.headers = headers
        }
        
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            // Track original URL on first redirect
            if self.originalURL == nil, let originalRequest = task.originalRequest {
                self.originalURL = originalRequest.url
                self.redirectHistory.append(self.originalURL!)
            }
            
            self.redirectCount += 1
            guard let redirectURL = request.url else {
                FullScreenVideoPlayerView.logger.debug("Redirect has no URL, stopping")
                completionHandler(nil)
                return
            }
            
            // Check for redirect loop - same URL as original or already visited
            if redirectURL == self.originalURL || self.redirectHistory.contains(redirectURL) {
                FullScreenVideoPlayerView.logger.debug("REDIRECT LOOP DETECTED!")
                FullScreenVideoPlayerView.logger.debug("Redirect URL matches original or was already visited")
                FullScreenVideoPlayerView.logger.debug("Original: \(self.originalURL?.absoluteString ?? "unknown", privacy: .public)")
                FullScreenVideoPlayerView.logger.debug("Redirect: \(redirectURL.absoluteString, privacy: .public)")
                FullScreenVideoPlayerView.logger.debug("Redirect count: \(self.redirectCount, privacy: .public)")
                completionHandler(nil) // Stop following redirects
                return
            }
            
            // Check redirect limit
            if self.redirectCount > self.maxRedirects {
                FullScreenVideoPlayerView.logger.debug("Maximum redirects (\(self.maxRedirects, privacy: .public)) exceeded, stopping")
                FullScreenVideoPlayerView.logger.debug("This might indicate a redirect loop on the server")
                completionHandler(nil) // Stop following redirects
                return
            }
            
            self.redirectHistory.append(redirectURL)
            
            // Create a new request with the redirect URL but preserve our authentication headers
            var redirectedRequest = request
            for (key, value) in self.headers {
                redirectedRequest.setValue(value, forHTTPHeaderField: key)
            }
            
            FullScreenVideoPlayerView.logger.debug("Redirect \(self.redirectCount, privacy: .public)/\(self.maxRedirects, privacy: .public) to: \(redirectURL.absoluteString, privacy: .public)")
            FullScreenVideoPlayerView.logger.debug("Preserved authentication headers in redirect")
            completionHandler(redirectedRequest)
        }
    }

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
    var positionUpdateObserver: Any?
    var mediaSelectionObserver: NSKeyValueObservation?
    private var _positionUpdateInterval: Double = 5.0
    /// Suppress subtitle bridge events during initial track selection / KVO noise (see analytics subtitle_change notes).
    private var suppressSubtitleBridgeEvents = true
    private var subtitleBridgeUnsuppressScheduled = false

    init(url: URL, rate: Float, playerId: String, exitOnEnd: Bool,
         loopOnEnd: Bool, pipEnabled: Bool, showControls: Bool,
         displayMode: String, stUrl: URL?, stLanguage: String?,
         stHeaders: [String: String]?, stOptions: [String: Any]?,
         title: String?, smallTitle: String?, artwork: String?,
         subtitleTracks: [[String: Any]]?,
         selectedSubtitleId: String?, positionUpdateInterval: Double = 5.0) {
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
        self._positionUpdateInterval = positionUpdateInterval

        // For HLS streams, use custom URL scheme to enable resource loader
        // This is needed both for subtitle injection AND for adding CLOSED-CAPTIONS=NONE when no subtitles
        let finalUrl: URL
        if FullScreenVideoPlayerView.isHLSStream(url: url) {
            // Convert URL to custom scheme for resource loader interception
            // Replace http:// or https:// with customscheme://
            let urlString = url.absoluteString
            let customUrlString: String
            if urlString.hasPrefix("http://") {
                customUrlString = urlString.replacingOccurrences(of: "http://", with: "\(HLSSubtitleResourceLoaderDelegate.customSchemePrefix)://")
            } else if urlString.hasPrefix("https://") {
                customUrlString = urlString.replacingOccurrences(of: "https://", with: "\(HLSSubtitleResourceLoaderDelegate.customSchemePrefix)://")
            } else {
                customUrlString = urlString
            }
            
            if let customUrl = URL(string: customUrlString) {
                finalUrl = customUrl
            } else {
                Self.logger.warning("Failed to create custom URL scheme, using original URL")
                finalUrl = url
            }
        } else {
            finalUrl = url
        }
        
        // Store video headers for potential use with subtitles
        if let headers = self._videoHeaders {
            self.videoAsset = AVURLAsset(url: finalUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        } else {
            self.videoAsset = AVURLAsset(url: finalUrl)
        }
        
        // Set up resource loader delegate for HLS streams
        // Always create delegate for HLS streams, even without subtitles, to add CLOSED-CAPTIONS=NONE
        if FullScreenVideoPlayerView.isHLSStream(url: url) {
            let bearerToken = FullScreenVideoPlayerView.extractBearerToken(from: self._videoHeaders)
            // Use empty array if no subtitles, so delegate can add CLOSED-CAPTIONS=NONE
            let tracks = subtitleTracks ?? []
            self.hlsSubtitleResourceLoader = HLSSubtitleResourceLoaderDelegate(
                subtitleTracks: tracks,
                bearerToken: bearerToken,
                originalVideoUrl: url
            )
            self.videoAsset.resourceLoader.setDelegate(self.hlsSubtitleResourceLoader, queue: DispatchQueue.main)
        }

        self.isPlaying = false
        super.init(frame: .zero)
        self.initialize()
        self.addObservers()
    }

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
  private func initialize() {
      Task { @MainActor in
          await self.initializeAsync()
      }
  }

  @MainActor
  private func initializeAsync() async {
      if let tracks = self._subtitleTracks, !tracks.isEmpty {
          let isHLS = FullScreenVideoPlayerView.isHLSStream(url: self._url)

          if isHLS {
              self.loadAllSubtitleTracksForHLS()
          } else {
              do {
                  let videoTracks = try await self.videoAsset.loadVideoTracks()
                  guard !videoTracks.isEmpty else {
                      self.playerItem = AVPlayerItem(asset: self.videoAsset)
                      self.player = AVPlayer(playerItem: self.playerItem)
                      self.setupPlayer()
                      return
                  }
                  await self.createPlayerWithSubtitles(
                      videoTracks: videoTracks,
                      subtitleTracks: tracks
                  )
              } catch {
                  Self.logger.error("Failed to load video tracks for subtitles: \(error)")
                  self.playerItem = AVPlayerItem(asset: self.videoAsset)
                  self.player = AVPlayer(playerItem: self.playerItem)
                  self.setupPlayer()
              }
          }
      } else if let subTitleUrl = self._stUrl {
          Self.logger.debug("Loading HLS stream: \(self._url)")

          do {
              let allTracks = try await self.videoAsset.loadAllTracks()
              Self.logger.debug("HLS stream loaded. Tracks count: \(allTracks.count)")

              let isHLSStream = FullScreenVideoPlayerView.isHLSStream(url: self._url)

              if isHLSStream {
                  Self.logger.debug("HLS stream detected - proceeding with player setup")
                  Self.logger.debug("HLS stream URL: \(self._url.absoluteString)")
                  Self.logger.debug("HLS stream tracks available: \(allTracks.count)")
                  await self.loadVideoAssetWithSubtitles(subTitleUrl: subTitleUrl)
              } else {
                  let videoTracks = try await self.videoAsset.loadVideoTracks()
                  guard !videoTracks.isEmpty else {
                      Self.logger.debug("No video tracks found in non-HLS stream - using simple player")
                      self.playerItem = AVPlayerItem(asset: self.videoAsset)
                      self.player = AVPlayer(playerItem: self.playerItem)
                      self.setupPlayer()
                      return
                  }

                  await self.loadVideoAssetWithSubtitles(subTitleUrl: subTitleUrl)
              }
          } catch {
              Self.logger.error("Failed to load video asset: \(error)")
              self.playerItem = AVPlayerItem(asset: self.videoAsset)
              self.player = AVPlayer(playerItem: self.playerItem)
              self.setupPlayer()
          }
      } else {
          self.playerItem = AVPlayerItem(asset: self.videoAsset)
          self.player = AVPlayer(playerItem: self.playerItem)
          self.setupPlayer()
      }
  }

    @MainActor
    private func loadVideoAssetWithSubtitles(subTitleUrl: URL) async {
        Self.logger.debug("Loading video asset with subtitles...")

        let isHLSStream = FullScreenVideoPlayerView.isHLSStream(url: self._url)

        if isHLSStream {
            Self.logger.debug("HLS stream detected - setting up player with subtitles")
            Self.logger.debug("HLS URL: \(self._url.absoluteString)")
            self.setupSubtitlesForHLS(subTitleUrl: subTitleUrl)
        } else {
            do {
                let allTracks = try await self.videoAsset.loadAllTracks()
                let duration = try await self.videoAsset.loadDurationValue()
                Self.logger.debug("Video asset loaded. Tracks count: \(allTracks.count)")
                Self.logger.debug("Video asset duration: \(duration.seconds, privacy: .public) seconds")

                let videoTracks = try await self.videoAsset.loadVideoTracks()
                Self.logger.debug("Video tracks count: \(videoTracks.count)")

                if videoTracks.isEmpty {
                    Self.logger.debug("No video tracks found after loading - falling back to simple player")
                    self.playerItem = AVPlayerItem(asset: self.videoAsset)
                    self.player = AVPlayer(playerItem: self.playerItem)
                    self.setupPlayer()
                    return
                }

                await self.createPlayerWithSubtitles(subTitleUrl: subTitleUrl, videoTracks: videoTracks)
            } catch {
                Self.logger.error("Failed to load video asset with subtitles: \(error)")
                self.playerItem = AVPlayerItem(asset: self.videoAsset)
                self.player = AVPlayer(playerItem: self.playerItem)
                self.setupPlayer()
            }
        }
    }
    
    private func setupSubtitlesForHLS(subTitleUrl: URL) {
        Self.logger.debug("Setting up subtitles for HLS stream...")
        
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
        Self.logger.debug("Setting up custom subtitle display...")
        
        // Read and parse subtitle content
        do {
            let subtitleContent = try String(contentsOf: subTitleUrl, encoding: .utf8)
            let isVTT = subtitleContent.hasPrefix("WEBVTT")
            Self.logger.debug("Subtitle format detected: \(isVTT ? "VTT" : "SRT")")
            
            // Parse subtitles based on format
            let subtitles: [(start: Double, end: Double, text: String)]
            if isVTT {
                subtitles = parseVTTContent(subtitleContent)
            } else {
                subtitles = parseSRTContent(subtitleContent)
            }
            
            Self.logger.debug("Parsed \(subtitles.count) subtitle entries")
            
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
                    Self.logger.debug("Added subtitle label constraints after layout")
                }
                Self.logger.debug("Added subtitle label to content overlay view")
            } else {
                Self.logger.debug("Content overlay view is nil!")
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
                        Self.logger.debug("Subtitle: \(newText)")
                    } else {
                        // Hide subtitle instantly
                        subtitleLabel.isHidden = true
                        Self.logger.debug("Subtitle cleared")
                    }
                }
            }
            
            // Store the observer for cleanup later
            self.subtitleTimeObserver = timeObserver
            
        } catch {
            Self.logger.debug("Failed to read subtitle file: \(error)")
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
    
    private static func isHLSStream(url: URL) -> Bool {
        let urlString = url.absoluteString.lowercased()
        return urlString.contains(".m3u8") || urlString.contains("m3u8")
    }
    
    /// Extracts bearer token from headers (Authorization header or custom token header)
    private static func extractBearerToken(from headers: [String: String]?) -> String? {
        guard let headers = headers else { return nil }
        
        // Check for Authorization header with Bearer token
        if let authHeader = headers["Authorization"] ?? headers["authorization"] {
            if authHeader.hasPrefix("Bearer ") {
                let token = String(authHeader.dropFirst(7)) // Remove "Bearer " prefix
                return token
            }
        }
        
        // Check for custom token headers
        for (key, value) in headers {
            let lowerKey = key.lowercased()
            if lowerKey.contains("token") && !value.isEmpty {
                // If it's already a bearer token, extract it
                if value.hasPrefix("Bearer ") {
                    return String(value.dropFirst(7))
                }
                return value
            }
        }
        
        return nil
    }
    
    @MainActor
    private func createPlayerWithSubtitles(subTitleUrl: URL, videoTracks: [AVAssetTrack]) async {
        Self.logger.debug("Creating player with subtitles...")

        var textStyle: [AVTextStyleRule] = []
        if let opt = self._stOptions {
            textStyle.append(contentsOf: self.setSubTitleStyle(options: opt))
        }

        let subTitleAsset = AVURLAsset(url: subTitleUrl)
        let composition = AVMutableComposition()

        do {
            let duration = try await self.videoAsset.loadDurationValue()
            Self.logger.debug("Subtitle asset duration: \(duration.seconds, privacy: .public) seconds")

            if let videoTrack = composition.addMutableTrack(
                withMediaType: AVMediaType.video,
                preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) {

                let audioTracks = try await self.videoAsset.loadAudioTracks()
                let audioTrack = composition.addMutableTrack(
                    withMediaType: AVMediaType.audio,
                    preferredTrackID: Int32(kCMPersistentTrackID_Invalid))

                try videoTrack.insertTimeRange(
                    CMTimeRangeMake(start: CMTime.zero, duration: duration),
                    of: videoTracks[0],
                    at: CMTime.zero)

                if !audioTracks.isEmpty, let audioTrack = audioTrack {
                    try audioTrack.insertTimeRange(
                        CMTimeRangeMake(start: CMTime.zero, duration: duration),
                        of: audioTracks[0],
                        at: CMTime.zero)
                }

                let subtitleTracks = try await subTitleAsset.loadTextTracks()
                if !subtitleTracks.isEmpty {
                    if let subtitleTrack = composition.addMutableTrack(
                        withMediaType: .text,
                        preferredTrackID: kCMPersistentTrackID_Invalid) {
                        try subtitleTrack.insertTimeRange(
                            CMTimeRangeMake(start: CMTime.zero, duration: duration),
                            of: subtitleTracks[0],
                            at: CMTime.zero)

                        self.playerItem = AVPlayerItem(asset: composition)
                        self.playerItem?.textStyleRules = textStyle
                        Self.logger.debug("Successfully added subtitle track")
                    } else {
                        Self.logger.debug("Failed to create subtitle track")
                        self.playerItem = AVPlayerItem(asset: self.videoAsset)
                    }
                } else {
                    Self.logger.debug("No subtitle tracks found in subtitle asset")
                    self.playerItem = AVPlayerItem(asset: self.videoAsset)
                }
            } else {
                Self.logger.debug("Failed to create video track")
                self.playerItem = AVPlayerItem(asset: self.videoAsset)
            }
        } catch {
            Self.logger.debug("Failed to create player with subtitles: \(error)")
            self.playerItem = AVPlayerItem(asset: self.videoAsset)
        }

        self.player = AVPlayer(playerItem: self.playerItem)
        self.setupPlayer()
    }
    
    // MARK: - Multiple Subtitle Tracks Support
    
    private func loadAllSubtitleTracksForHLS() {
        guard let tracks = self._subtitleTracks, !tracks.isEmpty else {
            // Still create player without subtitles
            self.playerItem = AVPlayerItem(asset: self.videoAsset)
            self.player = AVPlayer(playerItem: self.playerItem)
            self.videoPlayer.player = self.player
            self.setupPlayer()
            return
        }

        // Create player item with the HLS asset (resource loader will inject subtitles)
        self.playerItem = AVPlayerItem(asset: self.videoAsset)
        self.player = AVPlayer(playerItem: self.playerItem)
        self.videoPlayer.player = self.player
        self.setupPlayer()

        // Set initial subtitle selection after player is ready
        self.finishHLSSubtitleSetup()
    }
    
    private func finishHLSSubtitleSetup() {
        // Set initial active track
        if let selectedId = self._selectedSubtitleId ?? self._subtitleTracks?.first?["id"] as? String {
            self._activeSubtitleTrackId = selectedId
        }
        
        // Wait for player to be ready before setting initial subtitle selection
        // Subtitles are now injected via resource loader and will appear in native iOS menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.setInitialSubtitleSelection()
            
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
                Self.logger.debug("Added subtitle label constraints after layout")
            }
            Self.logger.debug("Added subtitle label to content overlay view")
        } else {
            Self.logger.debug("Content overlay view is nil!")
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
    
    // MARK: - Create and Replace Player Item with Subtitles
    
    /// Creates composition using a specific asset (either original or player item's asset)
    private func createCompositionWithAsset(asset: AVAsset, subtitleTracks: [[String: Any]]) {
        Task { @MainActor in
            await self.createCompositionWithAssetAsync(asset: asset, subtitleTracks: subtitleTracks)
        }
    }

    @MainActor
    private func createCompositionWithAssetAsync(asset: AVAsset, subtitleTracks: [[String: Any]]) async {
        Self.logger.debug("🔨 Creating composition with asset tracks + subtitle tracks...")

        let videoTracks = (try? await asset.loadVideoTracks()) ?? []

        guard !videoTracks.isEmpty else {
            Self.logger.error("No video tracks in provided asset")
            return
        }

        let assetToUse: AVAsset
        if let urlAsset = asset as? AVURLAsset {
            assetToUse = urlAsset
        } else {
            Self.logger.warning(" Player item's asset is not AVURLAsset, using original videoAsset")
            assetToUse = self.videoAsset
        }

        if let composition = await self.createCompositionWithMultipleSubtitlesForHLS(
            videoAsset: assetToUse as! AVURLAsset,
            subtitleTracks: subtitleTracks
        ) {
            Self.logger.notice(" Composition created successfully with subtitles")

            let newPlayerItem = AVPlayerItem(asset: composition)
            newPlayerItem.textStyleRules = self.getTextStyleRules()

            if let currentPlayer = self.player {
                currentPlayer.replaceCurrentItem(with: newPlayerItem)
                self.playerItem = newPlayerItem
                self.setInitialSubtitleSelection()
                Self.logger.notice(" Player item replaced with composition containing subtitle tracks")
                Self.logger.debug("   Subtitles should now appear in native iOS subtitle selection menu")
            }
        } else {
            Self.logger.error(" Failed to create composition with subtitles")
        }
    }
    
    /// Retries creating composition with subtitles until asset tracks become available
    private func retryCreateCompositionWithSubtitles(subtitleTracks: [[String: Any]], retryCount: Int) {
        // For HLS, tracks typically never become available, so use fewer retries
        // This ensures fallback triggers quickly
        let maxRetries = 5 // Reduced from 15 - HLS tracks won't become available anyway
        
        guard retryCount < maxRetries else {
            Self.logger.error(" Max retries (\(maxRetries)) reached - asset tracks never became available")
            Self.logger.debug("   For HLS streams, tracks might not be directly accessible")
            Self.logger.debug("   Video will continue playing, but subtitles won't appear in native menu")
            Self.logger.debug("   🔄 Falling back to custom UILabel subtitle display (like working branch)")
            Self.logger.debug("   This will load and display all subtitle tracks using custom overlay")
            self.subtitleRetryInProgress = false // Reset flag
            // For HLS, we already use loadAllSubtitleTracksForHLS directly
            // This fallback should only be for non-HLS streams
            if FullScreenVideoPlayerView.isHLSStream(url: self.videoAsset.url) {
                self.loadAllSubtitleTracksForHLS()
            } else {
                // For non-HLS, we can't easily add external subtitles after composition fails
                // Just continue without subtitles
                Self.logger.debug("   ⚠️ Non-HLS composition failed - subtitles unavailable")
            }
            return
        }
        
        let delay = Double(retryCount + 1) * 0.5 // 0.5s, 1s, 1.5s, etc.

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self = self else { return }

            guard let playerItem = self.playerItem else {
                self.retryCreateCompositionWithSubtitles(subtitleTracks: subtitleTracks, retryCount: retryCount + 1)
                return
            }

            let playerItemAsset = playerItem.asset

            do {
                try await playerItemAsset.loadTracksOnly()
                try await self.videoAsset.loadTracksOnly()

                let playerItemVideoTracks = try await playerItemAsset.loadVideoTracks()
                let originalVideoTracks = try await self.videoAsset.loadVideoTracks()

                Self.logger.debug("   Retry \(retryCount + 1)/\(maxRetries):")
                Self.logger.debug("      Player item asset tracks: \(playerItemVideoTracks.count)")
                Self.logger.debug("      Original asset tracks: \(originalVideoTracks.count)")

                let tracksToUse = !playerItemVideoTracks.isEmpty ? playerItemVideoTracks : originalVideoTracks
                let assetToUse = !playerItemVideoTracks.isEmpty ? playerItemAsset : self.videoAsset

                if !tracksToUse.isEmpty {
                    Self.logger.notice(" Tracks now available! Creating composition with all subtitle tracks...")
                    self.subtitleRetryInProgress = false
                    await self.createCompositionWithAssetAsync(asset: assetToUse, subtitleTracks: subtitleTracks)
                } else {
                    self.retryCreateCompositionWithSubtitles(subtitleTracks: subtitleTracks, retryCount: retryCount + 1)
                }
            } catch {
                self.retryCreateCompositionWithSubtitles(subtitleTracks: subtitleTracks, retryCount: retryCount + 1)
            }
        }
    }
    
    /// Creates a composition using tracks from the player item (for HLS streams)
    /// This is needed because HLS tracks might only be available through player item, not asset
    /// NOTE: This method doesn't work - can't copy HLS tracks from player item
    private func createCompositionFromPlayerItemTracks(subtitleTracks: [[String: Any]]) {
        Task { @MainActor in
            await self.createCompositionFromPlayerItemTracksAsync(subtitleTracks: subtitleTracks)
        }
    }

    @MainActor
    private func createCompositionFromPlayerItemTracksAsync(subtitleTracks: [[String: Any]]) async {
        Self.logger.debug("🔨 Creating composition from player item tracks (HLS)...")

        guard let playerItem = self.playerItem else {
            Self.logger.error(" Player item is nil")
            return
        }

        let playerItemVideoTracks = playerItem.tracks.compactMap { $0.assetTrack }.filter { $0.mediaType == .video }
        let playerItemAudioTracks = playerItem.tracks.compactMap { $0.assetTrack }.filter { $0.mediaType == .audio }

        Self.logger.debug("   Player item video tracks: \(playerItemVideoTracks.count)")
        Self.logger.debug("   Player item audio tracks: \(playerItemAudioTracks.count)")

        guard !playerItemVideoTracks.isEmpty else {
            Self.logger.error(" No video tracks in player item")
            return
        }

        if let composition = await self.createCompositionWithPlayerItemTracks(
            videoTracks: playerItemVideoTracks,
            audioTracks: playerItemAudioTracks,
            subtitleTracks: subtitleTracks
        ) {
            Self.logger.notice(" Composition created successfully with all tracks")

            let newPlayerItem = AVPlayerItem(asset: composition)
            newPlayerItem.textStyleRules = self.getTextStyleRules()

            if let currentPlayer = self.player {
                currentPlayer.replaceCurrentItem(with: newPlayerItem)
                self.playerItem = newPlayerItem
                self.setInitialSubtitleSelection()
                Self.logger.notice(" Player item replaced with composition containing \(subtitleTracks.count) subtitle tracks")
                Self.logger.debug("   Subtitles should now appear in native iOS subtitle selection menu")
            }
        } else {
            Self.logger.error(" Failed to create composition from player item tracks")
        }
    }
    
    private func createAndReplacePlayerItemWithSubtitles(subtitleTracks: [[String: Any]]) {
        Task { @MainActor in
            await self.createAndReplacePlayerItemWithSubtitlesAsync(subtitleTracks: subtitleTracks)
        }
    }

    @MainActor
    private func createAndReplacePlayerItemWithSubtitlesAsync(subtitleTracks: [[String: Any]]) async {
        Self.logger.debug("🔨 Creating composition with video/audio + subtitle tracks for native menu...")

        let videoTracks = (try? await self.videoAsset.loadVideoTracks()) ?? []

        guard !videoTracks.isEmpty else {
            Self.logger.error(" No video tracks available, cannot create composition")
            return
        }

        if let composition = await self.createCompositionWithMultipleSubtitlesForHLS(
            videoAsset: self.videoAsset,
            subtitleTracks: subtitleTracks
        ) {
            Self.logger.notice(" Composition created successfully with subtitles")

            Self.logger.debug("🔄 Creating new player item with composition...")
            let newPlayerItem = AVPlayerItem(asset: composition)
            newPlayerItem.textStyleRules = self.getTextStyleRules()
            let compositionTracks = (try? await composition.loadAllTracks()) ?? []
            Self.logger.debug("   ✅ Player item created, composition has \(compositionTracks.count) tracks")
            Self.logger.debug("   📊 Composition tracks breakdown:")
            let compVideoTracks = (try? await composition.loadVideoTracks()) ?? []
            let compAudioTracks = (try? await composition.loadAudioTracks()) ?? []
            let compSubtitleTracks = try? await composition.loadTracks(withMediaType: .subtitle)
            Self.logger.debug("      Video: \(compVideoTracks.count), Audio: \(compAudioTracks.count), Subtitle: \(compSubtitleTracks?.count ?? 0)")

            if let currentPlayer = self.player {
                Self.logger.debug("🔄 Replacing current player item...")
                currentPlayer.replaceCurrentItem(with: newPlayerItem)
                self.playerItem = newPlayerItem
                self.addMediaSelectionObserver()
                self.setInitialSubtitleSelection()
                Self.logger.notice(" Player item replaced with composition containing subtitle tracks")
                Self.logger.debug("   Subtitles should now appear in native iOS subtitle selection menu")
            }
        } else {
            Self.logger.error(" Failed to create composition with subtitles")
        }
    }
    
    /// Creates a composition with subtitle tracks even when video tracks aren't available yet
    /// For HLS streams, we need to wait for video tracks or the composition won't play
    /// This method will keep retrying until tracks are available
    /// IMPORTANT: Does NOT replace player item until video tracks are available (to keep video playing)
    private func createCompositionWithSubtitlesEvenIfNoTracks(subtitleTracks: [[String: Any]]) {
        Self.logger.debug("🔨 Attempting to create composition with subtitle tracks...")
        Self.logger.debug("   ⚠️ Video tracks not yet available - will keep retrying")
        Self.logger.debug("   ⚠️ Player item will NOT be replaced until video tracks are available (to keep video playing)")
        
        // Keep retrying to get video tracks
        var retryCount = 0
        let maxRetries = 10
        
        func tryCreateComposition() {
            guard retryCount < maxRetries else {
                Self.logger.error(" Max retries reached - video tracks never became available")
                Self.logger.debug("   Video will continue playing with original player item")
                Self.logger.debug("   Using custom subtitle display fallback method")
                self.setupCustomSubtitleDisplayForHLS(subtitleTracks: subtitleTracks)
                return
            }

            retryCount += 1
            let delay = Double(retryCount) * 0.5

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard let self = self else { return }

                do {
                    let videoTracks = try await self.videoAsset.loadVideoTracks()
                    Self.logger.debug("   Retry \(retryCount)/\(maxRetries): Video tracks: \(videoTracks.count)")

                    if !videoTracks.isEmpty {
                        Self.logger.notice(" Video tracks now available! Creating composition with all subtitle tracks...")
                        await self.createAndReplacePlayerItemWithSubtitlesAsync(subtitleTracks: subtitleTracks)
                    } else {
                        tryCreateComposition()
                    }
                } catch {
                    tryCreateComposition()
                }
            }
        }
        
        tryCreateComposition()
    }
    
    
    @MainActor
    private func createPlayerWithSubtitles(
        videoTracks: [AVAssetTrack],
        subtitleTracks: [[String: Any]]
    ) async {
        let audioTracks = (try? await self.videoAsset.loadAudioTracks()) ?? []

        if let composition = await self.createCompositionWithMultipleSubtitles(
            videoTracks: videoTracks,
            audioTracks: audioTracks,
            subtitleTracks: subtitleTracks
        ) {
            self.playerItem = AVPlayerItem(asset: composition)
            self.playerItem?.textStyleRules = self.getTextStyleRules()
            self.player = AVPlayer(playerItem: self.playerItem)
            self.setupPlayer()
            self.setInitialSubtitleSelection()
        } else {
            self.playerItem = AVPlayerItem(asset: self.videoAsset)
            self.player = AVPlayer(playerItem: self.playerItem)
            self.setupPlayer()
        }
    }
    
    private func createCompositionWithMultipleSubtitlesForHLS(
        videoAsset: AVURLAsset,
        subtitleTracks: [[String: Any]]
    ) async -> AVMutableComposition? {
        Self.logger.debug("🔧 createCompositionWithMultipleSubtitlesForHLS called")
        Self.logger.debug("   Input: \(subtitleTracks.count) subtitle tracks")
        Self.logger.debug("   Video asset URL: \(videoAsset.url.absoluteString)")

        let composition = AVMutableComposition()

        let videoTracks = (try? await videoAsset.loadVideoTracks()) ?? []
        let audioTracks = (try? await videoAsset.loadAudioTracks()) ?? []
        let assetDuration = try? await videoAsset.loadDurationValue()

        Self.logger.debug("   Available video tracks: \(videoTracks.count)")
        Self.logger.debug("   Available audio tracks: \(audioTracks.count)")

        if !videoTracks.isEmpty {
            guard let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                Self.logger.error(" Failed to create video track in composition")
                return nil
            }

            do {
                let duration = assetDuration ?? .invalid
                if duration.isValid && !duration.isIndefinite {
                    try compositionVideoTrack.insertTimeRange(
                        CMTimeRangeMake(start: .zero, duration: duration),
                        of: videoTracks[0],
                        at: .zero
                    )
                    Self.logger.notice(" Video track added to composition")
                } else {
                    Self.logger.warning(" Video asset duration is invalid, using estimated duration")
                    let estimatedDuration = CMTimeMake(value: 3600, timescale: 1)
                    try compositionVideoTrack.insertTimeRange(
                        CMTimeRangeMake(start: .zero, duration: estimatedDuration),
                        of: videoTracks[0],
                        at: .zero
                    )
                    Self.logger.notice(" Video track added to composition (estimated duration)")
                }
            } catch {
                Self.logger.error(" Failed to insert video track: \(error)")
                Self.logger.debug("   Will try to add subtitle tracks anyway - composition may not play video")
            }
        } else {
            Self.logger.warning(" No video tracks available - this is common for HLS")
            Self.logger.debug("   For HLS with external subtitles, we cannot create a valid composition")
            Self.logger.debug("   without video tracks. The native menu approach won't work for this case.")
            Self.logger.debug("   Returning nil - will need to use fallback method")
            return nil
        }

        if !audioTracks.isEmpty,
           let compositionAudioTrack = composition.addMutableTrack(
               withMediaType: .audio,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            do {
                let duration = assetDuration ?? .invalid
                let durationToUse = duration.isValid && !duration.isIndefinite
                    ? duration
                    : CMTimeMake(value: 3600, timescale: 1)
                try compositionAudioTrack.insertTimeRange(
                    CMTimeRangeMake(start: .zero, duration: durationToUse),
                    of: audioTracks[0],
                    at: .zero
                )
                Self.logger.notice(" Audio track added to composition")
            } catch {
                Self.logger.warning(" Failed to insert audio track: \(error)")
            }
        }
            
        // Add all subtitle tracks
        // Load all subtitle assets first, then add to composition
        Self.logger.debug("📝 Processing \(subtitleTracks.count) subtitle tracks...")
        Self.logger.debug("   🔍 Subtitle tracks details:")
        for (idx, track) in subtitleTracks.enumerated() {
            let trackId = track["id"] as? String ?? "nil"
            let language = track["language"] as? String ?? "nil"
            let url = track["url"] as? String ?? "nil"
            Self.logger.debug("      [\(idx)] id=\(trackId), lang=\(language), url=\(url)")
        }
        var subtitleAssets: [(asset: AVURLAsset, trackId: String, language: String)] = []
        
        // First, resolve all URLs and create assets
        for (index, trackDict) in subtitleTracks.enumerated() {
            Self.logger.debug("   Processing track \(index + 1)/\(subtitleTracks.count)...")
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
                Self.logger.error(" Failed to resolve subtitle URL for track: \(trackId)")
                continue
            }
            Self.logger.debug("   ✅ Resolved URL for track \(trackId): \(subtitleUrl.absoluteString)")
            
            // Check if SRT and convert to VTT if needed, or add language metadata to VTT
            let finalUrl: URL
            if subtitleUrl.pathExtension.lowercased() == "srt" {
                Self.logger.debug("   🔄 Converting SRT to VTT for track: \(trackId)")
                if let vttUrl = self.convertSRTToWebVTT(srtURL: subtitleUrl, language: language) {
                    finalUrl = vttUrl
                    Self.logger.debug("   ✅ SRT converted to VTT: \(vttUrl.absoluteString)")
                } else {
                    Self.logger.error(" Failed to convert SRT to VTT for track: \(trackId)")
                    continue
                }
            } else if subtitleUrl.pathExtension.lowercased() == "vtt" {
                // Ensure VTT file has language metadata
                Self.logger.debug("   🔍 Ensuring VTT has language metadata for track: \(trackId)")
                if let vttUrl = self.ensureVTTLanguageMetadata(vttURL: subtitleUrl, language: language) {
                    finalUrl = vttUrl
                    Self.logger.debug("   ✅ VTT language metadata ensured: \(vttUrl.absoluteString)")
                } else {
                    finalUrl = subtitleUrl
                    Self.logger.debug("   ⚠️ Could not add language metadata, using original VTT")
                }
            } else {
                finalUrl = subtitleUrl
                Self.logger.debug("   ℹ️ Using subtitle file as-is (extension: \(subtitleUrl.pathExtension))")
            }
            
            // Create asset with headers if available
            // Use subtitle headers if provided, otherwise fall back to video headers
            // This is important for auth - subtitles often need the same auth headers as video
            let headersToUse: [String: String]?
            if let stHeaders = self._stHeaders {
                headersToUse = stHeaders
                Self.logger.debug("   🔐 Using subtitle-specific headers for download:")
            } else if let videoHeaders = self._videoHeaders {
                // Fallback to video headers - subtitles often need same auth
                headersToUse = videoHeaders
                Self.logger.debug("   🔐 Using video headers for subtitle download (fallback):")
                Self.logger.debug("      Note: Subtitles will use same auth headers as video")
            } else {
                headersToUse = nil
                Self.logger.debug("   ⚠️ No headers provided for subtitle download")
                Self.logger.debug("      This may cause authentication failures if subtitle server requires auth")
                Self.logger.debug("      Subtitle URL: \(finalUrl.absoluteString)")
            }
            
            let subtitleAsset: AVURLAsset
            if let headers = headersToUse {
                for (key, value) in headers {
                    // Mask sensitive tokens in logs
                    let maskedValue = (key.lowercased().contains("token") || key.lowercased().contains("auth")) 
                        ? "***\(String(value.suffix(4)))" 
                        : value
                    Self.logger.debug("      \(key): \(maskedValue)")
                }
                subtitleAsset = AVURLAsset(url: finalUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            } else {
                subtitleAsset = AVURLAsset(url: finalUrl)
            }
            
            Self.logger.debug("   📥 Created AVURLAsset for track \(trackId)")
            subtitleAssets.append((asset: subtitleAsset, trackId: trackId, language: language))
        }
        
        Self.logger.debug("📦 Starting async load for \(subtitleAssets.count) subtitle assets...")

        var loadableAssets: [(asset: AVURLAsset, trackId: String, language: String)] = []
        for subtitleInfo in subtitleAssets {
            Self.logger.debug("   ⏳ Loading subtitle asset for track: \(subtitleInfo.trackId) from \(subtitleInfo.asset.url.absoluteString)")
            if subtitleInfo.asset.url.isFileURL {
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: subtitleInfo.asset.url.path) {
                    Self.logger.debug("   ❌ Subtitle file does not exist at path: \(subtitleInfo.asset.url.path)")
                    continue
                }
                Self.logger.debug("   ✅ Subtitle file exists at path: \(subtitleInfo.asset.url.path)")
            } else {
                Self.logger.debug("   🌐 Subtitle is remote URL, will download")
            }
            loadableAssets.append(subtitleInfo)
        }

        let loadedSubtitleAssets = await AVURLAsset.loadSubtitleAssets(loadableAssets)
        Self.logger.notice(" Loaded \(loadedSubtitleAssets.count) subtitle assets")

        var addedTracksCount = 0
        for subtitleInfo in loadedSubtitleAssets {
            let subtitleAssetTracks = subtitleInfo.textTracks

            Self.logger.debug("   🔧 Creating composition subtitle track for: \(subtitleInfo.trackId) (\(subtitleInfo.language))")
            guard let compositionSubtitleTrack = composition.addMutableTrack(
                withMediaType: .subtitle,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                Self.logger.error(" Failed to create subtitle track in composition for: \(subtitleInfo.trackId)")
                continue
            }
            Self.logger.debug("   ✅ Created composition subtitle track successfully")

            do {
                let duration = assetDuration ?? .invalid
                let durationToUse = duration.isValid && !duration.isIndefinite
                    ? duration
                    : CMTimeMake(value: 3600, timescale: 1)

                try compositionSubtitleTrack.insertTimeRange(
                    CMTimeRangeMake(start: .zero, duration: durationToUse),
                    of: subtitleAssetTracks[0],
                    at: .zero
                )

                let sourceTrack = subtitleAssetTracks[0]
                let languageTags = try? await sourceTrack.loadLanguageTags()
                if languageTags?.languageCode == nil || languageTags?.extendedTag == nil {
                    Self.logger.warning(" Source subtitle track has no language metadata for: \(subtitleInfo.trackId)")
                    Self.logger.debug("   This may cause issues with track identification in media selection")
                } else {
                    Self.logger.debug("   Source track language: \(languageTags?.extendedTag ?? "nil")")
                }

                addedTracksCount += 1
                Self.logger.notice(" Successfully added subtitle track: \(subtitleInfo.trackId) (\(subtitleInfo.language))")
            } catch {
                Self.logger.error(" Failed to insert subtitle track \(subtitleInfo.trackId): \(error)")
            }
        }
            
        Self.logger.debug("📊 Total subtitle tracks added to composition: \(addedTracksCount) out of \(subtitleAssets.count)")
        
        // CRITICAL: For HLS, if no video tracks were added, we CANNOT use this composition
        // A composition with only subtitle tracks (no video/audio) will not play
        // We must wait for video tracks to be available before creating the composition
        if videoTracks.isEmpty {
            Self.logger.error(" Cannot create composition: No video tracks available")
            Self.logger.debug("   A composition with only subtitle tracks will not play")
            Self.logger.debug("   Must wait for video tracks before creating composition")
            Self.logger.debug("   Subtitle tracks (\(addedTracksCount)) were prepared but composition is invalid")
            
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
    ) async -> AVMutableComposition? {
        Self.logger.debug("🔧 createCompositionWithPlayerItemTracks called")
        Self.logger.debug("   Video tracks: \(videoTracks.count)")
        Self.logger.debug("   Audio tracks: \(audioTracks.count)")
        Self.logger.debug("   Subtitle tracks: \(subtitleTracks.count)")

        let composition = AVMutableComposition()

        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            Self.logger.error(" Failed to create video track in composition")
            return nil
        }

        do {
            let duration = try await videoTracks[0].loadTimeRangeValue().duration
            try compositionVideoTrack.insertTimeRange(
                CMTimeRangeMake(start: .zero, duration: duration),
                of: videoTracks[0],
                at: .zero
            )
            Self.logger.notice(" Video track added to composition")
        } catch {
            Self.logger.error(" Failed to insert video track: \(error)")
            return nil
        }

        if !audioTracks.isEmpty,
           let compositionAudioTrack = composition.addMutableTrack(
               withMediaType: .audio,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            do {
                let duration = try await audioTracks[0].loadTimeRangeValue().duration
                try compositionAudioTrack.insertTimeRange(
                    CMTimeRangeMake(start: .zero, duration: duration),
                    of: audioTracks[0],
                    at: .zero
                )
                Self.logger.notice(" Audio track added to composition")
            } catch {
                Self.logger.warning(" Failed to insert audio track: \(error)")
            }
        }

        return await self.addSubtitleTracksToComposition(composition: composition, subtitleTracks: subtitleTracks)
    }
    
    /// Helper method to add subtitle tracks to an existing composition
    private func addSubtitleTracksToComposition(
        composition: AVMutableComposition,
        subtitleTracks: [[String: Any]]
    ) async -> AVMutableComposition? {
        Self.logger.debug("📝 Adding \(subtitleTracks.count) subtitle tracks to composition...")

        var subtitleAssets: [(asset: AVURLAsset, trackId: String, language: String)] = []

        for (_, trackDict) in subtitleTracks.enumerated() {
            guard let trackUrlString = trackDict["url"] as? String,
                  let trackId = trackDict["id"] as? String,
                  let language = trackDict["language"] as? String else {
                continue
            }

            var trackUrl: URL?
            if trackUrlString.hasPrefix("http://") || trackUrlString.hasPrefix("https://") {
                trackUrl = URL(string: trackUrlString)
            } else if trackUrlString.hasPrefix("file://") {
                trackUrl = URL(string: trackUrlString)
            } else {
                trackUrl = URL(fileURLWithPath: trackUrlString)
            }

            guard let subtitleUrl = trackUrl else { continue }

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

            let headersToUse = self._stHeaders ?? self._videoHeaders
            let subtitleAsset: AVURLAsset
            if let headers = headersToUse {
                subtitleAsset = AVURLAsset(url: finalUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            } else {
                subtitleAsset = AVURLAsset(url: finalUrl)
            }

            subtitleAssets.append((asset: subtitleAsset, trackId: trackId, language: language))
        }

        Self.logger.debug("📦 Starting async load for \(subtitleAssets.count) subtitle assets...")
        let loadedSubtitleAssets = await AVURLAsset.loadSubtitleAssets(subtitleAssets)
        Self.logger.notice(" Loaded \(loadedSubtitleAssets.count) subtitle assets")

        var addedTracksCount = 0
        for subtitleInfo in loadedSubtitleAssets {
            Self.logger.debug("   🔧 Creating composition subtitle track for: \(subtitleInfo.trackId) (\(subtitleInfo.language))")
            guard let compositionSubtitleTrack = composition.addMutableTrack(
                withMediaType: .subtitle,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                Self.logger.error(" Failed to create subtitle track in composition for: \(subtitleInfo.trackId)")
                continue
            }
            Self.logger.debug("   ✅ Created composition subtitle track successfully")

            do {
                let compVideoTracks = try await composition.loadVideoTracks()
                let duration: CMTime
                if compVideoTracks.isEmpty {
                    duration = CMTimeMake(value: 3600, timescale: 1)
                } else {
                    duration = try await compVideoTracks[0].loadTimeRangeValue().duration
                }
                Self.logger.debug("   ⏱️ Using duration: \(CMTimeGetSeconds(duration))s for subtitle track")

                try compositionSubtitleTrack.insertTimeRange(
                    CMTimeRangeMake(start: .zero, duration: duration),
                    of: subtitleInfo.textTracks[0],
                    at: .zero
                )

                addedTracksCount += 1
                Self.logger.notice(" Successfully added subtitle track: \(subtitleInfo.trackId) (\(subtitleInfo.language))")
            } catch {
                Self.logger.error(" Failed to insert subtitle track \(subtitleInfo.trackId): \(error)")
            }
        }

        Self.logger.debug("📊 Total subtitle tracks added to composition: \(addedTracksCount) out of \(subtitleAssets.count)")

        return composition
    }
    
    // MARK: - Non-HLS Composition (for regular video files with tracks available)
    
    private func createCompositionWithMultipleSubtitles(
        videoTracks: [AVAssetTrack],
        audioTracks: [AVAssetTrack],
        subtitleTracks: [[String: Any]]
    ) async -> AVMutableComposition? {
        Self.logger.debug("🔧 createCompositionWithMultipleSubtitles called (non-HLS)")
        Self.logger.debug("   Input: \(subtitleTracks.count) subtitle tracks")
        let composition = AVMutableComposition()

        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            Self.logger.error(" Failed to create video track in composition")
            return nil
        }
        Self.logger.notice(" Video track added to composition")

        do {
            let duration = try await self.videoAsset.loadDurationValue()

            try compositionVideoTrack.insertTimeRange(
                CMTimeRangeMake(start: .zero, duration: duration),
                of: videoTracks[0],
                at: .zero
            )

            if !audioTracks.isEmpty,
               let compositionAudioTrack = composition.addMutableTrack(
                   withMediaType: .audio,
                   preferredTrackID: kCMPersistentTrackID_Invalid
               ) {
                try compositionAudioTrack.insertTimeRange(
                    CMTimeRangeMake(start: .zero, duration: duration),
                    of: audioTracks[0],
                    at: .zero
                )
            }

            Self.logger.debug("📝 Processing \(subtitleTracks.count) subtitle tracks...")
            var subtitleAssets: [(asset: AVURLAsset, trackId: String, language: String)] = []
            
            // First, resolve all URLs and create assets
            for (index, trackDict) in subtitleTracks.enumerated() {
                Self.logger.debug("   Processing track \(index + 1)/\(subtitleTracks.count)...")
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
                    Self.logger.error(" Failed to resolve subtitle URL for track: \(trackId)")
                    continue
                }
                Self.logger.debug("   ✅ Resolved URL for track \(trackId): \(subtitleUrl.absoluteString)")
                
                // Check if SRT and convert to VTT if needed, or add language metadata to VTT
                let finalUrl: URL
                if subtitleUrl.pathExtension.lowercased() == "srt" {
                    Self.logger.debug("   🔄 Converting SRT to VTT for track: \(trackId)")
                    if let vttUrl = self.convertSRTToWebVTT(srtURL: subtitleUrl, language: language) {
                        finalUrl = vttUrl
                        Self.logger.debug("   ✅ SRT converted to VTT: \(vttUrl.absoluteString)")
                    } else {
                        Self.logger.error(" Failed to convert SRT to VTT for track: \(trackId)")
                        continue
                    }
                } else if subtitleUrl.pathExtension.lowercased() == "vtt" {
                    // Ensure VTT file has language metadata
                    Self.logger.debug("   🔍 Ensuring VTT has language metadata for track: \(trackId)")
                    if let vttUrl = self.ensureVTTLanguageMetadata(vttURL: subtitleUrl, language: language) {
                        finalUrl = vttUrl
                        Self.logger.debug("   ✅ VTT language metadata ensured: \(vttUrl.absoluteString)")
                    } else {
                        finalUrl = subtitleUrl
                        Self.logger.debug("   ⚠️ Could not add language metadata, using original VTT")
                    }
                } else {
                    finalUrl = subtitleUrl
                    Self.logger.debug("   ℹ️ Using subtitle file as-is (extension: \(subtitleUrl.pathExtension))")
                }
                
                // Create asset with headers if available
                let headersToUse: [String: String]?
                if let stHeaders = self._stHeaders {
                    headersToUse = stHeaders
                    Self.logger.debug("   🔐 Using subtitle-specific headers for download:")
                } else if let videoHeaders = self._videoHeaders {
                    headersToUse = videoHeaders
                    Self.logger.debug("   🔐 Using video headers for subtitle download (fallback):")
                } else {
                    headersToUse = nil
                    Self.logger.debug("   ⚠️ No headers provided for subtitle download")
                }
                
                let subtitleAsset: AVURLAsset
                if let headers = headersToUse {
                    subtitleAsset = AVURLAsset(url: finalUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                } else {
                    subtitleAsset = AVURLAsset(url: finalUrl)
                }
                
                Self.logger.debug("   📥 Created AVURLAsset for track \(trackId)")
                subtitleAssets.append((asset: subtitleAsset, trackId: trackId, language: language))
            }
            
            let loadedSubtitleAssets = await AVURLAsset.loadSubtitleAssets(subtitleAssets)
            var addedTracksCount = 0
            for subtitleInfo in loadedSubtitleAssets {
                Self.logger.debug("   🔧 Creating composition subtitle track for: \(subtitleInfo.trackId) (\(subtitleInfo.language))")
                guard let compositionSubtitleTrack = composition.addMutableTrack(
                    withMediaType: .subtitle,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    Self.logger.error(" Failed to create subtitle track in composition for: \(subtitleInfo.trackId)")
                    continue
                }
                Self.logger.debug("   ✅ Created composition subtitle track successfully")

                do {
                    try compositionSubtitleTrack.insertTimeRange(
                        CMTimeRangeMake(start: .zero, duration: duration),
                        of: subtitleInfo.textTracks[0],
                        at: .zero
                    )

                    addedTracksCount += 1
                    Self.logger.notice(" Successfully added subtitle track: \(subtitleInfo.trackId) (\(subtitleInfo.language))")
                } catch {
                    Self.logger.error(" Failed to insert subtitle track \(subtitleInfo.trackId): \(error)")
                }
            }

            Self.logger.debug("📊 Total subtitle tracks added to composition: \(addedTracksCount) out of \(subtitleAssets.count)")

            return composition
        } catch {
            Self.logger.debug("Failed to create composition with multiple subtitles: \(error)")
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
        guard let playerItem = self.playerItem else {
            return
        }
        
        // Wait for player item to be ready before selecting track
        if playerItem.status == .readyToPlay {
            self.selectInitialTrack()
        } else {
            // Observe status and select when ready
            self.itemStatusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
                guard let self = self else { return }
                if item.status == .readyToPlay {
                    self.selectInitialTrack()
                }
            }
        }
    }
    
    private func selectInitialTrack() {
        Task { @MainActor in
            await self.selectInitialTrackAsync()
        }
    }

    @MainActor
    private func selectInitialTrackAsync() async {
        guard let playerItem = self.playerItem else {
            Self.logger.warning(" selectInitialTrack: playerItem is nil")
            return
        }

        guard let mediaSelectionGroup = try? await playerItem.asset.loadLegibleMediaSelectionGroup() else {
            Self.logger.warning(" selectInitialTrack: No subtitle selection group available")
            let characteristics = (try? await playerItem.asset.loadAvailableMediaCharacteristics()) ?? []
            Self.logger.debug("   Available media characteristics: \(characteristics)")
            return
        }

        Self.logger.debug("📋 Available subtitle options: \(mediaSelectionGroup.options.count)")
        for (index, option) in mediaSelectionGroup.options.enumerated() {
            Self.logger.debug("   Option \(index): lang=\(option.extendedLanguageTag ?? "nil"), locale=\(option.locale?.identifier ?? "nil"), displayName=\(option.displayName)")
        }

        if let selectedId = self._selectedSubtitleId {
            Self.logger.debug("🎯 Attempting to select track by ID: \(selectedId)")
            let options = mediaSelectionGroup.options.filter { option in
                option.extendedLanguageTag == selectedId ||
                option.modernLanguageCode == selectedId ||
                option.displayName.contains(selectedId)
            }

            if let option = options.first {
                Self.logger.debug("   🎯 Found matching option: lang=\(option.extendedLanguageTag ?? "nil"), locale=\(option.locale?.identifier ?? "nil"), displayName=\(option.displayName)")
                playerItem.select(option, in: mediaSelectionGroup)
                Self.logger.notice(" Selected initial subtitle track: \(selectedId) (lang: \(option.extendedLanguageTag ?? "nil"), displayName: \(option.displayName))")

                let selectedOption = playerItem.currentMediaSelection.selectedMediaOption(in: mediaSelectionGroup)
                Self.logger.debug("   ✅ Verified selection: \(selectedOption?.displayName ?? "nil")")
            } else {
                Self.logger.error(" Could not find matching subtitle option for track ID: \(selectedId)")
                Self.logger.debug("   Available options:")
                for (idx, opt) in mediaSelectionGroup.options.enumerated() {
                    Self.logger.debug("      [\(idx)] lang=\(opt.extendedLanguageTag ?? "nil"), locale=\(opt.locale?.identifier ?? "nil"), displayName=\(opt.displayName)")
                }
                Self.logger.debug("   No subtitle selected - letting system decide")
            }
        } else {
            Self.logger.debug("   No _selectedSubtitleId set - not selecting any subtitle, letting system decide")
        }
    }

    /// Match `AVMediaSelectionOption` to app `subtitles[].id` from init when language aligns (stable bridge `trackId`).
    private func resolvedManifestSubtitleTrackId(for option: AVMediaSelectionOption) -> String? {
        guard let tracks = self._subtitleTracks else { return nil }
        let extTag = option.extendedLanguageTag?.lowercased()
        let localeId = option.locale?.identifier.lowercased()
        let langCode = option.modernLanguageCode?.lowercased()
        for track in tracks {
            guard let id = track["id"] as? String else { continue }
            guard let tLang = (track["language"] as? String)?.lowercased() else { continue }
            if let extTag = extTag, (extTag == tLang || extTag.hasPrefix(tLang + "-") || extTag.hasPrefix(tLang + "_")) {
                return id
            }
            if let localeId = localeId, localeId.hasPrefix(tLang) { return id }
            if let langCode = langCode, langCode == tLang { return id }
        }
        return nil
    }
    
    /// Adds observer for media selection changes (when user clicks subtitle option in native menu)
    private func addMediaSelectionObserver() {
        Self.logger.debug("🎧 Adding media selection change observer...")
        
        guard let playerItem = self.playerItem else {
            Self.logger.debug("   ⚠️ playerItem is nil, cannot add media selection observer")
            return
        }
        
        // Use KVO to observe currentMediaSelection changes
        // This will fire when user changes subtitle selection in native menu
        self.mediaSelectionObserver = playerItem.observe(\.currentMediaSelection, options: [.new, .old]) { [weak self] item, _ in
            guard let self = self else { return }
            Self.logger.debug("🎧 Media selection changed (user clicked in native menu)")

            Task { @MainActor in
                guard let mediaSelectionGroup = try? await item.asset.loadLegibleMediaSelectionGroup() else {
                    Self.logger.debug("   ⚠️ Could not get media selection group")
                    return
                }

                let selectedOption = item.currentMediaSelection.selectedMediaOption(in: mediaSelectionGroup)
                if let option = selectedOption {
                    Self.logger.debug("   ✅ User selected subtitle: lang=\(option.extendedLanguageTag ?? "nil"), locale=\(option.locale?.identifier ?? "nil"), displayName=\(option.displayName)")

                    let manifestId = self.resolvedManifestSubtitleTrackId(for: option)
                    if let mid = manifestId {
                        self._activeSubtitleTrackId = mid
                    } else if let localeId = option.locale?.identifier {
                        self._activeSubtitleTrackId = localeId
                    } else if let langTag = option.extendedLanguageTag {
                        self._activeSubtitleTrackId = langTag
                    } else {
                        self._activeSubtitleTrackId = option.displayName
                    }
                    Self.logger.debug("   📝 Updated _activeSubtitleTrackId to: \(self._activeSubtitleTrackId ?? "nil")")
                    let langCode: String
                    if let tag = option.extendedLanguageTag, !tag.isEmpty {
                        langCode = tag
                    } else if let lid = option.locale?.identifier, !lid.isEmpty {
                        langCode = lid
                    } else {
                        langCode = "und"
                    }
                    if !self.suppressSubtitleBridgeEvents {
                        self.postSubtitleBridgeEvent(language: langCode, trackId: manifestId)
                    }
                } else {
                    Self.logger.debug("   ℹ️ User deselected subtitles (selected nil)")
                    self._activeSubtitleTrackId = nil
                    if !self.suppressSubtitleBridgeEvents {
                        self.postSubtitleBridgeEvent(language: "off", trackId: nil)
                    }
                }
            }
        }

        Self.logger.debug("   ✅ Media selection observer added")
        self.scheduleSubtitleBridgeUnsuppress()
    }

    private func scheduleSubtitleBridgeUnsuppress() {
        guard !self.subtitleBridgeUnsuppressScheduled else { return }
        self.subtitleBridgeUnsuppressScheduled = true
        self.suppressSubtitleBridgeEvents = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in
            self?.suppressSubtitleBridgeEvents = false
        }
    }

    private func postSeekBridgeEvent(fromSeconds: Double, toSeconds: Double) {
        let rawDuration = self.getDuration()
        var info: [String: Any] = [
            "fromPlayerId": self._videoId,
            "fromPosition": fromSeconds,
            "toPosition": toSeconds
        ]
        if rawDuration.isFinite && rawDuration > 0 {
            info["duration"] = rawDuration
        }
        NotificationCenter.default.post(name: .playerItemSeekCompleted, object: nil, userInfo: info)
    }

    private func postSubtitleBridgeEvent(language: String, trackId: String?) {
        var info: [String: Any] = [
            "fromPlayerId": self._videoId,
            "language": language
        ]
        if let trackId = trackId {
            info["trackId"] = trackId
        }
        NotificationCenter.default.post(name: .playerItemSubtitleChange, object: nil, userInfo: info)
    }
    
    /// Fallback: Custom UILabel subtitle display for HLS when composition creation fails
    /// This loads all subtitle tracks, parses them, and displays using UILabel overlay
    private func setupCustomSubtitleDisplayForHLS(subtitleTracks: [[String: Any]]) {
        Self.logger.debug("🎬 ========================================")
        Self.logger.debug("🎬 CUSTOM SUBTITLE DISPLAY (FALLBACK)")
        Self.logger.debug("🎬 ========================================")
        Self.logger.debug("   📋 Why we're using this method:")
        Self.logger.debug("      - HLS streams don't expose tracks for composition creation")
        Self.logger.debug("      - This is an iOS AVFoundation limitation, NOT a backend issue")
        Self.logger.debug("      - Your backend provides all necessary data correctly")
        Self.logger.debug("      - This is the standard approach for HLS + external subtitles")
        Self.logger.debug("   📊 Data we have:")
        Self.logger.debug("      - Video URL: \(self.videoAsset.url.absoluteString)")
        Self.logger.debug("      - Subtitle tracks: \(subtitleTracks.count)")
        for (index, track) in subtitleTracks.enumerated() {
            if let trackId = track["id"] as? String,
               let trackUrl = track["url"] as? String,
               let trackLang = track["language"] as? String {
                Self.logger.debug("         Track \(index + 1): \(trackId) (\(trackLang))")
                Self.logger.debug("            URL: \(trackUrl)")
            }
        }
        Self.logger.debug("   🎯 What we'll do:")
        Self.logger.debug("      - Load all \(subtitleTracks.count) subtitle files via HTTP")
        Self.logger.debug("      - Parse VTT/SRT content")
        Self.logger.debug("      - Display using UILabel overlay on video player")
        Self.logger.debug("      - Update in real-time based on playback time")
        Self.logger.debug("   ⚠️ Note: Subtitles will be visible but won't appear in native iOS menu")
        Self.logger.debug("      (This is expected for HLS + external subtitles)")
        Self.logger.debug("🎬 ========================================")
        
        // Load all subtitle tracks asynchronously (like working branch)
        var loadedCount = 0
        let totalTracks = subtitleTracks.count
        
        for track in subtitleTracks {
            guard let trackUrlString = track["url"] as? String,
                  let trackId = track["id"] as? String else {
                loadedCount += 1
                if loadedCount >= totalTracks {
                    self.finishCustomSubtitleSetup()
                }
                continue
            }
            
            // Resolve URL
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
                trackUrl = URL(fileURLWithPath: trackUrlString)
            }
            
            guard let subtitleUrl = trackUrl else {
                Self.logger.debug("   ❌ Failed to resolve URL for track: \(trackId)")
                Self.logger.debug("      Original URL string: \(trackUrlString)")
                loadedCount += 1
                if loadedCount >= totalTracks {
                    self.finishCustomSubtitleSetup()
                }
                continue
            }
            
            Self.logger.debug("   📥 Loading subtitle track: \(trackId)")
            Self.logger.debug("      Resolved URL: \(subtitleUrl.absoluteString)")
            
            // Load subtitle file with proper headers for authentication
            // Use the same approach as working branch: URLSession.shared with headers in request
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                // Use URLSession.shared (like working branch) - it handles redirects automatically
                let session = URLSession.shared
                var request = URLRequest(url: subtitleUrl)
                
                // Add headers if they were provided for the video
                if let headers = self._stHeaders ?? self._videoHeaders {
                    for (key, value) in headers {
                        request.setValue(value, forHTTPHeaderField: key)
                    }
                    Self.logger.debug("      ✅ Added \(headers.count) authentication headers")
                } else {
                    Self.logger.debug("      ⚠️ No authentication headers available")
                }
                
                Self.logger.debug("      🌐 Starting HTTP request for subtitle file...")
                let task = session.dataTask(with: request) { [weak self] data, response, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        Self.logger.debug("      ❌ HTTP Error loading subtitle for track \(trackId):")
                        Self.logger.debug("         Error: \(error.localizedDescription)")
                        Self.logger.debug("         URL: \(subtitleUrl.absoluteString)")
                        DispatchQueue.main.async {
                            self.subtitleTracksData[trackId] = []
                            loadedCount += 1
                            if loadedCount >= totalTracks {
                                self.finishCustomSubtitleSetup()
                            }
                        }
                        return
                    }
                    
                    // Check HTTP response status
                    if let httpResponse = response as? HTTPURLResponse {
                        Self.logger.debug("      📊 HTTP Response for track \(trackId):")
                        Self.logger.debug("         Status Code: \(httpResponse.statusCode)")
                        Self.logger.debug("         Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
                        Self.logger.debug("         Content-Length: \(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "unknown") bytes")
                        
                        if httpResponse.statusCode != 200 {
                            Self.logger.debug("      ❌ HTTP Error: Status code \(httpResponse.statusCode) for track \(trackId)")
                            DispatchQueue.main.async {
                                self.subtitleTracksData[trackId] = []
                                loadedCount += 1
                                if loadedCount >= totalTracks {
                                    self.finishCustomSubtitleSetup()
                                }
                            }
                            return
                        }
                    }
                    
                    guard let data = data else {
                        Self.logger.debug("      ❌ No data received for track: \(trackId)")
                        DispatchQueue.main.async {
                            self.subtitleTracksData[trackId] = []
                            loadedCount += 1
                            if loadedCount >= totalTracks {
                                self.finishCustomSubtitleSetup()
                            }
                        }
                        return
                    }
                    
                    Self.logger.debug("      ✅ Received \(data.count) bytes of subtitle data")
                    
                    guard let subtitleContent = String(data: data, encoding: .utf8) else {
                        Self.logger.debug("      ❌ Failed to decode subtitle content as UTF-8 for track: \(trackId)")
                        Self.logger.debug("         Data size: \(data.count) bytes")
                        DispatchQueue.main.async {
                            self.subtitleTracksData[trackId] = []
                            loadedCount += 1
                            if loadedCount >= totalTracks {
                                self.finishCustomSubtitleSetup()
                            }
                        }
                        return
                    }
                    
                    Self.logger.debug("      📝 Decoded subtitle content (\(subtitleContent.count) characters)")
                    Self.logger.debug("      Preview (first 100 chars): \(String(subtitleContent.prefix(100)))")
                    
                    // Check if we got an error response (like 401)
                    if subtitleContent.contains("\"status\":401") || subtitleContent.contains("Unauthorized") {
                        Self.logger.debug("      ⚠️ Authentication failed (401) for subtitle track: \(trackId)")
                        DispatchQueue.main.async {
                            self.subtitleTracksData[trackId] = []
                            loadedCount += 1
                            if loadedCount >= totalTracks {
                                self.finishCustomSubtitleSetup()
                            }
                        }
                        return
                    }
                    
                    // Parse subtitle content
                    let isVTT = subtitleContent.hasPrefix("WEBVTT")
                    Self.logger.debug("      🔍 Detected format: \(isVTT ? "WebVTT" : "SRT")")
                    
                    let subtitles: [(start: Double, end: Double, text: String)]
                    if isVTT {
                        subtitles = self.parseVTTContent(subtitleContent)
                    } else {
                        subtitles = self.parseSRTContent(subtitleContent)
                    }
                    
                    Self.logger.debug("      ✅ Successfully parsed \(subtitles.count) subtitle entries for track: \(trackId)")
                    if !subtitles.isEmpty {
                        Self.logger.debug("         First subtitle: \(subtitles[0].start)s - \(subtitles[0].end)s")
                        Self.logger.debug("         Last subtitle: \(subtitles[subtitles.count - 1].start)s - \(subtitles[subtitles.count - 1].end)s")
                    }
                    
                    DispatchQueue.main.async {
                        self.subtitleTracksData[trackId] = subtitles
                        loadedCount += 1
                        if loadedCount >= totalTracks {
                            self.finishCustomSubtitleSetup()
                        }
                    }
                }
                
                task.resume()
            }
        }
    }
    
    /// Called when all subtitle tracks have finished loading
    private func finishCustomSubtitleSetup() {
        Self.logger.notice(" All subtitle tracks loaded for custom display")
        Self.logger.debug("   Loaded tracks: \(self.subtitleTracksData.keys.joined(separator: ", "))")
        
        // Set initial active track
        if let selectedId = self._selectedSubtitleId ?? self._subtitleTracks?.first?["id"] as? String {
            self._activeSubtitleTrackId = selectedId
            Self.logger.debug("   🎯 Initial active track: \(selectedId)")
        }
        
        // Wait for player to be ready before adding subtitle display
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.setupCustomSubtitleLabel()
        }
    }
    
    /// Sets up UILabel overlay for custom subtitle display
    private func setupCustomSubtitleLabel() {
        Self.logger.debug("🎨 Setting up custom subtitle UILabel overlay...")
        
        // Create subtitle label
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
            
            // Wait for the view to have proper dimensions before setting constraints
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSLayoutConstraint.activate([
                    label.centerXAnchor.constraint(equalTo: contentOverlayView.centerXAnchor),
                    label.bottomAnchor.constraint(equalTo: contentOverlayView.bottomAnchor, constant: -50),
                    label.leadingAnchor.constraint(greaterThanOrEqualTo: contentOverlayView.leadingAnchor, constant: 20),
                    label.trailingAnchor.constraint(lessThanOrEqualTo: contentOverlayView.trailingAnchor, constant: -20),
                    label.widthAnchor.constraint(lessThanOrEqualTo: contentOverlayView.widthAnchor, constant: -40)
                ])
                Self.logger.debug("   ✅ Added subtitle label constraints")
            }
            Self.logger.debug("   ✅ Added subtitle label to content overlay view")
        } else {
            Self.logger.debug("   ⚠️ Content overlay view is nil!")
        }
        
        // Store current subtitle to avoid unnecessary updates
        var currentDisplayedSubtitle: String? = nil
        
        // Set up subtitle timing with player time observer (like working branch)
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
                    Self.logger.debug("   📝 Subtitle: \(newText.prefix(50))...")
                } else {
                    // Hide subtitle instantly
                    label.isHidden = true
                }
            }
        }
        
        // Store the observer for cleanup later
        self.subtitleTimeObserver = timeObserver
        Self.logger.debug("   ✅ Custom subtitle display setup complete")
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
            Self.logger.debug("Failed to convert SRT to WebVTT: \(error)")
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
            Self.logger.debug("Failed to add language metadata to VTT: \(error)")
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
        self.player?.currentItem?.preferredPeakBitRate = 0
        
        // Additional optimizations to prevent HAL errors
        self.player?.currentItem?.preferredMaximumResolution = CGSize(width: 1920, height: 1080)
        self.player?.currentItem?.preferredForwardBufferDuration = 3.0
        if !self._showControls {
            self.videoPlayer.showsPlaybackControls = false
        }
        self.videoPlayer.player = self.player
        self.videoPlayer.updatesNowPlayingInfoCenter = false
        self.videoPlayer.isModalInPresentation = true
        self.videoPlayer.allowsPictureInPicturePlayback = false
        if isPIPModeAvailable && self._pipEnabled {
            self.videoPlayer.allowsPictureInPicturePlayback = true
        }

        self._isLoaded.updateValue(false, forKey: self._videoId)
    }
    
    // MARK: - Audio Session Configuration
    
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        // Try to deactivate any existing session (ignore errors if not active)
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        
        // Configure category - try progressively simpler configurations
        do {
            // Try with AirPlay and Bluetooth support (without mixWithOthers)
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetoothHFP])
        } catch {
            // Try with just AirPlay
            do {
                try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            } catch {
                // Try with no options
                do {
                    try audioSession.setCategory(.playback, mode: .moviePlayback, options: [])
                } catch {
                    Self.logger.error("Failed to configure audio session category: \(error.localizedDescription, privacy: .public)")
                    self.configureAudioSessionFallback()
                    return
                }
            }
        }
        
        // Set preferred sample rate (non-critical, continue on error)
        try? audioSession.setPreferredSampleRate(44100.0)
        
        // Set preferred buffer duration (non-critical, continue on error)
        try? audioSession.setPreferredIOBufferDuration(0.02)
        
        // Disable interruptions (non-critical)
        try? audioSession.setPrefersNoInterruptionsFromSystemAlerts(true)
        
        // Activate the session
        do {
            try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
        } catch {
            Self.logger.error("Failed to activate audio session: \(error.localizedDescription, privacy: .public)")
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
            
            Self.logger.notice(" Audio session fallback configured")
        } catch {
            Self.logger.error(" Failed to configure audio session fallback: \(error)")
        }
    }
    
    private func cleanupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Pause the player first to prevent HAL errors
            self.player?.pause()
            
            // Wait a moment for audio to stop
            Thread.sleep(forTimeInterval: 0.1)
            
            // Deactivate the session with proper options to notify other audio sessions
            // DO NOT reset category - let the audio player reactivate with its own category
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            Self.logger.notice(" Audio session deactivated (category preserved for audio player)")
        } catch {
            Self.logger.error(" Failed to deactivate audio session: \(error)")
            // Force deactivation as fallback
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setActive(false)
                Self.logger.notice(" Audio session force deactivated")
            } catch {
                Self.logger.error(" Failed to force deactivate audio session: \(error)")
            }
        }
    }
    
    // MARK: - Auto-play for HLS streams
    
    private func autoPlayIfHLSReady() {
        // Check if this is an HLS stream
        let isHLSStream = FullScreenVideoPlayerView.isHLSStream(url: self._url)
        
        if isHLSStream {
            
            // Small delay to ensure everything is properly set up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                
                // Start playing the HLS stream
                self.player?.play()
                self.player?.rate = self._videoRate
                self.isPlaying = true
                
                Self.logger.notice(" HLS stream auto-play started")
                
                // Start position updates
                self.startPositionUpdates()
                
                // Notify that playback has started
                let vId: [String: Any] = [
                    "fromPlayerId": self._videoId,
                    "currentTime": self._currentTime,
                    "videoRate": self._videoRate
                ]
                NotificationCenter.default.post(name: .playerItemPlay, object: nil, userInfo: vId)
            }
        } else {
            Self.logger.debug("📹 Non-HLS stream - no auto-play")
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
                            Self.logger.debug("failing to load")
                            self._isLoaded.updateValue(false, forKey: self._videoId)
                        case .unknown:
                            // Player item is not yet ready.
                            Self.logger.debug("playerItem not yet ready")

                        @unknown default:
                            Self.logger.debug("playerItem Error \(String(describing: self.playerItem?.error))")
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
                    Self.logger.debug("AVPlayer Rate for player \(self._videoId): Loading")
                } else if rate > 0 && self._isReadyToPlay {
                    if rate != self._videoRate {
                        player.rate = self._videoRate
                    }

                    self.isPlaying = true
                    // Start position updates when playback actually starts
                    self.startPositionUpdates()
                    NotificationCenter.default.post(name: .playerItemPlay, object: nil, userInfo: vId)
                } else if rate == 0 && !isVideoEnded && abs(self._currentTime - self._duration) < 0.2 {
                    self.isPlaying = false
                    let fromLoop = self._currentTime
                    player.seek(to: CMTime.zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                        guard let self = self, finished else { return }
                        DispatchQueue.main.async {
                            self._currentTime = 0
                            self.postSeekBridgeEvent(fromSeconds: fromLoop, toSeconds: 0)
                        }
                    }
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
                            Self.logger.debug("AVPlayer Rate for player \(self._videoId): Paused")
                            NotificationCenter.default.post(name: .playerItemPause, object: nil, userInfo: vId)
                        }
                    } else {
                        isRateZero = true
                    }
                } else if self._isBufferEmpty[self._videoId] ?? true {
                    Self.logger.debug("AVPlayer Rate for player \(self._videoId): Buffer Empty Loading")
                }
            })
        self.videoPlayerFrameObserver = self.videoPlayer
            .observe(\.view.frame, options: [.new, .old],
                     changeHandler: {[weak self] (_, _) in
                        guard let self = self else { return }
                        if !isInPIPMode && !isOpeningNativeFullscreen && self._isReadyToPlay {
                            if self.videoPlayer.isBeingDismissed && !isVideoEnded {
                                NotificationCenter.default.post(name: .playerFullscreenDismiss, object: nil)
                            }
                        }

                     })
        self.videoPlayerMoveObserver = self.videoPlayer
            .observe(\.view.center, options: [.new, .old],
                     changeHandler: {[weak self] (_, _) in
                        guard let self = self else { return }
                        if !isInPIPMode && !isOpeningNativeFullscreen && self._isReadyToPlay {
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
        Self.logger.debug("🧹 Cleaning up observers...")
        
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
        
        if let positionObserver = self.positionUpdateObserver {
            self.player?.removeTimeObserver(positionObserver)
            self.positionUpdateObserver = nil
        }
        
        // Clean up player
        self.player?.pause()
        self.player?.replaceCurrentItem(with: nil)
        self.player = nil
        self.playerItem = nil
        
        // Clean up video asset
        self.videoAsset.cancelLoading()
        self.videoAsset.resourceLoader.setDelegate(nil, queue: nil)
        
        // Clean up resource loader delegate
        self.hlsSubtitleResourceLoader = nil
        
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
        
        Self.logger.notice(" Observers cleaned up")
    }
    
    deinit {
        Self.logger.debug("🗑️ FullScreenVideoPlayerView deinit called")
        self.removeObservers()
    }
    
    // MARK: - Public cleanup method for manual disposal
    
    @objc func cleanup() {
        Self.logger.debug("🧹 Manual cleanup called")
        self.removeObservers()
        
        // Force immediate memory cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            autoreleasepool {
                // Force garbage collection
                Self.logger.debug("🔄 Forcing memory cleanup...")
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
        
        // Start position updates if not already started
        // Use a small delay to ensure player is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.startPositionUpdates()
        }
    }
    @objc func pause() {
        self.isPlaying = false
        self.player?.pause()
        
        // Stop position updates when paused
        self.stopPositionUpdates()
        
        Self.logger.debug("⏸️ Video playback paused")
    }
    @objc func didFinishPlaying() -> Bool {
        return isVideoEnded
    }
    @objc func getDuration() -> Double {
        if let item = self.playerItem, item.duration.isValid && !item.duration.isIndefinite {
            return item.duration.seconds
        }
        if self._duration > 0 {
            return self._duration
        }
        return 0
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
        let fromSeconds = self.getRealCurrentTime()
        let seekTime: CMTime = CMTimeMake(value: Int64(time*1000), timescale: 1000)
        self.player?.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard let self = self, finished else { return }
            DispatchQueue.main.async {
                self._currentTime = time
                self.postSeekBridgeEvent(fromSeconds: fromSeconds, toSeconds: time)
            }
        }
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
            Self.logger.error("Creating folder error: \(error.localizedDescription, privacy: .public)")
        }
        let task = session.dataTask(with: srtURL) { (data, _, error) in
            guard let data = data, error == nil else {
                Self.logger.debug("Download failed: \(error?.localizedDescription ?? "ukn")")
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
                Self.logger.debug("Processing subs error: \(error)")
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
            let fromSeconds = self.getRealCurrentTime()
            let time = CMTime(seconds: seconds, preferredTimescale: 1)
            self.player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                guard let self = self, finished else { return }
                DispatchQueue.main.async {
                    self.postSeekBridgeEvent(fromSeconds: fromSeconds, toSeconds: seconds)
                }
            }
            return .success
        }
        rcc.skipForwardCommand.isEnabled = true
        rcc.skipForwardCommand.addTarget {event in
            if let player = self.player, let currentItem = player.currentItem {
                let fromSeconds = CMTimeGetSeconds(currentItem.currentTime())
                let currentTime = fromSeconds + 10
                self.player?.seek(to: CMTimeMakeWithSeconds(currentTime, preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                    guard let self = self, finished else { return }
                    DispatchQueue.main.async {
                        self.postSeekBridgeEvent(fromSeconds: fromSeconds, toSeconds: currentTime)
                    }
                }
                return .success
            } else {
                return .commandFailed
            }
        }
        rcc.skipBackwardCommand.isEnabled = true
        rcc.skipBackwardCommand.addTarget {event in
            if let player = self.player, let currentItem = player.currentItem {
                let fromSeconds = CMTimeGetSeconds(currentItem.currentTime())
                let currentTime = fromSeconds - 10
                self.player?.seek(to: CMTimeMakeWithSeconds(currentTime, preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                    guard let self = self, finished else { return }
                    DispatchQueue.main.async {
                        self.postSeekBridgeEvent(fromSeconds: fromSeconds, toSeconds: currentTime)
                    }
                }
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
                    Self.logger.debug("Error while downloading the image: \(error?.localizedDescription ?? "")")
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
    
    // MARK: - Position Updates
    
    func startPositionUpdates() {
        // Remove existing observer if any
        if let existingObserver = self.positionUpdateObserver {
            self.player?.removeTimeObserver(existingObserver)
            self.positionUpdateObserver = nil
        }
        
        // Only start if player is available and interval is greater than 0
        guard let player = self.player, self._positionUpdateInterval > 0 else {
            return
        }
        
        let interval = CMTimeMake(value: Int64(self._positionUpdateInterval), timescale: 1)
        self.positionUpdateObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [weak self] time in
            guard let self = self else { return }
            
            // Only send updates when video is playing
            guard self.isPlaying, self.playerItem != nil else {
                return
            }
            
            let currentTime = CMTimeGetSeconds(time)
            let duration = self.getDuration()
            
            let info: [String: Any] = [
                "fromPlayerId": self._videoId,
                "currentTime": currentTime,
                "duration": duration
            ]
            
            NotificationCenter.default.post(
                name: .playerItemPositionUpdate,
                object: nil,
                userInfo: info
            )
        }
    }
    
    func stopPositionUpdates() {
        if let observer = self.positionUpdateObserver {
            self.player?.removeTimeObserver(observer)
            self.positionUpdateObserver = nil
        }
    }
}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
