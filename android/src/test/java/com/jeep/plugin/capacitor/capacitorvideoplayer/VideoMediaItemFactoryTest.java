package com.jeep.plugin.capacitor.capacitorvideoplayer;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import android.net.Uri;
import androidx.media3.common.C;
import androidx.media3.common.MediaItem;
import androidx.media3.common.MimeTypes;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 24)
public class VideoMediaItemFactoryTest {

  private static final Uri VIDEO_URI = Uri.parse("https://example.com/lecture.mp4");

  @Test
  public void fromUri_withoutSidecars_hasNoSubtitleConfigurations() {
    MediaItem item = VideoMediaItemFactory.fromUri(VIDEO_URI);

    assertNotNull(item.localConfiguration);
    assertTrue(item.localConfiguration.subtitleConfigurations.isEmpty());
  }

  @Test
  public void fromUriAndType_oneVtt_mapsSubtitleConfiguration() {
    SubtitleTrack de = new SubtitleTrack("de", "https://example.com/de.vtt", "de");
    de.setLabel("Deutsch");
    MediaItem item = VideoMediaItemFactory.fromUriAndType(
      Uri.parse("https://example.com/lecture.m3u8"),
      "m3u8",
      Collections.singletonList(de)
    );

    List<MediaItem.SubtitleConfiguration> configs = item.localConfiguration.subtitleConfigurations;
    assertEquals(1, configs.size());
    MediaItem.SubtitleConfiguration cfg = configs.get(0);
    assertEquals("de", cfg.id);
    assertEquals("de", cfg.language);
    assertEquals("Deutsch", cfg.label);
    assertEquals(MimeTypes.TEXT_VTT, cfg.mimeType);
    assertEquals(Uri.parse("https://example.com/de.vtt"), cfg.uri);
    assertEquals(C.ROLE_FLAG_SUBTITLE, cfg.roleFlags);
  }

  @Test
  public void fromUri_oneVtt_mapsSubtitleConfiguration() {
    SubtitleTrack de = new SubtitleTrack("de", "https://example.com/de.vtt", "de");
    de.setLabel("Deutsch");
    MediaItem item = VideoMediaItemFactory.fromUri(VIDEO_URI, Collections.singletonList(de));

    List<MediaItem.SubtitleConfiguration> configs = item.localConfiguration.subtitleConfigurations;
    assertEquals(1, configs.size());
    MediaItem.SubtitleConfiguration cfg = configs.get(0);
    assertEquals("de", cfg.id);
    assertEquals("de", cfg.language);
    assertEquals("Deutsch", cfg.label);
    assertEquals(MimeTypes.TEXT_VTT, cfg.mimeType);
    assertEquals(Uri.parse("https://example.com/de.vtt"), cfg.uri);
    assertEquals(C.ROLE_FLAG_SUBTITLE, cfg.roleFlags);
  }

  @Test
  public void fromUriAndType_multiTracks_mapsMimeAndFlags() {
    SubtitleTrack de = new SubtitleTrack("de", "https://example.com/de.vtt", "de");
    de.setDefault(true);
    SubtitleTrack en = new SubtitleTrack("en", "https://example.com/en.srt", "en");
    en.setForced(true);
    SubtitleTrack fr = new SubtitleTrack("fr", "https://example.com/fr.ass", "fr");
    SubtitleTrack ttml = new SubtitleTrack("tt", "https://example.com/tt.ttml", "tt");

    MediaItem item = VideoMediaItemFactory.fromUriAndType(VIDEO_URI, "mp4", Arrays.asList(de, en, fr, ttml));

    List<MediaItem.SubtitleConfiguration> configs = item.localConfiguration.subtitleConfigurations;
    assertEquals(4, configs.size());
    assertEquals(MimeTypes.TEXT_VTT, configs.get(0).mimeType);
    assertEquals(C.SELECTION_FLAG_DEFAULT, configs.get(0).selectionFlags);
    assertEquals(MimeTypes.APPLICATION_SUBRIP, configs.get(1).mimeType);
    assertEquals(C.SELECTION_FLAG_FORCED, configs.get(1).selectionFlags);
    assertEquals(MimeTypes.TEXT_SSA, configs.get(2).mimeType);
    assertEquals("fr", configs.get(2).id);
    assertEquals(MimeTypes.APPLICATION_TTML, configs.get(3).mimeType);
  }

  @Test
  public void fromUriAndType_deprecatedSingle_idIsLanguage() {
    List<SubtitleTrack> tracks = VideoMediaItemFactory.singleTrackFromUri(
      Uri.parse("https://example.com/de.vtt"),
      "de"
    );
    MediaItem item = VideoMediaItemFactory.fromUriAndType(VIDEO_URI, "mp4", tracks);

    assertEquals(1, item.localConfiguration.subtitleConfigurations.size());
    MediaItem.SubtitleConfiguration cfg = item.localConfiguration.subtitleConfigurations.get(0);
    assertEquals("de", cfg.id);
    assertEquals("de", cfg.language);
    assertEquals(MimeTypes.TEXT_VTT, cfg.mimeType);
    assertEquals(Uri.parse("https://example.com/de.vtt"), cfg.uri);
    assertEquals(C.SELECTION_FLAG_DEFAULT, cfg.selectionFlags);
  }
}
