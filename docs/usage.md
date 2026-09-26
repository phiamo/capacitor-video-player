# Usage

## Getting started

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
  subtitles: [{ id: 'en', url: 'https://example.com/en.vtt', language: 'en', label: 'English' }],
});
```

All options are in [API.md](./API.md#capvideoplayeroptions).

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
| jeepCapVideoPlayerPositionUpdate | ✅ | ✅ | ❌ | ✅ |
| jeepCapVideoPlayerBackground | ✅ | ✅ | ❌ | ❌ |
| jeepCapVideoPlayerError (DRM) | ✅ | ❌ | ❌ | ❌ |

### Seek / subtitle listener payloads

- **`jeepCapVideoPlayerSeek`:** `fromPlayerId`, `fromPosition`, `toPosition` (seconds). `duration` is included only when the duration is known (finite / player ready).
- **`jeepCapVideoPlayerSubtitleChange`:** `fromPlayerId`, `language` (IETF tag, `off`, or `und`). `trackId` is set when the app supplied manifest `subtitles[].id` can be matched (iOS native menu); otherwise omitted.

- **`jeepCapVideoPlayerPositionUpdate`:** `playerId`, `currentTime` (seconds), sent periodically while playing. Use it to keep an [audio handoff](./video-handoff.md) position current.
- **`jeepCapVideoPlayerExit`:** `dismiss`, `currentTime`.
- **`jeepCapVideoPlayerError`:** `fromPlayerId`, `error`, one of the [DRM error codes](./drm.md#errors).

Methods not in the table: `getLastKnownPosition({ playerId })` returns the last head that native saved, even if the WebView was suspended. `exitFullScreen`, `echo`.

Full reference: [API.md](./API.md).
