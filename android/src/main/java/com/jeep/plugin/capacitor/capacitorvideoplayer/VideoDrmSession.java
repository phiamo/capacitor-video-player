package com.jeep.plugin.capacitor.capacitorvideoplayer;

import androidx.media3.common.MediaItem;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.drm.DrmSessionManager;

/**
 * Plugin-owned DRM session. Host (Story 57.6) wraps drm-kit {@code WidevineSession}; this plugin
 * never imports drm-kit.
 */
@UnstableApi
public interface VideoDrmSession {
  /** Attach Widevine {@link MediaItem.DrmConfiguration} ({@code C.WIDEVINE_UUID}). */
  void applyDrm(MediaItem.Builder builder);

  DrmSessionManager getDrmSessionManager();

  void start();

  void release();
}
