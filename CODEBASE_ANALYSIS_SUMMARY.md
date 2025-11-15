# Capacitor Video Player Plugin - Codebase Analysis Summary

## Executive Summary

**@brylsherbert/capacitor-video-player** (v7.0.32) is a Capacitor 7 plugin providing cross-platform video playback with native implementations for iOS (AVPlayer), Android (ExoPlayer), and Web (HTML5 + HLS.js). The plugin supports fullscreen playback on all platforms and embedded playback on Web/Electron.

## Architecture Overview

### Core Architecture Pattern

The plugin follows the standard Capacitor plugin architecture:

```
TypeScript Interface Layer (src/definitions.ts, src/index.ts)
    ↓
Platform Implementations:
    ├── Web (src/web.ts, src/web-utils/videoplayer.ts)
    ├── iOS (ios/Plugin/CapacitorVideoPlayerPlugin.swift)
    └── Android (android/src/main/java/.../CapacitorVideoPlayerPlugin.java)
```

### Key Architectural Components

1. **Plugin Registration** (`src/index.ts`)
   - Registers plugin with Capacitor using `registerPlugin()`
   - Conditionally loads web implementation
   - Exports TypeScript definitions and plugin instance

2. **Type Definitions** (`src/definitions.ts`)
   - Defines `CapacitorVideoPlayerPlugin` interface with all methods
   - Defines option interfaces (capVideoPlayerOptions, capVideoPlayerIdOptions, etc.)
   - Defines result interfaces (capVideoPlayerResult)
   - Defines listener interfaces (capVideoListener, capExitListener)

3. **Web Implementation** (`src/web.ts`)
   - `CapacitorVideoPlayerWeb` class extending `WebPlugin`
   - Manages multiple players via `_players` object keyed by `playerId`
   - Handles DOM manipulation and container creation
   - Dispatches events via Capacitor's `notifyListeners()`

4. **Web Video Player** (`src/web-utils/videoplayer.ts`)
   - `VideoPlayer` class managing HTML5 video element
   - Handles HLS.js integration for streaming
   - Manages fullscreen and Picture-in-Picture modes
   - Dispatches custom DOM events that are caught by web plugin

5. **Native Implementations**
   - **iOS**: AVPlayerViewController with Swift extensions for features
   - **Android**: ExoPlayer in Fragment with Java implementation

## Player Management System

### PlayerId System

The plugin uses a `playerId` system to manage multiple concurrent players:

- **Web**: Players stored in `_players` object: `this._players[playerId] = new VideoPlayer(...)`
- **Fullscreen mode**: Default `playerId` = "fullscreen" (overrides provided ID)
- **Embedded mode**: Uses provided `playerId` to allow multiple embedded players
- **Native**: Each platform maintains player instances keyed by `playerId`

### Player Lifecycle

1. **Initialization** (`initPlayer`)
   - Validates options (mode, url, playerId, componentTag)
   - Resolves video source path (web/asset/internal)
   - Creates player instance (VideoPlayer/ExoPlayer/AVPlayer)
   - Sets up event listeners
   - Returns success/failure result

2. **Ready State**
   - Web: `videoEl.oncanplay` event → dispatches `videoPlayerReady`
   - Android: ExoPlayer listener → NotificationCenter → `jeepCapVideoPlayerReady`
   - iOS: AVPlayer status observer → NotificationCenter → `jeepCapVideoPlayerReady`

3. **Playback Control**
   - `play()` / `pause()` methods control playback state
   - `getCurrentTime()` / `setCurrentTime()` for seeking
   - `getVolume()` / `setVolume()` for audio control
   - `getRate()` / `setRate()` for playback speed

4. **Exit/Cleanup**
   - `exitPlayer()` or `exitFullScreen()` methods
   - Web: Removes DOM elements, clears player references
   - Native: Dismisses fragments/view controllers, releases resources

## Event System

### Event Flow Architecture

**Web Platform:**
```
VideoPlayer._createEvent() 
  → document.dispatchEvent(CustomEvent)
  → CapacitorVideoPlayerWeb.addListeners() catches event
  → this.notifyListeners('jeepCapVideoPlayerPlay', data)
  → JavaScript listeners receive event
```

**Android Platform:**
```
FullscreenExoPlayerFragment (ExoPlayer listener)
  → NotificationCenter.defaultCenter().postNotification()
  → CapacitorVideoPlayerPlugin.AddObserversToNotificationCenter()
  → MyRunnable.run() creates JSObject
  → notifyListeners('jeepCapVideoPlayerPlay', data)
  → JavaScript listeners receive event
```

**iOS Platform:**
```
FullScreenVideoPlayerView (AVPlayer observers)
  → NotificationCenter.default.post()
  → CapacitorVideoPlayerPlugin observers (@objc methods)
  → notifyListeners('jeepCapVideoPlayerPlay', data)
  → JavaScript listeners receive event
```

