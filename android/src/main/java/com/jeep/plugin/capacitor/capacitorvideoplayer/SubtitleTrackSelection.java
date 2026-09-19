package com.jeep.plugin.capacitor.capacitorvideoplayer;

import androidx.media3.common.C;
import androidx.media3.common.Format;
import androidx.media3.common.TrackSelectionOverride;
import androidx.media3.common.TrackSelectionParameters;
import androidx.media3.common.util.UnstableApi;

/**
 * Media3 subtitle pick / change / off via {@link TrackSelectionParameters}.
 */
@UnstableApi
final class SubtitleTrackSelection {

  static final String OFF_LANGUAGE = "off";

  private SubtitleTrackSelection() {}

  static boolean isTextDisabled(TrackSelectionParameters params) {
    return params.disabledTrackTypes.contains(C.TRACK_TYPE_TEXT);
  }

  static String offLanguageIfDisabled(TrackSelectionParameters params) {
    return isTextDisabled(params) ? OFF_LANGUAGE : null;
  }

  static boolean formatMatches(Format format, String trackId, String trackLanguage) {
    if (format.id != null && format.id.equals(trackId)) {
      return true;
    }
    if (trackLanguage != null && format.language != null && format.language.equals(trackLanguage)) {
      return true;
    }
    return format.language != null && format.language.equals(trackId);
  }

  static TrackSelectionParameters withTextOverride(
    TrackSelectionParameters current,
    TrackSelectionOverride override
  ) {
    return current
      .buildUpon()
      .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
      .clearOverridesOfType(C.TRACK_TYPE_TEXT)
      .addOverride(override)
      .build();
  }

  static TrackSelectionParameters withTextDisabled(TrackSelectionParameters current) {
    return current.buildUpon().clearOverridesOfType(C.TRACK_TYPE_TEXT).setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true).build();
  }
}
