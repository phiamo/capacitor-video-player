import XCTest
@testable import CapacitorVideoPlayerPlugin

final class VideoPlaybackErrorTests: XCTestCase {

    func test_from_mapsSecureConnectionFailed() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorSecureConnectionFailed)
        XCTAssertEqual(VideoPlaybackError.from(error), VideoPlaybackError.certificate)
    }

    func test_from_mapsUntrustedAndUnknownRoot() {
        XCTAssertEqual(
            VideoPlaybackError.from(NSError(domain: NSURLErrorDomain, code: NSURLErrorServerCertificateUntrusted)),
            VideoPlaybackError.certificate
        )
        XCTAssertEqual(
            VideoPlaybackError.from(NSError(domain: NSURLErrorDomain, code: NSURLErrorServerCertificateHasUnknownRoot)),
            VideoPlaybackError.certificate
        )
    }

    func test_from_walksUnderlyingError() {
        let tls = NSError(domain: NSURLErrorDomain, code: NSURLErrorServerCertificateHasBadDate)
        let wrapped = NSError(
            domain: AVFoundationErrorDomain,
            code: -11800,
            userInfo: [NSUnderlyingErrorKey: tls]
        )
        XCTAssertEqual(VideoPlaybackError.from(wrapped), VideoPlaybackError.certificate)
    }

    func test_from_otherFailuresAreGeneric() {
        let http = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse)
        XCTAssertEqual(VideoPlaybackError.from(http), VideoPlaybackError.generic)
        XCTAssertEqual(VideoPlaybackError.from(nil), VideoPlaybackError.generic)
    }

    func test_listenerData_usesCodeAndError() {
        let data = VideoPlaybackError.listenerData(fromPlayerId: "fullscreen", error: VideoPlaybackError.certificate)
        XCTAssertEqual(data["fromPlayerId"] as? String, "fullscreen")
        XCTAssertEqual(data["error"] as? String, "certificate")
        XCTAssertEqual(data["code"] as? String, "certificate")
    }
}

private let AVFoundationErrorDomain = "AVFoundationErrorDomain"
