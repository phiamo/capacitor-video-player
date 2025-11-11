<!-- 3ab1702b-8578-4a79-9506-fa9e1cc2d9e1 0fe229a4-da91-4d5e-8080-1ffb2b4b6fc2 -->
# Multiple Subtitle Tracks Support - Design Plan

## Executive Summary

This plan extends the Capacitor Video Player plugin to support multiple subtitle tracks with user selection capabilities across all platforms (Android, iOS, Web). The implementation maintains backward compatibility with the existing single-subtitle API while adding new multi-track functionality.

## Current State Analysis

### Android

- Uses ExoPlayer with `MergingMediaSource` for single subtitle
- Has `TrackSelector` but not used for subtitle selection
- ExoPlayer natively supports multiple subtitle tracks
- `StyledPlayerView` has built-in subtitle button but limited customization

### iOS

- Non-HLS: Uses `AVMutableComposition` with single subtitle track
- HLS: Custom `UILabel` overlay with manual parsing (single track)
- AVPlayer supports `AVMediaSelectionGroup` for multiple tracks
- No native UI for subtitle selection

### Web

- Currently no subtitle support
- HTML5 video supports `textTracks` API natively
- Can use `<track>` elements or JavaScript TextTrack API

## Design Goals

1. **Backward Compatibility**: Existing single-subtitle API continues to work
2. **Multi-Platform**: Consistent API across Android, iOS, Web
3. **User Experience**: Native-feeling subtitle selection UI on each platform
4. **Performance**: Efficient track loading and switching
5. **Extensibility**: Easy to add more subtitle-related features

## API Design

### TypeScript Interface Changes

#### New Interfaces

```typescript
// Subtitle track definition
export interface SubtitleTrack {
  id: string;                    // Unique identifier
  url: string;                    // Subtitle file URL/path
  language: string;               // ISO 639-1 language code (e.g., "en", "es")
  label?: string;                 // Display label (e.g., "English", "Spanish")
  mimeType?: string;              // Optional MIME type override
  isDefault?: boolean;            // Default track to select
  isForced?: boolean;             // Forced subtitle track
}

// Updated options interface
export interface capVideoPlayerOptions {
  // ... existing options ...
  
  // DEPRECATED: Use subtitles array instead
  subtitle?: string;
  language?: string;
  
  // NEW: Multiple subtitle tracks
  subtitles?: SubtitleTrack[];    // Array of subtitle tracks
  
  // NEW: Initial selected subtitle track ID
  selectedSubtitleId?: string;    // ID of initially selected track
  
  // Shared styling for all tracks (can be overridden per-track later)
  subtitleOptions?: SubTitleOptions;
}

// Subtitle track information (returned by getSubtitleTracks)
export interface SubtitleTrackInfo {
  id: string;
  language: string;
  label: string;
  isSelected: boolean;
  isAvailable: boolean;
}

// New methods
export interface CapacitorVideoPlayerPlugin {
  // ... existing methods ...
  
  /**
   * Get available subtitle tracks for a player
   */
  getSubtitleTracks(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  
  /**
   * Select a subtitle track by ID
   */
  selectSubtitleTrack(options: capSubtitleTrackOptions): Promise<capVideoPlayerResult>;
  
  /**
   * Disable subtitles (hide current track)
   */
  disableSubtitles(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  
  /**
   * Get currently selected subtitle track
   */
  getSelectedSubtitleTrack(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
}

export interface capSubtitleTrackOptions {
  playerId?: string;
  trackId: string;                // ID of track to select, or null to disable
}
```

#### Backward Compatibility Strategy

- Keep `subtitle` and `language` options working
- Internally convert single subtitle to array format
- Log deprecation warning when using old API
- Migration path: `{ subtitle: "url", language: "en" }` → `{ subtitles: [{ id: "en", url: "url", language: "en" }] }`

## Platform-Specific Implementation

### Android Implementation

#### Architecture Changes

1. **Track Management**

            - Store array of `SubtitleTrack` objects
            - Create `MediaItem.SubtitleConfiguration` for each track
            - Use `MergingMediaSource` with multiple subtitle sources
            - Track selection via ExoPlayer's `TrackSelector`

