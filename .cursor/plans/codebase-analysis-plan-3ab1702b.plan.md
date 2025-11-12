<!-- 3ab1702b-8578-4a79-9506-fa9e1cc2d9e1 8c47cd0c-3128-425e-ab5b-a2660c409d3b -->
# Extend Existing Custom Subtitle Menu with All Languages

## Problem Analysis

The current implementation already has:

- A custom CC button (line 797) that always shows "CC"
- A `showSubtitleSelectionMenu()` method (lines 818-870) that iterates through `_subtitleTracks` and adds each to a UIAlertController
- Custom UILabel rendering for HLS streams with manual timing

The user wants to ensure all languages from the `subtitles` array appear in the menu and improve the button to show the current language instead of just "CC".

## Current Implementation Review

### What Already Works:

1. **Menu Iteration** (lines 830-839): Already loops through all tracks and adds them to the menu
2. **Track Selection** (line 836): Calls `selectSubtitleTrack(trackId:)` when a language is selected
3. **Custom Rendering**: UILabel-based subtitle display for HLS streams

### What Needs Improvement:

1. **Button Label**: Currently always shows "CC" (line 797), should show current language or "CC" when none selected
2. **Menu Display**: Ensure all languages appear correctly (code already does this, but may need verification)
3. **Button Visibility**: Ensure button appears when subtitles are available

## Solution Approach

Keep the existing simple approach:

- Keep custom CC button
- Keep UIAlertController menu (already iterates through tracks)
- Update button label to show current language
- Ensure menu shows all languages properly
- Keep existing custom UILabel rendering

## Implementation Plan

### Step 1: Update Button Label to Show Current Language

**File**: `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`

- Modify `addSubtitleSelectionButton` method (line 794):
  - Instead of hardcoded "CC", determine current language from `_activeSubtitleTrackId` or `_selectedSubtitleId`
  - Look up label from `_subtitleTracks` array
  - Set button title to language label (e.g., "German", "English") or "CC" if none selected
  - Store reference to button for later updates

### Step 2: Create Method to Update Button Label

**File**: `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`

- Create method `updateSubtitleButtonLabel`:
  - Get current active track ID from `_activeSubtitleTrackId` or `_selectedSubtitleId`
  - Find matching track in `_subtitleTracks` array
  - Extract label (prefer `label`, fallback to `language`, fallback to `id`)
  - Update button title to show language or "CC" if none selected
  - Call this method whenever subtitle selection changes

### Step 3: Update Button Label on Track Selection

**File**: `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`

- In `selectSubtitleTrack` method (line 1520):
  - After setting `_activeSubtitleTrackId`
  - Call `updateSubtitleButtonLabel()` to refresh button display
  - Ensure this happens for both HLS and non-HLS streams

### Step 4: Ensure Menu Shows All Languages

**File**: `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`

- Verify `showSubtitleSelectionMenu` method (lines 818-870):
  - Already iterates through `_subtitleTracks` (line 830)
  - Already extracts label properly (line 832)
  - Already shows selected state with checkmark (line 835)
  - No changes needed, but verify it's being called correctly

### Step 5: Ensure Button is Added When Subtitles Available

**File**: `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`

- In `setupPlayer` method (line 787):
  - Verify `addSubtitleSelectionButton()` is called when `_subtitleTracks` is not empty
  - Ensure button is added for both HLS and non-HLS streams

### Step 6: Store Button Reference for Updates

**File**: `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`

- Add property to store button reference:
  - Add `private var subtitleButton: UIButton?` property
  - Store button reference in `addSubtitleSelectionButton`
  - Use stored reference in `updateSubtitleButtonLabel`

## Technical Details

### Button Label Logic:

```swift
private func updateSubtitleButtonLabel() {
    guard let button = subtitleButton else { return }
    
    let currentTrackId = _activeSubtitleTrackId ?? _selectedSubtitleId
    var buttonTitle = "CC"
    
    if let trackId = currentTrackId,
       let tracks = _subtitleTracks,
       let track = tracks.first(where: { ($0["id"] as? String) == trackId }) {
        buttonTitle = track["label"] as? String 
                   ?? track["language"] as? String 
                   ?? trackId
    }
    
    button.setTitle(buttonTitle, for: .normal)
}
```

### Track Selection Update:

```swift
// In selectSubtitleTrack method, after setting _activeSubtitleTrackId:
_activeSubtitleTrackId = trackId
updateSubtitleButtonLabel()
```

## Testing Requirements

1. Verify button shows current language (e.g., "German", "English") instead of always "CC"
2. Verify button shows "CC" when no subtitle is selected
3. Verify menu shows all languages from `subtitles` array
4. Verify menu shows checkmark (✓) next to selected language
5. Verify selecting a language updates button label
6. Verify selecting "Off" updates button to "CC"
7. Test with 3+ subtitle languages
8. Test with HLS streams
9. Test button appears when subtitles are available

## Files to Modify

1. **`ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`**:

   - `addSubtitleSelectionButton`: Update to show current language instead of "CC"
   - Add: `updateSubtitleButtonLabel` method
   - Add: `subtitleButton` property to store button reference
   - Update: `selectSubtitleTrack` to call `updateSubtitleButtonLabel()`
   - Verify: `showSubtitleSelectionMenu` already iterates through all tracks (no changes needed)

2. **No changes needed to**:

   - `ios/Plugin/CapacitorVideoPlayerPlugin.swift` (API unchanged)
   - `ios/Plugin/Extensions/*.swift` (interface unchanged)
   - TypeScript definitions (API unchanged)

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