import Foundation

/// Load-failure codes on `jeepCapVideoPlayerError` for an item that never became ready.
/// Separate from typed DRM discriminators — those stay on `VideoDrm`.
public enum VideoPlaybackError {
    public static let certificate = "certificate"
    public static let generic = "generic"

    /// TLS trust failures: `NSURLError` −1200…−1206, including wrapped `NSUnderlyingError`.
    public static func from(_ error: Error?) -> String {
        isCertificateFailure(error) ? certificate : generic
    }

    public static func listenerData(fromPlayerId: String, error: String) -> [String: Any] {
        let code = (error == certificate) ? certificate : generic
        return [
            "fromPlayerId": fromPlayerId,
            "error": code,
            "code": code
        ]
    }

    public static func isCertificateFailure(_ error: Error?) -> Bool {
        var current = error as NSError?
        var seen = Set<ObjectIdentifier>()
        while let err = current {
            let id = ObjectIdentifier(err)
            if seen.contains(id) {
                break
            }
            seen.insert(id)
            if err.domain == NSURLErrorDomain && (-1206)...(-1200) ~= err.code {
                return true
            }
            current = err.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return false
    }
}
