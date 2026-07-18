# Changelog

## [8.2.15] - 2026-07-18

### Fixed
- **Android:** On fullscreen exit, capture live ExoPlayer time and stop `seekTo(0)` before release so Epic 45 video→audio handoff is not poisoned by position 0 / a stale open position.
- **Android/iOS:** Persist last-known position on seek-completed and on exit; exit `currentTime` is a double so JS handoff can prefer the true video head when WebView missed ticks.

## [8.2.14] - 2026-07-17

### Fixed
- **Android:** Register `OnBackPressedCallback` in fullscreen video fragment so Predictive Back (gesture swipe and 3-button back on targetSdk 36) exits fullscreen / enters PiP again. Legacy `View.OnKeyListener` alone no longer receives `KEYCODE_BACK` on modern Android.

## [8.2.13] - 2026-07-17

### Fixed
- **iOS:** Set `isInPIPMode` in `AVPictureInPictureControllerDelegate.pictureInPictureControllerWillStartPictureInPicture` before `didEnterBackground`, so Epic 45 handoff does not tear down the player during PiP transition (fixes crash and audio-only PiP).
- **iOS/Android:** Emit `jeepCapVideoPlayerPipStart` / `jeepCapVideoPlayerPipStop` bridge events for JS PiP-aware background handling.

## [8.2.12] - 2026-07-15

### Fixed
- **Android:** Attach fullscreen video and picker overlays to `android.R.id.content` instead of the WebView's padded parent. On Android 15+ Capacitor SystemBars applies native padding to the WebView parent for safe-area insets; overlays on that parent were 136px short of true edge-to-edge width in landscape.

## [8.2.11] - 2026-07-15

### Fixed
- **Android:** Replace deprecated `SYSTEM_UI_FLAG_*` fullscreen APIs with `WindowCompat` / `WindowInsetsControllerCompat` for true edge-to-edge fullscreen on targetSdk 36.
- **Android:** Use `LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS` in fullscreen to eliminate white strip around camera cutout in landscape; reset to `DEFAULT` on exit.
- **iOS:** Emit `jeepCapVideoPlayerExit` when user closes native fullscreen via Done/X.
- **iOS:** Prevent Epic 45 handoff from dismissing video during open; improve fullscreen handling during app backgrounding.

## [8.2.10] - 2026-07-15

### Fixed
- **Android:** `adjustAspectRatio()` no longer switches resize mode (FIT/FILL) based on device orientation on rotation. It now only re-applies the *current* resize mode and forces a relayout. Previously rotating a fullscreen video from portrait to landscape force-switched to FILL, cropping content unacceptably for non-16:9 sources; users had to tap the resize button twice to get back to FIT.

## [8.2.9] - 2026-07-15

### Fixed
- **Android:** Defer resize-mode selection until ExoPlayer reports video dimensions (`onVideoSizeChanged`), preventing horizontal stretch when opening fullscreen in landscape before stream metadata is available. Default player view resize mode is now FIT until orientation-based mode is applied.

## [8.2.8] - 2026-07-15

### Fixed
- **Android:** Re-apply video resize mode after the player becomes ready and after immersive fullscreen UI settles, fixing incorrect aspect ratio when opening fullscreen video while the device is already in landscape (previously required tapping the resize button once).

## [8.2.1] - 2026-04-19

### Fixed
- **Android (Story 45.x):** `FullscreenExoPlayerFragment.onStop()` no longer calls `getActivity().finishAndRemoveTask()` when PiP mode is active. Previously this call killed the entire Capacitor Activity before the JS layer could run `endVideoSession()`, leaving the audio session unreleased and blocking resume-after-PiP. The fragment cleanup is now driven by the existing `playerFullscreenDismiss` notification path which emits `jeepCapVideoPlayerExit` to the WebView, allowing `endVideoSession` to restore the audio session and resume audio at the correct position.
- **Android (Story 45.x):** `onStart()` when `styledPlayerView` is null no longer calls `finishAndRemoveTask()` (same full-app kill as the old PiP path). It now logs and calls `playerExit()` so JS can receive the normal dismiss notification.

## 8.2.0 (2026-04-14)

### Add Features

- **`getLastKnownPosition`**: returns last playback head (seconds) persisted when `jeepCapVideoPlayerPositionUpdate` fires (iOS `UserDefaults`, Android `SharedPreferences`, Web in-memory). Used when the WebView is suspended or bridge events pause (Epic 45 / architecture PR-2).

## 8.1.0 (2026-03-30)

### Add Features

