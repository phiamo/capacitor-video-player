<p align="center"><br><img src="https://user-images.githubusercontent.com/236501/85893648-1c92e880-b7a8-11ea-926d-95355b8175c7.png" width="128" height="128" /></p>
<h3 align="center">Video Player</h3>
<p align="center"><strong><code>@dwbn/capacitor-video-player</code></strong></p>
<p align="center">
  Native video for Capacitor 8: <strong>fullscreen</strong> on Android, iOS, Web and Electron, and <strong>embedded</strong> on Web and Electron.
</p>

<p align="center">
  <a href="https://www.npmjs.com/package/@dwbn/capacitor-video-player"><img src="https://img.shields.io/npm/v/@dwbn/capacitor-video-player?style=flat-square" /></a>
  <a href="./LICENSE"><img src="https://img.shields.io/npm/l/@dwbn/capacitor-video-player?style=flat-square" /></a>
  <a href="https://capacitorjs.com"><img src="https://img.shields.io/badge/capacitor-8-119EFF?style=flat-square" /></a>
  <a href="#contributors-"><img src="https://img.shields.io/badge/all%20contributors-10-orange?style=flat-square" /></a>
</p>

> 📦 **Now on npm as `@dwbn/capacitor-video-player`.** This fork was previously used from git under the upstream name `@brylsherbert/capacitor-video-player`. The iOS pod is now `DwbnCapacitorVideoPlayer`. The repository stays here. [How to switch →](./docs/upgrading.md#brylsherbertcapacitor-video-player--dwbncapacitor-video-player)

Created by **Jean Pierre Quéau** in 2018, later maintained by **Harmon Wood** and **Bryl Sherbert**, and now maintained by [@phiamo](https://github.com/phiamo) for the DWBN apps. [History & credits →](./docs/history.md) · [A special note from the founder →](./docs/Jean_Pierre_Queau.md)

## Part of the DWBN media stack

| | Project | What it does |
|---|---|---|
| 🎵 | [**capacitor-plugin-playlist**](https://github.com/phiamo/capacitor-plugin-playlist) · [`@dwbn/capacitor-plugin-playlist`](https://www.npmjs.com/package/@dwbn/capacitor-plugin-playlist) | Background audio playlists, lock screen, audio↔video handoff |
| 🎬 | **capacitor-video-player** (this repo) · [`@dwbn/capacitor-video-player`](https://www.npmjs.com/package/@dwbn/capacitor-video-player) | Native fullscreen video with Media3 / AVPlayer, PiP, Chromecast and subtitles |
| 🔐 | [**drm-kit**](https://github.com/phiamo/drm-kit) · Swift Package Manager / JitPack | Widevine session and DRM identifiers that the host app plugs into both plugins |

The plugins work on their own. drm-kit is optional and is added by the **app**, never by a plugin. The [audio ↔ video handoff guide](https://github.com/phiamo/capacitor-plugin-playlist/blob/main/docs/video-handoff.md) shows all three working together.

## Platform support

| | Android | iOS | Web / Electron |
|---|---|---|---|
| Engine | androidx.media3 1.11.1 (ExoPlayer) | AVPlayer | HTML5 video + hls.js |
| Fullscreen / embedded | ✅ / — | ✅ / — | ✅ / ✅ |
| HLS, DASH | ✅ HLS, DASH, SmoothStreaming | ✅ HLS | ✅ HLS (hls.js) |
| Subtitles | ✅ | ✅ native menu | — |
| Picture-in-picture | ✅ | — | — |
| Chromecast | ✅ Media3 Cast | — | — |
| Lock screen / MediaSession | ✅ | ✅ artwork, title | — |
| DRM | ✅ Widevine via [drm-kit](./docs/drm.md) | planned (FairPlay) | — |
| Minimum | SDK 24 | iOS 18 | modern browsers |

The full method and listener matrix is in [usage.md](./docs/usage.md). Requires **Capacitor 8** (`@capacitor/core >= 8.0.0`).

## Install

```bash
npm install @dwbn/capacitor-video-player
npx cap sync
```

Android apps that use Chromecast, or that also use another Media3 library such as the playlist plugin, need a small setup. See [installation.md](./docs/installation.md).

## Quick start

```typescript
import { CapacitorVideoPlayer } from '@dwbn/capacitor-video-player';

await CapacitorVideoPlayer.addListener('jeepCapVideoPlayerExit', (e) => {
  console.log('closed at', e.currentTime);
});

await CapacitorVideoPlayer.initPlayer({
  mode: 'fullscreen',
  playerId: 'fullscreen',
  url: 'https://example.com/video.m3u8',
  title: 'My video',
});
```

## Documentation

| Guide | |
|---|---|
| [Installation](./docs/installation.md) | Install, Chromecast, the Media3 version pin, Electron |
| [Usage](./docs/usage.md) | Getting started, methods and listeners per platform, event payloads |
| [API reference](./docs/API.md) | URLs and assets, subtitles, Chromecast, every method and type (generated) |
| [Audio ↔ video handoff](./docs/video-handoff.md) | Working together with `@dwbn/capacitor-plugin-playlist` |
| [Protected playback (DRM)](./docs/drm.md) | Widevine on Android with drm-kit, error codes |
| [Upgrading](./docs/upgrading.md) | Moving to `@dwbn/…`, and to 8.3.0 (Media3) |
| [Legacy versions](./docs/legacy.md) | Capacitor 2–6 era usage, tutorials and example apps |
| [History & credits](./docs/history.md) | Maintainers through the years and all contributors |
| [Changelog](./CHANGELOG.md) | Release notes |

## Versioning

The major version follows Capacitor's major: **8.x targets Capacitor 8**, the same as [capacitor-plugin-playlist](https://github.com/phiamo/capacitor-plugin-playlist).

## Maintainers

| Maintainer | GitHub | Role | Active |
| --- | --- | --- | --- |
| Philipp Mohrenweiser | [phiamo](https://github.com/phiamo) | Maintainer of this fork (`@dwbn`) | ✅ |
| Bryl Sherbert | [brylsherbert247](https://github.com/brylsherbert247) | Capacitor 7/8 fork (`@brylsherbert`) | — |
| Harmon Wood | [harmonwood](https://github.com/harmonwood) | Maintainer of the original (6.x) | — |
| Quéau Jean Pierre | [jepiqueau](https://github.com/jepiqueau) | Founder (1.x–5.x) | ❌ |

## Contributors ✨

Thank you to [everyone who contributed](./docs/history.md#contributors-) over the years: Jean Pierre Quéau, Yelhouti, Mamane10, Пронин Андрей KANekT, Michael Rieger, Manuel García Marín, Jelle Oppenhuis, fegauthier, Harmon Wood, Eduardo Roth, Bryl Sherbert and phiamo. This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind are welcome!

<a href="https://ko-fi.com/W8V527Q5YX"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="ko-fi" /></a>

## License

[MIT](./LICENSE)