### Available Events

1. **jeepCapVideoPlayerReady** - Emitted when video is ready to play
   - Data: `{ playerId: string, currentTime: number }`

2. **jeepCapVideoPlayerPlay** - Emitted when playback starts
   - Data: `{ playerId: string, currentTime: number }`

3. **jeepCapVideoPlayerPause** - Emitted when playback pauses
   - Data: `{ playerId: string, currentTime: number }`

4. **jeepCapVideoPlayerEnded** - Emitted when video ends
   - Data: `{ playerId: string, currentTime: number }`

5. **jeepCapVideoPlayerExit** - Emitted when player is dismissed
   - Data: `{ dismiss: boolean, currentTime: number }`

## Video Source Resolution

### Source Types Supported

1. **Web URLs** (`http://` or `https://`)
   - Direct streaming from internet
   - Supports HLS (.m3u8), MP4, and other formats
   - Web: Direct URL assignment to video element
   - Native: URL passed to ExoPlayer/AVPlayer

2. **Assets** (`public/assets/...` or `assets/...`)
   - **iOS**: `Bundle.main.resourceURL.appendingPathComponent(filePath)`
   - **Android**: `file:///android_asset/` + path
   - **Web**: Relative path from app root

3. **Application Files** (`application/files/...`)
   - **iOS**: `Documents/files/` directory
   - **Android**: `context.getFilesDir() + "/files/"`
   - Files stored in app's private storage

4. **Device Media** (`internal`)
   - **iOS/Android**: Opens native video picker
   - User selects video from device gallery
   - Requires media permissions

5. **DCIM/File Paths** (`file:///...`)
   - Direct file system paths
   - Platform-specific path resolution
   - Requires appropriate permissions

### Path Resolution Implementation

**Android** (`FilesUtils.java`):
```java
public String getFilePath(String url) {
    if (url.startsWith("file:///")) return url;
    if (url.startsWith("http")) return url;
    if (url.startsWith("application")) {
        return context.getFilesDir() + "/" + url.substring(...);
    }
    if (url.contains("assets")) {
        return "file:///android_asset/" + url;
    }
    return null;
}
```

**iOS** (`CapacitorVideoPlayerPlugin.File.swift`):
- Checks URL prefix to determine source type
- Resolves paths using `NSSearchPathForDirectoriesInDomains`
- Validates file existence before returning URL

## Platform-Specific Implementations

### Web Implementation Details

**Key Files:**
- `src/web.ts` - Main web plugin class
- `src/web-utils/videoplayer.ts` - VideoPlayer class
- `src/web-utils/video-types.ts` - MIME type detection

**Features:**
- HTML5 `<video>` element as base
- HLS.js for HLS streaming support
- Fullscreen API integration
- Picture-in-Picture support
- Custom event system for player state
- DOM manipulation for container creation
- Shadow DOM support for web components

**Player Modes:**
- **Fullscreen**: Creates overlay with z-index 99995, enters fullscreen API
- **Embedded**: Creates sized container within component, z-index 2

### Android Implementation Details

**Key Files:**
- `CapacitorVideoPlayerPlugin.java` - Main plugin class
- `FullscreenExoPlayerFragment.java` - ExoPlayer fragment
- `CapacitorVideoPlayer.java` - Factory for creating fragments
- `FilesUtils.java` - File path resolution
- `NotificationCenter.java` - Event notification system

**Features:**
- ExoPlayer 2.x for video playback
- Support for HLS, DASH, SmoothStreaming
- Chromecast integration (optional)
- Picture-in-Picture mode
- Background playback with MediaSession
- Subtitle support (WebVTT, TTML, SRT, SSA/ASS)
- Custom ExoPlayer UI with StyledPlayerView

**Fragment Management:**
- Uses FragmentManager to add/remove fullscreen fragment
- FrameLayout container (ID: 256) for fragment hosting
- Lifecycle management tied to fragment lifecycle

### iOS Implementation Details

**Key Files:**
- `CapacitorVideoPlayerPlugin.swift` - Main plugin class
- `FullScreenVideoPlayerView.swift` - AVPlayer view controller wrapper
- `Extensions/*.swift` - Feature-specific extensions
  - `File.swift` - File path resolution
  - `Notifications.swift` - Event handling
  - `Observers.swift` - AVPlayer observers
  - `Fullscreen.swift` - Fullscreen presentation
  - `AVPlayerViewController.swift` - Player controller extensions

**Features:**
- AVPlayer/AVPlayerViewController for playback
- HLS streaming support
- Picture-in-Picture (iOS 14+)
- Background playback with AVAudioSession
- Subtitle support (WebVTT via custom implementation)
- Orientation locking (all/portrait/landscape)
- Custom player view controllers for orientation control

