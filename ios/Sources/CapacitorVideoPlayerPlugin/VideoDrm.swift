//
//  VideoDrm.swift
//  Plugin
//
//  Story 58.4: Swift port of the Android `VideoDrm`/`VideoDrmProvider`/`VideoDrmSession` trio.
//

import AVFoundation
import Capacitor
import Foundation

/// Plugin-owned DRM session. The host (Story 58.4) wraps drm-kit `FairPlaySession`; this plugin
/// never imports drm-kit.
public protocol VideoDrmSession: AnyObject {
    /// Routes the asset's FairPlay key requests through the session. Call before any
    /// `AVPlayerItem` is built from `asset`. `AVMutableComposition` does not conform to
    /// `AVContentKeyRecipient` in this SDK, so a composition rebuilt from `asset` (e.g. for
    /// multi-subtitle-track merging) cannot itself be re-registered — callers must not build an
    /// `AVPlayerItem` from a composition while a DRM session is attached; fall back to `asset`.
    func attach(to asset: AVURLAsset)
    func start()
    func release()
}

/// Host-registered factory for `VideoDrmSession`. Register from the app at launch via
/// `VideoDrm.setProvider(_:)`; do not pin drm-kit in this plugin.
public protocol VideoDrmProvider {
    /// Open a session for `initPlayer` `drm` options. `onError` receives exactly one
    /// discriminator: `blockedByStreamLimit` | `notEntitled` | `expired` | `network` | `unknown`.
    func open(_ drm: JSObject, onError: @escaping (String) -> Void) -> VideoDrmSession
}

/// Plugin-owned DRM provider registry. The host app registers drm-kit in Story 58.4; this module
/// does not depend on drm-kit. Mirrors Android `VideoDrm`.
public final class VideoDrm {

    public static let codeNoProvider = "noProvider"
    public static let codeNotSupported = "notSupported"
    public static let notSupportedMessage = "DRM not supported on this platform yet"

    public static let errorBlockedByStreamLimit = "blockedByStreamLimit"
    public static let errorNotEntitled = "notEntitled"
    public static let errorExpired = "expired"
    public static let errorNetwork = "network"
    public static let errorUnknown = "unknown"

    private static let lock = NSLock()
    private static var _provider: VideoDrmProvider?

    private init() {}

    public static func setProvider(_ next: VideoDrmProvider?) {
        lock.lock()
        _provider = next
        lock.unlock()
    }

    public static func getProvider() -> VideoDrmProvider? {
        lock.lock()
        defer { lock.unlock() }
        return _provider
    }

    /// Result of `open(_:onError:)`: no `drm` set, a registered session, or a missing-provider
    /// failure.
    public enum OpenAttempt {
        case none
        case noProvider
        case ok(VideoDrmSession)

        public var session: VideoDrmSession? {
            if case .ok(let session) = self {
                return session
            }
            return nil
        }

        public var failureCode: String? {
            if case .noProvider = self {
                return VideoDrm.codeNoProvider
            }
            return nil
        }
    }

    /// Open a session when `drm` is set. Missing `drm` is plain playback. Missing provider with
    /// `drm` set is `.noProvider`.
    public static func open(_ drm: JSObject?, onError: ((String) -> Void)?) -> OpenAttempt {
        guard let drm = drm else {
            return .none
        }
        guard let registered = getProvider() else {
            return .noProvider
        }
        let typedOnError: (String) -> Void = { error in
            onError?(VideoDrm.typedError(error))
        }
        let session = registered.open(drm, onError: typedOnError)
        return .ok(session)
    }

    public static func typedError(_ error: String) -> String {
        switch error {
        case errorBlockedByStreamLimit, errorNotEntitled, errorExpired, errorNetwork, errorUnknown:
            return error
        default:
            return errorUnknown
        }
    }

    /// Payload for the `jeepCapVideoPlayerError` event: `{fromPlayerId, error}`.
    public static func errorListenerData(fromPlayerId: String, error: String) -> [String: Any] {
        return [
            "fromPlayerId": fromPlayerId,
            "error": typedError(error)
        ]
    }
}