2. **Media Source Building**
   ```java
   private MediaSource buildMediaSourceWithSubtitles(Uri uri, List<SubtitleTrack> tracks) {
       MediaSource[] mediaSources = new MediaSource[tracks.size() + 1];
       mediaSources[0] = buildVideoMediaSource(uri);
       
       for (int i = 0; i < tracks.size(); i++) {
           SubtitleTrack track = tracks.get(i);
           MediaItem.SubtitleConfiguration subConfig = createSubtitleConfig(track);
           SingleSampleMediaSource subtitleSource = new SingleSampleMediaSource.Factory(dataSourceFactory)
               .createMediaSource(subConfig, C.TIME_UNSET);
           mediaSources[i + 1] = subtitleSource;
       }
       
       return new MergingMediaSource(mediaSources);
   }
   ```

3. **Track Selection**
   ```java
   public void selectSubtitleTrack(String trackId) {
       if (player == null || trackSelector == null) return;
       
       TrackGroupArray trackGroups = player.getCurrentTrackGroups();
       for (int i = 0; i < trackGroups.length; i++) {
           TrackGroup group = trackGroups.get(i);
           for (int j = 0; j < group.length; j++) {
               Format format = group.getFormat(j);
               if (format.id != null && format.id.equals(trackId)) {
                   DefaultTrackSelector.Parameters params = trackSelector.getParameters()
                       .buildUpon()
                       .setRendererDisabled(C.TRACK_TYPE_TEXT, false)
                       .setSelectionOverride(i, trackSelector.getParameters().build(), 
                           new SelectionOverride(0, j))
                       .build();
                   trackSelector.setParameters(params);
                   return;
               }
           }
       }
   }
   ```

4. **UI Implementation**

            - **Option 1**: Extend ExoPlayer's built-in subtitle button
                    - Custom `SubtitleView` with track selection dialog
                    - Override subtitle button click handler
            - **Option 2**: Custom subtitle selection UI
                    - Add subtitle button to player controls
                    - Show bottom sheet/dialog with track list
                    - Material Design components for consistency

5. **Track Information Retrieval**
   ```java
   public List<SubtitleTrackInfo> getSubtitleTracks() {
       List<SubtitleTrackInfo> tracks = new ArrayList<>();
       if (player == null) return tracks;
       
       TrackGroupArray trackGroups = player.getCurrentTrackGroups();
       for (int i = 0; i < trackGroups.length; i++) {
           TrackGroup group = trackGroups.get(i);
           if (group.getType() == C.TRACK_TYPE_TEXT) {
               for (int j = 0; j < group.length; j++) {
                   Format format = group.getFormat(j);
                   SubtitleTrackInfo info = new SubtitleTrackInfo();
                   info.id = format.id;
                   info.language = format.language;
                   info.label = format.label != null ? format.label : format.language;
                   info.isSelected = isTrackSelected(i, j);
                   info.isAvailable = true;
                   tracks.add(info);
               }
           }
       }
       return tracks;
   }
   ```


#### Files to Modify

- `CapacitorVideoPlayerPlugin.java`: Add new methods, handle subtitle array
- `FullscreenExoPlayerFragment.java`: 
        - Update `getSubTitle()` to handle multiple tracks
        - Add track selection methods
        - Add UI components for track selection
- Create `SubtitleTrackManager.java`: Track management utility class

### iOS Implementation

#### Architecture Changes

1. **Non-HLS Videos (AVMutableComposition)**

            - Create composition with multiple subtitle tracks
            - Use `AVMediaSelectionGroup` for track selection
            - Store track metadata for UI

2. **HLS Videos (Custom UILabel)**

            - Load and parse multiple subtitle files
            - Store parsed subtitles in dictionary keyed by track ID
            - Switch active subtitle track by changing displayed label content
            - Maintain separate time observers per track (or unified with track switching)

3. **Track Selection Implementation**
   ```swift
   func selectSubtitleTrack(trackId: String?) {
       if isHLSStream(url: self._url) {
           // HLS: Switch custom subtitle
           self._activeSubtitleTrackId = trackId
           // Update time observer to use selected track
       } else {
           // Non-HLS: Use AVMediaSelectionGroup
           guard let playerItem = self.playerItem else { return }
           guard let mediaSelectionGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return }
           
           if let trackId = trackId {
               let options = mediaSelectionGroup.options.filter { option in
                   // Match by track ID or language
                   return option.extendedLanguageTag == trackId || 
                          option.locale?.languageCode == trackId
               }
               if let option = options.first {
                   playerItem.select(option, in: mediaSelectionGroup)
               }
           } else {
               // Disable subtitles
               playerItem.select(nil, in: mediaSelectionGroup)
           }
       }
   }
   ```