**View Controller Management:**
- Presents AVPlayerViewController modally for fullscreen
- Custom view controllers for orientation control:
  - `AllOrientationAVPlayerController`
  - `LandscapeAVPlayerController`
  - `PortraitAVPlayerController`

## API Methods Reference

### Core Methods

1. **initPlayer(options)** - Initialize a video player
   - Required: `mode`, `url`, `playerId`, `componentTag` (web)
   - Optional: `rate`, `exitOnEnd`, `loopOnEnd`, `pipEnabled`, `bkmodeEnabled`, `showControls`, `displayMode`, `subtitle`, `language`, `headers`, `title`, `smallTitle`, `accentColor`, `chromecast`, `artwork`

2. **play(options)** - Start playback
   - Options: `{ playerId: string }`

3. **pause(options)** - Pause playback
   - Options: `{ playerId: string }`

4. **getCurrentTime(options)** - Get current playback position
   - Returns: `{ result: boolean, value: number }`

5. **setCurrentTime(options)** - Seek to position
   - Options: `{ playerId: string, seektime: number }`

6. **getDuration(options)** - Get video duration
   - Returns: `{ result: boolean, value: number }`

7. **getVolume(options)** / **setVolume(options)** - Audio control
   - Volume range: 0.0 - 1.0

8. **getMuted(options)** / **setMuted(options)** - Mute control

9. **getRate(options)** / **setRate(options)** - Playback speed
   - Supported rates: [0.25, 0.5, 0.75, 1.0, 2.0, 4.0]

10. **stopAllPlayers()** - Stop all active players

11. **exitPlayer()** - Exit current player (Android only)

12. **exitFullScreen(options)** - Exit fullscreen mode
    - Options: `{ playerId: string }`

## Extension Points

### Adding New Methods

1. **Define in TypeScript Interface** (`src/definitions.ts`):
   ```typescript
   export interface CapacitorVideoPlayerPlugin {
     newMethod(options: NewMethodOptions): Promise<capVideoPlayerResult>;
   }
   ```

2. **Implement in Web** (`src/web.ts`):
   ```typescript
   async newMethod(options: NewMethodOptions): Promise<capVideoPlayerResult> {
     // Web implementation
     return Promise.resolve({ result: true, method: 'newMethod' });
   }
   ```

3. **Implement in Native Platforms**:
   - **Android**: Add `@PluginMethod` annotated method in `CapacitorVideoPlayerPlugin.java`
   - **iOS**: Add `@objc func` method in `CapacitorVideoPlayerPlugin.swift`

### Adding New Options

Extend `capVideoPlayerOptions` interface:
```typescript
export interface capVideoPlayerOptions {
  // ... existing options
  newOption?: string;
}
```

Then handle in `initPlayer` implementations across all platforms.

### Adding New Events

1. **Define Listener Interface** (`src/definitions.ts`):
   ```typescript
   export interface capNewEventData {
     playerId?: string;
     customData?: any;
   }
   ```

2. **Dispatch in Web** (`src/web-utils/videoplayer.ts`):
   ```typescript
   this._createEvent('NewEvent', this._playerId);
   ```

3. **Dispatch in Native**:
   - **Android**: Post to NotificationCenter, observer calls `notifyListeners()`
   - **iOS**: Post to NotificationCenter, `@objc` method calls `notifyListeners()`

### Platform-Specific Features

- **Android-only**: Chromecast, custom ExoPlayer UI controls
- **iOS-only**: Custom subtitle implementation with HLS support
- **Web-only**: Embedded mode, HLS.js integration

## Build System

### TypeScript Compilation
- `tsconfig.json` compiles to `dist/esm/`
- Target: ES2017
- Module: ESNext
- Strict mode enabled

### Bundling
- `rollup.config.js` creates:
  - `dist/plugin.js` - IIFE format for browser
  - `dist/plugin.cjs.js` - CommonJS format
- External dependencies: `@capacitor/core`, `hls.js`

### Native Builds
- **iOS**: CocoaPods via `BrylsherbertCapacitorVideoPlayer.podspec`
- **Android**: Gradle build system

## Dependencies

### Core Dependencies
- `@capacitor/core` ^7.0.0 (peer dependency)
- `hls.js` ^1.4.0 (peer dependency, for web HLS support)

### Native Dependencies
- **Android**: ExoPlayer 2.x, Google Cast Framework
- **iOS**: AVFoundation, AVKit (system frameworks)

## Common Extension Scenarios

### 1. Adding Playlist Support
- Extend `capVideoPlayerOptions` with `playlist?: string[]`
- Modify `initPlayer` to handle array of URLs
- Add `nextVideo()` / `previousVideo()` methods
- Update player lifecycle to handle transitions

