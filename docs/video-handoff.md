# Audio ↔ video handoff

Apps that play background audio with [`@dwbn/capacitor-plugin-playlist`](https://github.com/phiamo/capacitor-plugin-playlist) and open videos with this plugin must hand audio focus back and forth: pause audio, play the video, then continue audio at the video's position.

The full guide lives with the playlist plugin, because it drives the handoff:

**→ [Audio ↔ video handoff guide](https://github.com/phiamo/capacitor-plugin-playlist/blob/main/docs/video-handoff.md)**, which covers the lifecycle diagram, a complete example with both plugins, platform behaviour, DRM and common pitfalls.

## What this plugin provides for it

| API | Use in the handoff |
|---|---|
| `initPlayer({ …, seektime })` | Start the video where the audio was |
| `jeepCapVideoPlayerPositionUpdate` | Keep the video head current while playing |
| `jeepCapVideoPlayerExit` (`currentTime`) | Trigger the resume of audio |
| `getLastKnownPosition({ playerId })` | Last head that native saved. It still works after the WebView was suspended (for example during PiP), so use it as a fallback on exit |
| `jeepCapVideoPlayerBackground` | App went to the background while the video was playing. The app can continue as audio |
| MediaSession id `org.dwbn.video` | Different from the playlist's `org.dwbn.playlist`, so both Media3 sessions can live in one app |
