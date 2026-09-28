# Protected playback (DRM)

`initPlayer` accepts an optional `drm` descriptor. On **Android** and **iOS**, the player plays it (Widevine / FairPlay) through a provider that the **host app** registers. **Web** refuses `drm` for now. Chromecast `MediaItem`s are not affected (no DRM).

The plugin deliberately does **not** depend on a DRM library. The DWBN apps use [**drm-kit**](https://github.com/phiamo/drm-kit). It provides the Widevine session (license, token refresh, heartbeat, stream limits) for this plugin and [`@dwbn/capacitor-plugin-playlist`](https://github.com/phiamo/capacitor-plugin-playlist) on Android, and the FairPlay session (`FairPlaySession`, `AVContentKeySession`-based) for this plugin on iOS.

## 1. Add drm-kit to the host app

`android/app/build.gradle` (the app module, not this plugin):

```gradle
repositories { maven { url 'https://jitpack.io' } }
dependencies { implementation 'com.github.phiamo:drm-kit:0.3.1' }
```

iOS: add `https://github.com/phiamo/drm-kit` as a Swift Package dependency of the **App target** (not this plugin — the plugin never imports drm-kit), pinned to a released tag.

## 2. Register the provider

Once, from your `Application` class:

```java
@UnstableApi
public class App extends Application {
  @Override
  public void onCreate() {
    super.onCreate();
    VideoDrm.setProvider(MyWidevineSession::new);   // com.jeep.plugin.capacitor.capacitorvideoplayer.VideoDrm
    AudioDrm.setProvider(MyWidevineSession::new);   // only if you also use the playlist plugin
  }
}
```

`MyWidevineSession` implements `VideoDrmSession` by wrapping drm-kit's `WidevineSession`. It receives the `drm` object from `initPlayer` and an `onError` callback. Token URL, heartbeat URL and the bearer token live in your app, never in the options. The [drm-kit README](https://github.com/phiamo/drm-kit#usage) has a complete session class.

iOS: once, from `AppDelegate`'s `application(_:didFinishLaunchingWithOptions:)`:

```swift
import CapacitorVideoPlayerPlugin

VideoDrm.setProvider(MyFairPlaySessionProvider())
```

`MyFairPlaySessionProvider` implements the plugin's `VideoDrmProvider` protocol; its `open(_:onError:)` returns a `MyFairPlaySession` implementing `VideoDrmSession` (`attach(to: AVURLAsset)`, `start()`, `release()`) by wrapping drm-kit's `FairPlaySession`. As on Android, token/heartbeat URLs and the bearer token live in your app, never in the `drm` options. `AVMutableComposition` does not conform to `AVContentKeyRecipient`, so a host implementation should not attempt to re-register the DRM session against a rebuilt composition — the plugin already skips composition-based multi-subtitle-track merging while a session is attached, and plays the original asset directly instead.

## 3. Pass `drm` to `initPlayer`

```typescript
const res = await CapacitorVideoPlayer.initPlayer({
  mode: 'fullscreen',
  playerId: 'fullscreen',
  url: 'https://cdn.example/talk-42/video.mpd',
  drm: {
    widevineLicenseUrl: 'https://license.example/widevine',
    playbackSessionId: 'ps_123',
    renewalCredential: '…',
  },
});
if (!res.result) console.warn(res.code, res.message); // noProvider | notSupported
```

`fairplayLicenseUrl` / `fairplayCertificateUrl` are consumed by the iOS FairPlay provider; ignored on Android. `widevineLicenseUrl` is ignored on iOS.

## Behaviour

| Situation | Result |
|---|---|
| No `drm` | Plain playback |
| `drm` set, no provider registered (Android or iOS) | `{ result: false, code: "noProvider" }`, no player created |
| `drm` set on web | `{ result: false, code: "notSupported", message: "DRM not supported on this platform yet" }` |

## Errors

Provider errors are emitted as `jeepCapVideoPlayerError` with `{ fromPlayerId, error }`:

| `error` | Meaning | Suggested handling |
|---|---|---|
| `blockedByStreamLimit` | Concurrent-stream limit reached | Tell the user; **do not auto-retry** |
| `notEntitled` | No right to play this item | Show entitlement message |
| `expired` | License / session expired | Refresh and retry once |
| `network` | License or token server unreachable | Retry with backoff |
| `unknown` | Anything else | Log, show generic error |

When audio and video are both protected, only one license may be active at a time. See [Handoff with DRM](https://github.com/phiamo/capacitor-plugin-playlist/blob/main/docs/video-handoff.md#handoff-with-drm).
