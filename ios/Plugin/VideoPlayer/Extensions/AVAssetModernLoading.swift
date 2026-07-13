import AVFoundation
import Foundation

enum AVAssetLoadingError: Error {
    case tracksNotLoaded
}

extension AVAsset {
    func loadVideoTracks() async throws -> [AVAssetTrack] {
        try await loadTracks(withMediaType: .video)
    }

    func loadAudioTracks() async throws -> [AVAssetTrack] {
        try await loadTracks(withMediaType: .audio)
    }

    func loadTextTracks() async throws -> [AVAssetTrack] {
        try await loadTracks(withMediaType: .text)
    }

    func loadDurationValue() async throws -> CMTime {
        try await load(.duration)
    }

    func loadAllTracks() async throws -> [AVAssetTrack] {
        try await load(.tracks)
    }

    func loadLegibleMediaSelectionGroup() async throws -> AVMediaSelectionGroup? {
        try await loadMediaSelectionGroup(for: .legible)
    }

    func loadAvailableMediaCharacteristics() async throws -> [AVMediaCharacteristic] {
        try await load(.availableMediaCharacteristicsWithMediaSelectionOptions)
    }

    func loadTracksAndDuration() async throws -> (tracks: [AVAssetTrack], duration: CMTime) {
        async let tracks = load(.tracks)
        async let duration = load(.duration)
        return try await (tracks, duration)
    }

    func loadTracksOnly() async throws {
        _ = try await load(.tracks)
    }

    func loadSubtitleAssetMetadata() async throws {
        _ = try await load(.tracks, .duration, .availableMediaCharacteristicsWithMediaSelectionOptions)
    }
}

extension AVAssetTrack {
    func loadDisplayProperties() async throws -> (transform: CGAffineTransform, naturalSize: CGSize) {
        async let transform = load(.preferredTransform)
        async let naturalSize = load(.naturalSize)
        return try await (transform, naturalSize)
    }

    func loadTimeRangeValue() async throws -> CMTimeRange {
        try await load(.timeRange)
    }

    func loadLanguageTags() async throws -> (languageCode: String?, extendedTag: String?) {
        async let languageCode = load(.languageCode)
        async let extendedTag = load(.extendedLanguageTag)
        return try await (languageCode, extendedTag)
    }
}

extension AVURLAsset {
    struct LoadedSubtitleAsset {
        let asset: AVURLAsset
        let trackId: String
        let language: String
        let textTracks: [AVAssetTrack]
    }

    static func loadSubtitleAssets(
        _ assets: [(asset: AVURLAsset, trackId: String, language: String)]
    ) async -> [LoadedSubtitleAsset] {
        await withTaskGroup(of: LoadedSubtitleAsset?.self) { group in
            for info in assets {
                group.addTask {
                    do {
                        try await info.asset.loadSubtitleAssetMetadata()
                        let textTracks = try await info.asset.loadTextTracks()
                        guard !textTracks.isEmpty else { return nil }
                        return LoadedSubtitleAsset(
                            asset: info.asset,
                            trackId: info.trackId,
                            language: info.language,
                            textTracks: textTracks
                        )
                    } catch {
                        return nil
                    }
                }
            }

            var loaded: [LoadedSubtitleAsset] = []
            for await result in group {
                if let result {
                    loaded.append(result)
                }
            }
            return loaded
        }
    }

    func loadVideoSize() async throws -> CGSize? {
        guard let track = try await loadVideoTracks().first else { return nil }
        let properties = try await track.loadDisplayProperties()
        return properties.naturalSize.applying(properties.transform)
    }
}

extension Locale {
    var modernLanguageCode: String? {
        language.languageCode?.identifier
    }
}

extension AVMediaSelectionOption {
    var modernLanguageCode: String? {
        locale?.modernLanguageCode
    }
}
