package com.jeep.plugin.capacitor.capacitorvideoplayer;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import androidx.media3.cast.RemoteCastPlayer;
import androidx.media3.common.DeviceInfo;
import androidx.media3.common.util.UnstableApi;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 24)
@UnstableApi
public class FullscreenExoPlayerFragmentTest {

  @Test
  public void isRemoteCastConnected_nullPlayer_isFalse() {
    assertFalse(FullscreenExoPlayerFragment.isRemoteCastConnected((androidx.media3.common.Player) null));
  }

  @Test
  public void isRemoteCastConnected_nullDeviceInfo_isFalse() {
    assertFalse(FullscreenExoPlayerFragment.isRemoteCastConnected((DeviceInfo) null));
  }

  @Test
  public void isRemoteCastConnected_localPlayback_isFalse() {
    DeviceInfo local = new DeviceInfo.Builder(DeviceInfo.PLAYBACK_TYPE_LOCAL).build();
    assertFalse(FullscreenExoPlayerFragment.isRemoteCastConnected(local));
  }

  @Test
  public void isRemoteCastConnected_remoteEmptySentinel_isFalse() {
    assertFalse(FullscreenExoPlayerFragment.isRemoteCastConnected(RemoteCastPlayer.DEVICE_INFO_REMOTE_EMPTY));
  }

  @Test
  public void isRemoteCastConnected_remoteWithRoutingId_isTrue() {
    DeviceInfo remote = new DeviceInfo.Builder(DeviceInfo.PLAYBACK_TYPE_REMOTE)
      .setRoutingControllerId("cast-session")
      .build();
    assertTrue(FullscreenExoPlayerFragment.isRemoteCastConnected(remote));
  }

  @Test
  public void fragmentSource_doesNotUseDeprecatedPipFullscreenOrCastSessionApis() throws IOException {
    String source = new String(Files.readAllBytes(fragmentSource()), StandardCharsets.UTF_8);
    assertFalse("no-arg PiP", source.matches("(?s).*enterPictureInPictureMode\\(\\s*\\).*"));
    assertTrue(source.contains("enterPictureInPictureMode(pictureInPictureParams"));
    assertTrue(source.contains("VERSION_CODES.O"));
    assertFalse(source.contains("LayoutParams.FLAG_FULLSCREEN"));
    assertFalse(source.contains("setSessionAvailabilityListener"));
    assertTrue(source.contains("onDeviceInfoChanged"));
    assertTrue(source.contains("new RemoteCastPlayer.Builder"));
    assertTrue(source.contains("DwbnVideoHandoffBridge.attach"));
    assertTrue(source.contains("DwbnVideoHandoffBridge.detach"));
    int castBuilder = source.indexOf("new MediaItem.Builder()");
    assertTrue(castBuilder >= 0);
    String castItem = source.substring(castBuilder, source.indexOf(".build();", castBuilder));
    assertFalse("Cast MediaItem must not attach DRM", castItem.contains("setDrmConfiguration"));
    assertTrue(source.contains("player.prepare();\n      if (drmSession != null) {\n        drmSession.start();"));
    assertTrue(source.contains("drmSession.release();"));
    assertTrue(source.indexOf("drmSession.release();") < source.indexOf("player.release();"));
    assertTrue(source.contains("void setInitialPlaybackPositionMs(long positionMs)"));
    assertTrue(source.contains("player.setMediaSource(mediaSource, playbackPosition)"));
    assertFalse(source.contains("Toast.makeText(context, \"Video Url not found\""));
    assertTrue(source.contains("onPlayerError"));
    assertTrue(source.contains("ERROR_CODE_IO_BAD_HTTP_STATUS"));
    assertTrue(source.contains("duration != C.TIME_UNSET"));
  }

  @Test
  public void pluginSource_appliesInitPlayerSeektimeToFragment() throws IOException {
    Path[] candidates = {
      Paths.get("src/main/java/com/jeep/plugin/capacitor/capacitorvideoplayer/CapacitorVideoPlayerPlugin.java"),
      Paths.get("../capacitor-video-player/android/src/main/java/com/jeep/plugin/capacitor/capacitorvideoplayer/CapacitorVideoPlayerPlugin.java"),
      Paths.get("../../capacitor-video-player/android/src/main/java/com/jeep/plugin/capacitor/capacitorvideoplayer/CapacitorVideoPlayerPlugin.java"),
    };
    Path plugin = null;
    for (Path path : candidates) {
      if (Files.isRegularFile(path)) {
        plugin = path;
        break;
      }
    }
    assertTrue(plugin != null);
    String source = new String(Files.readAllBytes(plugin), StandardCharsets.UTF_8);
    assertTrue(source.contains("call.getDouble(\"seektime\")"));
    assertTrue(source.contains("setInitialPlaybackPositionMs(initialSeekMs)"));
  }

  private static Path fragmentSource() {
    Path[] candidates = {
      Paths.get("src/main/java/com/jeep/plugin/capacitor/capacitorvideoplayer/FullscreenExoPlayerFragment.java"),
      Paths.get("../capacitor-video-player/android/src/main/java/com/jeep/plugin/capacitor/capacitorvideoplayer/FullscreenExoPlayerFragment.java"),
      Paths.get("../../capacitor-video-player/android/src/main/java/com/jeep/plugin/capacitor/capacitorvideoplayer/FullscreenExoPlayerFragment.java"),
    };
    for (Path path : candidates) {
      if (Files.isRegularFile(path)) {
        return path;
      }
    }
    throw new AssertionError("FullscreenExoPlayerFragment.java not found from " + Paths.get("").toAbsolutePath());
  }
}
