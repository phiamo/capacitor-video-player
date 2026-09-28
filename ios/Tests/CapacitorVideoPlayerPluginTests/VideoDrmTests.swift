//
//  VideoDrmTests.swift
//  CapacitorVideoPlayerPluginTests
//
//  Story 58.4: mirrors Android `VideoDrmTest` registry/typed-error coverage.
//

import AVFoundation
import Capacitor
import XCTest
@testable import CapacitorVideoPlayerPlugin

final class VideoDrmTests: XCTestCase {

    override func tearDown() {
        VideoDrm.setProvider(nil)
        super.tearDown()
    }

    func test_getProvider_defaultIsNil() {
        XCTAssertNil(VideoDrm.getProvider())
    }

    func test_open_withoutDrm_isPlainPlayback() {
        let attempt = VideoDrm.open(nil, onError: nil)
        XCTAssertNil(attempt.failureCode)
        XCTAssertNil(attempt.session)
    }

    func test_open_drmWithoutProvider_isNoProvider() {
        let drm: JSObject = ["fairplayLicenseUrl": "https://license.example/fp"]
        let attempt = VideoDrm.open(drm, onError: nil)
        XCTAssertEqual(attempt.failureCode, VideoDrm.codeNoProvider)
        XCTAssertNil(attempt.session)
    }

    func test_open_withProvider_returnsSession() {
        let session = FakeVideoDrmSession()
        VideoDrm.setProvider(FakeVideoDrmProvider { _, _ in session })
        let drm: JSObject = ["playbackSessionId": "sess-1"]
        let attempt = VideoDrm.open(drm, onError: nil)
        XCTAssertNil(attempt.failureCode)
        XCTAssertTrue((attempt.session as? FakeVideoDrmSession) === session)
    }

    func test_errorListenerData_carriesDiscriminator() {
        let data = VideoDrm.errorListenerData(
            fromPlayerId: "fullscreen",
            error: VideoDrm.errorBlockedByStreamLimit
        )
        XCTAssertEqual(data["fromPlayerId"] as? String, "fullscreen")
        XCTAssertEqual(data["error"] as? String, "blockedByStreamLimit")
    }

    func test_errorListenerData_coercesUnknownDiscriminator() {
        let data = VideoDrm.errorListenerData(fromPlayerId: "p1", error: "licenseDenied")
        XCTAssertEqual(data["fromPlayerId"] as? String, "p1")
        XCTAssertEqual(data["error"] as? String, VideoDrm.errorUnknown)
    }

    func test_providerOnError_emitsTypedPayload() {
        var errors: [String] = []
        VideoDrm.setProvider(FakeVideoDrmProvider { _, onError in
            let session = FakeVideoDrmSession()
            session.onError = onError
            return session
        })
        let attempt = VideoDrm.open([:]) { errors.append($0) }
        let session = attempt.session as? FakeVideoDrmSession
        session?.onError?(VideoDrm.errorNotEntitled)
        XCTAssertEqual(errors, [VideoDrm.errorNotEntitled])
        let payload = VideoDrm.errorListenerData(fromPlayerId: "p1", error: errors[0])
        XCTAssertEqual(payload["fromPlayerId"] as? String, "p1")
        XCTAssertEqual(payload["error"] as? String, "notEntitled")
    }

    func test_typedError_passesThroughKnownDiscriminators() {
        for value in [
            VideoDrm.errorBlockedByStreamLimit,
            VideoDrm.errorNotEntitled,
            VideoDrm.errorExpired,
            VideoDrm.errorNetwork,
            VideoDrm.errorUnknown
        ] {
            XCTAssertEqual(VideoDrm.typedError(value), value)
        }
    }

    func test_typedError_coercesUnknownStrings() {
        XCTAssertEqual(VideoDrm.typedError("somethingElse"), VideoDrm.errorUnknown)
    }
}

// MARK: - Fakes

private final class FakeVideoDrmProvider: VideoDrmProvider {
    let factory: (JSObject, @escaping (String) -> Void) -> VideoDrmSession

    init(_ factory: @escaping (JSObject, @escaping (String) -> Void) -> VideoDrmSession) {
        self.factory = factory
    }

    func open(_ drm: JSObject, onError: @escaping (String) -> Void) -> VideoDrmSession {
        factory(drm, onError)
    }
}

private final class FakeVideoDrmSession: VideoDrmSession {
    var onError: ((String) -> Void)?
    var attachedAsset: AVURLAsset?
    var startCalled = false
    var releaseCalled = false

    func attach(to asset: AVURLAsset) {
        attachedAsset = asset
    }

    func start() {
        startCalled = true
    }

    func release() {
        releaseCalled = true
    }
}
