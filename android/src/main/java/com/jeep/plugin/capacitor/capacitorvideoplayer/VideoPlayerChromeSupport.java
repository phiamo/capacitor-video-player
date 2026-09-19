package com.jeep.plugin.capacitor.capacitorvideoplayer;

import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.widget.ImageView;
import androidx.appcompat.view.ContextThemeWrapper;
import androidx.core.content.ContextCompat;
import androidx.core.graphics.drawable.DrawableCompat;
import androidx.mediarouter.app.MediaRouteButton;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLConnection;

/** Package-visible helpers for Cast artwork and player chrome setup (testable without inflating the fragment). */
final class VideoPlayerChromeSupport {

  static final int ARTWORK_CONNECT_TIMEOUT_MS = 10_000;
  static final int ARTWORK_READ_TIMEOUT_MS = 10_000;

  private VideoPlayerChromeSupport() {}

  static boolean hasNonEmptyText(String value) {
    return value != null && !value.isEmpty();
  }

  static boolean canApplyCastArtwork(boolean fragmentAdded, ImageView castImageView) {
    return fragmentAdded && castImageView != null;
  }

  static void configureArtworkConnection(HttpURLConnection connection) {
    connection.setConnectTimeout(ARTWORK_CONNECT_TIMEOUT_MS);
    connection.setReadTimeout(ARTWORK_READ_TIMEOUT_MS);
  }

  static Bitmap decodeCastArtworkBitmap(String image) {
    if (image == null || image.isEmpty()) {
      return null;
    }
    HttpURLConnection connection = null;
    try {
      URL url = new URL(image);
      String protocol = url.getProtocol();
      if (!"http".equalsIgnoreCase(protocol) && !"https".equalsIgnoreCase(protocol)) {
        return null;
      }
      URLConnection opened = url.openConnection();
      if (!(opened instanceof HttpURLConnection)) {
        return null;
      }
      connection = (HttpURLConnection) opened;
      connection.setDoInput(true);
      configureArtworkConnection(connection);
      connection.connect();
      try (InputStream input = connection.getInputStream()) {
        return BitmapFactory.decodeStream(input);
      }
    } catch (IOException ignored) {
      return null;
    } finally {
      if (connection != null) {
        connection.disconnect();
      }
    }
  }

  static Integer parseAccentColorOrNull(String accentColor) {
    if (accentColor == null || accentColor.isEmpty()) {
      return null;
    }
    try {
      return Color.parseColor(accentColor);
    } catch (IllegalArgumentException ignored) {
      return null;
    }
  }

  static void applyMediaRouteButtonWhiteTint(Context context, MediaRouteButton button) {
    if (button == null || context == null) {
      return;
    }
    Context castContext = new ContextThemeWrapper(context, androidx.mediarouter.R.style.Theme_MediaRouter);
    TypedArray a = castContext.obtainStyledAttributes(
      null,
      androidx.mediarouter.R.styleable.MediaRouteButton,
      androidx.mediarouter.R.attr.mediaRouteButtonStyle,
      0
    );
    Drawable drawable = a.getDrawable(androidx.mediarouter.R.styleable.MediaRouteButton_externalRouteEnabledDrawable);
    a.recycle();
    if (drawable == null) {
      return;
    }
    DrawableCompat.setTint(drawable, ContextCompat.getColor(context, R.color.white));
    drawable.setState(button.getDrawableState());
    button.setRemoteIndicatorDrawable(drawable);
  }
}
