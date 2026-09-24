<p align="center"><br><img src="https://user-images.githubusercontent.com/236501/85893648-1c92e880-b7a8-11ea-926d-95355b8175c7.png" width="128" height="128" /></p>
<h3 align="center">Video Player</h3>
<p align="center"><strong><code>@brylsherbert/capacitor-video-player</code></strong></p>
<br>
<p align="center" style="font-size:32px;color:red"><strong>CAPACITOR 8</strong> — fork maintained for DWBN / phiamo (see <a href="./CHANGELOG.md">CHANGELOG</a> 8.3.0 Media3)</p><br>
<br>
<p align="center" style="font-size:20px;color:red"><a href="https://github.com/jepiqueau/capacitor-video-player/blob/master/docs/Jean_Pierre_Queau.md"><strong>Special note from Jean Pierre Quéau the original founder of this project.</strong></a></p>
<br>
<p align="center">
  Capacitor Video Player Plugin is a custom Native Capacitor plugin to play a video 
<br>
  <strong>fullscreen</strong> on IOS, Android, Web and Electron platforms
<br>
  <strong>embedded</strong> on Web and Electron platforms
</p>

<p align="center">
  <img src="https://img.shields.io/maintenance/yes/2024?style=flat-square" />
  <a href="https://github.com/jepiqueau/capacitor-video-player/actions?query=workflow%3A%22CI%22"><img src="https://img.shields.io/github/workflow/status/jepiqueau/capacitor-video-player/CI?style=flat-square" /></a>
  <a href="https://www.npmjs.com/package/capacitor-video-player"><img src="https://img.shields.io/npm/l/capacitor-video-player.svg?style=flat-square" /></a>
<br>
  <a href="https://www.npmjs.com/package/capacitor-video-player"><img src="https://img.shields.io/npm/dw/capacitor-video-player?style=flat-square" /></a>
  <a href="https://www.npmjs.com/package/capacitor-video-player"><img src="https://img.shields.io/npm/v/capacitor-video-player?style=flat-square" /></a>
<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
<a href="#contributors-"><img src="https://img.shields.io/badge/all%20contributors-10-orange?style=flat-square" /></a>
<!-- ALL-CONTRIBUTORS-BADGE:END -->
</p>

## Maintainers

