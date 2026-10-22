package com.jeep.plugin.capacitor.capacitorvideoplayer;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import android.graphics.Color;
import android.view.WindowManager;
import android.widget.ImageView;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 28)
public class VideoPlayerChromeSupportTest {

  @Test
  public void hasNonEmptyText_usesValueNotIdentity() {
    assertFalse(VideoPlayerChromeSupport.hasNonEmptyText(null));
    assertFalse(VideoPlayerChromeSupport.hasNonEmptyText(""));
    assertFalse(VideoPlayerChromeSupport.hasNonEmptyText(new String("")));
    assertTrue(VideoPlayerChromeSupport.hasNonEmptyText("https://example.com/art.jpg"));
  }

  @Test
  public void isRemoteHttpArtworkUrl_rejectsNullEmptyAndNonHttp() {
    assertFalse(VideoPlayerChromeSupport.isRemoteHttpArtworkUrl(null));
    assertFalse(VideoPlayerChromeSupport.isRemoteHttpArtworkUrl(""));
    assertFalse(VideoPlayerChromeSupport.isRemoteHttpArtworkUrl("file:///tmp/art.png"));
    assertFalse(VideoPlayerChromeSupport.isRemoteHttpArtworkUrl("not a url"));
    assertTrue(VideoPlayerChromeSupport.isRemoteHttpArtworkUrl("https://example.com/art.jpg"));
    assertTrue(VideoPlayerChromeSupport.isRemoteHttpArtworkUrl("http://example.com/art.jpg"));
  }

  @Test
  public void decodeCastArtworkBitmap_nullOrEmpty_returnsNull() {
    assertNull(VideoPlayerChromeSupport.decodeCastArtworkBitmap(RuntimeEnvironment.getApplication(), null));
    assertNull(VideoPlayerChromeSupport.decodeCastArtworkBitmap(RuntimeEnvironment.getApplication(), ""));
    assertNull(VideoPlayerChromeSupport.decodeCastArtworkBitmap(null, "https://example.com/art.jpg"));
  }

  @Test
  public void decodeCastArtworkBitmap_nonHttp_returnsNullWithoutException() {
    assertNull(VideoPlayerChromeSupport.decodeCastArtworkBitmap(RuntimeEnvironment.getApplication(), "file:///tmp/art.png"));
  }

  @Test
  public void loadCastArtworkInto_nonHttp_doesNotThrow() {
    ImageView view = new ImageView(RuntimeEnvironment.getApplication());
    VideoPlayerChromeSupport.loadCastArtworkInto(null, "https://example.com/art.jpg");
    VideoPlayerChromeSupport.loadCastArtworkInto(view, null);
    VideoPlayerChromeSupport.loadCastArtworkInto(view, "");
    VideoPlayerChromeSupport.loadCastArtworkInto(view, "file:///tmp/art.png");
  }

  @Test
  public void playerCutoutMode_isAlwaysNotDeprecatedDefault() {
    assertEquals(
      WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS,
      VideoPlayerChromeSupport.playerCutoutMode()
    );
    assertTrue(
      VideoPlayerChromeSupport.playerCutoutMode() != WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_DEFAULT
    );
    assertTrue(
      VideoPlayerChromeSupport.playerCutoutMode() != WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
    );
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