4. **UI Implementation**

            - **Option 1**: Use AVPlayerViewController's built-in subtitle menu
                    - Limited customization
                    - Works for non-HLS only
            - **Option 2**: Custom subtitle selection UI
                    - Add subtitle button to player controls
                    - Show action sheet or popover with track list
                    - iOS-style UI components (UIAlertController or custom view)

5. **Multiple Subtitle Loading (HLS)**
   ```swift
   private var subtitleTracks: [String: [(start: Double, end: Double, text: String)]] = [:]
   private var _activeSubtitleTrackId: String?
   
   private func loadMultipleSubtitles(tracks: [SubtitleTrack]) {
       for track in tracks {
           if let url = resolveSubtitleURL(track.url) {
               do {
                   let content = try String(contentsOf: url, encoding: .utf8)
                   let isVTT = content.hasPrefix("WEBVTT")
                   let parsed = isVTT ? parseVTTContent(content) : parseSRTContent(content)
                   subtitleTracks[track.id] = parsed
               } catch {
                   print("Failed to load subtitle track \(track.id): \(error)")
               }
           }
       }
   }
   ```


#### Files to Modify

- `CapacitorVideoPlayerPlugin.swift`: Add new methods, handle subtitle array
- `FullScreenVideoPlayerView.swift`:
        - Update initialization to handle multiple tracks
        - Add track selection methods
        - Update HLS subtitle rendering to support multiple tracks
        - Add UI components for track selection
- Create `SubtitleTrackManager.swift`: Track management utility

### Web Implementation

#### Architecture

1. **HTML5 TextTrack API**

            - Use native `<track>` elements or JavaScript TextTrack API
            - Support for WebVTT format natively
            - SRT conversion to VTT if needed

2. **Implementation**
   ```typescript
   private async initializeSubtitles(tracks: SubtitleTrack[]) {
       if (!this.videoEl) return;
       
       for (const track of tracks) {
           const trackElement = document.createElement('track');
           trackElement.kind = 'subtitles';
           trackElement.src = track.url;
           trackElement.srclang = track.language;
           trackElement.label = track.label || track.language;
           trackElement.default = track.isDefault || false;
           
           this.videoEl.appendChild(trackElement);
       }
       
       // Wait for tracks to load
       await this.waitForTracksLoaded();
       
       // Select initial track
       if (this.selectedTrackId) {
           this.selectSubtitleTrack(this.selectedTrackId);
       }
   }
   
   private selectSubtitleTrack(trackId: string | null) {
       if (!this.videoEl) return;
       
       const tracks = Array.from(this.videoEl.textTracks);
       
       for (const track of tracks) {
           track.mode = (track.id === trackId || track.language === trackId) 
               ? 'showing' 
               : 'hidden';
       }
   }
   ```

3. **UI Implementation**

            - Custom subtitle selection menu
            - Overlay button on video player
            - Dropdown or modal with track list
            - Styled to match player design

4. **SRT Support**

            - Convert SRT to VTT format on-the-fly
            - Use Blob URL for converted content
            - Or use JavaScript SRT parser library

#### Files to Modify

- `src/web.ts`: Add subtitle initialization and track selection
- `src/web-utils/videoplayer.ts`: 
        - Add subtitle track management
        - Add UI for track selection
        - Handle SRT to VTT conversion if needed

## User Experience Design

### Android UX

1. **Subtitle Button**

            - Located in ExoPlayer's control bar
            - Shows current subtitle language or "Off"
            - Tap opens subtitle selection dialog

2. **Selection Dialog**

            - Bottom sheet with track list
            - Each item shows: Language label, track ID, selected indicator
            - "Off" option at top to disable subtitles
            - Material Design styling
            - Smooth animations

3. **Visual Feedback**

            - Selected track highlighted
            - Checkmark icon for active track
            - Immediate subtitle update on selection

### iOS UX

1. **Subtitle Button**

            - Custom button in player controls overlay
            - Shows current language or "CC" icon
            - Tap opens action sheet

2. **Selection Interface**

            - Action sheet (iOS style) with track options
            - Each option shows language label
            - Checkmark for selected track
            - "Off" option to disable
            - Dismisses on selection

3. **Visual Feedback**

            - Immediate subtitle change
            - Smooth transitions
            - Native iOS feel

### Web UX

1. **Subtitle Control**

            - Custom button in player controls
            - Dropdown menu or modal overlay
            - Shows current selection

2. **Selection Interface**

            - Dropdown list or modal dialog
            - Track options with language labels
            - Radio button or checkmark for selection
            - "Off" option available

