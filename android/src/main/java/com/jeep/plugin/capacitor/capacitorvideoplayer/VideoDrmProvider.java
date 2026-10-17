package com.jeep.plugin.capacitor.capacitorvideoplayer;

import androidx.media3.common.util.UnstableApi;
import com.getcapacitor.JSObject;
import java.util.function.Consumer;

/**
 * Host-registered factory for {@link VideoDrmSession}. Register from the app {@code Application}
 * via {@link VideoDrm#setProvider(VideoDrmProvider)}; do not pin drm-kit in this plugin.
 */
@UnstableApi
public interface VideoDrmProvider {
  /**
   * Open a session for {@code initPlayer} {@code drm} options. {@code onError} receives exactly one
   * discriminator: {@code blockedByStreamLimit} | {@code notEntitled} | {@code expired} |
   * {@code network} | {@code unknown}.
   */
  VideoDrmSession open(JSObject drm, Consumer<String> onError);
}
