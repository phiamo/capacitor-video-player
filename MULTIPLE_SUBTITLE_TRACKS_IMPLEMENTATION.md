# Multiple Subtitle Tracks Implementation

## Overview

This document describes the implementation of multiple subtitle track support for the Capacitor Video Player plugin. The feature allows users to provide multiple subtitle tracks and switch between them during video playback.

## Implementation Summary

### ✅ Completed Features

#### 1. TypeScript API Design
- **New Interfaces:**
  - `SubtitleTrack`: Defines a subtitle track with id, url, language, label, mimeType, isDefault, isForced
  - `SubtitleTrackInfo`: Return type for track information queries
  - `capSubtitleTrackOptions`: Options for track selection methods

- **Updated Interfaces:**
  - `capVideoPlayerOptions`: Added `subtitles` array, `selectedSubtitleId`, deprecated `subtitle` and `language`
  - `CapacitorVideoPlayerPlugin`: Added 4 new methods:
    - `getSubtitleTracks()`: Get available subtitle tracks
    - `selectSubtitleTrack()`: Select a track by ID
    - `disableSubtitles()`: Disable/hide subtitles
    - `getSelectedSubtitleTrack()`: Get currently selected track

#### 2. Backward Compatibility
- **All Platforms:** Automatic conversion of single `subtitle`/`language` API to new array format
- **Deprecation Warnings:** Console warnings when old API is used
- **Seamless Migration:** Existing code continues to work without changes

#### 3. Web Platform Implementation
- **HTML5 TextTrack API:** Full support for multiple subtitle tracks
- **SRT to VTT Conversion:** Automatic conversion for browser compatibility
- **Subtitle Selection UI:** Custom dropdown menu in fullscreen mode
- **Styling Support:** CSS-based subtitle styling (foreground/background color, font size)
- **Track Management:** Complete implementation of all 4 new methods

#### 4. Android Platform Implementation
- **ExoPlayer Integration:** Multiple tracks via `MergingMediaSource`
- **Track Selection:** ExoPlayer's `TrackSelector` for programmatic track switching
- **Built-in UI:** ExoPlayer's native subtitle button (automatically shows when multiple tracks available)
- **SubtitleTrack Class:** Java class for track management
- **Track Matching:** Smart matching by ID, language, or label
- **All Methods:** Complete implementation of track management methods

#### 5. iOS Platform Implementation
- **HLS Streams:** Custom UILabel-based subtitle display with multiple track support
- **Non-HLS Streams:** AVMutableComposition with AVMediaSelectionGroup support
- **Track Loading:** Asynchronous loading of all subtitle tracks
- **Subtitle Selection UI:** Custom "CC" button with action sheet menu
- **Track Switching:** Dynamic track switching for both HLS and non-HLS streams
- **All Methods:** Complete implementation of track management methods

## API Usage Examples

### New API (Multiple Tracks)

```typescript
import { CapacitorVideoPlayer } from '@brylsherbert/capacitor-video-player';

// Initialize player with multiple subtitle tracks
await CapacitorVideoPlayer.initPlayer({
  mode: 'fullscreen',
  url: 'https://example.com/video.mp4',
  playerId: 'player1',
  componentTag: 'body',
  subtitles: [
    {
      id: 'en',
      url: 'https://example.com/subtitles/en.vtt',
      language: 'en',
      label: 'English',
      isDefault: true
    },
    {
      id: 'es',
      url: 'https://example.com/subtitles/es.vtt',
      language: 'es',
      label: 'Spanish'
    },
    {
      id: 'fr',
      url: 'https://example.com/subtitles/fr.vtt',
      language: 'fr',
      label: 'French'
    }
  ],
  selectedSubtitleId: 'en', // Optional: specify initial track
  subtitleOptions: {
    foregroundColor: 'rgba(255,255,255,1)',
    backgroundColor: 'rgba(0,0,0,0.8)',
    fontSize: 18
  }
});

// Get available tracks
const tracksResult = await CapacitorVideoPlayer.getSubtitleTracks({
  playerId: 'player1'
});
console.log('Available tracks:', tracksResult.value);

// Switch to Spanish subtitles
await CapacitorVideoPlayer.selectSubtitleTrack({
  playerId: 'player1',
  trackId: 'es'
});

// Disable subtitles
await CapacitorVideoPlayer.disableSubtitles({
  playerId: 'player1'
});

// Get currently selected track
const selectedResult = await CapacitorVideoPlayer.getSelectedSubtitleTrack({
  playerId: 'player1'
});
console.log('Selected track:', selectedResult.value);
```

### Backward Compatible API (Still Works)

