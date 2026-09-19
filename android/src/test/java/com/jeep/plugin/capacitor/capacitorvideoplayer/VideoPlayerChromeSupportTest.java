package com.jeep.plugin.capacitor.capacitorvideoplayer;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import android.graphics.Bitmap;
import android.graphics.Color;
import android.widget.ImageView;
import java.net.HttpURLConnection;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 24)
public class VideoPlayerChromeSupportTest {

  @Test
  public void hasNonEmptyText_usesValueNotIdentity() {
    assertFalse(VideoPlayerChromeSupport.hasNonEmptyText(null));
    assertFalse(VideoPlayerChromeSupport.hasNonEmptyText(""));
    assertFalse(VideoPlayerChromeSupport.hasNonEmptyText(new String("")));
    assertTrue(VideoPlayerChromeSupport.hasNonEmptyText("https://example.com/art.jpg"));
  }

  @Test
  public void decodeCastArtworkBitmap_nullOrEmpty_returnsNull() {
    assertNull(VideoPlayerChromeSupport.decodeCastArtworkBitmap(null));
    assertNull(VideoPlayerChromeSupport.decodeCastArtworkBitmap(""));
  }

  @Test
  public void decodeCastArtworkBitmap_nonHttp_returnsNullWithoutException() {
    assertNull(VideoPlayerChromeSupport.decodeCastArtworkBitmap("file:///tmp/art.png"));
  }

  @Test
  public void configureArtworkConnection_setsTenSecondTimeouts() {
    HttpURLConnection connection = new HttpURLConnection(null) {
      @Override
      public void disconnect() {}

      @Override
      public boolean usingProxy() {
        return false;
      }

      @Override
      public void connect() {}
    };
    VideoPlayerChromeSupport.configureArtworkConnection(connection);
    assertEquals(VideoPlayerChromeSupport.ARTWORK_CONNECT_TIMEOUT_MS, connection.getConnectTimeout());
    assertEquals(VideoPlayerChromeSupport.ARTWORK_READ_TIMEOUT_MS, connection.getReadTimeout());
  }

  @Test
  public void canApplyCastArtwork_requiresAddedFragmentAndView() {
    ImageView view = new ImageView(RuntimeEnvironment.getApplication());
    assertFalse(VideoPlayerChromeSupport.canApplyCastArtwork(false, view));
    assertFalse(VideoPlayerChromeSupport.canApplyCastArtwork(true, null));
    assertTrue(VideoPlayerChromeSupport.canApplyCastArtwork(true, view));
  }

  @Test
  public void parseAccentColorOrNull_invalidOrEmpty_returnsNull() {
    assertNull(VideoPlayerChromeSupport.parseAccentColorOrNull(null));
    assertNull(VideoPlayerChromeSupport.parseAccentColorOrNull(""));
    assertNull(VideoPlayerChromeSupport.parseAccentColorOrNull("#not-a-color"));
  }

  @Test
  public void parseAccentColorOrNull_validHex_returnsColor() {
    assertEquals(Color.RED, (int) VideoPlayerChromeSupport.parseAccentColorOrNull("#FF0000"));
  }

  @Test
  public void applyMediaRouteButtonWhiteTint_nullContextOrButton_doesNotThrow() {
    VideoPlayerChromeSupport.applyMediaRouteButtonWhiteTint(null, null);
    VideoPlayerChromeSupport.applyMediaRouteButtonWhiteTint(RuntimeEnvironment.getApplication(), null);
  }
}