3. **Styling**

            - Matches player theme
            - Responsive design
            - Accessible (keyboard navigation, ARIA labels)

## Implementation Phases

### Phase 1: API and Type Definitions

- Update TypeScript interfaces
- Add new method signatures
- Implement backward compatibility layer
- Update documentation

### Phase 2: Android Implementation

- Modify media source building for multiple tracks
- Implement track selection logic
- Add track information retrieval
- Create subtitle selection UI
- Testing and refinement

### Phase 3: iOS Implementation

- Update non-HLS subtitle handling
- Update HLS subtitle handling for multiple tracks
- Implement track selection
- Create subtitle selection UI
- Testing and refinement

### Phase 4: Web Implementation

- Implement HTML5 TextTrack support
- Add subtitle track management
- Create subtitle selection UI
- SRT to VTT conversion if needed
- Testing and refinement

### Phase 5: Integration and Testing

- Cross-platform testing
- Backward compatibility verification
- Performance optimization
- Documentation updates
- Example apps update

## Technical Considerations

### Performance

- Lazy loading: Load subtitle files only when needed
- Caching: Cache parsed subtitle content
- Memory management: Clean up unused tracks
- Network: Efficient subtitle file loading

### Error Handling

- Invalid track IDs: Graceful fallback
- Missing files: Skip track, show warning
- Parse errors: Log error, continue with other tracks
- Network failures: Retry logic or skip track

### Accessibility

- Screen reader support for track selection
- Keyboard navigation
- High contrast mode support
- Subtitle styling accessibility

### Testing Requirements

- Unit tests for track management
- Integration tests for each platform
- UI/UX testing on real devices
- Backward compatibility tests
- Performance tests with many tracks

## Migration Guide

### For Existing Users

**Old API (still works):**

```typescript
await CapacitorVideoPlayer.initPlayer({
  subtitle: 'https://example.com/en.vtt',
  language: 'en'
});
```

**New API (recommended):**

```typescript
await CapacitorVideoPlayer.initPlayer({
  subtitles: [
    { id: 'en', url: 'https://example.com/en.vtt', language: 'en', label: 'English' },
    { id: 'es', url: 'https://example.com/es.vtt', language: 'es', label: 'Spanish' }
  ],
  selectedSubtitleId: 'en'
});
```

## Success Criteria

1. ✅ Support for multiple subtitle tracks on all platforms
2. ✅ User-friendly subtitle selection UI on each platform
3. ✅ Backward compatibility maintained
4. ✅ Performance: Track switching < 100ms
5. ✅ All existing tests pass
6. ✅ Documentation complete
7. ✅ Example apps updated

## Risks and Mitigations

| Risk | Impact | Mitigation |

|------|--------|------------|

| Breaking existing functionality | High | Extensive backward compatibility testing |

| Performance degradation | Medium | Lazy loading, caching, optimization |

| Platform-specific bugs | Medium | Platform-specific testing, gradual rollout |

| UI inconsistency | Low | Design guidelines, platform-specific UX |

| Web browser compatibility | Medium | Feature detection, polyfills if needed |

## Future Enhancements

- Subtitle search functionality
- Custom subtitle styling per track
- Subtitle download/offline support
- Auto-translation integration
- Subtitle editing capabilities
- Embedded subtitle support (from video container)

### To-dos

- [ ] Design and implement TypeScript interfaces for multiple subtitle tracks (SubtitleTrack, updated capVideoPlayerOptions, new methods)
- [ ] Implement backward compatibility layer to convert single subtitle API to array format
- [ ] Modify Android media source building to support multiple subtitle tracks using MergingMediaSource
- [ ] Implement ExoPlayer track selection logic for subtitle tracks in Android
- [ ] Create subtitle selection UI for Android (bottom sheet/dialog with track list)
- [ ] Update iOS non-HLS subtitle handling to support multiple tracks via AVMutableComposition and AVMediaSelectionGroup
- [ ] Update iOS HLS subtitle handling to support multiple tracks with custom UILabel switching
- [ ] Create subtitle selection UI for iOS (action sheet or custom popover)
- [ ] Implement HTML5 TextTrack API support for multiple subtitle tracks on Web platform
- [ ] Create subtitle selection UI for Web (dropdown or modal with track list)
- [ ] Comprehensive testing across all platforms including backward compatibility, performance, and UI/UX
- [ ] Update API documentation, create migration guide, and update example apps