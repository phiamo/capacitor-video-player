//
//  HLSSubtitleResourceLoaderDelegate.swift
//  Plugin
//
//  Created for HLS subtitle playlist injection
//

import Foundation
import AVFoundation
import os

/// Resource loader delegate that injects subtitle tracks into HLS playlists
class HLSSubtitleResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    
    // Logger for this class
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "org.dwbn.awareness",
        category: String(describing: HLSSubtitleResourceLoaderDelegate.self)
    )
    
    // Custom URL scheme to trigger resource loader interception
    static let customSchemePrefix = "customscheme"
    
    // Subtitle playlist URL prefix
    private let subtitlePlaylistUrlPrefix = "\(HLSSubtitleResourceLoaderDelegate.customSchemePrefix)SubtitlePlaylist"
    
    private let session: URLSession
    private let subtitleTracks: [[String: Any]]
    private let bearerToken: String?
    private let originalVideoUrl: URL
    
    // Cache for subtitle playlists
    private var subtitlePlaylists: [String: String] = [:]
    
    init(subtitleTracks: [[String: Any]], bearerToken: String?, originalVideoUrl: URL) {
        self.subtitleTracks = subtitleTracks
        self.bearerToken = bearerToken
        self.originalVideoUrl = originalVideoUrl
        self.session = URLSession(configuration: .default)
        super.init()
    }
    
    // MARK: - AVAssetResourceLoaderDelegate
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, 
                       shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        
        let requestString = loadingRequest.request.url?.absoluteString ?? ""
        let dataRequest = loadingRequest.dataRequest
        
        Self.logger.trace("Resource loader intercepted request: \(requestString, privacy: .public)")
        
        // Handle subtitle playlist requests
        if requestString.hasPrefix(subtitlePlaylistUrlPrefix) {
            return handleSubtitlePlaylistRequest(loadingRequest: loadingRequest)
        }
        
        // Handle master playlist requests - inject subtitle tracks
        // Master playlist requests typically:
        // 1. Have requestedOffset == 0 (start of file)
        // 2. Have requestedLength > 0 but relatively small (master playlists are text)
        // 3. Contain .m3u8 in URL or are the initial request
        if let dataRequest = dataRequest,
           dataRequest.requestedOffset == 0,
           dataRequest.requestedLength > 0 {
            
            // Check if this is a master playlist request
            let isMasterPlaylist = requestString.contains(".m3u8") || 
                                   requestString.contains("manifest") ||
                                   (dataRequest.requestedLength < 50000) // Master playlists are typically small (< 50KB)
            
            if isMasterPlaylist {
                Self.logger.debug("Detected master playlist request")
                return handleMasterPlaylistRequest(loadingRequest: loadingRequest)
            }
        }
        
        // For other requests (video/audio fragments), redirect to original URL
        return handleRedirectRequest(loadingRequest: loadingRequest, originalUrl: originalVideoUrl)
    }
    
    // MARK: - Master Playlist Handling
    
    private func handleMasterPlaylistRequest(loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        Self.logger.debug("Handling master playlist request")
        
        // Remove custom scheme to get original URL
        guard let requestUrlString = loadingRequest.request.url?.absoluteString else {
            Self.logger.error("Failed to get request URL")
            loadingRequest.finishLoading(with: NSError(domain: "HLSSubtitleLoader", code: -1, userInfo: nil))
            return true
        }
        
        // Restore original scheme (https or http)
        let originalUrlString: String
        if requestUrlString.hasPrefix("\(HLSSubtitleResourceLoaderDelegate.customSchemePrefix)://") {
            if originalVideoUrl.scheme == "https" {
                originalUrlString = requestUrlString.replacingOccurrences(
                    of: "\(HLSSubtitleResourceLoaderDelegate.customSchemePrefix)://",
                    with: "https://"
                )
            } else {
                originalUrlString = requestUrlString.replacingOccurrences(
                    of: "\(HLSSubtitleResourceLoaderDelegate.customSchemePrefix)://",
                    with: "http://"
                )
            }
        } else {
            originalUrlString = requestUrlString
        }
        
        guard let originalUrl = URL(string: originalUrlString) else {
            Self.logger.error("Failed to create original URL from: \(originalUrlString, privacy: .public)")
            loadingRequest.finishLoading(with: NSError(domain: "HLSSubtitleLoader", code: -1, userInfo: nil))
            return true
        }
        
        // Create request with headers if needed
        var request = URLRequest(url: originalUrl)
        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Fetch the master playlist
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                Self.logger.error("Error fetching master playlist: \(error.localizedDescription, privacy: .public)")
                loadingRequest.finishLoading(with: error)
                return
            }
            
            guard let data = data,
                  let playlistString = String(data: data, encoding: .utf8) else {
                Self.logger.error("Failed to decode master playlist")
                loadingRequest.finishLoading(with: NSError(domain: "HLSSubtitleLoader", code: -1, userInfo: nil))
                return
            }
            
            Self.logger.notice("Master playlist fetched, injecting subtitle tracks")
            
            // Inject subtitle tracks into the playlist
            let modifiedPlaylist = self.injectSubtitlesIntoPlaylist(playlistString: playlistString)
            
            // Send modified playlist back
            if let modifiedData = modifiedPlaylist.data(using: .utf8) {
                loadingRequest.dataRequest?.respond(with: modifiedData)
                loadingRequest.finishLoading()
                Self.logger.notice("Master playlist modified and sent")
            } else {
                loadingRequest.finishLoading(with: NSError(domain: "HLSSubtitleLoader", code: -1, userInfo: nil))
            }
        }
        
        task.resume()
        return true
    }
    
    // MARK: - Subtitle Playlist Handling
    
    private func handleSubtitlePlaylistRequest(loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        Self.logger.debug("Handling subtitle playlist request")
        
        guard let requestUrl = loadingRequest.request.url else {
            Self.logger.error("Invalid subtitle playlist request URL")
            loadingRequest.finishLoading(with: NSError(domain: "HLSSubtitleLoader", code: -1, userInfo: nil))
            return true
        }
        
        let requestString = requestUrl.absoluteString
        
        // Extract language/track ID from URL
        // Format: customschemeSubtitlePlaylist://<language>.m3u8
        let urlComponents = requestString.replacingOccurrences(of: subtitlePlaylistUrlPrefix + "://", with: "")
        let trackIdentifier = urlComponents.components(separatedBy: ".").first ?? ""
        
        Self.logger.trace("Track identifier: \(trackIdentifier, privacy: .public)")
        
        // Find matching subtitle track
        guard let track = subtitleTracks.first(where: { track in
            let trackId = track["id"] as? String ?? ""
            let language = track["language"] as? String ?? ""
            return trackId == trackIdentifier || language == trackIdentifier
        }) else {
            Self.logger.error("No matching subtitle track found for: \(trackIdentifier, privacy: .public)")
            loadingRequest.finishLoading(with: NSError(domain: "HLSSubtitleLoader", code: -1, userInfo: nil))
            return true
        }
        
        guard let subtitleUrlString = track["url"] as? String,
              var subtitleUrl = URL(string: subtitleUrlString) else {
            Self.logger.error("Invalid subtitle URL in track")
            loadingRequest.finishLoading(with: NSError(domain: "HLSSubtitleLoader", code: -1, userInfo: nil))
            return true
        }
        
        // Append bearer token as query parameter
        if let token = bearerToken {
            if var urlComponents = URLComponents(url: subtitleUrl, resolvingAgainstBaseURL: false) {
                var queryItems = urlComponents.queryItems ?? []
                // Check if bearer parameter already exists
                if !queryItems.contains(where: { $0.name == "bearer" }) {
                    queryItems.append(URLQueryItem(name: "bearer", value: token))
                    urlComponents.queryItems = queryItems
                    if let newUrl = urlComponents.url {
                        subtitleUrl = newUrl
                        Self.logger.trace("Appended bearer token to subtitle URL")
                    }
                } else {
                    Self.logger.trace("Bearer token already present in URL")
                }
            } else {
                // Fallback: append as query string manually
                let separator = subtitleUrl.absoluteString.contains("?") ? "&" : "?"
                if let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   let newUrl = URL(string: "\(subtitleUrl.absoluteString)\(separator)bearer=\(encodedToken)") {
                    subtitleUrl = newUrl
                    Self.logger.trace("Appended bearer token to subtitle URL (fallback method)")
                }
            }
        }
        
        Self.logger.debug("Fetching subtitle from: \(subtitleUrl.absoluteString, privacy: .public)")
        
        // Fetch subtitle file
        var request = URLRequest(url: subtitleUrl)
        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                Self.logger.error("Error fetching subtitle: \(error.localizedDescription, privacy: .public)")
                loadingRequest.finishLoading(with: error)
                return
            }
            
            guard let data = data,
                  let subtitleContent = String(data: data, encoding: .utf8) else {
                Self.logger.error("Failed to decode subtitle content")
                loadingRequest.finishLoading(with: NSError(domain: "HLSSubtitleLoader", code: -1, userInfo: nil))
                return
            }
            
            Self.logger.notice("Subtitle content fetched (\(data.count, privacy: .public) bytes)")
            
            // Create HLS subtitle playlist from VTT/SRT content
            let playlist = self.createSubtitlePlaylistFromVTT(vttContent: subtitleContent, subtitleUrl: subtitleUrl)
            
            // Send playlist back
            if let playlistData = playlist.data(using: .utf8) {
                loadingRequest.dataRequest?.respond(with: playlistData)
                loadingRequest.finishLoading()
                Self.logger.notice("Subtitle playlist created and sent")
            } else {
                loadingRequest.finishLoading(with: NSError(domain: "HLSSubtitleLoader", code: -1, userInfo: nil))
            }
        }
        
        task.resume()
        return true
    }
    
    // MARK: - Playlist Modification
    
    private func injectSubtitlesIntoPlaylist(playlistString: String) -> String {
        let lines = playlistString.components(separatedBy: .newlines)
        var modifiedLines: [String] = []
        
        // Process each line
        for line in lines {
            modifiedLines.append(line)
            
            // If this is a stream info line, add subtitle group attribute
            if line.hasPrefix("#EXT-X-STREAM-INF:") {
                // Check if SUBTITLES attribute already exists
                if !line.contains("SUBTITLES=") {
                    modifiedLines[modifiedLines.count - 1] = line + ",SUBTITLES=\"subs\""
                }
            }
        }
        
        // Add subtitle media declarations before the first stream
        var subtitleMediaLines: [String] = []
        for track in subtitleTracks {
            guard let trackId = track["id"] as? String,
                  let language = track["language"] as? String else {
                continue
            }
            
            // Get title from track, fallback to name or language
            let title = (track["title"] as? String) ?? (track["name"] as? String) ?? language
            
            // Create subtitle playlist URL with custom scheme
            let subtitlePlaylistUrl = "\(subtitlePlaylistUrlPrefix)://\(trackId).m3u8"
            
            let mediaLine = "#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID=\"subs\",LANGUAGE=\"\(language)\",NAME=\"\(title)\",AUTOSELECT=YES,URI=\"\(subtitlePlaylistUrl)\""
            subtitleMediaLines.append(mediaLine)
        }
        
        // Insert subtitle media lines before the first stream
        var insertIndex = -1
        for (index, line) in modifiedLines.enumerated() {
            if line.hasPrefix("#EXT-X-STREAM-INF:") {
                insertIndex = index
                break
            }
        }
        
        if insertIndex >= 0 {
            modifiedLines.insert(contentsOf: subtitleMediaLines, at: insertIndex)
        } else {
            // If no stream found, append at the end
            modifiedLines.append(contentsOf: subtitleMediaLines)
        }
        
        return modifiedLines.joined(separator: "\n")
    }
    
    // MARK: - VTT to Playlist Conversion
    
    private func createSubtitlePlaylistFromVTT(vttContent: String, subtitleUrl: URL) -> String {
        // Parse VTT to find the last timestamp (matching C# implementation)
        let noWhitespaceVtt = vttContent.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        
        guard let arrowRange = noWhitespaceVtt.range(of: "-->", options: .backwards) else {
            Self.logger.warning("Could not find timestamp in VTT, using default duration")
            return createDefaultSubtitlePlaylist(subtitleUrl: subtitleUrl)
        }
        
        // Get substring after the arrow
        let arrowIndex = arrowRange.upperBound
        let afterArrow = String(noWhitespaceVtt[arrowIndex...])
        
        guard let firstColon = afterArrow.firstIndex(of: ":"),
              let period = afterArrow.firstIndex(of: "."),
              firstColon > afterArrow.startIndex else {
            Self.logger.warning("Could not parse timestamp, using default duration")
            return createDefaultSubtitlePlaylist(subtitleUrl: subtitleUrl)
        }
        
        // Extract time string from firstColon - 2 to period (matching C# logic)
        // Ensure we have enough characters before firstColon
        let offset = min(2, afterArrow.distance(from: afterArrow.startIndex, to: firstColon))
        let startIndex = afterArrow.index(firstColon, offsetBy: -offset)
        let timeString = String(afterArrow[startIndex..<period])
        
        // Parse time string (format: HH:MM:SS)
        let timeComponents = timeString.components(separatedBy: ":")
        guard timeComponents.count == 3,
              let hours = Int(timeComponents[0]),
              let minutes = Int(timeComponents[1]),
              let seconds = Int(timeComponents[2]) else {
            Self.logger.warning("Could not parse time components, using default duration")
            return createDefaultSubtitlePlaylist(subtitleUrl: subtitleUrl)
        }
        
        let totalSeconds = hours * 3600 + minutes * 60 + seconds
        
        // Create HLS subtitle playlist
        let playlistLines: [String] = [
            "#EXTM3U",
            "#EXT-X-TARGETDURATION:\(totalSeconds)",
            "#EXT-X-VERSION:3",
            "#EXT-X-MEDIA-SEQUENCE:0",
            "#EXT-X-PLAYLIST-TYPE:VOD",
            "#EXTINF:\(totalSeconds),",
            subtitleUrl.absoluteString,
            "#EXT-X-ENDLIST"
        ]
        
        return playlistLines.joined(separator: "\n")
    }
    
    private func createDefaultSubtitlePlaylist(subtitleUrl: URL) -> String {
        let playlistLines: [String] = [
            "#EXTM3U",
            "#EXT-X-TARGETDURATION:3600",
            "#EXT-X-VERSION:3",
            "#EXT-X-MEDIA-SEQUENCE:0",
            "#EXT-X-PLAYLIST-TYPE:VOD",
            "#EXTINF:3600,",
            subtitleUrl.absoluteString,
            "#EXT-X-ENDLIST"
        ]
        
        return playlistLines.joined(separator: "\n")
    }
    
    // MARK: - Redirect Handling
    
    private func handleRedirectRequest(loadingRequest: AVAssetResourceLoadingRequest, originalUrl: URL) -> Bool {
        // For fragment requests (video/audio segments), redirect to original URL
        guard let requestUrl = loadingRequest.request.url else {
            return false
        }
        
        let requestString = requestUrl.absoluteString
        
        // Remove custom scheme prefix and restore original scheme
        let originalUrlString: String
        if requestString.hasPrefix("\(HLSSubtitleResourceLoaderDelegate.customSchemePrefix)://") {
            // Restore original scheme (http or https)
            if originalUrl.scheme == "https" {
                originalUrlString = requestString.replacingOccurrences(
                    of: "\(HLSSubtitleResourceLoaderDelegate.customSchemePrefix)://",
                    with: "https://"
                )
            } else {
                originalUrlString = requestString.replacingOccurrences(
                    of: "\(HLSSubtitleResourceLoaderDelegate.customSchemePrefix)://",
                    with: "http://"
                )
            }
        } else {
            originalUrlString = requestString
        }
        
        guard let redirectUrl = URL(string: originalUrlString) else {
            Self.logger.error("Failed to create redirect URL from: \(requestString, privacy: .public)")
            return false
        }
        
        // Create redirect response
        let redirectRequest = URLRequest(url: redirectUrl)
        loadingRequest.redirect = redirectRequest
        
        let redirectResponse = HTTPURLResponse(
            url: redirectUrl,
            statusCode: 302,
            httpVersion: nil,
            headerFields: nil
        )
        loadingRequest.response = redirectResponse
        loadingRequest.finishLoading()
        
        return true
    }
}

