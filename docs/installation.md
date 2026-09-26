# Installation

```bash
npm install @dwbn/capacitor-video-player
npx cap sync
```

For Electron, also run `npx cap sync @capacitor-community/electron`.

### Build
  Then build YOUR_APPLICATION

  ```
  npm run build
  npx cap copy
  npx cap copy web
  npx cap copy @capacitor-community/electron
  npx cap open android
  npx cap open ios
  npx cap open @capacitor-community/electron
  npx cap serve
  ```

## Configuration

No Capacitor plugin configuration is required for basic playback.

**Android Chromecast:** your host app must set Cast options in `AndroidManifest.xml` (see [API.md](./API.md#chromecast-support)). **Android 13+:** declare `POST_NOTIFICATIONS` in the host manifest and request at runtime if you rely on lock-screen / media notifications together with other plugins.

For protected content, see [drm.md](./drm.md).

## Android: pin one Media3 version

The plugin ships androidx.media3 **1.11.1** and Cast framework **22.3.1**. Pin the same Media3 version for the whole app, especially if another Media3 library such as [`@dwbn/capacitor-plugin-playlist`](https://github.com/phiamo/capacitor-plugin-playlist) is in the same APK. In `android/variables.gradle` (or `ext`):

```gradle
media3Version = '1.11.1'
```

In the root `android/build.gradle`:

```gradle
allprojects {
    configurations.configureEach {
        resolutionStrategy {
            eachDependency { details ->
                if (details.requested.group == 'androidx.media3') {
                    details.useVersion rootProject.ext.media3Version
                }
            }
        }
    }
}
```

Do **not** add `com.google.android.exoplayer:exoplayer-*:2.x` to the app. The video MediaSession id is `org.dwbn.video`, and the playlist plugin uses `org.dwbn.playlist`. Media3 needs the two ids to be different.

## Browser support

The web implementation follows [Capacitor's browser support](https://capacitorjs.com/docs/web#browser-support).

## Dependencies

- hls.js for HLS videos on Web and Electron platforms
- **Android:** [androidx.media3](https://developer.android.com/jetpack/androidx/releases/media3) **1.11.1** (`ExoPlayer`, `PlayerView`, `MediaSession`, `RemoteCastPlayer`) for HLS, DASH, SmoothStreaming, and progressive video. Do **not** add legacy `com.google.android.exoplayer:exoplayer-*:2.x` in your host app.

Next: [Usage](./usage.md) · [Audio ↔ video handoff](./video-handoff.md)
