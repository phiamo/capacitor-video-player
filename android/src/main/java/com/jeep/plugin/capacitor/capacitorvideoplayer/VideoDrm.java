package com.jeep.plugin.capacitor.capacitorvideoplayer;

import androidx.media3.common.util.UnstableApi;
import com.getcapacitor.JSObject;
import java.util.function.Consumer;

/**
 * Plugin-owned DRM provider registry. The host app registers drm-kit in Story 57.6; this module
 * does not depend on drm-kit.
 */
@UnstableApi
public final class VideoDrm {

  public static final String CODE_NO_PROVIDER = "noProvider";
  public static final String CODE_NOT_SUPPORTED = "notSupported";
  public static final String NOT_SUPPORTED_MESSAGE = "DRM not supported on this platform yet";

  public static final String ERROR_BLOCKED_BY_STREAM_LIMIT = "blockedByStreamLimit";
  public static final String ERROR_NOT_ENTITLED = "notEntitled";
  public static final String ERROR_EXPIRED = "expired";
  public static final String ERROR_NETWORK = "network";
  public static final String ERROR_UNKNOWN = "unknown";

  private static volatile VideoDrmProvider provider;

  private VideoDrm() {}

  public static void setProvider(VideoDrmProvider next) {
    provider = next;
  }

  public static VideoDrmProvider getProvider() {
    return provider;
  }

  /**
   * Open a session when {@code drm} is set. Missing {@code drm} is plain playback. Missing provider
   * with {@code drm} set is {@link #CODE_NO_PROVIDER}.
   */
  public static OpenAttempt open(JSObject drm, Consumer<String> onError) {
    if (drm == null) {
      return OpenAttempt.none();
    }
    VideoDrmProvider registered = getProvider();
    if (registered == null) {
      return OpenAttempt.noProvider();
    }
    return OpenAttempt.ok(registered.open(drm, onError));
  }

  public static JSObject errorListenerData(String fromPlayerId, String error) {
    JSObject data = new JSObject();
    data.put("fromPlayerId", fromPlayerId);
    data.put("error", error);
    return data;
  }

  public static final class OpenAttempt {

    public final VideoDrmSession session;
    public final String failureCode;

    private OpenAttempt(VideoDrmSession session, String failureCode) {
      this.session = session;
      this.failureCode = failureCode;
    }

    public static OpenAttempt none() {
      return new OpenAttempt(null, null);
    }

    public static OpenAttempt noProvider() {
      return new OpenAttempt(null, CODE_NO_PROVIDER);
    }

    public static OpenAttempt ok(VideoDrmSession session) {
      return new OpenAttempt(session, null);
    }
  }
}