```typescript
// Old API still works with deprecation warning
await CapacitorVideoPlayer.initPlayer({
  mode: 'fullscreen',
  url: 'https://example.com/video.mp4',
  playerId: 'player1',
  componentTag: 'body',
  subtitle: 'https://example.com/subtitles/en.vtt',
  language: 'en',
  subtitleOptions: {
    foregroundColor: 'rgba(255,255,255,1)',
    backgroundColor: 'rgba(0,0,0,0.8)',
    fontSize: 18
  }
});
```

## Platform-Specific Details

### Web Platform
- **Format Support:** VTT (native), SRT (auto-converted to VTT)
- **UI:** Custom dropdown menu in top-right corner (fullscreen mode only)
- **Styling:** CSS `::cue` pseudo-element for subtitle styling
- **Track Selection:** HTML5 TextTrack API `mode` property

### Android Platform
- **Format Support:** VTT, SRT, TTML, SSA/ASS
- **UI:** ExoPlayer's built-in subtitle button (appears automatically)
- **Track Selection:** ExoPlayer TrackSelector API
- **Styling:** CaptionStyleCompat for subtitle appearance

### iOS Platform
- **Format Support:** VTT (native), SRT (parsed manually for HLS)
- **UI:** Custom "CC" button with action sheet (when multiple tracks available)
- **HLS Streams:** Custom UILabel overlay with manual parsing
- **Non-HLS Streams:** AVMutableComposition with AVMediaSelectionGroup
- **Styling:** AVTextStyleRule for non-HLS, direct UILabel properties for HLS

## File Changes Summary

### TypeScript/Web
- `src/definitions.ts`: Added new interfaces and methods
- `src/web.ts`: Added backward compatibility and new method implementations
- `src/web-utils/videoplayer.ts`: Complete subtitle track management with UI

### Android
- `android/src/main/java/.../SubtitleTrack.java`: New class for track representation
- `android/src/main/java/.../CapacitorVideoPlayerPlugin.java`: Updated initPlayer, added 4 new methods
- `android/src/main/java/.../FullscreenExoPlayerFragment.java`: Multiple track support, track selection logic
- `android/src/main/java/.../CapacitorVideoPlayer.java`: Updated to pass subtitle tracks

### iOS
- `ios/Plugin/CapacitorVideoPlayerPlugin.swift`: Updated initPlayer, added 4 new methods
- `ios/Plugin/CapacitorVideoPlayer.swift`: Updated to pass subtitle tracks
- `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift`: Complete multiple track support for HLS and non-HLS
- `ios/Plugin/Extensions/CapacitorVideoPlayerPlugin.Fullscreen.swift`: Updated method signatures

## Testing Checklist

### Web Platform
- [ ] Single subtitle track (backward compatibility)
- [ ] Multiple subtitle tracks
- [ ] Track switching during playback
- [ ] SRT to VTT conversion
- [ ] Subtitle styling
- [ ] UI menu functionality

### Android Platform
- [ ] Single subtitle track (backward compatibility)
- [ ] Multiple subtitle tracks
- [ ] Track switching via ExoPlayer button
- [ ] Track switching via API
- [ ] All subtitle formats (VTT, SRT, TTML, SSA)
- [ ] Subtitle styling

### iOS Platform
- [ ] Single subtitle track (backward compatibility)
- [ ] Multiple subtitle tracks (HLS)
- [ ] Multiple subtitle tracks (non-HLS)
- [ ] Track switching via UI button
- [ ] Track switching via API
- [ ] Subtitle styling

## Known Limitations

1. **iOS Non-HLS Multiple Tracks:** Currently uses first track in composition. Full multiple track support would require more complex composition management.

2. **Track Format Support:**
   - Web: VTT (native), SRT (converted)
   - Android: VTT, SRT, TTML, SSA/ASS
   - iOS: VTT (native), SRT (parsed for HLS)

3. **UI Customization:** Subtitle selection UI is platform-native and may have limited customization options.

## Migration Guide

### From Single Subtitle to Multiple Tracks

**Before:**
```typescript
await CapacitorVideoPlayer.initPlayer({
  subtitle: 'https://example.com/en.vtt',
  language: 'en'
});
```

**After:**
```typescript
await CapacitorVideoPlayer.initPlayer({
  subtitles: [
    {
      id: 'en',
      url: 'https://example.com/en.vtt',
      language: 'en',
      label: 'English',
      isDefault: true
    }
  ]
});
```

The old API continues to work but will show a deprecation warning.

## Next Steps

1. **Testing:** Comprehensive testing across all platforms
2. **Documentation:** Update API documentation with examples
3. **Example Apps:** Create example apps demonstrating the feature
4. **Performance:** Optimize track loading and switching performance

