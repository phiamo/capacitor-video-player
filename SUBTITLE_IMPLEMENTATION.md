# Subtitle Implementation Documentation

## Overview

The Capacitor Video Player plugin provides subtitle support for iOS and Android platforms. Subtitles are **not supported on Web/Electron platforms**. This document provides a comprehensive overview of how subtitles are implemented, configured, and displayed across the supported platforms.

## Platform Support

| Platform | Subtitle Support | Supported Formats |
|----------|-----------------|-------------------|
| **Android** | ✅ Full Support | WebVTT (.vtt), TTML/SMPTE (.ttml, .dfxp, .xml), SubRip (.srt), SubStationAlpha (.ssa, .ass) |
| **iOS** | ✅ Full Support | WebVTT (.vtt), SubRip (.srt) - converted to VTT |
| **Web/Electron** | ❌ Not Supported | N/A |

## API Configuration

### Subtitle Options in initPlayer

Subtitles are configured through the `initPlayer` method using the following options:

```typescript
interface capVideoPlayerOptions {
  subtitle?: string;           // URL/path to subtitle file
  language?: string;           // Language code (ISO 639-1)
  subtitleOptions?: SubTitleOptions;  // Styling options
}

interface SubTitleOptions {
  foregroundColor?: string;    // RGBA color (default: "rgba(255,255,255,1)")
  backgroundColor?: string;    // RGBA color (default: "rgba(0,0,0,1)")
  fontSize?: number;          // Font size in pixels (default: 16)
}
```

### Example Usage

```typescript
await CapacitorVideoPlayer.initPlayer({
  mode: 'fullscreen',
  url: 'https://example.com/video.mp4',
  playerId: 'player1',
  subtitle: 'https://example.com/subtitles.vtt',
  language: 'en',
  subtitleOptions: {
    foregroundColor: 'rgba(255,255,255,1)',
    backgroundColor: 'rgba(0,0,0,0.7)',
    fontSize: 18
  }
});
```

## Subtitle Source Resolution

Subtitles can be loaded from the same source types as videos:

### 1. Web URLs
- **Format**: `http://...` or `https://...`
- **Example**: `https://example.com/subtitles.vtt`
- **Platforms**: Android, iOS

### 2. Application Assets
- **Android**: `"public/assets/video/subtitles.srt"`
- **iOS**: `"public/assets/video/subtitles.vtt"`
- **Path Resolution**: 
  - Android: `file:///android_asset/` + path
  - iOS: `Bundle.main.resourceURL.appendingPathComponent(path)`

### 3. Application Files
- **Format**: `application/files/subtitles.vtt`
- **Android Path**: `/data/user/0/YOUR_APP_PACKAGE/files/subtitles.vtt`
- **iOS Path**: `/data/Containers/Data/Applications/YOUR_APP/Documents/files/subtitles.vtt`

### 4. Device Media (Internal)
- **Format**: `internal` (uses native picker)
- **Platforms**: Android, iOS
- **Note**: Requires media permissions

## Android Implementation

### Architecture

Android uses **ExoPlayer** with native subtitle rendering support. Subtitles are integrated using ExoPlayer's `MergingMediaSource` to combine video and subtitle tracks.

### Key Components

1. **Subtitle Configuration** (`FullscreenExoPlayerFragment.java`)
   - Subtitle URI parsing and validation
   - MIME type detection based on file extension
   - Language code processing

2. **Media Source Merging** (`getSubTitle()` method)
   - Creates `MediaItem.SubtitleConfiguration` with subtitle metadata
   - Uses `SingleSampleMediaSource` for subtitle track
   - Merges with video using `MergingMediaSource`

3. **Subtitle Styling** (`setSubtitle()` method)
   - Applies `CaptionStyleCompat` for visual styling
   - Configures foreground/background colors
   - Sets font size using `TypedValue.COMPLEX_UNIT_DIP`

### Implementation Details

#### Subtitle File Processing

