//
//  HLSSubtitleResourceLoaderDelegateTests.swift
//  CapacitorVideoPlayerPluginTests
//
//  Regression coverage for the AUTOSELECT bug: injected subtitle tracks must not set
//  AUTOSELECT=YES, or AVKit's automatic media selection rejects them on a device whose
//  caption display mode is the iOS default ("forced-only"), leaving the track highlighted
//  in the CC menu but never actually rendering cues. Confirmed live via device logs
//  ("Received a non-forced-only media selection ... when display type was forced-only").
//

import XCTest
@testable import CapacitorVideoPlayerPlugin

final class HLSSubtitleResourceLoaderDelegateTests: XCTestCase {

    private let samplePlaylist = """
    #EXTM3U
    #EXT-X-VERSION:6
    #EXT-X-STREAM-INF:BANDWIDTH=1000000
    video.m3u8
    """

    private func makeDelegate(tracks: [[String: Any]]) -> HLSSubtitleResourceLoaderDelegate {
        HLSSubtitleResourceLoaderDelegate(
            subtitleTracks: tracks,
            bearerToken: nil,
            originalVideoUrl: URL(string: "https://example.com/master.m3u8")!
        )
    }

    func test_injectedSubtitleLine_isNotAutoSelected() {
        let tracks: [[String: Any]] = [[
            "id": "cs",
            "language": "cs",
            "title": "Czech",
            "isDefault": false,
        ]]
        let delegate = makeDelegate(tracks: tracks)

        let result = delegate.injectSubtitlesIntoPlaylist(playlistString: samplePlaylist)

        XCTAssertTrue(result.contains("AUTOSELECT=NO"), "Injected subtitle line must not auto-select: \(result)")
        XCTAssertFalse(result.contains("AUTOSELECT=YES"), "AUTOSELECT=YES triggers AVKit's automatic media selection, which rejects non-forced tracks under the iOS default caption display mode: \(result)")
    }

    func test_injectedSubtitleLine_staysNonForced() {
        let tracks: [[String: Any]] = [[
            "id": "cs",
            "language": "cs",
            "title": "Czech",
        ]]
        let delegate = makeDelegate(tracks: tracks)

        let result = delegate.injectSubtitlesIntoPlaylist(playlistString: samplePlaylist)

        XCTAssertTrue(result.contains("FORCED=NO"))
    }

    func test_defaultTrack_stillMarkedDefault_butNotAutoSelected() {
        let tracks: [[String: Any]] = [[
            "id": "cs",
            "language": "cs",
            "title": "Czech",
            "isDefault": true,
        ]]
        let delegate = makeDelegate(tracks: tracks)

        let result = delegate.injectSubtitlesIntoPlaylist(playlistString: samplePlaylist)

        XCTAssertTrue(result.contains("DEFAULT=YES"))
        XCTAssertTrue(result.contains("AUTOSELECT=NO"))
    }

    func test_noSubtitleTracks_playlistUnchanged() {
        let delegate = makeDelegate(tracks: [])

        let result = delegate.injectSubtitlesIntoPlaylist(playlistString: samplePlaylist)

        XCTAssertFalse(result.contains("EXT-X-MEDIA"))
        XCTAssertTrue(result.contains("CLOSED-CAPTIONS=NONE"))
    }
}
