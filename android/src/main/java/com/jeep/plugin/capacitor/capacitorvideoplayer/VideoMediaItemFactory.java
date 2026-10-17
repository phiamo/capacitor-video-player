package com.jeep.plugin.capacitor.capacitorvideoplayer;

import android.net.Uri;
import androidx.media3.common.C;
import androidx.media3.common.MediaItem;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.util.UnstableApi;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

/**
 * Single factory for video {@link MediaItem} instances. Story 57.4 — optional {@link
 * VideoDrmSession#applyDrm} is the only place Widevine {@link MediaItem.DrmConfiguration}
 * attaches. Story 55.2 — sidecar tracks are {@link MediaItem.SubtitleConfiguration} on this item.
 */
@UnstableApi
public final class VideoMediaItemFactory {

  private VideoMediaItemFactory() {}

  public static MediaItem fromUri(Uri uri) {
    return fromUriAndType(uri, null, null);
  }

  public static MediaItem fromUri(Uri uri, List<SubtitleTrack> tracks) {
    return fromUriAndType(uri, null, tracks);
  }

  public static MediaItem fromUriAndType(Uri uri, String vType) {
    return fromUriAndType(uri, vType, null);
  }

  public static MediaItem fromUriAndType(Uri uri, String vType, List<SubtitleTrack> tracks) {
    return fromUriAndType(uri, vType, tracks, null);
  }

  public static MediaItem fromUriAndType(
    Uri uri,
    String vType,
    List<SubtitleTrack> tracks,
    VideoDrmSession drmSession
  ) {
    MediaItem.Builder builder = new MediaItem.Builder().setUri(uri);
    if (vType != null) {
      switch (vType) {
        case "m3u8":
          builder.setMimeType(MimeTypes.APPLICATION_M3U8);
          break;
        case "dash":
        case "mpd":
          builder.setMimeType(MimeTypes.APPLICATION_MPD);
          break;
        case "ism":
          builder.setMimeType(MimeTypes.APPLICATION_SS);
          break;
        default:
          break;
      }
    }
    List<MediaItem.SubtitleConfiguration> configs = toSubtitleConfigurations(tracks);
    if (!configs.isEmpty()) {
      builder.setSubtitleConfigurations(configs);
    }
    if (drmSession != null) {
      drmSession.applyDrm(builder);
    }
    return builder.build();
  }

  /**
   * Deprecated {@code subtitle} + {@code language} path: one sidecar whose id is the language
   * string.
   */
  public static List<SubtitleTrack> singleTrackFromUri(Uri sturi, String language) {
    List<SubtitleTrack> tracks = new ArrayList<>();
    SubtitleTrack track = new SubtitleTrack();
    String lang = language != null && !language.isEmpty() ? language : "en";
    track.setId(lang);
    track.setUrl(sturi.toString());
    track.setLanguage(lang);
    track.setLabel(
      language != null && !language.isEmpty() ? Locale.forLanguageTag(language).getDisplayLanguage() : "Subtitle"
    );
    track.setDefault(true);
    tracks.add(track);
    return tracks;
  }

  static List<MediaItem.SubtitleConfiguration> toSubtitleConfigurations(List<SubtitleTrack> tracks) {
    if (tracks == null || tracks.isEmpty()) {
      return Collections.emptyList();
    }
    List<MediaItem.SubtitleConfiguration> configs = new ArrayList<>(tracks.size());
    for (SubtitleTrack track : tracks) {
      Uri trackUri = Uri.parse(track.getUrl());
      String mimeType = track.getMimeType();
      if (mimeType == null || mimeType.isEmpty()) {
        mimeType = getMimeType(trackUri);
      }

      String languageLabel = track.getLabel();
      if (languageLabel == null || languageLabel.isEmpty()) {
        languageLabel = Locale.forLanguageTag(track.getLanguage()).getDisplayLanguage();
      }

      int selectionFlags = track.isDefault() ? C.SELECTION_FLAG_DEFAULT : 0;
      if (track.isForced()) {
        selectionFlags |= C.SELECTION_FLAG_FORCED;
      }

      configs.add(
        new MediaItem.SubtitleConfiguration.Builder(trackUri)
          .setMimeType(mimeType)
          .setId(track.getId())
          .setLabel(languageLabel)
          .setRoleFlags(C.ROLE_FLAG_SUBTITLE)
          .setSelectionFlags(selectionFlags)
          .setLanguage(track.getLanguage())
          .build()
      );
    }
    return configs;
  }

  static String getMimeType(Uri sturi) {
    String lastSegment = sturi.getLastPathSegment();
    if (lastSegment == null) return MimeTypes.TEXT_VTT;
    int lastDot = lastSegment.lastIndexOf(".");
    if (lastDot == -1) return MimeTypes.TEXT_VTT;
    String extension = lastSegment.substring(lastDot + 1).toLowerCase(Locale.US);
    String mimeType = "";
    if (extension.equals("vtt")) {
      mimeType = MimeTypes.TEXT_VTT;
    } else if (extension.equals("srt")) {
      mimeType = MimeTypes.APPLICATION_SUBRIP;
    } else if (extension.equals("ssa") || extension.equals("ass")) {
      mimeType = MimeTypes.TEXT_SSA;
    } else if (extension.equals("ttml") || extension.equals("dfxp") || extension.equals("xml")) {
      mimeType = MimeTypes.APPLICATION_TTML;
    }
    return mimeType;
  }
}