```java
private MediaSource getSubTitle(MediaSource mediaSource, Uri sturi, DataSource.Factory dataSourceFactory) {
    // Create mediaSource with subtitle
    MediaSource[] mediaSources = new MediaSource[2];
    mediaSources[0] = mediaSource;
    String mimeType = getMimeType(sturi);

    // Get language label from language code
    String languageLabel = Locale.forLanguageTag(language).getDisplayLanguage();
    MediaItem.SubtitleConfiguration subConfig = new MediaItem.SubtitleConfiguration.Builder(sturi)
        .setMimeType(mimeType)
        .setUri(sturi)
        .setId(subTitle)
        .setLabel(languageLabel)
        .setRoleFlags(C.ROLE_FLAG_CAPTION)
        .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
        .setLanguage(language)
        .build();

    SingleSampleMediaSource subtitleSource = new SingleSampleMediaSource.Factory(dataSourceFactory)
        .createMediaSource(subConfig, C.TIME_UNSET);

    mediaSources[1] = subtitleSource;
    mediaSource = new MergingMediaSource(mediaSources);
    return mediaSource;
}
```

#### MIME Type Detection

```java
private String getMimeType(Uri sturi) {
    String lastSegment = sturi.getLastPathSegment();
    String extension = lastSegment.substring(lastSegment.lastIndexOf(".") + 1);
    String mimeType = "";
    if (extension.equals("vtt")) {
        mimeType = MimeTypes.TEXT_VTT;
    } else if (extension.equals("srt")) {
        mimeType = MimeTypes.APPLICATION_SUBRIP;
    } else if (extension.equals("ssa") || extension.equals("ass")) {
        mimeType = MimeTypes.TEXT_SSA;
    } else if (extension.equals("ttml") || extension.equals("dfxp") || extension.equals("xml")) {
        mimeType = MimeTypes.APPLICATION_TTML;
    }
    return mimeType;
}
```

#### Subtitle Styling

```java
private void setSubtitle(boolean transparent) {
    int foreground;
    int background;
    if (!transparent) {
        foreground = Color.WHITE;
        background = Color.BLACK;
        if (stForeColor.length() > 4 && stForeColor.substring(0, 4).equals("rgba")) {
            foreground = getColorFromRGBA(stForeColor);
        }
        if (stBackColor.length() > 4 && stBackColor.substring(0, 4).equals("rgba")) {
            background = getColorFromRGBA(stBackColor);
        }
    } else {
        foreground = Color.TRANSPARENT;
        background = Color.TRANSPARENT;
    }
    styledPlayerView
        .getSubtitleView()
        .setStyle(
            new CaptionStyleCompat(foreground, background, Color.TRANSPARENT, 
                CaptionStyleCompat.EDGE_TYPE_NONE, Color.WHITE, null)
        );
    styledPlayerView.getSubtitleView().setFixedTextSize(TypedValue.COMPLEX_UNIT_DIP, stFontSize);
    styledPlayerView.setShowSubtitleButton(true);
}
```

#### RGBA Color Conversion

```java
private int getColorFromRGBA(String rgbaColor) {
    int ret = 0;
    String color = rgbaColor.substring(rgbaColor.indexOf("(") + 1, rgbaColor.indexOf(")"));
    List<String> colors = Arrays.asList(color.split(","));
    if (colors.size() == 4) {
        ret = (Math.round(Float.parseFloat(colors.get(3).trim()) * 255) & 0xff) << 24 |
            (Integer.parseInt(colors.get(0).trim()) & 0xff) << 16 |
            (Integer.parseInt(colors.get(1).trim()) & 0xff) << 8 |
            (Integer.parseInt(colors.get(2).trim()) & 0xff);
    }
    return ret;
}
```

### Supported Formats

- **WebVTT (.vtt)**: `MimeTypes.TEXT_VTT`
- **SubRip (.srt)**: `MimeTypes.APPLICATION_SUBRIP`
- **SubStationAlpha (.ssa, .ass)**: `MimeTypes.TEXT_SSA`
- **TTML/SMPTE (.ttml, .dfxp, .xml)**: `MimeTypes.APPLICATION_TTML`

### Integration Points

1. **Initialization** (`initPlayer` in `CapacitorVideoPlayerPlugin.java`)
   - Extracts subtitle path from options
   - Extracts language code
   - Extracts subtitle options (colors, font size)
   - Passes to fragment creation

2. **Fragment Setup** (`FullscreenExoPlayerFragment.onCreateView`)
   - Stores subtitle URI, language, and options
   - Processes subtitle options (foreground/background colors, font size)