| Maintainer        | GitHub                                      | Social | Active |
| ----------------- | ------------------------------------------- | ------ | ------ |
| Harmon Wood       | [harmonwood](https://github.com/harmonwood) |        | ✅     |
| Quéau Jean Pierre | [jepiqueau](https://github.com/jepiqueau)   |        | ❌     |

## LATEST FOR CAPACITOR 8 (main)

Peer dependency: `@capacitor/core >= 8.0.0`. Current release **8.3.0**.

## Browser Support

The plugin follows the guidelines from the `Capacitor Team`,

- [Capacitor Browser Support](https://capacitorjs.com/docs/v3/web#browser-support)

meaning that it will not work in IE11 without additional JavaScript transformations, e.g. with [Babel](https://babeljs.io/).

## Installation

  ```bash
  npm install --save @brylsherbert/capacitor-video-player
  npx cap sync
  npx cap sync @capacitor-community/electron
  ```

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

**Android Chromecast:** your host app must set Cast options in `AndroidManifest.xml` (see [docs/API.md](./docs/API.md#chromecast-support)). **Android 13+:** declare `POST_NOTIFICATIONS` in the host manifest and request at runtime if you rely on lock-screen / media notifications together with other plugins.

### Protected playback (Android)

This plugin does **not** pin `drm-kit`. The host app that needs Widevine adds `drm-kit` itself and registers a provider at launch from the app `Application` class (not a plugin Gradle / `Package.swift` dependency):

```java
VideoDrm.setProvider((drm, onError) -> {
  // Story 57.6: wrap drm-kit WidevineSession. Token URL, heartbeat URL, and Bearer live here.
});
```

`initPlayer` `{ drm }` without a registered provider returns `{ result: false, code: "noProvider" }` and does not create a player. iOS and web refuse `{ drm }` with `{ result: false, code: "notSupported", message: "DRM not supported on this platform yet" }`. Typed provider errors are emitted as `jeepCapVideoPlayerError` `{ fromPlayerId, error }`. Chromecast `MediaItem`s are unchanged (no DRM).

## Upgrading a host app (8.3.0)

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

   See [API.md Chromecast](./docs/API.md#chromecast-support). Do **not** add sync `CastContext.getSharedInstance(this)` in `MainActivity` — 8.3.0 initializes Cast inside the player.
5. **Release builds with minify:** add to `proguard-rules.pro`:

   ```proguard
   -keep class androidx.media3.cast.DefaultCastOptionsProvider { *; }
   ```

   The class is referenced only from manifest meta-data and can be stripped by R8.
6. **Android 13+ (API 33+):** `POST_NOTIFICATIONS` in the host manifest + runtime request when showing media notifications.
7. If the app also uses `capacitor-plugin-playlist`, ship playlist **0.12.0** in the **same** release. Session ids: video `org.dwbn.video`, playlist `org.dwbn.playlist`.

## Supported methods

| Name                               | Android | iOS | Electron | Web |
| :--------------------------------- | :------ | :-- | :------- | :-- |
| initPlayer (mode fullscreen)       | ✅      | ✅  | ✅       | ✅  |
| initPlayer (mode embedded)         | ❌      | ❌  | ✅       | ✅  |
| initPlayer (url assets)            | ✅      | ✅  | ✅       | ✅  |
| initPlayer (url internal)          | ✅      | ✅  | ❌       | ❌  |
| initPlayer (url application/files) | ✅      | ✅  | ❌       | ❌  |
| initPlayer (subtitles)             | ✅      | ✅  | ❌       | ❌  |
| initPlayer (headers)               | ✅      | ✅  | ❌       | ❌  |
| initPlayer (title)                 | ✅      | ✅  | ❌       | ❌  |
| initPlayer (smallTitle)            | ✅      | ✅  | ❌       | ❌  |
| initPlayer (accentColor)           | ✅      | ❌  | ❌       | ❌  |
| initPlayer (chromecast)            | ✅      | ❌  | ❌       | ❌  |
| initPlayer (artwork)               | ✅      | ✅  | ❌       | ❌  |
| isPlaying                          | ✅      | ✅  | ✅       | ✅  |
| play                               | ✅      | ✅  | ✅       | ✅  |
| pause                              | ✅      | ✅  | ✅       | ✅  |
| getCurrentTime                     | ✅      | ✅  | ✅       | ✅  |
| setCurrentTime                     | ✅      | ✅  | ✅       | ✅  |
| getDuration                        | ✅      | ✅  | ✅       | ✅  |
| getMuted                           | ✅      | ✅  | ✅       | ✅  |
| setMuted                           | ✅      | ✅  | ✅       | ✅  |
| getVolume                          | ✅      | ✅  | ✅       | ✅  |
| setVolume                          | ✅      | ✅  | ✅       | ✅  |
| stopAllPlayers                     | ✅      | ✅  | ✅       | ✅  |
| getRate                            | ✅      | ✅  | ✅       | ✅  |
| setRate                            | ✅      | ✅  | ✅       | ✅  |
| showController                     | ✅      | ❌  | ❌       | ❌  |
| isControllerIsFullyVisible         | ✅      | ❌  | ❌       | ❌  |
| exitPlayer                         | ✅      | ❌  | ❌       | ❌  |

## Supported listeners

| Name                    | Android | iOS | Electron | Web |
| :---------------------- | :------ | :-- | :------- | :-- |
| jeepCapVideoPlayerReady | ✅      | ✅  | ✅       | ✅  |
| jeepCapVideoPlayerSeek  | ✅      | ✅  | ✅       | ✅  |
| jeepCapVideoPlayerSubtitleChange | ✅      | ✅  | ✅       | ✅  |
| jeepCapVideoPlayerPlay  | ✅      | ✅  | ✅       | ✅  |
| jeepCapVideoPlayerPause | ✅      | ✅  | ✅       | ✅  |
| jeepCapVideoPlayerEnded | ✅      | ✅  | ✅       | ✅  |
| jeepCapVideoPlayerExit  | ✅      | ✅  | ✅       | ✅  |
| jeepCapVideoPlayerPipStart | ✅   | ❌  | ❌       | ❌  |
| jeepCapVideoPlayerPipStop  | ✅   | ❌  | ❌       | ❌  |

### Seek / subtitle listener payloads

- **`jeepCapVideoPlayerSeek`:** `fromPlayerId`, `fromPosition`, `toPosition` (seconds). `duration` is included only when the duration is known (finite / player ready).
- **`jeepCapVideoPlayerSubtitleChange`:** `fromPlayerId`, `language` (IETF tag, `off`, or `und`). `trackId` is set when the app supplied manifest `subtitles[].id` can be matched (iOS native menu); otherwise omitted.

### Verification

- Automated: `npm test` runs `npm run build` (TypeScript + bundle). Manual matrix: device/simulator for seek + subtitles on iOS, Android, and Web.

## Documentation

[API_Documentation](https://www.capacitorvideoplayer.com/API/)

## Tutorials Blog

 - [JeepQ Capacitor Plugin Tutorials](https://jepiqueau.github.io/)


## Applications demonstrating the use of the plugin

### Capacitor 5 Apps

 - [ionic7-angular-videoplayer-app](https://github.com/jepiqueau/blog-tutorials-apps/tree/main/Videoplayer/ionic7-angular-videoplayer-app)

 - [vant-nuxt-videoplayer-app](https://github.com/jepiqueau/blog-tutorials-apps/tree/main/Videoplayer/vant-nuxt-videoplayer-app)


### Application Starter (Not yet updated to 5.0.0)

- [angular-video-player-app-starter](https://github.com/jepiqueau/angular-videoplayer-app-starter)

- [react-video-player-app-starter](https://github.com/jepiqueau/react-video-player-app-starter)

- [vite-react-videoplayer-app](https://github.com/jepiqueau/vite-react-videoplayer-app)
 
- [vue-videoplayer-app](https://github.com/jepiqueau/vue-videoplayer-app-starter)

## Usage 2.4.7 (historical)

Capacitor 2 API — **not** current. See [Usage_2.4.7.md](./docs/Usage_2.4.7.md) (archived).

## Usage 3.x (historical)

Capacitor 3 import patterns — **not** current. See [Usage_3.0.0.md](./docs/Usage_3.0.0.md) (archived). Install **`@brylsherbert/capacitor-video-player@8.3.0`** with Capacitor 8 plugin imports today.

## Dependencies

- hls.js for HLS videos on Web and Electron platforms
- **Android:** [androidx.media3](https://developer.android.com/jetpack/androidx/releases/media3) **1.11.1** (`ExoPlayer`, `PlayerView`, `MediaSession`, `RemoteCastPlayer`) for HLS, DASH, SmoothStreaming, and progressive video. Do **not** add legacy `com.google.android.exoplayer:exoplayer-*:2.x` in your host app.

## Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
    <td align="center"><a href="https://github.com/jepiqueau"><img src="https://avatars3.githubusercontent.com/u/16580653?v=4" width="100px;" alt=""/><br /><sub><b>Jean Pierre Quéau</b></sub></a><br /><a href="https://github.com/jepiqueau/capacitor-video-player/commits?author=jepiqueau" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/yelhouti"><img src="https://avatars.githubusercontent.com/u/5471639?v=4" width="100px;" alt=""/><br /><sub><b>Yelhouti</b></sub></a><br /><a href="https://github.com/jepiqueau/capacitor-video-player/commits?author=yelhouti" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/mamane10"><img src="https://avatars.githubusercontent.com/u/46500089?v=4" width="100px;" alt=""/><br /><sub><b>Mamane10</b></sub></a><br /><a href="https://github.com/jepiqueau/capacitor-video-player/commits?author=mamane10" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/KANekT"><img src="https://avatars.githubusercontent.com/u/580273?v=4" width="100px;" alt=""/><br /><sub><b>Пронин Андрей KANekT</b></sub></a><br /><a href="https://github.com/jepiqueau/capacitor-video-player/commits?author=KANekT" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/mueslirieger"><img src="https://avatars.githubusercontent.com/u/20973893?v=4" width="100px;" alt=""/><br /><sub><b>Michael Rieger</b></sub></a><br /><a href="https://github.com/jepiqueau/capacitor-video-player/commits?author=mueslirieger" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/PhantomPainX"><img src="https://avatars.githubusercontent.com/u/47803967?v=4" width="100px;" alt=""/><br /><sub><b>Manuel García Marín</b></sub></a><br /><a href="https://github.com/jepiqueau/capacitor-video-player/commits?author=PhantomPainX" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/j-oppenhuis"><img src="https://avatars.githubusercontent.com/u/46529655?v=4" width="100px;" alt=""/><br /><sub><b>Jelle Oppenhuis</b></sub></a><br /><a href="https://github.com/jepiqueau/capacitor-video-player/commits?author=j-oppenhuis" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/fegauthier"><img src="https://avatars.githubusercontent.com/u/12112673?v=4" width="100px;" alt=""/><br /><sub><b>fegauthier</b></sub></a><br /><a href="https://github.com/jepiqueau/capacitor-video-player/commits?author=fegauthier" title="Code">💻</a></td>
    
  </tr>
  <tr>
    <td align="center"><a href="https://github.com/harmonwood"><img src="https://avatars.githubusercontent.com/u/460843?v=4" width="100px;" alt="Harmon Wood"/><br /><sub><b>Harmon Wood</b></sub></a><br /><a href="https://github.com/harmonwood/capacitor-video-player/commits?author=harmonwood" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/eduardoRoth"><img src="https://avatars.githubusercontent.com/u/5419161?v=4" width="100px;" alt="Eduardo Roth"/><br /><sub><b>Eduardo Roth</b></sub></a><br /><a href="https://github.com/harmonwood/capacitor-video-player/commits?author=eduardoroth" title="Code">💻</a></td>
  </tr>
</table>

<!-- markdownlint-enable -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!
