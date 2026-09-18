package com.jeep.plugin.capacitor.capacitorvideoplayer;

import android.net.Uri;
import androidx.media3.common.MediaItem;
import androidx.media3.common.MimeTypes;

/**
 * Single factory for video {@link MediaItem} instances. Story 55.1 — no DRM; later epics attach
 * {@link MediaItem.DrmConfiguration} here only.
 */
public final class VideoMediaItemFactory {

  private VideoMediaItemFactory() {}

  public static MediaItem fromUri(Uri uri) {
    return fromUriAndType(uri, null);
  }

  public static MediaItem fromUriAndType(Uri uri, String vType) {
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
    return builder.build();
  }
}