- Bridge events `jeepCapVideoPlayerSeek` and `jeepCapVideoPlayerSubtitleChange` (iOS, Android, Web) with documented payloads (`fromPosition` / `toPosition` / `duration`, `language` / optional `trackId`). No analytics SDK added to the plugin.

### Bug Fixes

- Web: document `videoPlayer*` listeners use stable handler references; `initPlayer` re-attaches after teardown; `duration` omitted when unknown (Web/iOS/Android).
- iOS: subtitle bridge `trackId` prefers manifest `subtitles[].id` when the legible option matches track language.

## 5.5.1 (2023-12-08)

### Chores

 - Update to Capacitor 5.5.1

### Add Features

 - Add access to `Documents` & `Download` directory (iOS)

### Bug Fixes

 - Fix the app's Documents directory (iOS)

## 5.5.0 (2023-12-07)

### Chores

 - Update to Capacitor 5.5.0

### Add Features

 - Add access to `Documents` folder (Android)

### Bug Fixes

 - Fix issue with permissions for API >=33 (Android)
 in the `AndroidManifest.xml` set
 
 ```xml
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
```



## 5.0.4-1 (2023-11-13)

### Add Features

 - Add link to JeepQ Capacitor Plugin Tutorials

 - Add link to application ionic7-angular-videoplayer-app 

 - Add link to application vant-nuxt-videoplayer-app

### Bug Fixes

 - play video file from Directory.data on iOS issue#134

 - Back button is locking to portrait orientation issue#136

## 5.0.3 (2023-11-04)

### Bug Fixes

 - Web Plugin fix event listeners issue

## 5.0.2 (2023-09-25)

### Bug Fixes (PR#133 from PhantomPainX)

 - Android ExoPlayer 2.19.0 update, Cast and NowPlayingInfo fixes #133

## 5.0.1 (2023-06-07)

### Add Features (PR#129 from PhantomPainX)

 - Add display information in NowPlayingInfo center (iOS) with title, smallTitle and artwork (capVideoPlayerOptions)

