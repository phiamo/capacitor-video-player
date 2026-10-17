# History & credits

This plugin has had four homes. Each maintainer carried it to the next Capacitor generation. Thank you all 🙏

| When | Maintainer | What happened |
|---|---|---|
| Dec 2018 – 2024 | **Jean Pierre Quéau** ([@jepiqueau](https://github.com/jepiqueau)), founder | Created `capacitor-video-player` together with Ionic Capacitor itself and maintained it through Capacitor 1–5: fullscreen and embedded players, subtitles, Chromecast, many example apps and tutorials. → [His farewell note](./Jean_Pierre_Queau.md) |
| 2024 | **Harmon Wood** ([@harmonwood](https://github.com/harmonwood)) | Took over ownership ([harmonwood/capacitor-video-player](https://github.com/harmonwood/capacitor-video-player#maintainers)), released Capacitor 6 (`capacitor-video-player` 6.x) and built the [documentation microsite](https://www.capacitorvideoplayer.com). |
| Jul 2025 | **Bryl Sherbert** ([@brylsherbert247](https://github.com/brylsherbert247)) | Forked for Capacitor 7 and 8 and published [`@brylsherbert/capacitor-video-player`](https://www.npmjs.com/package/@brylsherbert/capacitor-video-player) 7.x–8.0. |
| Oct 2025 – today | **phiamo** ([@phiamo](https://github.com/phiamo)) for DWBN | Forked for the DWBN apps: moved Android to androidx.media3 (including Cast and PiP), native subtitle menus, seek/position events, audio↔video handoff with [capacitor-plugin-playlist](https://github.com/phiamo/capacitor-plugin-playlist), and Widevine DRM through [drm-kit](https://github.com/phiamo/drm-kit). Published as **`@dwbn/capacitor-video-player`**. |

The Android namespace `com.jeep.plugin.capacitor.capacitorvideoplayer` and the `jeepCapVideoPlayer*` event names still carry Jean Pierre's "jeep" prefix. They are kept on purpose, for compatibility and as a nod to where it all started.

## Maintainers

| Maintainer | GitHub | Role | Active |
| --- | --- | --- | --- |
| Philipp Mohrenweiser | [phiamo](https://github.com/phiamo) | Maintainer of this fork (`@dwbn`) | ✅ |
| Bryl Sherbert | [brylsherbert247](https://github.com/brylsherbert247) | Capacitor 7/8 fork (`@brylsherbert`) | — |
| Harmon Wood | [harmonwood](https://github.com/harmonwood) | Maintainer of the original (6.x) | — |
| Quéau Jean Pierre | [jepiqueau](https://github.com/jepiqueau) | Founder (1.x–5.x) | ❌ |

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


Older documentation (Capacitor 2–5 usage, tutorials, example apps) is collected in [legacy.md](./legacy.md).