3. **Player Initialization** (`initializePlayer`)
   - Calls `setSubtitle(false)` if subtitle URI exists
   - Merges subtitle with video media source

4. **Media Source Building**
   - `buildAssetMediaSource()`: Includes subtitle if `sturi != null`
   - `buildHttpMediaSource()`: Includes subtitle if `sturi != null`
   - Both call `getSubTitle()` to merge subtitle track

### User Controls

- ExoPlayer's `StyledPlayerView` provides a built-in subtitle button
- Users can toggle subtitles on/off via the player controls
- Subtitle button visibility controlled by `setShowSubtitleButton(true)`

## iOS Implementation

### Architecture

iOS uses **AVPlayer** with two different subtitle rendering approaches:

1. **AVMutableComposition** (for non-HLS videos): Embeds subtitle tracks directly into the composition
2. **Custom UILabel Overlay** (for HLS streams): Manual parsing and display of subtitle files

### Key Components

1. **Subtitle URL Resolution** (`CapacitorVideoPlayerPlugin.File.swift`)
   - Resolves subtitle file paths similar to video paths
   - Validates file existence

2. **Subtitle Loading** (`FullScreenVideoPlayerView.swift`)
   - Detects HLS vs non-HLS streams
   - Chooses appropriate subtitle rendering method
   - Handles both VTT and SRT formats

3. **Subtitle Parsing** (Custom implementation)
   - `parseVTTContent()`: Parses WebVTT format
   - `parseSRTContent()`: Parses SubRip format
   - Converts timestamps to seconds for synchronization

4. **Subtitle Display** (Custom UILabel)
   - Creates UILabel overlay on video player
   - Updates text based on playback time
   - Applies styling from `subtitleOptions`

### Implementation Details

#### HLS Stream Subtitle Handling

For HLS streams, iOS uses a **custom subtitle rendering system** because AVPlayer's native subtitle support has limitations with HLS:

```swift
private func setupSubtitlesForHLS(subTitleUrl: URL) {
    // Create player item with the original HLS asset
    self.playerItem = AVPlayerItem(asset: self.videoAsset)
    self.player = AVPlayer(playerItem: self.playerItem)
    
    // CRITICAL: Assign player to videoPlayer BEFORE setting up subtitles
    self.videoPlayer.player = self.player
    
    // Set up the player first
    self.setupPlayer()
    
    // Wait for player to be ready before adding subtitles
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        guard let self = self else { return }
        self.addSubtitlesToPlayer(subTitleUrl: subTitleUrl)
        self.autoPlayIfHLSReady()
    }
}
```

#### Custom Subtitle Display (HLS)

```swift
private func addSubtitlesToPlayer(subTitleUrl: URL) {
    // Read and parse subtitle content
    do {
        let subtitleContent = try String(contentsOf: subTitleUrl, encoding: .utf8)
        let isVTT = subtitleContent.hasPrefix("WEBVTT")
        
        // Parse subtitles based on format
        let subtitles: [(start: Double, end: Double, text: String)]
        if isVTT {
            subtitles = parseVTTContent(subtitleContent)
        } else {
            subtitles = parseSRTContent(subtitleContent)
        }
        
        // Create subtitle label
        let subtitleLabel = UILabel()
        subtitleLabel.textColor = UIColor.white
        subtitleLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        subtitleLabel.textAlignment = .center
        subtitleLabel.font = UIFont.systemFont(ofSize: 16)
        subtitleLabel.numberOfLines = 0
        subtitleLabel.isHidden = true
        
        // Add to content overlay view
        if let contentOverlayView = self.videoPlayer.contentOverlayView {
            contentOverlayView.addSubview(subtitleLabel)
            // Set up constraints...
        }
        
        // Set up time observer for subtitle synchronization
        let timeObserver = self.player?.addPeriodicTimeObserver(
            forInterval: CMTimeMake(value: 1, timescale: 1), 
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            let currentTime = time.seconds
            let currentSubtitle = self.findSubtitleForTime(currentTime, subtitles: subtitles)
            
            let newText = currentSubtitle?.text ?? ""
            if !newText.isEmpty {
                subtitleLabel.text = newText
                subtitleLabel.isHidden = false
                subtitleLabel.alpha = 1.0
            } else {
                subtitleLabel.isHidden = true
            }
        }
        
        self.subtitleTimeObserver = timeObserver
    } catch {
        print("Failed to read subtitle file: \(error)")
    }
}
```