### Bug Fixes (PR#129 from PhantomPainX)

 - displayMode default "portrait" to "all" (unlocked orientation) (related: Exit listener not working correctly on Android #127)
 - Audio of the videos doesn't mix with other audios anymore (iOS)


## 5.0.0 (2023-05-25)

### Chores

 - Update to Capacitor 5.0.4

## 4.8.1 (2023-05-25)

### Add Features

 - Add new functions for Android PR#121 from fegauthier 

## 4.8.0 (2023-05-23)

### Add Features

 - add showControls in capVideoPlayerOptions (iOS &Android only)
 - add displayMode in capVideoPlayerOptions (iOS &Android only)

### Bug Fixes

 - Fix Hide controls and loading indicator issue#98
 - Fix issue#127 by implementing the landscape/portrait mode natively
 
## 4.8.0-1 (2023-05-12)

### Chores

 - Update to Capacitor 4.6.2
 - Update to hls.js 1.4.3
 
## 4.6.2 (2023-05-12)

### Bug Fixes

- Issue #122, some changes and MediaRouteButton fix PR#124 by PhantomPainX 

## 4.6.2-3 (2023-03-02)

### Bug Fixes

 - PR Android: Add support for devices who doesnt support Google Play Service by fegauthier
 - Fix initPlayer issue Capacitor 4 issue#118 Android

## 4.6.2-1 (2023-01-24)

### Chores

 - Update to Capacitor 4.6.2

### Bug Fixes

 - PR Android: Check pipEnabled in backPressed function by j-oppenhuis

## 4.6.1 (2023-01-22)

### Chores

 - Update to Capacitor 4.6.1
 - Update to hls.js 1.3.1 (Web)
 - Update to Exoplayer 2.18.1 (Android)

### Bug Fixes

 - PR Exoplayer v2.18.1 and some updates - fixes #114 from PhantomPainX [Notes from PhantomPainX](https://github.com/jepiqueau/capacitor-video-player/blob/master/docs/Notes_Exoplayer2.18.1.md)

## 4.1.0 (2022-09-11)

### Bug Fixes

 - Android Fix bug in getVideoType Error 1 issue#108

## 4.1.0-1 (2022-09-04)

### Chores

- Update to Capacitor 4.1.0

### Bug Fixes

 - Android Fix bug in initPlayer with permissions

## 4.0.1 (2022-09-04)

### Chores

- Update to Capacitor 4.0.1

## 3.7.5 (2022-09-05)

### Bug Fixes

 - Android Fix bug in initPlayer with permissions

## 3.7.4 (2022-09-03)

### Bug Fixes

 - The latest version doesn't play video files from the local device storage #89

### Add Features

 - add permission request for reading media file for API > 28
 
## 3.7.3 (2022-08-31)

### Bug Fixes

 - API.md Android Quirks
 - iOS - Swiping Video Off Screen Does Not Destroy The Video #105

## 3.7.2 (2022-08-31)

### Chores

 - (Android) Exoplayer 2.16.0 by Manuel García Marín (https://github.com/PhantomPainX)

### Added Features

 - (Android) Add Chromecast features

## 3.7.1 (2022-08-27)

 - (Android) New layout, features and some fixes #106 by Manuel García Marín (https://github.com/PhantomPainX)


## 3.7.0 (2022-08-23)

### Chores

- Update to Capacitor 3.7.0

### Add Features

 - Headers support for iOS and Android #101

## 3.4.2 (2022-04-12)

### Bug Fixes

 - Fix Notification center ConcurrentModificationException issue#86


## 3.4.2-2 (2022-03-31)

### Bug Fixes

 - Fix error when trying to create a product archive in Xcode issue#85

## 3.4.2-1 (2022-03-26)

### Chores

- Update to Capacitor 3.4.2

### Bug Fixes

 - Fix application crashes sometimes on stop issue#84 Android

## 3.4.1 (2022-03-12)

### Add Features

 - Add `bkmodeEnabled` boolean parameter in `capVideoPlayerOptions` to enable/disable BackgroundMode (iOS, Android only)

## 3.4.1-3 (2022-03-08)

### Bug Fixes

 - Fix .setCategory(.playback  iOS

## 3.4.1-2 (2022-03-08)

### Bug Fixes

 - Fix issue#78 iOS
 - Fix issue#79 Android
 - Fix issue#80 Android

## 3.4.1-1 (2022-03-02)

### Chores

- Update to Capacitor 3.4.1

### Add Features

 - Add `pipEnable` boolean parameter in `capVideoPlayerOptions` (iOS, Android)

### Bug Fixes

 - Fix audio continue to play when tap on X in PIP window (Android)

## 3.4.0 (2022-03-01)

### Bug Fixes

- Fix On Android, apps exit if you play a video, pause, and then resume the app issue#77

## 3.4.0-4 (2022-02-13)

### Add Features

 - Add `loopOnEnd` boolean parameter in `capVideoPlayerOptions` (iOS, Android)

### Bug Fixes

- Fix feat: move loopOnEnd to initPlayer issue#76

## 3.4.0-3 (2022-02-07)

### Add Features

 - Add `exitOnEnd` boolean parameter in `capVideoPlayerOptions` (iOS, Android)

### Bug Fixes

- Fix feat: move exitOnEnd to initPlayer issue#74

## 3.4.0-2 (2022-02-05)

### Add Features

- Add methods `getRate` and `setRate(rate)` with rate in [0.25,0.5,0.75,1.0,2.0,4.0] otherwise 1.0

### Bug Fixes

- Fix feature request > speed control issue#67

## 3.4.0-1 (2022-01-26)

### Chores

- Update to Capacitor 3.4.0

## Bug Fixes

- fix dynamic id in web.ts
- update README


## 3.3.2 (2021-12-11)

### Chores

- Update to Capacitor 3.3.2

### Bug Fixes

- fix from PiP to Fullscreen iOS platform

## 3.3.1 (2021-12-11)

### Add Features

- Add Picture in Picture iOS platform
- Add link to a `vite-react-videoplayer-app` 

### Bug Fixes

- fix Controls position for Picture in Picture Android
- fix setVolume as Float Android

## 3.3.1-2 (2021-11-17)

### Bug Fixes

- iOS fix DCIM folder as URL-Path issue#56
- iOS fix Player does not play video on iOS with "filePath not implemented" message issue#61

## 3.3.1-1 (2021-11-13)

### Chores

- Update to Capacitor 3.3.1

### Add Features

- Add Picture in Picture Android platform


## 3.3.0-1 (2021-11-08)

### Bug Fixes

- Android fix DCIM folder as URL-Path issue#56

## 3.2.5 (2021-11-06)

### Chores

- Update to Capacitor 3.2.5

### Bug Fixes

- fix Play from folders inside Application Folder issue#55

## 3.2.0-2 (2021-08-30)

### Bug Fixes

- fix package.json version

## 3.2.0-1 (2021-08-30)

### Chores

- Update to Capacitor 3.2.0

## 3.0.0-rc.2 (2021-06-21)

### Chores

- Update to Capacitor 3.0.0

### Bug Fixes

- fix Android subtitle issue#46

## 3.0.0-rc.1 (2021-06-01)

### Added Features

- Android platform

## 3.0.0-alpha.1 (2021-05-31)

### Chores

- Update to Capacitor 3.0.0

### Added Features

- iOS, Web, Electron platforms


## 2.4.7 (2021-05-31)

- Final version with Capacitor 2.4.7

### Bug Fixes

- fix Add test script in package.json

## 2.4.7-2 (2021-04-03)

### Added Features

- Add SubTitle to iOS platform issue#40
- Add change to foreground & background colors as well as font size

## 2.4.7-1 (2021-03-30)

### Chores

- Update to Capacitor 2.4.7

### Added Features

- Add SubTitle to Android platform issue#40

## 2.4.5-2 (2021-01-09)

### Bug Fixes

- fix Add Back Button issue#35 on Android

## 2.4.5-1 (2021-01-09)

### Chores

- Update to Capacitor 2.4.5
- @capacitor-community/electron 1.3.2

### Bug Fixes

- fix Screen falling asleep issue#33 on Android

## 2.4.2-2 (2020-10-04)

### Added Features

- add docgen to generate the API documentation

### Bug Fixes

- cleanup divContainer element as input of initPlayer

## 2.4.2-1 (2020-09-25)

### Chores

- Update to Capacitor 2.4.2

## 2.3.1-3 (2020-09-22)

### Bug Fixes

- fix CapacitorVideoPlayer.podspec
- fix return data in handlePlayerExit (Web)
- remove the wasPaused variable (Android)
- nullify the player in playerFullscreenExit (iOS)

## 2.3.1-2 (2020-09-16)

### Added Features

- add a link to a Ionic/React app starter

### Bug Fixes

- fix bugs to make it compatible with Ionic/React

## 2.3.1-1 (2020-08-27)

### Bug Fixes

- fix issue#23 iOS & Android video from app asset video folder

## 2.3.1-0 (2020-08-26)

### Bug Fixes

- fix issue#18 check for videoPlayFullScreenView nil

## 2.3.0 (2020-08-26)

### Added Features

- add read video from internal application folder on iOS
- add read video from internal application folder on Android

## 2.3.0-beta.4 (2020-08-20)

### Bug Fixes

- fix issue#20 Exit player when in PIP mode
- fix issue#19 Play video from local storage by giving the **url = "internal"**

## 2.3.0-beta.3 (2020-08-09)

### Bug Fixes

- fix issue#17 showing the status bar after fullscreen mode

## 2.3.0-beta.2 (2020-08-07)

### Bug Fixes

- fix issue#18 play video with url parameters
- fix issue#17 create programmatically the FrameLayout for the fragment

## 2.3.0-beta.1 (2020-08-06)

### Chores

- Update to Capacitor 2.1.0

### Bug Fixes

- fix Lint and SwiftLint issues

## 2.1.0 (2020-06-15)

### Added Features

- add interactive apis for native players (issue#15)
- remove Web Plugin Events
- add plugin listeners for Web and Native Plugins

## 2.1.0-3 (2020-05-28)

### Bug Fixes

- fix Android ism type not playing

## 2.1.0-2 (2020-05-28)

### Bug Fixes

- fix issue#14 url without type

## 2.1.0-1

### Chores

- Update to Capacitor 2.1.0

### Added Features

- issue#13 Background Video support for ios

## 2.0.1 (2020-05-08)

### Added Features

- Add support for DASH, HLS, ISM videos for Android plugin by using the ExoPlayer (issue#10)

## 2.0.1-6 (2020-05-06)

### Bug Fixes

- fix README

## 2.0.1-5 (2020-05-06)

### Added Features

- Add support for Hls video for Web & IOS plugin (issue#10)

## 2.0.1-4 (2020-04-30)

### Bug Fixes

- fix issue#12 add stopAllPlayers() method

## 2.0.1-3 (2020-04-30)

### Bug Fixes

- fix issue#11 test-angular-jeep-capacitor-plugins link in readme

## 2.0.1-2(2020-04-23)

### Added Features

- add a Progress Bar in Android Plugin

## 2.0.1-1(2020-04-19)

### Chores

- Update to Capacitor 2.0.1
- Update to AndroidX

## 1.5.1 (2020-03-17)

### Added Features

- Undeprecating the npm package to allow user to load only this capacitor plugin in there applications (advise by the Ionic Capacitor team)
