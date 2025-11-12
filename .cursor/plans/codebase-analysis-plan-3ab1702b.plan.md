<!-- 3ab1702b-8578-4a79-9506-fa9e1cc2d9e1 8c47cd0c-3128-425e-ab5b-a2660c409d3b -->
# Integrate HLS External Subtitles into Native iOS AVPlayerViewController Controls

## Problem Analysis

Currently, the implementation uses a custom CC button with a UIAlertController menu. The user wants to integrate multiple subtitle languages directly into AVPlayerViewController's native subtitle menu (which appears when tapping the video controls), similar to how speed selection and other native controls work.

### Key Context:

1. **Subtitle Source**: All subtitles come from the plugin's `subtitles` array (line 189-190 in `CapacitorVideoPlayerPlugin.swift`)
2. **Stream Type**: Primarily HLS streams (`.m3u8`), no embedded subtitles in HLS manifest
3. **Subtitle Format**: External VTT/SRT files provided via URLs in the `subtitles` array
4. **Goal**: Make all subtitle languages appear in the native AVPlayerViewController subtitle menu

### Current Implementation:

- Custom CC button in `contentOverlayView` (lines 794-816 in `FullScreenVideoPlayerView.swift`)
- For HLS: Custom UILabel rendering with manual timing (`loadAllSubtitleTracksForHLS`, `setupHLSSubtitleDisplay`)
- Subtitles are loaded from external URLs and parsed manually
- Custom menu via `UIAlertController` when CC button is tapped

### Technical Challenge:

For HLS streams, external subtitle files cannot be directly added to `AVMutableComposition` without breaking HLS features (adaptive streaming, etc.). However, we can create a composition that includes the HLS video/audio tracks plus external subtitle text tracks.

## Solution Approach

### Primary Strategy: Composition-Based Approach for HLS

1. **Create AVMutableComposition from HLS Asset**:

   - Extract video and audio tracks from HLS `AVURLAsset`
   - Add all external subtitle files as text tracks to composition
   - Set proper metadata (language, locale) on each subtitle track
   - Create `AVPlayerItem` from composition

2. **Metadata Configuration**:

   - Set language code and locale on each text track
   - Use `AVMetadataItem` to ensure proper display names in native menu
   - Match track IDs with provided subtitle track IDs

3. **Remove Custom UI**:

   - Remove custom CC button
   - Remove custom UILabel rendering (use native rendering)
   - Let AVPlayerViewController handle all subtitle display and selection

4. **Track Selection**:

   - Use `AVMediaSelectionGroup` to programmatically select tracks
   - Observe `AVPlayerItemMediaSelectionDidChangeNotification` to sync with user selections

## Implementation Plan

### Step 1: Create Method to Build Composition from HLS with Subtitles

**File**: `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`

- Create new method `createCompositionFromHLSWithSubtitles`:
  - Accepts HLS `AVURLAsset` and array of subtitle track dictionaries
  - Create `AVMutableComposition`
  - Load and extract video tracks from HLS asset
  - Load and extract audio tracks from HLS asset
  - Add video/audio tracks to composition
  - Call helper to add all subtitle tracks
  - Return composition

### Step 2: Create Method to Add Multiple Subtitle Tracks

**File**: `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`

- Create method `addMultipleSubtitleTracksToComposition`:
  - Accepts `AVMutableComposition`, array of subtitle track dictionaries, video duration
  - For each subtitle track in array:
    - Get subtitle URL from `track["url"]`
    - Create `AVAsset` from subtitle URL (WebVTT files work directly)
    - For SRT: Convert to WebVTT format first
    - Load subtitle asset tracks
    - Add as text track to composition
    - Apply metadata (language, locale, label)

### Step 3: Convert SRT to WebVTT for AVFoundation

**File**: `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`

- Create helper method `convertSRTToWebVTT`:
  - Parse SRT content
  - Convert to WebVTT format
  - Create temporary file or return WebVTT string
  - Return URL to WebVTT file

### Step 4: Set Metadata on Subtitle Tracks

**File**: `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`

- Create method `applyMetadataToSubtitleTrack`:
  - Accepts composition track and subtitle track dictionary
  - Get language code from `track["language"]`
  - Get locale identifier (derive from language if needed)
  - Get label from `track["label"]` or language
  - Use `AVMutableMetadataItem` to set:
    - Language identifier
    - Locale
    - Extended language tag
  - Apply metadata to track

### Step 5: Update HLS Stream Initialization

**File**: `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`

- Modify `loadAllSubtitleTracksForHLS` method (line 227):
  - Instead of loading for custom rendering, create composition
  - Call `createCompositionFromHLSWithSubtitles`
  - Create `AVPlayerItem` from composition
  - Set player item on player
  - Remove all custom UILabel setup code

### Step 6: Remove Custom Subtitle UI

**File**: `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`

- Remove `addSubtitleSelectionButton` method (lines 794-816)
- Remove `showSubtitleSelectionMenu` method (lines 818-875)
- Remove call to `addSubtitleSelectionButton` in `setupPlayer` (line 787)
- Remove `setupHLSSubtitleDisplay` method (lines 305-380)
- Remove `subtitleLabel` property (line 56)
- Remove `subtitleTracksData` property (line 55) - no longer needed for display
- Remove `subtitleTimeObserver` property (line 50)
- Remove manual subtitle parsing and timing logic

### Step 7: Update Track Selection to Use Native Selection

**File**: `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`

