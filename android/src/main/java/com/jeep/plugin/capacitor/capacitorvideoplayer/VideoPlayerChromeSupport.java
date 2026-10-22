package com.jeep.plugin.capacitor.capacitorvideoplayer;

import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.view.WindowManager;
import android.widget.ImageView;
import androidx.appcompat.view.ContextThemeWrapper;
import androidx.core.content.ContextCompat;
import androidx.core.graphics.drawable.DrawableCompat;
import androidx.mediarouter.app.MediaRouteButton;
import com.bumptech.glide.Glide;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.concurrent.TimeUnit;

/** Package-visible helpers for Cast artwork and player chrome setup (testable without inflating the fragment). */
final class VideoPlayerChromeSupport {

  static final int ARTWORK_READ_TIMEOUT_MS = 10_000;
  static final int ARTWORK_MAX_PX = 1280;

  private VideoPlayerChromeSupport() {}

  static boolean hasNonEmptyText(String value) {
    return value != null && !value.isEmpty();
  }

  static boolean canApplyCastArtwork(boolean fragmentAdded, ImageView castImageView) {
    return fragmentAdded && castImageView != null;
  }

  static boolean isRemoteHttpArtworkUrl(String image) {
    if (image == null || image.isEmpty()) {
      return false;
    }
    try {
      URL url = new URL(image);
      String protocol = url.getProtocol();
      return "http".equalsIgnoreCase(protocol) || "https".equalsIgnoreCase(protocol);
    } catch (MalformedURLException ignored) {
      return false;
    }
  }

  static int playerCutoutMode() {
    return WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS;
  }

  static void loadCastArtworkInto(ImageView target, String image) {
    if (target == null || !isRemoteHttpArtworkUrl(image)) {
      return;
    }
    Glide.with(target)
      .load(image)
      .override(ARTWORK_MAX_PX, ARTWORK_MAX_PX)
      .centerCrop()
      .timeout(ARTWORK_READ_TIMEOUT_MS)
      .into(target);
  }

  static Bitmap decodeCastArtworkBitmap(Context context, String image) {
    if (context == null || !isRemoteHttpArtworkUrl(image)) {
      return null;
    }
    try {
      return Glide.with(context.getApplicationContext())
        .asBitmap()
        .load(image)
        .override(ARTWORK_MAX_PX, ARTWORK_MAX_PX)
        .timeout(ARTWORK_READ_TIMEOUT_MS)
        .submit()
        .get(ARTWORK_READ_TIMEOUT_MS, TimeUnit.MILLISECONDS);
    } catch (Exception ignored) {
      return null;
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
