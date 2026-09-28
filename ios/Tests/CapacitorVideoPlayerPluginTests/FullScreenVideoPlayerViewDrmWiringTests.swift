//
//  FullScreenVideoPlayerViewDrmWiringTests.swift
//  CapacitorVideoPlayerPluginTests
//
//  Story 58.4: source-text guardrail mirroring Android's
//  FullscreenExoPlayerFragmentTest.fragmentSource_doesNotUseDeprecatedPipFullscreenOrCastSessionApis
//  (which asserts drmSession.start()/.release() ordering in source, since a full runtime test of
//  the fragment/view is impractical). Verifies the DRM session is attached and started before any
//  AVPlayerItem is built from videoAsset, and released from both deinit and cleanup().
//

import XCTest

final class FullScreenVideoPlayerViewDrmWiringTests: XCTestCase {

    func test_drmSessionAttachedAndStartedBeforeInitialize() throws {
        let source = try Self.sourceText()
        let attachRange = try XCTUnwrap(source.range(of: "drmSession.attach(to: self.videoAsset)"))
        let startRange = try XCTUnwrap(source.range(of: "drmSession.start()"))
        let initializeRange = try XCTUnwrap(source.range(of: "self.initialize()"))
        XCTAssertTrue(attachRange.lowerBound < initializeRange.lowerBound,
                      "drmSession.attach(to:) must run before self.initialize() builds the first AVPlayerItem")
        XCTAssertTrue(startRange.lowerBound < initializeRange.lowerBound,
                      "drmSession.start() must run before self.initialize() builds the first AVPlayerItem")
    }

    func test_drmSessionReleasedFromDeinitAndCleanup() throws {
        let source = try Self.sourceText()
        let releaseCount = source.components(separatedBy: "self.drmSession?.release()").count - 1
        XCTAssertEqual(releaseCount, 2, "expected drmSession release() from both deinit and cleanup()")
    }

    private static func sourceText() throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let sourceFile = testFile
            .deletingLastPathComponent() // CapacitorVideoPlayerPluginTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // ios/
            .appendingPathComponent("Sources/CapacitorVideoPlayerPlugin/VideoPlayer/FullScreenVideoPlayerView.swift")
        return try String(contentsOf: sourceFile, encoding: .utf8)
    }
}
