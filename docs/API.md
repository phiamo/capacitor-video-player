# API Documentation

## Methods Index

<docgen-index>

* [`echo(...)`](#echo)
* [`initPlayer(...)`](#initplayer)
* [`isPlaying(...)`](#isplaying)
* [`play(...)`](#play)
* [`pause(...)`](#pause)
* [`getDuration(...)`](#getduration)
* [`getCurrentTime(...)`](#getcurrenttime)
* [`getLastKnownPosition(...)`](#getlastknownposition)
* [`setCurrentTime(...)`](#setcurrenttime)
* [`getVolume(...)`](#getvolume)
* [`setVolume(...)`](#setvolume)
* [`getMuted(...)`](#getmuted)
* [`setMuted(...)`](#setmuted)
* [`setRate(...)`](#setrate)
* [`getRate(...)`](#getrate)
* [`stopAllPlayers()`](#stopallplayers)
* [`showController()`](#showcontroller)
* [`isControllerIsFullyVisible()`](#iscontrollerisfullyvisible)
* [`exitPlayer()`](#exitplayer)
* [`exitFullScreen(...)`](#exitfullscreen)
* [`getSubtitleTracks(...)`](#getsubtitletracks)
* [`selectSubtitleTrack(...)`](#selectsubtitletrack)
* [`disableSubtitles(...)`](#disablesubtitles)
* [`getSelectedSubtitleTrack(...)`](#getselectedsubtitletrack)
* [`addListener('jeepCapVideoPlayerReady', ...)`](#addlistenerjeepcapvideoplayerready-)
* [`addListener('jeepCapVideoPlayerPlay', ...)`](#addlistenerjeepcapvideoplayerplay-)
* [`addListener('jeepCapVideoPlayerPause', ...)`](#addlistenerjeepcapvideoplayerpause-)
* [`addListener('jeepCapVideoPlayerEnded', ...)`](#addlistenerjeepcapvideoplayerended-)
* [`addListener('jeepCapVideoPlayerExit', ...)`](#addlistenerjeepcapvideoplayerexit-)
* [`addListener('jeepCapVideoPlayerPositionUpdate', ...)`](#addlistenerjeepcapvideoplayerpositionupdate-)
* [`addListener('jeepCapVideoPlayerSeek', ...)`](#addlistenerjeepcapvideoplayerseek-)
* [`addListener('jeepCapVideoPlayerSubtitleChange', ...)`](#addlistenerjeepcapvideoplayersubtitlechange-)
* [`addListener('jeepCapVideoPlayerBackground', ...)`](#addlistenerjeepcapvideoplayerbackground-)
* [`addListener('jeepCapVideoPlayerPipStart', ...)`](#addlistenerjeepcapvideoplayerpipstart-)
* [`addListener('jeepCapVideoPlayerPipStop', ...)`](#addlistenerjeepcapvideoplayerpipstop-)
* [`addListener('jeepCapVideoPlayerError', ...)`](#addlistenerjeepcapvideoplayererror-)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>
* [Listeners](#listeners)

## Url

### from the Web

. `http:/..../video.mp4`
. `https:/..../video.mp4`

### from Asset

- iOS Plugin
  . `"public/assets/video/video.mp4"`

- Android Plugin
  . `"public/assets/video/video.mp4"` not anymore the `resource/raw folder`

- Web & Electron Plugins
  . `"assets/video/video.mp4"`

### from Application Folder

- iOS Plugin
  . `application/files/video.mp4` is corresponding to :
  **/data/Containers/Data/Applications/YOUR_APPLICATION/Documents/files/video.mp4**

- Android Plugin
  . `application/files/video.mp4` is corresponding to :
  **/data/user/0/YOUR_APPLICATION_PACKAGE/files/video.mp4**

### from your Device Media

- iOS & Android Plugin only
  . `internal`

### from DCIM folder

- Android Plugin 
  . `file:///sdcard/DCIM/Camera/YOUR_VIDEO` 
  . `file:///storage/extSdCard/DCIM/Camera/YOUR_VIDEO`

- iOS Plugin 
  . `file:///var/mobile/Media/DCIM/100APPLE/YOUR_VIDEO`
  . `file:///var/mobile/Containers/Data/Application/YOUR_APPLICATION_ID/tmp/YOUR_VIDEO`
  
  
## Subtitle (Android, iOS Only)

### Supported Formats

- Android Plugin
  . `WebVTT .vtt extension`
  . `TTML/SMPTE .ttml, .dfxp, .xml extensions`
  . `SubRip .srt extension`
  . `SubStationAlpha .ssa, .ass extensions`

- iOS Plugin
  . `WebVTT .vtt extension`

### from the Web

. `http:/..../video.vtt`
. `https:/..../video.vtt`

### from Asset

- Android Plugin
  . `"public/assets/video/video.srt"`

- iOS Plugin
  . `"public/assets/video/video.vtt"`

### from Application Folder

- Android Plugin
  . `application/files/video.vtt` is corresponding to :
  **/data/user/0/YOUR_APPLICATION_PACKAGE/files//video.vtt**

- iOS Plugin
  . `application/files/video.vtt` is corresponding to :
  **/data/Containers/Data/Applications/YOUR_APPLICATION/Documents/files/video.vtt**

### from Internal (Gallery, DCIM)

- Android plugin
  .for API higher than 28 add the following in the app manifest file

  ```
      <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
  ```
  and you will be prompted for authorization to access media files. 

## Chromecast Support

  Android Only

### Chromecast explanation

The cast option is enabled by default, otherwise you can disable it with the option chromecast = false in InitPlayer options.

Cast button will only be available if your cast devices are connected in the same WIFI network, if not, the button won't be visible.

Some videos won't work with Cast, as not every video format is supported.

When you start casting, the video controllers will be available to control your cast. If you exit the app or close the video, the cast will end automatically.

Cast title will be the same as title and smallTitle, if these are not added, then it will be blank

### Android setup (8.3.0+)

Chromecast requires manifest meta-data in your **host** app. The plugin bundles Media3 and Cast dependencies — do **not** pin old ExoPlayer 2 or `play-services-cast-framework:21.2.0` in your app `build.gradle`.

 - AndroidManifest.xml

```xml
<application>
    ...
    <meta-data
        android:name="com.google.android.gms.cast.framework.OPTIONS_PROVIDER_CLASS_NAME"
        android:value="androidx.media3.cast.DefaultCastOptionsProvider" />
</application>
```

If you upgraded from **8.2.x**, replace `com.google.android.exoplayer2.ext.cast.DefaultCastOptionsProvider` with the value above.

**ProGuard / R8** (release builds with `minifyEnabled true`):

```proguard
-keep class androidx.media3.cast.DefaultCastOptionsProvider { *; }
```

Cast is initialized asynchronously inside the fullscreen player — you do **not** need `CastContext.getSharedInstance(this)` in `MainActivity`.

**Upgrading from 8.2.x:** pin `media3Version = '1.11.1'` and force every `androidx.media3` module in the host Gradle (see [Upgrading to 8.3.0](./upgrading.md#to-830-media3)).

## Methods

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### echo(...)

```typescript
echo(options: capEchoOptions) => Promise<capVideoPlayerResult>
```

Echo

| Param         | Type                                                      |
| ------------- | --------------------------------------------------------- |
| **`options`** | <code><a href="#capechooptions">capEchoOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### initPlayer(...)

```typescript
initPlayer(options: capVideoPlayerOptions) => Promise<capVideoPlayerResult>
```

Initialize a video player

| Param         | Type                                                                    |
| ------------- | ----------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeroptions">capVideoPlayerOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### isPlaying(...)

```typescript
isPlaying(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Return if a given playerId is playing

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### play(...)

```typescript
play(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Play the current video from a given playerId

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### pause(...)

```typescript
pause(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Pause the current video from a given playerId

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### getDuration(...)

```typescript
getDuration(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Get the duration of the current video from a given playerId

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### getCurrentTime(...)

```typescript
getCurrentTime(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Get the current time of the current video from a given playerId

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### getLastKnownPosition(...)

```typescript
getLastKnownPosition(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Last playback head (seconds) persisted on native when position ticks fire;
survives WebView suspension (Epic 45 / PR-2).

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### setCurrentTime(...)

```typescript
setCurrentTime(options: capVideoTimeOptions) => Promise<capVideoPlayerResult>
```

Set the current time to seek the current video to from a given playerId

| Param         | Type                                                                |
| ------------- | ------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideotimeoptions">capVideoTimeOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### getVolume(...)

```typescript
getVolume(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Get the volume of the current video from a given playerId

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### setVolume(...)

```typescript
setVolume(options: capVideoVolumeOptions) => Promise<capVideoPlayerResult>
```

Set the volume of the current video to from a given playerId

| Param         | Type                                                                    |
| ------------- | ----------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideovolumeoptions">capVideoVolumeOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### getMuted(...)

```typescript
getMuted(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Get the muted of the current video from a given playerId

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### setMuted(...)

```typescript
setMuted(options: capVideoMutedOptions) => Promise<capVideoPlayerResult>
```

Set the muted of the current video to from a given playerId

| Param         | Type                                                                  |
| ------------- | --------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideomutedoptions">capVideoMutedOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### setRate(...)

```typescript
setRate(options: capVideoRateOptions) => Promise<capVideoPlayerResult>
```

Set the rate of the current video from a given playerId

| Param         | Type                                                                |
| ------------- | ------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideorateoptions">capVideoRateOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### getRate(...)

```typescript
getRate(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Get the rate of the current video from a given playerId

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### stopAllPlayers()

```typescript
stopAllPlayers() => Promise<capVideoPlayerResult>
```

Stop all players playing

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### showController()

```typescript
showController() => Promise<capVideoPlayerResult>
```

Show controller

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### isControllerIsFullyVisible()

```typescript
isControllerIsFullyVisible() => Promise<capVideoPlayerResult>
```

isControllerIsFullyVisible

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### exitPlayer()

```typescript
exitPlayer() => Promise<capVideoPlayerResult>
```

Exit player

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### exitFullScreen(...)

```typescript
exitFullScreen(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Exit fullscreen mode for a given playerId

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### getSubtitleTracks(...)

```typescript
getSubtitleTracks(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Get available subtitle tracks for a player

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### selectSubtitleTrack(...)

```typescript
selectSubtitleTrack(options: capSubtitleTrackOptions) => Promise<capVideoPlayerResult>
```

Select a subtitle track by ID

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capsubtitletrackoptions">capSubtitleTrackOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### disableSubtitles(...)

```typescript
disableSubtitles(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Disable subtitles (hide current track)

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### getSelectedSubtitleTrack(...)

```typescript
getSelectedSubtitleTrack(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Get currently selected subtitle track

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### addListener('jeepCapVideoPlayerReady', ...)

```typescript
addListener(eventName: 'jeepCapVideoPlayerReady', listenerFunc: (data: capVideoListener) => void) => Promise<PluginListenerHandle>
```

Player is ready to play.

| Param              | Type                                                                             |
| ------------------ | -------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'jeepCapVideoPlayerReady'</code>                                           |
| **`listenerFunc`** | <code>(data: <a href="#capvideolistener">capVideoListener</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('jeepCapVideoPlayerPlay', ...)

```typescript
addListener(eventName: 'jeepCapVideoPlayerPlay', listenerFunc: (data: capVideoListener) => void) => Promise<PluginListenerHandle>
```

Playback started or resumed.

| Param              | Type                                                                             |
| ------------------ | -------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'jeepCapVideoPlayerPlay'</code>                                            |
| **`listenerFunc`** | <code>(data: <a href="#capvideolistener">capVideoListener</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('jeepCapVideoPlayerPause', ...)

```typescript
addListener(eventName: 'jeepCapVideoPlayerPause', listenerFunc: (data: capVideoListener) => void) => Promise<PluginListenerHandle>
```

Playback paused.

| Param              | Type                                                                             |
| ------------------ | -------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'jeepCapVideoPlayerPause'</code>                                           |
| **`listenerFunc`** | <code>(data: <a href="#capvideolistener">capVideoListener</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('jeepCapVideoPlayerEnded', ...)

```typescript
addListener(eventName: 'jeepCapVideoPlayerEnded', listenerFunc: (data: capVideoListener) => void) => Promise<PluginListenerHandle>
```

Video reached its end.

| Param              | Type                                                                             |
| ------------------ | -------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'jeepCapVideoPlayerEnded'</code>                                           |
| **`listenerFunc`** | <code>(data: <a href="#capvideolistener">capVideoListener</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('jeepCapVideoPlayerExit', ...)

```typescript
addListener(eventName: 'jeepCapVideoPlayerExit', listenerFunc: (data: capExitListener) => void) => Promise<PluginListenerHandle>
```

Fullscreen player closed; `currentTime` is the head at exit.

| Param              | Type                                                                           |
| ------------------ | ------------------------------------------------------------------------------ |
| **`eventName`**    | <code>'jeepCapVideoPlayerExit'</code>                                          |
| **`listenerFunc`** | <code>(data: <a href="#capexitlistener">capExitListener</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('jeepCapVideoPlayerPositionUpdate', ...)

```typescript
addListener(eventName: 'jeepCapVideoPlayerPositionUpdate', listenerFunc: (data: capPositionUpdateListener) => void) => Promise<PluginListenerHandle>
```

Periodic playback head while playing.

| Param              | Type                                                                                               |
| ------------------ | -------------------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'jeepCapVideoPlayerPositionUpdate'</code>                                                    |
| **`listenerFunc`** | <code>(data: <a href="#cappositionupdatelistener">capPositionUpdateListener</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('jeepCapVideoPlayerSeek', ...)

```typescript
addListener(eventName: 'jeepCapVideoPlayerSeek', listenerFunc: (data: capSeekCompletedListener) => void) => Promise<PluginListenerHandle>
```

A seek completed.

| Param              | Type                                                                                             |
| ------------------ | ------------------------------------------------------------------------------------------------ |
| **`eventName`**    | <code>'jeepCapVideoPlayerSeek'</code>                                                            |
| **`listenerFunc`** | <code>(data: <a href="#capseekcompletedlistener">capSeekCompletedListener</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('jeepCapVideoPlayerSubtitleChange', ...)

```typescript
addListener(eventName: 'jeepCapVideoPlayerSubtitleChange', listenerFunc: (data: capSubtitleChangeListener) => void) => Promise<PluginListenerHandle>
```

The user picked another subtitle track (or turned subtitles off).

| Param              | Type                                                                                               |
| ------------------ | -------------------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'jeepCapVideoPlayerSubtitleChange'</code>                                                    |
| **`listenerFunc`** | <code>(data: <a href="#capsubtitlechangelistener">capSubtitleChangeListener</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('jeepCapVideoPlayerBackground', ...)

```typescript
addListener(eventName: 'jeepCapVideoPlayerBackground', listenerFunc: (data: capVideoPlayerBackgroundData) => void) => Promise<PluginListenerHandle>
```

| Param              | Type                                                                                                     |
| ------------------ | -------------------------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'jeepCapVideoPlayerBackground'</code>                                                              |
| **`listenerFunc`** | <code>(data: <a href="#capvideoplayerbackgrounddata">capVideoPlayerBackgroundData</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('jeepCapVideoPlayerPipStart', ...)

```typescript
addListener(eventName: 'jeepCapVideoPlayerPipStart', listenerFunc: (data: capVideoPlayerPipListener) => void) => Promise<PluginListenerHandle>
```

| Param              | Type                                                                                               |
| ------------------ | -------------------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'jeepCapVideoPlayerPipStart'</code>                                                          |
| **`listenerFunc`** | <code>(data: <a href="#capvideoplayerpiplistener">capVideoPlayerPipListener</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('jeepCapVideoPlayerPipStop', ...)

```typescript
addListener(eventName: 'jeepCapVideoPlayerPipStop', listenerFunc: (data: capVideoPlayerPipListener) => void) => Promise<PluginListenerHandle>
```

| Param              | Type                                                                                               |
| ------------------ | -------------------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'jeepCapVideoPlayerPipStop'</code>                                                           |
| **`listenerFunc`** | <code>(data: <a href="#capvideoplayerpiplistener">capVideoPlayerPipListener</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('jeepCapVideoPlayerError', ...)

```typescript
addListener(eventName: 'jeepCapVideoPlayerError', listenerFunc: (data: capVideoPlayerDrmErrorData) => void) => Promise<PluginListenerHandle>
```

Typed DRM playback error from the host-registered provider (Android).
Discriminator is exactly one of the five strings in <a href="#capvideoplayerdrmerror">`capVideoPlayerDrmError`</a>.

| Param              | Type                                                                                                 |
| ------------------ | ---------------------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'jeepCapVideoPlayerError'</code>                                                               |
| **`listenerFunc`** | <code>(data: <a href="#capvideoplayerdrmerrordata">capVideoPlayerDrmErrorData</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### Interfaces


#### capVideoPlayerResult

| Prop          | Type                 | Description                                                                                                                                                                                         |
| ------------- | -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`result`**  | <code>boolean</code> | result set to true when successful else false                                                                                                                                                       |
| **`method`**  | <code>string</code>  | method name                                                                                                                                                                                         |
| **`value`**   | <code>any</code>     | value returned                                                                                                                                                                                      |
| **`message`** | <code>string</code>  | message string                                                                                                                                                                                      |
| **`code`**    | <code>string</code>  | Machine-readable failure: `noProvider` (Android or iOS, `drm` set but the host did not register a provider) or `notSupported` (web, when `drm` is set — iOS returns `noProvider` since Story 58.4). |


#### capEchoOptions

| Prop        | Type                | Description         |
| ----------- | ------------------- | ------------------- |
| **`value`** | <code>string</code> | String to be echoed |


#### capVideoPlayerOptions

| Prop                         | Type                                                              | Description                                                                                                                                                                                                                                                                                             |
| ---------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`mode`**                   | <code>string</code>                                               | Player mode - "fullscreen" - "embedded" (Web only)                                                                                                                                                                                                                                                      |
| **`url`**                    | <code>string</code>                                               | The url of the video to play                                                                                                                                                                                                                                                                            |
| **`subtitle`**               | <code>string</code>                                               | The url of subtitle associated with the video                                                                                                                                                                                                                                                           |
| **`language`**               | <code>string</code>                                               | The language of subtitle see https://github.com/libyal/libfwnt/wiki/Language-Code-identifiers                                                                                                                                                                                                           |
| **`subtitles`**              | <code>SubtitleTrack[]</code>                                      | Multiple subtitle tracks Array of subtitle track definitions                                                                                                                                                                                                                                            |
| **`selectedSubtitleId`**     | <code>string</code>                                               | Initial selected subtitle track ID If not specified, first track with isDefault=true is selected, or first track if none marked as default                                                                                                                                                              |
| **`subtitleOptions`**        | <code><a href="#subtitleoptions">SubTitleOptions</a></code>       | SubTitle Options Shared styling for all tracks (can be overridden per-track later)                                                                                                                                                                                                                      |
| **`playerId`**               | <code>string</code>                                               | Id of DIV Element parent of the player                                                                                                                                                                                                                                                                  |
| **`rate`**                   | <code>number</code>                                               | Initial playing rate                                                                                                                                                                                                                                                                                    |
| **`exitOnEnd`**              | <code>boolean</code>                                              | Exit on VideoEnd (iOS, Android) default: true                                                                                                                                                                                                                                                           |
| **`loopOnEnd`**              | <code>boolean</code>                                              | Loop on VideoEnd when exitOnEnd false (iOS, Android) default: false                                                                                                                                                                                                                                     |
| **`pipEnabled`**             | <code>boolean</code>                                              | Picture in Picture Enable (iOS, Android) default: true                                                                                                                                                                                                                                                  |
| **`bkmodeEnabled`**          | <code>boolean</code>                                              | Background Mode Enable (iOS, Android) default: true                                                                                                                                                                                                                                                     |
| **`showControls`**           | <code>boolean</code>                                              | Show Controls Enable (iOS, Android) default: true                                                                                                                                                                                                                                                       |
| **`displayMode`**            | <code>string</code>                                               | Display Mode ["all", "portrait", "landscape"] (iOS, Android) default: "all"                                                                                                                                                                                                                             |
| **`componentTag`**           | <code>string</code>                                               | Component Tag or DOM Element Tag (React app)                                                                                                                                                                                                                                                            |
| **`width`**                  | <code>number</code>                                               | Player Width (mode "embedded" only)                                                                                                                                                                                                                                                                     |
| **`height`**                 | <code>number</code>                                               | Player height (mode "embedded" only)                                                                                                                                                                                                                                                                    |
| **`headers`**                | <code>{ [key: string]: string; }</code>                           | Headers for the request (iOS, Android) by Manuel García Marín (https://github.com/PhantomPainX)                                                                                                                                                                                                         |
| **`title`**                  | <code>string</code>                                               | Title shown in the player (Android) by Manuel García Marín (https://github.com/PhantomPainX)                                                                                                                                                                                                            |
| **`smallTitle`**             | <code>string</code>                                               | Subtitle shown below the title in the player (Android) by Manuel García Marín (https://github.com/PhantomPainX)                                                                                                                                                                                         |
| **`accentColor`**            | <code>string</code>                                               | ExoPlayer Progress Bar and Spinner color (Android) by Manuel García Marín (https://github.com/PhantomPainX) Must be a valid hex color code default: #FFFFFF                                                                                                                                             |
| **`chromecast`**             | <code>boolean</code>                                              | Chromecast enable/disable (Android) by Manuel García Marín (https://github.com/PhantomPainX) default: true                                                                                                                                                                                              |
| **`artwork`**                | <code>string</code>                                               | Artwork url to be shown in Chromecast player by Manuel García Marín (https://github.com/PhantomPainX) default: ""                                                                                                                                                                                       |
| **`positionUpdateInterval`** | <code>number</code>                                               | Position update interval in seconds for periodic position events default: 5                                                                                                                                                                                                                             |
| **`seektime`**               | <code>number</code>                                               | Initial seek position in seconds applied before first play (iOS/Android). Prefer this over seeking after jeepCapVideoPlayerPlay to avoid races.                                                                                                                                                         |
| **`drm`**                    | <code><a href="#capvideodrmoptions">capVideoDrmOptions</a></code> | Optional DRM descriptor fields (API names). Android and iOS attach Widevine/FairPlay through a host-registered provider. Token URL, heartbeat URL, and Bearer live on that provider, not here. FairPlay fields are ignored on Android; `widevineLicenseUrl` is ignored on iOS. Web refuses this option. |


#### SubtitleTrack

Subtitle track definition

| Prop            | Type                 | Description                                                                            |
| --------------- | -------------------- | -------------------------------------------------------------------------------------- |
| **`id`**        | <code>string</code>  | Unique identifier for the track                                                        |
| **`url`**       | <code>string</code>  | Subtitle file URL/path                                                                 |
| **`language`**  | <code>string</code>  | ISO 639-1 language code (e.g., "en", "es")                                             |
| **`label`**     | <code>string</code>  | Display label (e.g., "English", "Spanish") If not provided, language code will be used |
| **`mimeType`**  | <code>string</code>  | Optional MIME type override If not provided, will be detected from file extension      |
| **`isDefault`** | <code>boolean</code> | Default track to select If multiple tracks have isDefault=true, first one is selected  |
| **`isForced`**  | <code>boolean</code> | Forced subtitle track Forced tracks are always shown when available                    |


#### SubTitleOptions

| Prop                  | Type                | Description                                           |
| --------------------- | ------------------- | ----------------------------------------------------- |
| **`foregroundColor`** | <code>string</code> | Foreground Color in RGBA (default rgba(255,255,255,1) |
| **`backgroundColor`** | <code>string</code> | Background Color in RGBA (default rgba(0,0,0,1)       |
| **`fontSize`**        | <code>number</code> | Font Size in pixels (default 16)                      |


#### capVideoDrmOptions

| Prop                         | Type                                                                      | Description                                                             |
| ---------------------------- | ------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| **`widevineLicenseUrl`**     | <code>string</code>                                                       |                                                                         |
| **`playbackSessionId`**      | <code>string</code>                                                       |                                                                         |
| **`renewalCredential`**      | <code>string</code>                                                       |                                                                         |
| **`streamLimit`**            | <code><a href="#capvideodrmstreamlimit">capVideoDrmStreamLimit</a></code> |                                                                         |
| **`fairplayLicenseUrl`**     | <code>string</code>                                                       | Consumed by the iOS FairPlay provider (Story 58.4); ignored on Android. |
| **`fairplayCertificateUrl`** | <code>string</code>                                                       |                                                                         |


#### capVideoDrmStreamLimit

Optional `initPlayer` DRM fields. Names match the playback API.
Token / heartbeat URLs and Bearer are supplied by the host provider (57.6).

| Prop                           | Type                |
| ------------------------------ | ------------------- |
| **`mode`**                     | <code>string</code> |
| **`renewalIntervalSeconds`**   | <code>number</code> |
| **`heartbeatIntervalSeconds`** | <code>number</code> |


#### capVideoPlayerIdOptions

| Prop           | Type                | Description                            |
| -------------- | ------------------- | -------------------------------------- |
| **`playerId`** | <code>string</code> | Id of DIV Element parent of the player |


#### capVideoTimeOptions

| Prop           | Type                | Description                            |
| -------------- | ------------------- | -------------------------------------- |
| **`playerId`** | <code>string</code> | Id of DIV Element parent of the player |
| **`seektime`** | <code>number</code> | Video time value you want to seek to   |


#### capVideoVolumeOptions

| Prop           | Type                | Description                            |
| -------------- | ------------------- | -------------------------------------- |
| **`playerId`** | <code>string</code> | Id of DIV Element parent of the player |
| **`volume`**   | <code>number</code> | Volume value between [0 - 1]           |


#### capVideoMutedOptions

| Prop           | Type                 | Description                            |
| -------------- | -------------------- | -------------------------------------- |
| **`playerId`** | <code>string</code>  | Id of DIV Element parent of the player |
| **`muted`**    | <code>boolean</code> | Muted value true or false              |


#### capVideoRateOptions

| Prop           | Type                | Description                            |
| -------------- | ------------------- | -------------------------------------- |
| **`playerId`** | <code>string</code> | Id of DIV Element parent of the player |
| **`rate`**     | <code>number</code> | Rate value                             |


#### capSubtitleTrackOptions

| Prop           | Type                        | Description                                                      |
| -------------- | --------------------------- | ---------------------------------------------------------------- |
| **`playerId`** | <code>string</code>         | Id of DIV Element parent of the player                           |
| **`trackId`**  | <code>string \| null</code> | ID of track to select, or null/empty string to disable subtitles |


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |


#### capVideoListener

| Prop              | Type                | Description                                |
| ----------------- | ------------------- | ------------------------------------------ |
| **`playerId`**    | <code>string</code> | Id of DIV Element parent of the player     |
| **`currentTime`** | <code>number</code> | Video current time when listener trigerred |


#### capExitListener

| Prop              | Type                                     | Description                                                               |
| ----------------- | ---------------------------------------- | ------------------------------------------------------------------------- |
| **`dismiss`**     | <code>boolean</code>                     | Dismiss value true or false                                               |
| **`currentTime`** | <code>number</code>                      | Video current time when listener trigerred                                |
| **`wasPlaying`**  | <code>string \| number \| boolean</code> | May arrive as boolean, 0/1, or 'true'/'false' depending on native bridge. |


#### capPositionUpdateListener

| Prop              | Type                | Description                                |
| ----------------- | ------------------- | ------------------------------------------ |
| **`playerId`**    | <code>string</code> | Id of DIV Element parent of the player     |
| **`currentTime`** | <code>number</code> | Video current time when listener triggered |
| **`duration`**    | <code>number</code> | Video duration in seconds                  |


#### capSeekCompletedListener

Payload for `jeepCapVideoPlayerSeek` (seek completed; not high-frequency).

| Prop               | Type                | Description                          |
| ------------------ | ------------------- | ------------------------------------ |
| **`fromPlayerId`** | <code>string</code> |                                      |
| **`fromPosition`** | <code>number</code> | Seconds before seek                  |
| **`toPosition`**   | <code>number</code> | Seconds after seek                   |
| **`duration`**     | <code>number</code> | Total duration in seconds when known |


#### capSubtitleChangeListener

Payload for `jeepCapVideoPlayerSubtitleChange` (vendor-neutral; map to analytics in the app).

| Prop               | Type                | Description                                     |
| ------------------ | ------------------- | ----------------------------------------------- |
| **`fromPlayerId`** | <code>string</code> |                                                 |
| **`language`**     | <code>string</code> | BCP 47 / IETF language tag, `"off"`, or `"und"` |
| **`trackId`**      | <code>string</code> | Stable track id when available                  |


#### capVideoPlayerBackgroundData

Payload for the jeepCapVideoPlayerBackground event (Android: app backgrounded while playing).

| Prop               | Type                | Description                                                  |
| ------------------ | ------------------- | ------------------------------------------------------------ |
| **`fromPlayerId`** | <code>string</code> | The player id that was playing when the app was backgrounded |
| **`currentTime`**  | <code>number</code> | Playback position in seconds at the moment of backgrounding  |


#### capVideoPlayerPipListener

Payload for jeepCapVideoPlayerPipStart / jeepCapVideoPlayerPipStop (iOS/Android PiP lifecycle).

| Prop               | Type                |
| ------------------ | ------------------- |
| **`fromPlayerId`** | <code>string</code> |
| **`currentTime`**  | <code>number</code> |


#### capVideoPlayerDrmErrorData

| Prop               | Type                                                                      |
| ------------------ | ------------------------------------------------------------------------- |
| **`fromPlayerId`** | <code>string</code>                                                       |
| **`error`**        | <code><a href="#capvideoplayerdrmerror">capVideoPlayerDrmError</a></code> |


### Type Aliases


#### capVideoPlayerDrmError

Exactly the five discriminators from app `drm-playback-messages.ts`.

<code>'blockedByStreamLimit' | 'notEntitled' | 'expired' | 'network' | 'unknown'</code>

</docgen-api>

### Listeners

The listeners are attached to the plugin not anymore to the DOM document element.

| Listener                    | Type                                  | Description                             |
| --------------------------- | ------------------------------------- | --------------------------------------- |
| **jeepCapVideoPlayerReady** | [capVideoListener](#capvideolistener) | Emitted when the video start to play    |
| **jeepCapVideoPlayerPlay**  | [capVideoListener](#capvideolistener) | Emitted when the video start to play    |
| **jeepCapVideoPlayerPause** | [capVideoListener](#capvideolistener) | Emitted when the video is paused        |
| **jeepCapVideoPlayerEnded** | [capVideoListener](#capvideolistener) | Emitted when the video has ended        |
| **jeepCapVideoPlayerExit**  | [capExitListener](#capexitlistener)   | Emitted when the Exit button is clicked |

#### capVideoListener

| Prop            | Type   | Description                                |
| --------------- | ------ | ------------------------------------------ |
| **playerId**    | string | Id of DIV Element parent of the player     |
| **currentTime** | number | Video current time when listener trigerred |

#### capExitListener

| Prop            | Type    | Description                                |
| --------------- | ------- | ------------------------------------------ |
| **dismiss**     | boolean | Dismiss value true or false                |
| **currentTime** | number  | Video current time when listener trigerred |