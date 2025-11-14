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
    // TEMPORARY: Flag to disable all subtitle functionality for testing
    private let SUBTITLES_DISABLED = false
    
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
    private var subtitleRetryInProgress: Bool = false // Prevent duplicate retry mechanisms
    
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
            if originalURL == nil, let originalRequest = task.originalRequest {
                originalURL = originalRequest.url
                redirectHistory.append(originalURL!)
            }
            
            redirectCount += 1
            guard let redirectURL = request.url else {
                print("      ❌ Redirect has no URL, stopping")
                completionHandler(nil)
                return
            }
            
            // Check for redirect loop - same URL as original or already visited
            if redirectURL == originalURL || redirectHistory.contains(redirectURL) {
                print("      ❌ REDIRECT LOOP DETECTED!")
                print("         Redirect URL matches original or was already visited")
                print("         Original: \(originalURL?.absoluteString ?? "unknown")")
                print("         Redirect: \(redirectURL.absoluteString)")
                print("         Redirect count: \(redirectCount)")
                completionHandler(nil) // Stop following redirects
                return
            }
            
            // Check redirect limit
            if redirectCount > maxRedirects {
                print("      ❌ Maximum redirects (\(maxRedirects)) exceeded, stopping")
                print("         This might indicate a redirect loop on the server")
                completionHandler(nil) // Stop following redirects
                return
            }
            
            redirectHistory.append(redirectURL)
            
            // Create a new request with the redirect URL but preserve our authentication headers
            var redirectedRequest = request
            for (key, value) in headers {
                redirectedRequest.setValue(value, forHTTPHeaderField: key)
            }
            
            print("      🔄 Redirect \(redirectCount)/\(maxRedirects) to: \(redirectURL.absoluteString)")
            print("      ✅ Preserved authentication headers in redirect")
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
    var mediaSelectionObserver: NSKeyValueObservation?
    var ccButtonHideTimer: Timer?

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
      print("🔍 ========================================")
      print("🔍 INITIALIZE() CALLED")
      print("🔍 ========================================")
      print("   Video URL: \(self._url.absoluteString)")
      print("   Subtitle tracks count: \(_subtitleTracks?.count ?? 0)")
      if let tracks = _subtitleTracks {
          print("   Subtitle tracks details:")
          for (index, track) in tracks.enumerated() {
              print("      Track \(index + 1): id=\(track["id"] ?? "nil"), url=\(track["url"] ?? "nil"), lang=\(track["language"] ?? "nil")")
          }
      } else {
          print("   ⚠️ _subtitleTracks is nil")
      }
      print("   Single subtitle URL: \(_stUrl?.absoluteString ?? "nil")")
      print("🔍 ========================================")
      
      // Simplified approach: Always create player with video asset, then add subtitles using library
      // Following the library example: https://github.com/mhergon/AVPlayerViewController-Subtitles
      print("   🎥 Setting up player with video asset...")
      self.playerItem = AVPlayerItem(asset: self.videoAsset)
      self.player = AVPlayer(playerItem: self.playerItem)
      
      // CRITICAL: Assign player to videoPlayer BEFORE setting up subtitles
      self.videoPlayer.player = self.player
      self.setupPlayer()
      
      // Add subtitles if available (using library, no composition needed)
      if !SUBTITLES_DISABLED {
          if let tracks = _subtitleTracks, !tracks.isEmpty {
              // Multiple subtitle tracks
              print("   ✅ Multiple subtitle tracks detected: \(tracks.count) tracks")
              self.setupMultipleSubtitlesWithAVPlayerViewControllerSubtitles(subtitleTracks: tracks)
          } else if let subTitleUrl = self._stUrl {
              // Single subtitle
              print("   ✅ Single subtitle detected")
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                  self?.addSubtitlesToPlayer(subTitleUrl: subTitleUrl)
              }
          }
      }
  }
    
    
    private func addSubtitlesToPlayer(subTitleUrl: URL) {
        print("Setting up subtitles using AVPlayerViewController-Subtitles...")
        
        // Ensure player is assigned before adding subtitles
        guard self.videoPlayer.player != nil else {
            print("⚠️ Player not ready, retrying...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.addSubtitlesToPlayer(subTitleUrl: subTitleUrl)
            }
            return
        }
        
        // Handle VTT files - library primarily supports SRT, but may support VTT
        // Try direct first, library should handle both formats
        let subtitleURL = subTitleUrl
        
        // Add subtitles using library
        // Library API: addSubtitles() sets up the label, then open() loads the file
        self.videoPlayer.addSubtitles()
        
        if subtitleURL.scheme == "http" || subtitleURL.scheme == "https" {
            // For remote URLs, download with custom headers and save to temp file, then use open()
            self.downloadSubtitleWithHeaders(url: subtitleURL) { [weak self] tempFileURL in
                guard let self = self, let fileURL = tempFileURL else {
                    print("❌ Failed to download subtitle or get temp file URL")
                    return
                }
                print("✅ Got temp file URL: \(fileURL.path)")
                DispatchQueue.main.async {
                    do {
                        print("📂 Opening subtitle file from local path: \(fileURL.path)")
                        
                        // Check if it's a VTT file - library only supports SRT, so we need to convert or parse VTT ourselves
                        let isVTT = fileURL.pathExtension.lowercased() == "vtt"
                        
                        if isVTT {
                            // For VTT files, read content and convert to SRT format or parse directly
                            print("📝 Detected VTT file - converting to SRT format for library")
                            let vttContent = try String(contentsOf: fileURL, encoding: .utf8)
                            let srtContent = self.convertVTTToSRT(vttContent: vttContent)
                            
                            // Use show() method directly with converted SRT content
                            self.videoPlayer.show(subtitles: srtContent)
                            print("✅ Successfully converted and displayed VTT subtitle")
                        } else {
                            // For SRT files, use library's open method
                            try self.videoPlayer.open(fileFromLocal: fileURL, encoding: .utf8)
                            print("✅ Successfully opened SRT subtitle file using open(fileFromLocal:)")
                        }
                        
                        self.applySubtitleStyling()
                        print("✅ Applied subtitle styling")
                        // Clean up temp file after a delay (give library time to read it)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            do {
                                try FileManager.default.removeItem(at: fileURL)
                                print("🧹 Cleaned up temp subtitle file")
                            } catch {
                                print("⚠️ Failed to clean up temp file: \(error)")
                            }
                        }
                    } catch {
                        print("❌ Failed to open downloaded subtitle file: \(error)")
                        print("   File exists: \(FileManager.default.fileExists(atPath: fileURL.path))")
                        // Clean up temp file on error
                        try? FileManager.default.removeItem(at: fileURL)
                    }
                }
            }
        } else {
            // For local files, check format and handle accordingly
            print("📂 Opening local subtitle file: \(subtitleURL.path)")
            let isVTT = subtitleURL.pathExtension.lowercased() == "vtt"
            
            do {
                if isVTT {
                    // For VTT files, read and convert to SRT
                    print("📝 Detected VTT file - converting to SRT format for library")
                    let vttContent = try String(contentsOf: subtitleURL, encoding: .utf8)
                    let srtContent = self.convertVTTToSRT(vttContent: vttContent)
                    self.videoPlayer.show(subtitles: srtContent)
                    print("✅ Successfully converted and displayed VTT subtitle")
                } else {
                    // For SRT files, use library's open method
                    try self.videoPlayer.open(fileFromLocal: subtitleURL, encoding: .utf8)
                    print("✅ Successfully opened SRT subtitle file")
                }
                self.applySubtitleStyling()
            } catch {
                print("❌ Failed to add subtitles: \(error)")
            }
        }
    }
    
    /// Apply subtitle styling from options
    private func applySubtitleStyling() {
        guard let options = self._stOptions else { return }
        
        if let fontSize = options["fontSize"] as? CGFloat {
            self.videoPlayer.subtitleLabel?.font = UIFont.systemFont(ofSize: fontSize)
        }
        if let fgColor = options["foregroundColor"] as? String,
           let color = self.parseRGBA(fgColor) {
            self.videoPlayer.subtitleLabel?.textColor = color
        }
        if let bgColor = options["backgroundColor"] as? String,
           let color = self.parseRGBA(bgColor) {
            self.videoPlayer.subtitleLabel?.backgroundColor = color.withAlphaComponent(0.7)
        }
    }
    
    /// Convert VTT (WebVTT) format to SRT format for the library
    /// The library only supports SRT format, so we need to convert VTT
    private func convertVTTToSRT(vttContent: String) -> String {
        var srtContent = ""
        var lines = vttContent.components(separatedBy: .newlines)
        var index = 1
        var i = 0
        
        // Skip WEBVTT header and any metadata
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines, WEBVTT header, and metadata
            if line.isEmpty || line.hasPrefix("WEBVTT") || line.hasPrefix("NOTE") || line.contains("-->") == false {
                i += 1
                continue
            }
            
            // Look for time line (format: 00:00:00.000 --> 00:00:05.000)
            if line.contains("-->") {
                // Convert VTT time format to SRT format
                // VTT: 00:00:00.000 --> 00:00:05.000
                // SRT: 00:00:00,000 --> 00:00:05,000 (comma instead of dot for milliseconds)
                var timeLine = line.replacingOccurrences(of: ".", with: ",", options: [], range: nil)
                
                // Add index
                srtContent += "\(index)\n"
                srtContent += "\(timeLine)\n"
                index += 1
                
                // Collect subtitle text until next time line or empty line
                i += 1
                var textLines: [String] = []
                while i < lines.count {
                    let nextLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if nextLine.isEmpty {
                        i += 1
                        break
                    }
                    if nextLine.contains("-->") {
                        // Next time line found, don't consume it
                        break
                    }
                    textLines.append(nextLine)
                    i += 1
                }
                
                // Add text (remove HTML tags if present)
                let text = textLines.joined(separator: " ").replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                srtContent += "\(text)\n\n"
            } else {
                i += 1
            }
        }
        
        return srtContent
    }
    
    /// Download subtitle file with custom headers and save to temporary file, then return file URL
    private func downloadSubtitleWithHeaders(url: URL, completion: @escaping (URL?) -> Void) {
        print("Downloading subtitle with custom headers: \(url.absoluteString)")
        
        // Get headers to use (subtitle headers or video headers as fallback)
        let headersToUse = self._stHeaders ?? self._videoHeaders
        
        // Create URLSession with delegate to handle redirects with auth headers
        let delegate = SubtitleURLSessionDelegate(headers: headersToUse ?? [:])
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 10.0
        sessionConfig.timeoutIntervalForResource = 30.0
        let session = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)
        
        var request = URLRequest(url: url)
        
        // Add headers if available
        if let headers = headersToUse {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            print("   Added \(headers.count) authentication headers")
        } else {
            print("   ⚠️ No headers available for subtitle download")
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("   ❌ Subtitle download error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    print("   ❌ Subtitle download failed with status: \(httpResponse.statusCode)")
                    completion(nil)
                    return
                }
            }
            
            guard let data = data else {
                print("   ❌ Failed to get subtitle data")
                completion(nil)
                return
            }
            
            // Determine file extension from URL or content
            let fileExtension = url.pathExtension.isEmpty ? "srt" : url.pathExtension
            
            // Create temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let tempFileURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
            
            do {
                try data.write(to: tempFileURL)
                print("   ✅ Subtitle downloaded and saved to temp file: \(tempFileURL.path)")
                completion(tempFileURL)
            } catch {
                print("   ❌ Failed to save subtitle to temp file: \(error)")
                completion(nil)
            }
        }
        
        task.resume()
    }
    
    
    private func isHLSStream(url: URL) -> Bool {
        let urlString = url.absoluteString.lowercased()
        return urlString.contains(".m3u8") || urlString.contains("m3u8")
    }
    
    /// Normalizes a URL string by converting HTTP to HTTPS for iOS App Transport Security compliance
    /// This ensures all network requests use secure connections as required by iOS
    /// - Parameter urlString: The original URL string (may be HTTP or HTTPS)
    /// - Returns: The normalized URL string with HTTPS scheme
    private func normalizeSubtitleURL(_ urlString: String) -> String {
        if urlString.hasPrefix("http://") {
            let normalized = urlString.replacingOccurrences(of: "http://", with: "https://")
            print("   🔒 Converting HTTP to HTTPS for ATS compliance: \(normalized)")
            return normalized
        }
        return urlString
    }
    
    /// Normalizes a URL by converting HTTP to HTTPS for iOS App Transport Security compliance
    /// - Parameter url: The original URL (may be HTTP or HTTPS)
    /// - Returns: The normalized URL with HTTPS scheme, or original if already HTTPS or not HTTP
    private func normalizeSubtitleURL(_ url: URL) -> URL {
        if url.scheme == "http" {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.scheme = "https"
            if let httpsURL = components?.url {
                print("   🔒 Converting HTTP to HTTPS for ATS compliance: \(httpsURL.absoluteString)")
                return httpsURL
            }
        }
        return url
    }
    
    
    /// Starts a timer that continuously tries to hide the CC button
    /// This is necessary because the button may be recreated by AVPlayerViewController
    private func startHidingCCButton() {
        // Stop any existing timer
        self.ccButtonHideTimer?.invalidate()
        self.ccButtonHideTimer = nil
        
        // Start a timer that runs every 0.5 seconds to hide the CC button
        self.ccButtonHideTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.hideNativeSubtitleMenuButton()
        }
        
        // Also try immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.hideNativeSubtitleMenuButton()
        }
    }
    
    /// Stops the CC button hiding timer (call when player is dismissed)
    private func stopHidingCCButton() {
        self.ccButtonHideTimer?.invalidate()
        self.ccButtonHideTimer = nil
    }
    
    /// Attempts to hide the native subtitle menu button by traversing the view hierarchy
    private func hideNativeSubtitleMenuButton() {
        // Ensure player view controller is presented and view is loaded
        guard self.videoPlayer.isViewLoaded, let playerView = self.videoPlayer.view else {
            // View not loaded yet - this is OK, will retry
            return
        }
        
        // First, try to dismiss any open subtitle menu/popover
        // The menu might be a UIPopoverPresentationController or similar
        if let presentedVC = self.videoPlayer.presentedViewController {
            // Check if it's the subtitle menu
            if presentedVC.title?.lowercased().contains("subtitle") == true ||
               presentedVC.title?.lowercased().contains("caption") == true {
                print("   🚫 Dismissing open subtitle menu...")
                presentedVC.dismiss(animated: false, completion: nil)
            }
        }
        
        // Also check for popover presentation controllers
        if let popover = self.videoPlayer.popoverPresentationController {
            print("   🚫 Dismissing popover...")
            popover.delegate = nil
        }
        
        // Recursively search for the subtitle button and menu
        func findAndHideSubtitleElements(in view: UIView, depth: Int = 0) -> Bool {
            // Limit recursion depth to avoid infinite loops
            guard depth <= 15 else {
                return false
            }
            
            var found = false
            
            // Check if this view is a button with subtitle-related text
            if let button = view as? UIButton {
                let title = button.title(for: .normal) ?? ""
                let accessibilityLabel = button.accessibilityLabel ?? ""
                
                // Check for subtitle-related labels
                if title.lowercased().contains("subtitle") ||
                   title.lowercased().contains("cc") ||
                   title.lowercased().contains("caption") ||
                   accessibilityLabel.lowercased().contains("subtitle") ||
                   accessibilityLabel.lowercased().contains("cc") ||
                   accessibilityLabel.lowercased().contains("caption") ||
                   title == "CC" {
                    // Only hide if button is actually visible
                    if !button.isHidden && button.alpha > 0 {
                        button.isHidden = true
                        button.isEnabled = false
                        button.alpha = 0.0
                        print("   🚫 Found and hid native subtitle button: '\(title)' / '\(accessibilityLabel)'")
                        found = true
                    }
                }
            }
            
            // Check if this is a menu/popover view (might be a UITableView or similar)
            if let tableView = view as? UITableView {
                // Check if it contains subtitle-related content
                if tableView.accessibilityLabel?.lowercased().contains("subtitle") == true ||
                   tableView.accessibilityLabel?.lowercased().contains("caption") == true {
                    // Try to hide the entire menu
                    view.isHidden = true
                    view.alpha = 0.0
                    print("   🚫 Found and hid subtitle menu table view")
                    found = true
                }
            }
            
            // Check if this view has a legible content characteristic (might be the subtitle container)
            if view.accessibilityTraits.contains(.button) {
                let label = view.accessibilityLabel ?? ""
                if label.lowercased().contains("subtitle") ||
                   label.lowercased().contains("cc") ||
                   label.lowercased().contains("caption") ||
                   label == "CC" {
                    // Only hide if view is actually visible
                    if !view.isHidden && view.alpha > 0 {
                        view.isHidden = true
                        view.alpha = 0.0
                        print("   🚫 Found and hid native subtitle accessibility element: '\(label)'")
                        found = true
                    }
                }
            }
            
            // Recursively search subviews (safely)
            for subview in view.subviews {
                if findAndHideSubtitleElements(in: subview, depth: depth + 1) {
                    found = true
                }
            }
            
            return found
        }
        
        // Search the player view hierarchy
        if findAndHideSubtitleElements(in: playerView) {
            // Found and hid elements - timer will keep checking
        }
        // If not found, timer will retry on next interval
    }
    
    /// Helper method to deselect native subtitle tracks and log details
    private func deselectNativeSubtitles(playerItem: AVPlayerItem, mediaSelectionGroup: AVMediaSelectionGroup) {
        print("   🔍 Analyzing native subtitle tracks...")
        print("   📋 Available native subtitle options: \(mediaSelectionGroup.options.count)")
        for (idx, option) in mediaSelectionGroup.options.enumerated() {
            print("      [\(idx)] displayName='\(option.displayName)'")
            print("          extendedLanguageTag='\(option.extendedLanguageTag ?? "nil")'")
            print("          locale='\(option.locale?.identifier ?? "nil")'")
            print("          mediaType='\(option.mediaType.rawValue)'")
            print("          hasMediaCharacteristic(.legible)=\(option.hasMediaCharacteristic(.legible))")
        }
        
        // Check current selection
        if let currentSelection = playerItem.currentMediaSelection.selectedMediaOption(in: mediaSelectionGroup) {
            print("   ⚠️ Current subtitle selection: \(currentSelection.displayName)")
            print("      This is why native subtitles are being displayed!")
        } else {
            print("   ✅ No subtitle currently selected")
        }
        
        // Deselect any selected subtitle option
        playerItem.select(nil, in: mediaSelectionGroup)
        print("   🚫 Deselected all native subtitle tracks (using custom UILabel)")
        
        // Verify deselection
        if let stillSelected = playerItem.currentMediaSelection.selectedMediaOption(in: mediaSelectionGroup) {
            print("   ❌ WARNING: Subtitle still selected after deselection: \(stillSelected.displayName)")
        } else {
            print("   ✅ Verified: No subtitle selected")
        }
    }
    
    private func setupHLSSubtitleDisplay() {
        // Actively deselect any native subtitle tracks and prevent them from being selected
        // This must be done after player item is ready and we need to keep them deselected
        if let playerItem = self.playerItem {
            // Set up observer to immediately deselect any subtitle tracks that get selected
            // This prevents native subtitles from appearing even if user clicks the menu
            let observer = playerItem.observe(\.currentMediaSelection, options: [.new]) { [weak self] item, _ in
                guard let self = self else { return }
                if let mediaSelectionGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible),
                   let selectedOption = item.currentMediaSelection.selectedMediaOption(in: mediaSelectionGroup) {
                    // Immediately deselect any subtitle that gets selected
                    item.select(nil, in: mediaSelectionGroup)
                    print("   🚫 Blocked native subtitle selection: \(selectedOption.displayName)")
                }
            }
            // Store observer to keep it alive
            self.mediaSelectionObserver = observer
            
            // CRITICAL: Also hide the CC button by continuously checking and hiding it
            // The button may appear after view loads or be recreated, so we need to keep hiding it
            self.startHidingCCButton()
            
            // Wait a bit for player item to fully load its tracks, then deselect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, let playerItem = self.playerItem else { return }
                
                // Deselect any legible (subtitle) tracks
                // Check both asset and playerItem for media selection groups
                var mediaSelectionGroup: AVMediaSelectionGroup?
                
                // First try playerItem asset
                mediaSelectionGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
                
                // If not found, wait for asset to load and try again
                if mediaSelectionGroup == nil {
                    print("   ⏳ Media selection group not ready yet, waiting for asset to load...")
                    playerItem.asset.loadValuesAsynchronously(forKeys: ["availableMediaCharacteristicsWithMediaSelectionOptions"]) {
                        DispatchQueue.main.async {
                            if let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
                                mediaSelectionGroup = group
                                self.deselectNativeSubtitles(playerItem: playerItem, mediaSelectionGroup: group)
                            } else {
                                print("   ℹ️ No legible media selection group found after loading")
                            }
                        }
                    }
                } else {
                    self.deselectNativeSubtitles(playerItem: playerItem, mediaSelectionGroup: mediaSelectionGroup!)
                    // Also try to hide the native subtitle menu button in the UI
                    // TEMPORARILY DISABLED - testing if this causes player not to show
                    // self.hideNativeSubtitleMenuButton()
                }
            }
        }
        
        // Use library for subtitle display instead of custom UILabel
        // Load the selected subtitle track using the library
        if let tracks = self._subtitleTracks,
           let selectedId = self._selectedSubtitleId ?? tracks.first?["id"] as? String,
           let selectedTrack = tracks.first(where: { ($0["id"] as? String) == selectedId }) ?? tracks.first,
           let trackUrlString = selectedTrack["url"] as? String {
            
            // Resolve URL
            var trackUrl: URL?
            if trackUrlString.hasPrefix("http://") || trackUrlString.hasPrefix("https://") {
                let normalizedUrlString = self.normalizeSubtitleURL(trackUrlString)
                trackUrl = URL(string: normalizedUrlString)
            } else if trackUrlString.hasPrefix("file://") {
                trackUrl = URL(string: trackUrlString)
            } else {
                trackUrl = URL(fileURLWithPath: trackUrlString)
            }
            
            if let subtitleUrl = trackUrl {
                print("   Loading subtitle track using library: \(selectedId)")
                self._activeSubtitleTrackId = selectedId
                // Wait a bit for player to be ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.addSubtitlesToPlayer(subTitleUrl: subtitleUrl)
                }
            }
        }
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
        print("🔨 Creating composition with asset tracks + subtitle tracks...")
        
        // Get video tracks from the provided asset
        let videoTracks = asset.tracks(withMediaType: .video)
        
        guard !videoTracks.isEmpty else {
            print("❌ No video tracks in provided asset")
            return
        }
        
        // Create composition with video/audio + subtitle tracks
        // Convert AVAsset to AVURLAsset if needed (for HLS, player item's asset might not be AVURLAsset)
        // If it's not an AVURLAsset, we need to use the original videoAsset
        let assetToUse: AVAsset
        if let urlAsset = asset as? AVURLAsset {
            assetToUse = urlAsset
        } else {
            // Fall back to original videoAsset if player item's asset isn't AVURLAsset
            print("⚠️ Player item's asset is not AVURLAsset, using original videoAsset")
            assetToUse = self.videoAsset
        }
        
        if let composition = self.createCompositionWithMultipleSubtitlesForHLS(
            videoAsset: assetToUse as! AVURLAsset,
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
    
    /// Retries creating composition with subtitles until asset tracks become available
    private func retryCreateCompositionWithSubtitles(subtitleTracks: [[String: Any]], retryCount: Int) {
        // For HLS, tracks typically never become available, so use fewer retries
        // This ensures fallback triggers quickly
        let maxRetries = 5 // Reduced from 15 - HLS tracks won't become available anyway
        
        guard retryCount < maxRetries else {
            print("❌ Max retries (\(maxRetries)) reached - asset tracks never became available")
            print("   For HLS streams, tracks might not be directly accessible")
            print("   Video will continue playing, but subtitles won't appear in native menu")
            print("   🔄 Falling back to custom UILabel subtitle display (like working branch)")
            print("   This will load and display all subtitle tracks using custom overlay")
            self.subtitleRetryInProgress = false // Reset flag
            // For HLS, we already use loadAllSubtitleTracksForHLS directly
            // This fallback should only be for non-HLS streams
            if self.isHLSStream(url: self.videoAsset.url) {
                // Subtitles will be loaded via setupMultipleSubtitlesWithAVPlayerViewControllerSubtitles
            } else {
                // For non-HLS, we can't easily add external subtitles after composition fails
                // Just continue without subtitles
                print("   ⚠️ Non-HLS composition failed - subtitles unavailable")
            }
            return
        }
        
        let delay = Double(retryCount + 1) * 0.5 // 0.5s, 1s, 1.5s, etc.
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            
            // Check both player item asset and original asset
            guard let playerItem = self.playerItem else {
                self.retryCreateCompositionWithSubtitles(subtitleTracks: subtitleTracks, retryCount: retryCount + 1)
                return
            }
            
            let playerItemAsset = playerItem.asset
            
            // Try loading tracks from both assets
            playerItemAsset.loadValuesAsynchronously(forKeys: ["tracks"]) {
                self.videoAsset.loadValuesAsynchronously(forKeys: ["tracks"]) {
                    DispatchQueue.main.async {
                        let playerItemVideoTracks = playerItemAsset.tracks(withMediaType: .video)
                        let originalVideoTracks = self.videoAsset.tracks(withMediaType: .video)
                        
                        print("   Retry \(retryCount + 1)/\(maxRetries):")
                        print("      Player item asset tracks: \(playerItemVideoTracks.count)")
                        print("      Original asset tracks: \(originalVideoTracks.count)")
                        
                        let tracksToUse = !playerItemVideoTracks.isEmpty ? playerItemVideoTracks : originalVideoTracks
                        let assetToUse = !playerItemVideoTracks.isEmpty ? playerItemAsset : self.videoAsset
                        
                        if !tracksToUse.isEmpty {
                            print("✅ Tracks now available! Creating composition with all subtitle tracks...")
                            self.subtitleRetryInProgress = false // Reset flag
                            self.createCompositionWithAsset(asset: assetToUse, subtitleTracks: subtitleTracks)
                        } else {
                            // Try again
                            self.retryCreateCompositionWithSubtitles(subtitleTracks: subtitleTracks, retryCount: retryCount + 1)
                        }
                    }
                }
            }
        }
    }
    
    /// Creates a composition using tracks from the player item (for HLS streams)
    /// This is needed because HLS tracks might only be available through player item, not asset
    /// NOTE: This method doesn't work - can't copy HLS tracks from player item
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
            print("🔄 Creating new player item with composition...")
            let newPlayerItem = AVPlayerItem(asset: composition)
            newPlayerItem.textStyleRules = self.getTextStyleRules()
            print("   ✅ Player item created, composition has \(composition.tracks.count) tracks")
            print("   📊 Composition tracks breakdown:")
            let videoTracks = composition.tracks(withMediaType: .video)
            let audioTracks = composition.tracks(withMediaType: .audio)
            let subtitleTracks = composition.tracks(withMediaType: .subtitle)
            print("      Video: \(videoTracks.count), Audio: \(audioTracks.count), Subtitle: \(subtitleTracks.count)")
            
            // Replace current player item
            if let currentPlayer = self.player {
                print("🔄 Replacing current player item...")
                currentPlayer.replaceCurrentItem(with: newPlayerItem)
                self.playerItem = newPlayerItem
                
                // Add observer for media selection changes (when user clicks in native menu)
                self.addMediaSelectionObserver()
                
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
    
    /// Uses AVPlayerViewControllerSubtitles library for multiple subtitle tracks
    private func setupMultipleSubtitlesWithAVPlayerViewControllerSubtitles(subtitleTracks: [[String: Any]]) {
        print("📝 Setting up multiple subtitles using AVPlayerViewControllerSubtitles...")
        
        // Store tracks for switching
        self._subtitleTracks = subtitleTracks
        
        // Load initial track (selected or first)
        if let selectedId = self._selectedSubtitleId ?? subtitleTracks.first?["id"] as? String,
           let selectedTrack = subtitleTracks.first(where: { ($0["id"] as? String) == selectedId }) ?? subtitleTracks.first,
           let trackUrlString = selectedTrack["url"] as? String {
            
            // Resolve URL
            var trackUrl: URL?
            if trackUrlString.hasPrefix("http://") || trackUrlString.hasPrefix("https://") {
                let normalizedUrlString = self.normalizeSubtitleURL(trackUrlString)
                trackUrl = URL(string: normalizedUrlString)
            } else if trackUrlString.hasPrefix("file://") {
                trackUrl = URL(string: trackUrlString)
            } else {
                trackUrl = URL(fileURLWithPath: trackUrlString)
            }
            
            if let subtitleUrl = trackUrl {
                print("   Loading subtitle track: \(selectedId)")
                self.addSubtitlesToPlayer(subTitleUrl: subtitleUrl)
                self._activeSubtitleTrackId = selectedId
            }
        }
        
        // Set up track switching capability
        self.setInitialSubtitleSelection()
    }
    
    /// Switch to a different subtitle track
    private func switchSubtitleTrack(trackId: String) {
        guard let tracks = self._subtitleTracks,
              let track = tracks.first(where: { ($0["id"] as? String) == trackId }),
              let trackUrlString = track["url"] as? String else {
            print("⚠️ Track not found: \(trackId)")
            return
        }
        
        // Resolve URL
        var trackUrl: URL?
        if trackUrlString.hasPrefix("http://") || trackUrlString.hasPrefix("https://") {
            let normalizedUrlString = self.normalizeSubtitleURL(trackUrlString)
            trackUrl = URL(string: normalizedUrlString)
        } else if trackUrlString.hasPrefix("file://") {
            trackUrl = URL(string: trackUrlString)
        } else {
            trackUrl = URL(fileURLWithPath: trackUrlString)
        }
        
        if let subtitleUrl = trackUrl {
            // Remove existing subtitles and add new one
            // Library API: addSubtitles() sets up the label, then show() displays the content
            self.videoPlayer.addSubtitles()
            
            if subtitleUrl.scheme == "http" || subtitleUrl.scheme == "https" {
                // For remote URLs, download with custom headers and save to temp file, then use open()
                self.downloadSubtitleWithHeaders(url: subtitleUrl) { [weak self] tempFileURL in
                    guard let self = self, let fileURL = tempFileURL else { return }
                    DispatchQueue.main.async {
                        do {
                            // Check if it's a VTT file
                            let isVTT = fileURL.pathExtension.lowercased() == "vtt"
                            
                            if isVTT {
                                // For VTT files, read and convert to SRT
                                print("📝 Detected VTT file - converting to SRT format for library")
                                let vttContent = try String(contentsOf: fileURL, encoding: .utf8)
                                let srtContent = self.convertVTTToSRT(vttContent: vttContent)
                                self.videoPlayer.show(subtitles: srtContent)
                                print("✅ Successfully converted and displayed VTT subtitle")
                            } else {
                                // For SRT files, use library's open method
                                try self.videoPlayer.open(fileFromLocal: fileURL, encoding: .utf8)
                                print("✅ Successfully opened SRT subtitle file")
                            }
                            
                            self.applySubtitleStyling()
                            // Clean up temp file after a delay (give library time to read it)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                try? FileManager.default.removeItem(at: fileURL)
                            }
                        } catch {
                            print("Failed to open downloaded subtitle file: \(error)")
                            // Clean up temp file on error
                            try? FileManager.default.removeItem(at: fileURL)
                        }
                    }
                }
            } else {
                // For local files, check format and handle accordingly
                let isVTT = subtitleUrl.pathExtension.lowercased() == "vtt"
                
                do {
                    if isVTT {
                        // For VTT files, read and convert to SRT
                        print("📝 Detected VTT file - converting to SRT format for library")
                        let vttContent = try String(contentsOf: subtitleUrl, encoding: .utf8)
                        let srtContent = self.convertVTTToSRT(vttContent: vttContent)
                        self.videoPlayer.show(subtitles: srtContent)
                        print("✅ Successfully converted and displayed VTT subtitle")
                    } else {
                        // For SRT files, use library's open method
                        try self.videoPlayer.open(fileFromLocal: subtitleUrl, encoding: .utf8)
                        print("✅ Successfully opened SRT subtitle file")
                    }
                    self.applySubtitleStyling()
                } catch {
                    print("Failed to switch subtitle track: \(error)")
                }
            }
            self._activeSubtitleTrackId = trackId
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
        
        // For HLS, we might not be able to get video tracks from the asset
        // Instead, we'll create a composition that references the original asset
        // and add subtitle tracks to it. The video will continue playing from the original asset.
        // However, we still need at least one video track in the composition for it to be valid.
        
        // Try to add video track if available
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
                // For HLS, if we can't copy tracks, we might need to use a different approach
                // But let's continue and see if we can at least add subtitle tracks
                print("   Will try to add subtitle tracks anyway - composition may not play video")
            }
        } else {
            print("⚠️ No video tracks available - this is common for HLS")
            print("   For HLS with external subtitles, we cannot create a valid composition")
            print("   without video tracks. The native menu approach won't work for this case.")
            print("   Returning nil - will need to use fallback method")
            return nil
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
        print("   🔍 Subtitle tracks details:")
        for (idx, track) in subtitleTracks.enumerated() {
            let trackId = track["id"] as? String ?? "nil"
            let language = track["language"] as? String ?? "nil"
            let url = track["url"] as? String ?? "nil"
            print("      [\(idx)] id=\(trackId), lang=\(language), url=\(url)")
        }
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
                // Normalize URL (HTTP -> HTTPS for ATS compliance)
                let normalizedUrlString = self.normalizeSubtitleURL(trackUrlString)
                trackUrl = URL(string: normalizedUrlString)
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
                // For remote URLs, we need to download first, add LANGUAGE header, then cache locally
                print("   🔍 Ensuring VTT has language metadata for track: \(trackId)")
                if subtitleUrl.isFileURL {
                    // Local file - can directly modify
                    if let vttUrl = self.ensureVTTLanguageMetadata(vttURL: subtitleUrl, language: language) {
                        finalUrl = vttUrl
                        print("   ✅ VTT language metadata ensured (local): \(vttUrl.absoluteString)")
                    } else {
                        finalUrl = subtitleUrl
                        print("   ⚠️ Could not add language metadata to local VTT, using original")
                    }
                } else {
                    // Remote URL - need to download, add LANGUAGE header, cache locally
                    print("   🌐 Remote VTT URL detected - will download and add LANGUAGE header")
                    if let cachedVttUrl = self.downloadAndEnsureVTTLanguageMetadata(remoteURL: subtitleUrl, language: language, trackId: trackId) {
                        finalUrl = cachedVttUrl
                        print("   ✅ VTT downloaded, LANGUAGE header added, cached: \(cachedVttUrl.absoluteString)")
                    } else {
                        finalUrl = subtitleUrl
                        print("   ⚠️ Could not download/add language metadata, using original remote URL")
                        print("   ⚠️ This will cause 'CC' to show in native menu instead of language name")
                    }
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
                    // Check VTT file content for LANGUAGE header
                    if let content = try? String(contentsOf: subtitleInfo.asset.url, encoding: .utf8) {
                        if content.contains("LANGUAGE:") {
                            let langLine = content.components(separatedBy: .newlines).first(where: { $0.contains("LANGUAGE:") })
                            print("   📋 VTT file has LANGUAGE header: \(langLine ?? "not found")")
                            print("   Expected language from array: \(subtitleInfo.language)")
                        } else {
                            print("   ⚠️ VTT file missing LANGUAGE header!")
                            print("   Expected: LANGUAGE: \(subtitleInfo.language)")
                            print("   This will cause 'CC' to show in native menu instead of language name")
                        }
                    }
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
                        print("            hasMediaCharacteristic(.legible): \(track.hasMediaCharacteristic(.legible))")
                        print("            Expected language from array: \(subtitleInfo.language)")
                        if track.languageCode == nil && track.extendedLanguageTag == nil {
                            print("            ⚠️ NO LANGUAGE METADATA - This will cause 'CC' to show in native menu!")
                            print("            💡 VTT file needs 'LANGUAGE: \(subtitleInfo.language)' header")
                        }
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
            
            // Use AVMediaType.subtitle for proper native menu support (instead of .text)
            print("   🔧 Creating composition subtitle track for: \(subtitleInfo.trackId) (\(subtitleInfo.language))")
            guard let compositionSubtitleTrack = composition.addMutableTrack(
                withMediaType: .subtitle,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                print("❌ Failed to create subtitle track in composition for: \(subtitleInfo.trackId)")
                continue
            }
            print("   ✅ Created composition subtitle track successfully")
            
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
                    print("   Language from array: \(subtitleInfo.language)")
                    print("   This may cause issues with track identification in media selection")
                    print("   ⚠️ VTT file may not have LANGUAGE header, or AVFoundation didn't extract it")
                    print("   💡 Ensure VTT file has 'LANGUAGE: \(subtitleInfo.language)' header")
                } else {
                    print("   ✅ Source track language: \(sourceTrack.extendedLanguageTag ?? "nil")")
                    print("   Language from array: \(subtitleInfo.language)")
                    // Verify language matches
                    if let trackLang = sourceTrack.extendedLanguageTag, 
                       !trackLang.contains(subtitleInfo.language) && 
                       !subtitleInfo.language.contains(trackLang) {
                        print("   ⚠️ Language mismatch: track has '\(trackLang)' but array has '\(subtitleInfo.language)'")
                    }
                }
                
                // Log track metadata for debugging
                print("   📋 Track metadata:")
                print("      languageCode: \(sourceTrack.languageCode ?? "nil")")
                print("      extendedLanguageTag: \(sourceTrack.extendedLanguageTag ?? "nil")")
                print("      hasMediaCharacteristic(.legible): \(sourceTrack.hasMediaCharacteristic(.legible))")
                
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
        var subtitleAssets: [(asset: AVURLAsset, trackId: String, language: String)] = []
        
        // Resolve URLs and create assets (same logic as before)
        for (_, trackDict) in subtitleTracks.enumerated() {
            guard let trackUrlString = trackDict["url"] as? String,
                  let trackId = trackDict["id"] as? String,
                  let language = trackDict["language"] as? String else {
                continue
            }
            
            // Resolve URL (same logic as createCompositionWithMultipleSubtitlesForHLS)
            var trackUrl: URL?
            if trackUrlString.hasPrefix("http://") || trackUrlString.hasPrefix("https://") {
                // Normalize URL (HTTP -> HTTPS for ATS compliance)
                let normalizedUrlString = self.normalizeSubtitleURL(trackUrlString)
                trackUrl = URL(string: normalizedUrlString)
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
            // Use AVMediaType.subtitle for proper native menu support
            print("   🔧 Creating composition subtitle track for: \(subtitleInfo.trackId) (\(subtitleInfo.language))")
            guard let compositionSubtitleTrack = composition.addMutableTrack(
                withMediaType: .subtitle,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                print("❌ Failed to create subtitle track in composition for: \(subtitleInfo.trackId)")
                continue
            }
            print("   ✅ Created composition subtitle track successfully")
            
            do {
                // Use video track duration from composition
                let videoTracks = composition.tracks(withMediaType: .video)
                let duration = videoTracks.isEmpty ? CMTimeMake(value: 3600, timescale: 1) : videoTracks[0].timeRange.duration
                print("   ⏱️ Using duration: \(CMTimeGetSeconds(duration))s for subtitle track")
                
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
                    // Convert HTTP to HTTPS for iOS App Transport Security compliance
                    var urlString = trackUrlString
                    if urlString.hasPrefix("http://") {
                        urlString = urlString.replacingOccurrences(of: "http://", with: "https://")
                        print("   🔒 Converting HTTP to HTTPS for ATS compliance: \(urlString)")
                    }
                    trackUrl = URL(string: urlString)
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
                
                // Use AVMediaType.subtitle for proper native menu support
                print("   🔧 Creating composition subtitle track for: \(subtitleInfo.trackId) (\(subtitleInfo.language))")
                guard let compositionSubtitleTrack = composition.addMutableTrack(
                    withMediaType: .subtitle,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    print("❌ Failed to create subtitle track in composition for: \(subtitleInfo.trackId)")
                    continue
                }
                print("   ✅ Created composition subtitle track successfully")
                
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
        print("🎬 setInitialSubtitleSelection called")
        guard let playerItem = self.playerItem else {
            print("   ⚠️ playerItem is nil, cannot set initial subtitle selection")
            return
        }
        
        print("   📊 Player item status: \(playerItem.status.rawValue)")
        print("   📊 Selected subtitle ID: \(_selectedSubtitleId ?? "nil")")
        print("   📊 Subtitle tracks count: \(_subtitleTracks?.count ?? 0)")
        
        // Wait for player item to be ready before selecting track
        if playerItem.status == .readyToPlay {
            print("   ✅ Player item is ready, selecting initial track immediately")
            self.selectInitialTrack()
        } else {
            print("   ⏳ Player item not ready yet, observing status...")
            // Observe status and select when ready
            self.itemStatusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
                print("   📊 Player item status changed to: \(item.status.rawValue)")
                if item.status == .readyToPlay {
                    print("   ✅ Player item is now ready, selecting initial track")
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
                print("   🎯 Found matching option: lang=\(option.extendedLanguageTag ?? "nil"), locale=\(option.locale?.identifier ?? "nil"), displayName=\(option.displayName)")
                playerItem.select(option, in: mediaSelectionGroup)
                print("✅ Selected initial subtitle track: \(selectedId) (lang: \(option.extendedLanguageTag ?? "nil"), displayName: \(option.displayName))")
                
                // Verify selection was applied
                let selectedOption = playerItem.currentMediaSelection.selectedMediaOption(in: mediaSelectionGroup)
                print("   ✅ Verified selection: \(selectedOption?.displayName ?? "nil")")
            } else {
                print("❌ Could not find matching subtitle option for track ID: \(selectedId)")
                print("   Available options:")
                for (idx, opt) in mediaSelectionGroup.options.enumerated() {
                    print("      [\(idx)] lang=\(opt.extendedLanguageTag ?? "nil"), locale=\(opt.locale?.identifier ?? "nil"), displayName=\(opt.displayName)")
                }
                // Try selecting first available option as fallback
                if let firstOption = mediaSelectionGroup.options.first {
                    playerItem.select(firstOption, in: mediaSelectionGroup)
                    print("🔄 Fallback: Selected first available subtitle option: \(firstOption.displayName)")
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
    
    /// Adds observer for media selection changes (when user clicks subtitle option in native menu)
    private func addMediaSelectionObserver() {
        print("🎧 Adding media selection change observer...")
        
        guard let playerItem = self.playerItem else {
            print("   ⚠️ playerItem is nil, cannot add media selection observer")
            return
        }
        
        // Use KVO to observe currentMediaSelection changes
        // This will fire when user changes subtitle selection in native menu
        self.mediaSelectionObserver = playerItem.observe(\.currentMediaSelection, options: [.new, .old]) { [weak self] item, change in
            guard let self = self else { return }
            print("🎧 Media selection changed (user clicked in native menu)")
            
            guard let mediaSelectionGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
                print("   ⚠️ Could not get media selection group")
                return
            }
            
            let selectedOption = item.currentMediaSelection.selectedMediaOption(in: mediaSelectionGroup)
            if let option = selectedOption {
                print("   ✅ User selected subtitle: lang=\(option.extendedLanguageTag ?? "nil"), locale=\(option.locale?.identifier ?? "nil"), displayName=\(option.displayName)")
                
                // Update active subtitle track ID based on selection
                if let localeId = option.locale?.identifier {
                    self._activeSubtitleTrackId = localeId
                } else if let langTag = option.extendedLanguageTag {
                    self._activeSubtitleTrackId = langTag
                } else {
                    self._activeSubtitleTrackId = option.displayName
                }
                print("   📝 Updated _activeSubtitleTrackId to: \(self._activeSubtitleTrackId ?? "nil")")
            } else {
                print("   ℹ️ User deselected subtitles (selected nil)")
                self._activeSubtitleTrackId = nil
            }
        }
        
        print("   ✅ Media selection observer added")
    }
    
    /// Fallback: Custom UILabel subtitle display for HLS when composition creation fails
    /// This loads all subtitle tracks, parses them, and displays using UILabel overlay
    /// Similar to working branch approach and AVPlayerViewController-Subtitles library
    private func setupCustomSubtitleDisplayForHLS(subtitleTracks: [[String: Any]]) {
        print("🎬 Setting up subtitles for HLS using AVPlayerViewController-Subtitles library...")
        print("   📊 Subtitle tracks: \(subtitleTracks.count)")
        
        // Store tracks for switching
        self._subtitleTracks = subtitleTracks
        
        // Load the selected track using the library
        if let selectedId = self._selectedSubtitleId ?? subtitleTracks.first?["id"] as? String,
           let selectedTrack = subtitleTracks.first(where: { ($0["id"] as? String) == selectedId }) ?? subtitleTracks.first,
           let trackUrlString = selectedTrack["url"] as? String {
            
            // Resolve URL
            var trackUrl: URL?
            if trackUrlString.hasPrefix("http://") || trackUrlString.hasPrefix("https://") {
                let normalizedUrlString = self.normalizeSubtitleURL(trackUrlString)
                trackUrl = URL(string: normalizedUrlString)
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
            
            if let subtitleUrl = trackUrl {
                print("   Loading subtitle track using library: \(selectedId)")
                self._activeSubtitleTrackId = selectedId
                // Wait for player to be ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.addSubtitlesToPlayer(subTitleUrl: subtitleUrl)
                }
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
    
    /// Downloads a remote VTT file, adds LANGUAGE header, and caches it locally
    /// Format: WEBVTT\nLANGUAGE: <iso-639-1-code>\n\n<content>
    /// CRITICAL: Must have blank line after LANGUAGE header for proper WebVTT format
    private func downloadAndEnsureVTTLanguageMetadata(remoteURL: URL, language: String, trackId: String) -> URL? {
        // Normalize URL (HTTP -> HTTPS for ATS compliance)
        let finalURL = self.normalizeSubtitleURL(remoteURL)
        
        print("   📥 Downloading remote VTT file: \(finalURL.absoluteString)")
        
        // Use semaphore to make this synchronous (we're already in async context)
        let semaphore = DispatchSemaphore(value: 0)
        var downloadedData: Data?
        var downloadError: Error?
        
        // Use video headers for authentication (same as video)
        let headersToUse = self._videoHeaders ?? self._stHeaders
        
        // Create custom URLSession with delegate to handle redirects with auth headers
        let sessionDelegate = SubtitleURLSessionDelegate(headers: headersToUse ?? [:])
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 10.0
        sessionConfig.timeoutIntervalForResource = 10.0
        let session = URLSession(configuration: sessionConfig, delegate: sessionDelegate, delegateQueue: nil)
        
        var request = URLRequest(url: finalURL)
        if let headers = headersToUse {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            print("   🔐 Added \(headers.count) authentication headers")
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                downloadError = error
                print("   ❌ Download error: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    if let data = data {
                        downloadedData = data
                        print("   ✅ Downloaded \(data.count) bytes (HTTP \(httpResponse.statusCode))")
                    } else {
                        downloadError = NSError(domain: "SubtitleDownload", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    }
                } else {
                    downloadError = NSError(domain: "SubtitleDownload", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                    print("   ❌ HTTP error: \(httpResponse.statusCode)")
                }
            } else if let data = data {
                downloadedData = data
                print("   ✅ Downloaded \(data.count) bytes")
            } else {
                downloadError = NSError(domain: "SubtitleDownload", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
            }
            semaphore.signal()
        }
        
        task.resume()
        
        // Wait for download (max 10 seconds)
        let timeout = semaphore.wait(timeout: .now() + 10.0)
        if timeout == .timedOut {
            print("   ❌ Download timeout after 10 seconds")
            return nil
        }
        
        guard let data = downloadedData else {
            print("   ❌ Download failed: \(downloadError?.localizedDescription ?? "unknown error")")
            return nil
        }
        
        // Decode content
        guard let vttContent = String(data: data, encoding: .utf8) else {
            print("   ❌ Failed to decode VTT content as UTF-8")
            return nil
        }
        
        print("   📄 VTT content length: \(vttContent.count) characters")
        print("   📋 First 200 chars: \(String(vttContent.prefix(200)))")
        
        // Check if already has LANGUAGE header
        if vttContent.contains("LANGUAGE:") {
            print("   ℹ️ VTT already has LANGUAGE header, using as-is")
            // Still cache it locally for consistency
        } else {
            print("   ➕ Adding LANGUAGE header: LANGUAGE: \(language)")
        }
        
        // Add LANGUAGE header if missing
        // WebVTT format requires: WEBVTT\nLANGUAGE: <code>\n\n<cues>
        let lines = vttContent.components(separatedBy: .newlines)
        var newLines: [String] = []
        var foundWebVTT = false
        var hasLanguage = false
        var webvttIndex: Int?
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed == "WEBVTT" && !foundWebVTT {
                foundWebVTT = true
                webvttIndex = index
                newLines.append(line)
            } else if trimmed.hasPrefix("LANGUAGE:") {
                hasLanguage = true
                newLines.append(line)
            } else {
                newLines.append(line)
            }
        }
        
        // If WEBVTT not found, prepend it with LANGUAGE and blank line
        if !foundWebVTT {
            newLines.insert("WEBVTT", at: 0)
            newLines.insert("LANGUAGE: \(language)", at: 1)
            newLines.insert("", at: 2) // Blank line required by WebVTT spec
        } else if !hasLanguage {
            // WEBVTT found but no LANGUAGE - insert after WEBVTT with blank line
            if let index = webvttIndex {
                newLines.insert("LANGUAGE: \(language)", at: index + 1)
                // Check if next line is already blank, if not insert one
                if index + 2 < newLines.count && !newLines[index + 2].trimmingCharacters(in: .whitespaces).isEmpty {
                    newLines.insert("", at: index + 2)
                }
            }
        }
        
        // Write to cache
        guard let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            print("   ❌ Failed to get caches directory")
            return nil
        }
        
        let newVttFileName = "\(trackId)_\(language).vtt"
        let newVttURL = cachesURL.appendingPathComponent(newVttFileName)
        
        let newContent = newLines.joined(separator: "\n")
        do {
            try newContent.write(to: newVttURL, atomically: true, encoding: .utf8)
            print("   ✅ Cached VTT with LANGUAGE header: \(newVttURL.path)")
            print("   📋 First 150 chars of cached file: \(String(newContent.prefix(150)))")
            print("   🔍 Verifying LANGUAGE header format...")
            
            // Verify the format is correct
            let firstLines = newContent.components(separatedBy: .newlines).prefix(5)
            for (idx, line) in firstLines.enumerated() {
                print("      Line \(idx): '\(line)'")
            }
            
            return newVttURL
        } catch {
            print("   ❌ Failed to write cached VTT: \(error)")
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
        
        // Stop CC button hiding timer
        self.stopHidingCCButton()
        
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
        
        // Library handles subtitle cleanup automatically
        // No need to manually clean up subtitle labels or observers
        
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