- Modify `selectSubtitleTrack` (line 1520):
  - Get `AVMediaSelectionGroup` for `.legible` characteristic from `playerItem.asset`
  - Find matching option by:
    - Language code (`option.locale?.languageCode`)
    - Locale identifier (`option.locale?.identifier`)
    - Extended language tag (`option.extendedLanguageTag`)
    - Display name (`option.displayName`)
  - Use `playerItem.select(option, in: mediaSelectionGroup)` for native selection
  - Remove all custom UILabel hiding/showing logic
  - Remove HLS-specific custom rendering logic

### Step 8: Observe Native Selection Changes

**File**: `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`

- In `addObservers` method (line 1191):
  - Add observer for `AVPlayerItemMediaSelectionDidChangeNotification`:
    - Update `_activeSubtitleTrackId` when user selects from native menu
    - Sync with plugin state if needed
    - Store observer reference for cleanup

### Step 9: Handle Initial Track Selection

**File**: `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`

- After composition is created and player item is ready:
  - If `selectedSubtitleId` is provided, find matching track in `AVMediaSelectionGroup`
  - Select that track programmatically
  - Ensure initial selection happens after asset tracks are loaded

### Step 10: Clean Up Unused Code

**File**: `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`

- Remove `parseVTTContent`, `parseSRTContent` methods (if only used for display)
- Remove `findSubtitleForTime` method (if only used for display)
- Remove `parseRGBA` method (if only used for custom label styling)
- Keep parsing methods if needed for SRT to WebVTT conversion

## Technical Implementation Details

### Creating Composition from HLS:

```swift
let composition = AVMutableComposition()
// Load HLS asset tracks
hlsAsset.loadValuesAsynchronously(forKeys: ["tracks"]) {
    let videoTracks = hlsAsset.tracks(withMediaType: .video)
    let audioTracks = hlsAsset.tracks(withMediaType: .audio)
    // Add to composition
    // Then add subtitle tracks
}
```

### Adding WebVTT Subtitle Track:

```swift
// WebVTT files can be loaded as AVAsset
let subtitleAsset = AVURLAsset(url: vttURL)
subtitleAsset.loadValuesAsynchronously(forKeys: ["tracks"]) {
    if let textTrack = subtitleAsset.tracks(withMediaType: .text).first {
        let compositionTrack = composition.addMutableTrack(
            withMediaType: .text,
            preferredTrackID: kCMPersistentTrackID_Invalid)
        try compositionTrack.insertTimeRange(
            CMTimeRangeMake(start: .zero, duration: videoDuration),
            of: textTrack,
            at: .zero)
        // Apply metadata
    }
}
```

### Setting Track Metadata:

```swift
// Metadata is set via AVAssetTrack properties
// Language and locale are typically set when creating the track
// We may need to use AVMutableCompositionTrack's metadata property
// Or set via AVMediaSelectionOption when available
```

## Important Considerations

1. **HLS Compatibility**: Creating composition from HLS may affect adaptive streaming. Test adaptive bitrate switching.

2. **Subtitle Format**: WebVTT is natively supported. SRT files need conversion to WebVTT.

3. **Track Identification**: Ensure each track has unique metadata for selection matching.

4. **Performance**: Loading multiple subtitle files asynchronously. Show loading state if needed.

5. **Authentication**: Subtitle URLs may require headers (from `_stHeaders`). Use `AVURLAsset` with options.

## Testing Requirements

1. Test with 3+ subtitle languages in `subtitles` array
2. Verify all languages appear in native AVPlayerViewController menu
3. Test track selection from native menu works
4. Verify subtitles display correctly via native rendering
5. Test with WebVTT and SRT formats
6. Test initial track selection via `selectedSubtitleId`
7. Verify native controls show/hide properly
8. Test HLS adaptive streaming still works
9. Test with authenticated subtitle URLs

## Files to Modify

1. **`ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`**:

   - `loadAllSubtitleTracksForHLS`: Replace with composition-based approach
   - Add: `createCompositionFromHLSWithSubtitles`
   - Add: `addMultipleSubtitleTracksToComposition`
   - Add: `applyMetadataToSubtitleTrack`
   - Add: `convertSRTToWebVTT` (if needed)
   - Update: `selectSubtitleTrack` to use native selection
   - Update: `addObservers` to observe native selection changes
   - Remove: `addSubtitleSelectionButton`, `showSubtitleSelectionMenu`, `setupHLSSubtitleDisplay`
   - Remove: Custom subtitle rendering properties and logic

2. **No changes needed to**:

   - `ios/Plugin/CapacitorVideoPlayerPlugin.swift` (API interface unchanged)
   - `ios/Plugin/Extensions/*.swift` (interface unchanged)
   - TypeScript definitions (API remains the same)

### To-dos

- [ ] Analyze current HLS subtitle loading and rendering implementation to understand what needs to be replaced
- [ ] Create method to build AVMutableComposition from HLS asset with video/audio tracks plus external subtitle text tracks
- [ ] Implement method to add all subtitle tracks from subtitles array to composition as text tracks with proper metadata
- [ ] Set language, locale, and display name metadata on each subtitle track so they appear correctly in native menu
- [ ] Remove custom CC button, UIAlertController menu, and custom UILabel subtitle rendering
- [ ] Update selectSubtitleTrack to use AVMediaSelectionGroup for native track selection
- [ ] Add observer for AVPlayerItemMediaSelectionDidChangeNotification to sync with user selections from native menu
- [ ] Implement logic to select initial subtitle track based on selectedSubtitleId when composition is ready
- [ ] Test that all subtitle languages appear in native menu and selection works correctly