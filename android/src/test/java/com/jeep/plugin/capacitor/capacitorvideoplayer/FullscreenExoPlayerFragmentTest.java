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