#### Non-HLS Subtitle Handling (AVMutableComposition)

For non-HLS videos, iOS uses AVFoundation's composition system:

```swift
private func createPlayerWithSubtitles(subTitleUrl: URL, videoTracks: [AVAssetTrack]) {
    var textStyle: [AVTextStyleRule] = []
    if let opt = self._stOptions {
        textStyle.append(contentsOf: self.setSubTitleStyle(options: opt))
    }

    let subTitleAsset = AVAsset(url: subTitleUrl)
    let composition = AVMutableComposition()

    // Add video track
    if let videoTrack = composition.addMutableTrack(
        withMediaType: AVMediaType.video,
        preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) {
        
        // Add audio track if exists
        let audioTracks = self.videoAsset.tracks(withMediaType: AVMediaType.audio)
        // ... audio track insertion ...
        
        // Check if subtitle asset has text tracks
        let subtitleTracks = subTitleAsset.tracks(withMediaType: .text)
        if !subtitleTracks.isEmpty {
            if let subtitleTrack = composition.addMutableTrack(
                withMediaType: .text,
                preferredTrackID: kCMPersistentTrackID_Invalid) {
                do {
                    let duration = self.videoAsset.duration
                    try subtitleTrack.insertTimeRange(
                        CMTimeRangeMake(start: CMTime.zero, duration: duration),
                        of: subtitleTracks[0],
                        at: CMTime.zero)

                    self.playerItem = AVPlayerItem(asset: composition)
                    self.playerItem?.textStyleRules = textStyle
                } catch {
                    print("Failed to insert subtitle track: \(error)")
                    self.playerItem = AVPlayerItem(asset: self.videoAsset)
                }
            }
        }
    }
}
```

#### VTT Parsing

```swift
private func parseVTTContent(_ content: String) -> [(start: Double, end: Double, text: String)] {
    var subtitles: [(start: Double, end: Double, text: String)] = []
    let lines = content.components(separatedBy: .newlines)
    var i = 0
    
    // Skip WEBVTT header
    while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
        if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("WEBVTT") {
            i += 1
            break
        }
        i += 1
    }
    
    while i < lines.count {
        let line = lines[i].trimmingCharacters(in: .whitespaces)
        
        if line.isEmpty {
            i += 1
            continue
        }
        
        // Check if this is a timestamp line (VTT format: 00:00:00.000 --> 00:00:20.000)
        if line.contains("-->") {
            let timeParts = line.components(separatedBy: " --> ")
            if timeParts.count == 2 {
                let startTime = parseVTTTimeString(timeParts[0])
                let endTime = parseVTTTimeString(timeParts[1])
                
                // Get the subtitle text (next non-empty lines)
                var subtitleText = ""
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                    if !subtitleText.isEmpty {
                        subtitleText += "\n"
                    }
                    subtitleText += lines[i].trimmingCharacters(in: .whitespaces)
                    i += 1
                }
                
                if !subtitleText.isEmpty {
                    subtitles.append((start: startTime, end: endTime, text: subtitleText))
                }
            }
        }
        i += 1
    }
    
    return subtitles
}
```

#### SRT Parsing

```swift
private func parseSRTContent(_ content: String) -> [(start: Double, end: Double, text: String)] {
    var subtitles: [(start: Double, end: Double, text: String)] = []
    let lines = content.components(separatedBy: .newlines)
    var i = 0
    
    while i < lines.count {
        let line = lines[i].trimmingCharacters(in: .whitespaces)
        
        // Skip empty lines and sequence numbers
        if line.isEmpty || Int(line) != nil {
            i += 1
            continue
        }
        
        // Check if this is a timestamp line
        if line.contains("-->") {
            let timeParts = line.components(separatedBy: " --> ")
            if timeParts.count == 2 {
                let startTime = parseTimeString(timeParts[0])
                let endTime = parseTimeString(timeParts[1])
                
                // Get the subtitle text (next non-empty lines)
                var subtitleText = ""
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                    if !subtitleText.isEmpty {
                        subtitleText += "\n"
                    }
                    subtitleText += lines[i].trimmingCharacters(in: .whitespaces)
                    i += 1
                }
                
                if !subtitleText.isEmpty {
                    subtitles.append((start: startTime, end: endTime, text: subtitleText))
                }
            }
        }
        i += 1
    }
    
    return subtitles
}
```

