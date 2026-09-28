//
//  FullScreenVideoPlayerViewDrmWiringTests.swift
//  CapacitorVideoPlayerPluginTests
//
//  Story 58.4: exercises FullScreenVideoPlayerView's actual DRM wiring — attach(to:)/start() run
//  during init, release() runs from cleanup() — rather than pattern-matching the source text.
//  `initialize()` only schedules a `Task { @MainActor in ... }` and returns immediately, so by the
//  time `init(...)` returns, the synchronous attach/start calls that precede it have already run.
//

import AVFoundation
import Capacitor
import XCTest
@testable import CapacitorVideoPlayerPlugin

final class FullScreenVideoPlayerViewDrmWiringTests: XCTestCase {

    func test_drmSessionAttachedAndStartedDuringInit() {
        let session = FakeVideoDrmSession()
        let view = makeView(drmSession: session)
        XCTAssertTrue(session.attachedAsset === view.videoAsset,
                      "drmSession.attach(to:) must be called with the view's own videoAsset")
        XCTAssertTrue(session.startCalled)
        view.cleanup()
    }

    func test_cleanupReleasesTheDrmSession() {
        let session = FakeVideoDrmSession()
        let view = makeView(drmSession: session)
        XCTAssertFalse(session.releaseCalled)
        view.cleanup()
        XCTAssertTrue(session.releaseCalled)
    }

    func test_plainPlaybackWithoutDrmSessionConstructsCleanly() {
        // No session registered (drm absent, or noProvider already short-circuited upstream):
        // the view must build normally with a nil drmSession.
        let view = makeView(drmSession: nil)
        XCTAssertNotNil(view.videoAsset)
        view.cleanup()
    }

    private func makeView(drmSession: VideoDrmSession?) -> FullScreenVideoPlayerView {
        FullScreenVideoPlayerView(
            url: URL(string: "https://example.com/video.mp4")!,
            rate: 1.0, playerId: "test-player", exitOnEnd: true,
            loopOnEnd: false, pipEnabled: false, showControls: true,
            displayMode: "all", stUrl: nil, stLanguage: nil,
            stHeaders: nil, stOptions: nil,
            title: nil, smallTitle: nil, artwork: nil,
            subtitleTracks: nil, selectedSubtitleId: nil,
            drmSession: drmSession)
    }
}

private final class FakeVideoDrmSession: VideoDrmSession {
    var attachedAsset: AVAsset?
    var startCalled = false
    var releaseCalled = false

    func attach(to asset: AVAsset) {
        attachedAsset = asset
    }

    func start() {
        startCalled = true
    }

    func release() {
        releaseCalled = true
    }
}
