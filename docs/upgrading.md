# Upgrading a host app

## `@brylsherbert/capacitor-video-player` → `@dwbn/capacitor-video-player`

This fork is now published to npm as `@dwbn/capacitor-video-player`. Before, apps pulled it from git under the upstream name `@brylsherbert/capacitor-video-player`.

```bash
npm uninstall @brylsherbert/capacitor-video-player
npm i @dwbn/capacitor-video-player
npx cap sync
```

```diff
- import { CapacitorVideoPlayer } from '@brylsherbert/capacitor-video-player';
+ import { CapacitorVideoPlayer } from '@dwbn/capacitor-video-player';
```

- **iOS:** the CocoaPods pod and the Swift Package product are now called **`DwbnCapacitorVideoPlayer`** (before: `BrylsherbertCapacitorVideoPlayer`). `npx cap sync` rewrites the Podfile / `CapApp-SPM`. If you referenced the old name by hand, update it.
- **Unchanged:** the Capacitor plugin name (`CapacitorVideoPlayer`), the JavaScript API, the event names and the Android namespace `com.jeep.plugin.capacitor.capacitorvideoplayer`.

Coming from the original `capacitor-video-player` (jepiqueau / Harmon Wood, Capacitor ≤ 6)? Switch the package name in the same way, then follow the steps below.

## To 8.3.0 (Media3)

**Capacitor / JavaScript:** no changes — `initPlayer`, play/pause/seek, subtitle methods, and `jeepCapVideoPlayer*` events are unchanged from 8.2.x.

**Android host app:** update manifest/Gradle, then `npx cap sync android`.

1. Bump to **8.3.0** (or newer) and run `npx cap sync android`.
2. **Pin one Media3 version** — in `android/variables.gradle` (or `ext`):

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

3. **Do not** add `com.google.android.exoplayer:exoplayer-*:2.x` or copy old `play-services-cast-framework:21.2.0` into your app module. The plugin ships Media3 **1.11.1** and Cast framework **22.3.1**.
4. **Chromecast manifest (required if you use Cast):** change the options provider class from ExoPlayer 2 to Media3:

   `com.google.android.exoplayer2.ext.cast.DefaultCastOptionsProvider` → `androidx.media3.cast.DefaultCastOptionsProvider`

   See [API.md Chromecast](./API.md#chromecast-support). Do **not** add sync `CastContext.getSharedInstance(this)` in `MainActivity` — 8.3.0 initializes Cast inside the player.
5. **Release builds with minify:** add to `proguard-rules.pro`:

   ```proguard
   -keep class androidx.media3.cast.DefaultCastOptionsProvider { *; }
   ```

   The class is referenced only from manifest meta-data and can be stripped by R8.
6. **Android 13+ (API 33+):** `POST_NOTIFICATIONS` in the host manifest + runtime request when showing media notifications.
7. If the app also uses the playlist plugin, ship [`@dwbn/capacitor-plugin-playlist`](https://github.com/phiamo/capacitor-plugin-playlist) 8.x (0.12.0 or newer) in the **same** release. Session ids: video `org.dwbn.video`, playlist `org.dwbn.playlist`.

For Capacitor 2–3 era usage, see [legacy.md](./legacy.md).