#### Time String Parsing

```swift
private func parseVTTTimeString(_ timeString: String) -> Double {
    // VTT format: 00:00:00.000 or 00:00:00,000
    let cleanTime = timeString.replacingOccurrences(of: ",", with: ".")
    let components = cleanTime.components(separatedBy: ":")
    if components.count == 3 {
        let hours = Double(components[0]) ?? 0
        let minutes = Double(components[1]) ?? 0
        let seconds = Double(components[2]) ?? 0
        return hours * 3600 + minutes * 60 + seconds
    }
    return 0
}

private func parseTimeString(_ timeString: String) -> Double {
    let components = timeString.components(separatedBy: ":")
    if components.count == 3 {
        let hours = Double(components[0]) ?? 0
        let minutes = Double(components[1]) ?? 0
        let seconds = Double(components[2]) ?? 0
        return hours * 3600 + minutes * 60 + seconds
    }
    return 0
}
```

#### Subtitle Styling (AVTextStyleRule)

```swift
private func setSubTitleStyle(options: [String: Any]) -> [AVTextStyleRule] {
    var styles: [AVTextStyleRule] = []
    
    // Background color
    var backColor: [Float] = [1.0, 0.0, 0.0, 0.0]
    if let bckCol = options["backgroundColor"] as? String {
        let color = self.getColorFromRGBA(rgba: bckCol)
        backColor = color.count > 0 ? color : backColor
    }
    if let textStyle: AVTextStyleRule = AVTextStyleRule(textMarkupAttributes: [
        kCMTextMarkupAttribute_CharacterBackgroundColorARGB as String: backColor
    ]) {
        styles.append(textStyle)
    }

    // Foreground color
    var foreColor: [Float] = [1.0, 1.0, 1.0, 1.0]
    if let foreCol = options["foregroundColor"] as? String {
        let color = self.getColorFromRGBA(rgba: foreCol)
        foreColor = color.count > 0 ? color : foreColor
    }
    if let textStyle1: AVTextStyleRule = AVTextStyleRule(textMarkupAttributes: [
        kCMTextMarkupAttribute_ForegroundColorARGB as String: foreColor
    ]) {
        styles.append(textStyle1)
    }
    
    // Font size
    var ftSize = 160
    if let pixSize = options["fontSize"] as? Int {
        ftSize = pixSize * 10
    }
    if let textStyle2: AVTextStyleRule = AVTextStyleRule(textMarkupAttributes: [
        kCMTextMarkupAttribute_RelativeFontSize as String: ftSize,
        kCMTextMarkupAttribute_CharacterEdgeStyle as String: kCMTextMarkupCharacterEdgeStyle_None
    ]) {
        styles.append(textStyle2)
    }
    
    return styles
}
```

#### SRT to VTT Conversion

