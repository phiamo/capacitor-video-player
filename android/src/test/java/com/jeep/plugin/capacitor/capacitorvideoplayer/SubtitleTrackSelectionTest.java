package com.jeep.plugin.capacitor.capacitorvideoplayer;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import androidx.media3.common.C;
import androidx.media3.common.Format;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.TrackGroup;
import androidx.media3.common.TrackSelectionOverride;
import androidx.media3.common.TrackSelectionParameters;
import androidx.media3.common.util.UnstableApi;
import com.google.common.collect.ImmutableList;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 24)
@UnstableApi
public class SubtitleTrackSelectionTest {

  @Test
  public void formatMatches_pickByIdOrLanguage() {
    Format format = new Format.Builder().setId("track-de").setLanguage("de").setSampleMimeType(MimeTypes.TEXT_VTT).build();

    assertTrue(SubtitleTrackSelection.formatMatches(format, "track-de", null));
    assertTrue(SubtitleTrackSelection.formatMatches(format, "other", "de"));
    assertTrue(SubtitleTrackSelection.formatMatches(format, "de", null));
    assertFalse(SubtitleTrackSelection.formatMatches(format, "en", "en"));
  }

  @Test
  public void withTextOverride_enablesTextAndAddsOverride() {
    Format format = new Format.Builder().setId("de").setLanguage("de").setSampleMimeType(MimeTypes.TEXT_VTT).build();
    TrackGroup group = new TrackGroup(format);
    TrackSelectionOverride override = new TrackSelectionOverride(group, ImmutableList.of(0));
    TrackSelectionParameters current = new TrackSelectionParameters.Builder(RuntimeEnvironment.getApplication())
      .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
      .build();

    TrackSelectionParameters next = SubtitleTrackSelection.withTextOverride(current, override);

    assertFalse(SubtitleTrackSelection.isTextDisabled(next));
    assertEquals(override, next.overrides.get(group));
  }

  @Test
  public void withTextDisabled_emitsOffViaParameters() {
    TrackSelectionParameters current = new TrackSelectionParameters.Builder(RuntimeEnvironment.getApplication()).build();

    TrackSelectionParameters next = SubtitleTrackSelection.withTextDisabled(current);

    assertTrue(SubtitleTrackSelection.isTextDisabled(next));
    assertEquals(null, SubtitleTrackSelection.offLanguageIfDisabled(current));
    assertEquals(SubtitleTrackSelection.OFF_LANGUAGE, SubtitleTrackSelection.offLanguageIfDisabled(next));
  }
}