### 2. Adding Quality Selection
- Expose ExoPlayer track selector (Android)
- Expose AVPlayer variant selection (iOS)
- Add `getAvailableQualities()` method
- Add `setQuality()` method

### 3. Adding Analytics/Tracking
- Hook into existing event system
- Add tracking calls in event handlers
- Extend result objects with analytics data

### 4. Custom UI Overlays
- **Web**: Modify `VideoPlayer` class to add custom DOM elements
- **Android**: Extend `StyledPlayerView` or add custom views
- **iOS**: Add subviews to `AVPlayerViewController` or use custom overlay

### 5. Advanced Subtitle Features
- Multiple subtitle tracks
- Subtitle styling options (already partially supported)
- Subtitle search/filter
- Custom subtitle rendering

## Key Insights for Extension Development

### 1. Player Management
- Always use `playerId` to identify players
- Web stores players in `_players` object
- Native platforms maintain single fullscreen player instance
- Multiple embedded players possible on web only

### 2. Event System
- Web uses DOM events → plugin listeners → Capacitor listeners
- Native uses NotificationCenter → plugin observers → Capacitor listeners
- Always include `playerId` in event data
- Use `retainUntilConsumed: true` for native events

### 3. Source Resolution
- Path resolution is platform-specific
- Always validate file existence for local files
- Handle permissions for device media access
- URL encoding may be needed for web sources

### 4. Lifecycle Management
- Initialize → Ready → Play → Pause/End → Exit
- Clean up resources on exit
- Handle background/foreground transitions
- Manage audio session (iOS) and media session (Android)

### 5. Platform Differences
- **Web**: DOM-based, event-driven, supports embedded mode
- **Android**: Fragment-based, ExoPlayer, Chromecast support
- **iOS**: ViewController-based, AVPlayer, orientation control

## Testing Considerations

### Web Testing
- Test in multiple browsers (Chrome, Safari, Firefox)
- Test HLS streaming vs MP4
- Test fullscreen API compatibility
- Test Picture-in-Picture support

### Native Testing
- Test on physical devices (not just simulators)
- Test permission flows
- Test background playback
- Test orientation changes
- Test Picture-in-Picture mode

## File Organization Reference

### TypeScript Source
- `src/index.ts` - Plugin registration
- `src/definitions.ts` - Type definitions
- `src/web.ts` - Web implementation
- `src/web-utils/videoplayer.ts` - Web video player class
- `src/web-utils/video-types.ts` - Video type detection

### Android Source
- `android/src/main/java/.../CapacitorVideoPlayerPlugin.java` - Main plugin
- `android/src/main/java/.../FullscreenExoPlayerFragment.java` - Player fragment
- `android/src/main/java/.../CapacitorVideoPlayer.java` - Factory class
- `android/src/main/java/.../Utilities/` - Utility classes
- `android/src/main/java/.../Notifications/` - Notification system
- `android/src/main/java/.../PickerVideo/` - Video picker

### iOS Source
- `ios/Plugin/CapacitorVideoPlayerPlugin.swift` - Main plugin
- `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift` - Player view
- `ios/Plugin/Extensions/` - Feature extensions
- `ios/Plugin/VideoPicker/` - Video picker

### Documentation
- `docs/API.md` - API documentation
- `docs/Usage_*.md` - Usage examples
- `readme.md` - Project overview

## Questions Answered

### How are multiple players managed?
- Web: `_players` object keyed by `playerId`, supports multiple embedded players
- Native: Single fullscreen player instance, identified by `playerId` but only one active at a time

### How do events flow from native to JavaScript?
- Native platforms use NotificationCenter pattern
- Observers in plugin class catch notifications
- `notifyListeners()` bridges to JavaScript
- JavaScript code uses `addListener()` to subscribe

### How are video sources resolved?
- Platform-specific utility classes handle path resolution
- Checks URL prefix to determine source type
- Resolves to native file paths or URLs
- Validates file existence for local files

### What's the player lifecycle?
1. `initPlayer()` - Create and configure player
2. Ready event - Player loaded and ready
3. Play/Pause - Control playback
4. End event - Video finished
5. Exit - Cleanup and dismiss

### How are platform differences abstracted?
- Common TypeScript interface defines API
- Platform-specific implementations handle differences
- Options may have platform-specific behavior
- Some methods/platforms may not support all features

### What are the extension points?
- Add methods to interface and all implementations
- Extend option interfaces for new configuration
- Add events via notification system
- Platform-specific features in native code only

## Conclusion

This plugin provides a solid foundation for cross-platform video playback with clear separation between interface and implementation. The event-driven architecture and player management system make it extensible, while platform-specific optimizations ensure native performance. When extending, follow the established patterns: define in TypeScript, implement across all platforms, and use the notification system for events.