iOS includes a utility function to convert SRT files to VTT format (though it's not currently used in the main flow):

```swift
private func srtSubtitleToVtt(srtURL: URL) -> URL {
    guard let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
        fatalError("Couldn't get caches directory")
    }
    let vttFileName = UUID().uuidString + ".vtt"
    let vttURL = cachesURL.appendingPathComponent(vttFileName)
    
    // Download and convert SRT to VTT
    let session = URLSession(configuration: .default)
    let task = session.dataTask(with: srtURL) { (data, _, error) in
        guard let data = data, error == nil else { return }
        
        do {
            let tempSRTURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("subtitulos.srt")
            try data.write(to: tempSRTURL)
            let srtContent = try String(contentsOf: tempSRTURL, encoding: .utf8)
            let vttContent = srtContent.replacingOccurrences(of: ",", with: ".")
            let vttString = "WEBVTT\n\n" + vttContent
            try vttString.write(toFile: vttURL.path, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: tempSRTURL)
        } catch {
            print("Processing subs error: \(error)")
        }
    }
    
    task.resume()
    return vttURL
}
```

### Supported Formats

- **WebVTT (.vtt)**: Native support via AVFoundation or custom parsing
- **SubRip (.srt)**: Custom parsing implementation

### Integration Points

1. **Initialization** (`initPlayer` in `CapacitorVideoPlayerPlugin.swift`)
   - Extracts subtitle path from options
   - Resolves subtitle URL using `getURLFromFilePath()`
   - Extracts language and options
   - Passes to `createVideoPlayerFullscreenView()`

2. **Player View Creation** (`FullScreenVideoPlayerView.init`)
   - Stores subtitle URL, language, and options
   - Determines if subtitle should be loaded

3. **Player Initialization** (`initialize()`)
   - Checks if subtitle URL exists
   - Detects HLS vs non-HLS stream
   - Routes to appropriate subtitle loading method

4. **Subtitle Loading**
   - **HLS**: `setupSubtitlesForHLS()` → `addSubtitlesToPlayer()` (custom UILabel)
   - **Non-HLS**: `loadVideoAssetWithSubtitles()` → `createPlayerWithSubtitles()` (AVMutableComposition)

### Cleanup

Subtitles are cleaned up when the player is dismissed:

```swift
func cleanup() {
    // Remove time observer
    if let subtitleObserver = self.subtitleTimeObserver {
        self.player?.removeTimeObserver(subtitleObserver)
        self.subtitleTimeObserver = nil
    }
    
    // Clean up subtitle labels from content overlay
    if let contentOverlayView = self.videoPlayer.contentOverlayView {
        contentOverlayView.subviews.forEach { view in
            if view is UILabel {
                view.removeFromSuperview()
            }
        }
    }
}
```

## Subtitle Format Specifications

### WebVTT Format

```
WEBVTT

00:00:00.000 --> 00:00:05.000
First subtitle line
Second subtitle line

00:00:05.500 --> 00:00:10.000
Next subtitle
```

### SubRip (SRT) Format

```
1
00:00:00,000 --> 00:00:05,000
First subtitle line
Second subtitle line

2
00:00:05,500 --> 00:00:10,000
Next subtitle
```

### Key Differences

- **VTT**: Uses `.` for milliseconds, starts with `WEBVTT` header
- **SRT**: Uses `,` for milliseconds, has sequence numbers, no header

## Styling Options

### Color Format

Colors are specified in RGBA format: `"rgba(red, green, blue, alpha)"`

- **red, green, blue**: Integer values 0-255
- **alpha**: Float value 0.0-1.0

### Default Values

- **Foreground Color**: `rgba(255,255,255,1)` (white, fully opaque)
- **Background Color**: `rgba(0,0,0,1)` (black, fully opaque)
- **Font Size**: `16` pixels

### Platform-Specific Styling

**Android:**
- Uses `CaptionStyleCompat` for styling
- Font size in DIP (Density Independent Pixels)
- Supports edge style (none in current implementation)

**iOS:**
- Uses `AVTextStyleRule` for composition-based subtitles
- Uses `UILabel` properties for custom HLS subtitles
- Font size converted: `pixels * 10` for AVTextStyleRule

## Language Codes

Language codes follow ISO 639-1 standard (2-letter codes):

- `en` - English
- `es` - Spanish
- `fr` - French
- `de` - German
- etc.

The language code is used to:
- Set the subtitle track language in ExoPlayer (Android)
- Generate display language label from locale (Android)
- Store for potential future use (iOS)

## Limitations and Considerations

### Platform Limitations

1. **Web/Electron**: No subtitle support
2. **iOS HLS**: Requires custom implementation (not using native AVPlayer subtitles)
3. **Android**: Full native support via ExoPlayer

### Format Limitations

1. **iOS**: Only VTT and SRT supported (SRT parsed manually)
2. **Android**: Supports all listed formats natively
3. **Complex Subtitle Features**: 
   - No support for positioning cues
   - No support for styling within subtitle text
   - No support for multiple simultaneous subtitle tracks

### Performance Considerations

1. **iOS HLS Custom Subtitles**: 
   - Time observer runs every second (1 Hz)
   - Subtitle parsing happens once at initialization
   - UILabel updates are lightweight

2. **Android Native Subtitles**:
   - Handled entirely by ExoPlayer
   - No performance overhead from custom rendering

3. **File Loading**:
   - Subtitle files are loaded synchronously
   - Large subtitle files may cause brief UI blocking

### Error Handling

1. **File Not Found**: Returns error message, player continues without subtitles
2. **Invalid Format**: May cause parsing errors, subtitles won't display
3. **Network Errors**: Subtitle loading fails silently (for web URLs)

## Best Practices

### Subtitle File Preparation

1. **Use WebVTT when possible**: Better cross-platform support
2. **Keep files small**: Large subtitle files may cause performance issues
3. **Validate format**: Ensure timestamps are correctly formatted
4. **Test encoding**: Use UTF-8 encoding for international characters

### Configuration Recommendations

1. **Always provide language code**: Helps with track selection
2. **Use appropriate colors**: Ensure contrast for readability
3. **Test font sizes**: Different screen sizes may need different sizes
4. **Handle errors gracefully**: Check for subtitle loading failures

### Platform-Specific Tips

**Android:**
- ExoPlayer handles all subtitle rendering automatically
- Users can toggle subtitles via player controls
- Supports more formats natively

**iOS:**
- For HLS streams, custom subtitle rendering is used
- For non-HLS, native AVFoundation composition is used
- SRT files are parsed manually (may have edge case issues)

## Troubleshooting

### Common Issues

1. **Subtitles not displaying**
   - Check file path/URL is correct
   - Verify file format is supported
   - Check file encoding (should be UTF-8)
   - Verify timestamps are valid

2. **Subtitles out of sync**
   - Check timestamp format matches expected format
   - Verify video and subtitle are for same video version
   - Check for timezone or frame rate mismatches

3. **Styling not applied**
   - Verify RGBA format is correct
   - Check color values are within valid ranges
   - Ensure fontSize is a positive integer

4. **iOS HLS subtitles not working**
   - Verify subtitle file is accessible
   - Check console logs for parsing errors
   - Ensure content overlay view is available

### Debugging

**Android:**
- Check Logcat for subtitle-related messages
- Verify `sturi` is not null in fragment
- Check ExoPlayer track selection

**iOS:**
- Check console for parsing errors
- Verify subtitle URL is resolved correctly
- Check if content overlay view exists
- Monitor time observer execution

## Future Enhancements

Potential improvements for subtitle support:

1. **Multiple Subtitle Tracks**: Support for selecting from multiple subtitle files
2. **Embedded Subtitles**: Support for subtitles embedded in video files
3. **Web Platform Support**: Implement subtitle support for web using HTML5 text tracks
4. **Advanced Styling**: Support for positioning, text styling, and animations
5. **Subtitle Search**: Ability to search within subtitle text
6. **Auto-download**: Automatic subtitle download from services
7. **Subtitle Synchronization**: Tools to adjust subtitle timing

## Code References

### Android Files
- `android/src/main/java/.../CapacitorVideoPlayerPlugin.java` - Subtitle option extraction
- `android/src/main/java/.../FullscreenExoPlayerFragment.java` - Subtitle implementation
  - `getSubTitle()` - Media source merging
  - `setSubtitle()` - Styling application
  - `getMimeType()` - Format detection
  - `getColorFromRGBA()` - Color conversion

### iOS Files
- `ios/Plugin/CapacitorVideoPlayerPlugin.swift` - Subtitle option extraction
- `ios/Plugin/VideoPlayer/FullScreenVideoPlayerView.swift` - Subtitle implementation
  - `initialize()` - Subtitle loading entry point
  - `loadVideoAssetWithSubtitles()` - Route to appropriate method
  - `setupSubtitlesForHLS()` - HLS subtitle setup
  - `addSubtitlesToPlayer()` - Custom subtitle display
  - `createPlayerWithSubtitles()` - Composition-based subtitles
  - `parseVTTContent()` - VTT parsing
  - `parseSRTContent()` - SRT parsing
  - `setSubTitleStyle()` - Styling configuration
- `ios/Plugin/Extensions/CapacitorVideoPlayerPlugin.File.swift` - Subtitle URL resolution

### TypeScript Definitions
- `src/definitions.ts` - Subtitle option interfaces



