package com.jeep.plugin.capacitor.capacitorvideoplayer;

import androidx.media3.common.PlaybackException;
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
    Consumer<String> typedOnError = error -> {
      if (onError != null) {
        onError.accept(typedError(error));
      }
    };
    try {
      VideoDrmSession session = registered.open(drm, typedOnError);
      if (session == null) {
        return OpenAttempt.noProvider();
      }
      return OpenAttempt.ok(session);
    } catch (RuntimeException e) {
      typedOnError.accept(ERROR_UNKNOWN);
      return OpenAttempt.noProvider();
    }
  }

  public static String typedError(String error) {
    if (
      ERROR_BLOCKED_BY_STREAM_LIMIT.equals(error) ||
      ERROR_NOT_ENTITLED.equals(error) ||
      ERROR_EXPIRED.equals(error) ||
      ERROR_NETWORK.equals(error) ||
      ERROR_UNKNOWN.equals(error)
    ) {
      return error;
    }
    return ERROR_UNKNOWN;
  }

  public static JSObject errorListenerData(String fromPlayerId, String error) {
    JSObject data = new JSObject();
    data.put("fromPlayerId", fromPlayerId);
    data.put("error", typedError(error));
    return data;
  }

  /**
   * Maps ExoPlayer DRM failures (CDM KEY_EXPIRED / 6006 / 6008) to a typed JS discriminator.
   * Non-DRM errors return null so the fragment keeps its existing exit path.
   */
  public static String fromPlaybackException(PlaybackException error) {
    if (error == null) {
      return null;
    }
    if (!isDrmPlaybackError(error)) {
      return null;
    }
    if (isKeyExpired(error)) {
      return ERROR_EXPIRED;
    }
    return ERROR_UNKNOWN;
  }

  static boolean isDrmPlaybackError(PlaybackException error) {
    int code = error.errorCode;
    if (
      code >= PlaybackException.ERROR_CODE_DRM_UNSPECIFIED &&
      code < PlaybackException.ERROR_CODE_DRM_UNSPECIFIED + 1000
    ) {
      return true;
    }
    return causeLooksLikeDrm(error);
  }

  static boolean isKeyExpired(Throwable error) {
    Throwable current = error;
    while (current != null) {
      if (current instanceof PlaybackException) {
        int code = ((PlaybackException) current).errorCode;
        if (
          code == PlaybackException.ERROR_CODE_DRM_LICENSE_EXPIRED ||
          code == PlaybackException.ERROR_CODE_DRM_SYSTEM_ERROR
        ) {
          return true;
        }
      }
      if (messageLooksExpired(current)) {
        return true;
      }
      current = current.getCause();
    }
    return false;
  }

  private static boolean causeLooksLikeDrm(Throwable error) {
    Throwable current = error;
    while (current != null) {
      String name = current.getClass().getName();
      if (name.contains("CryptoException") || name.contains("MediaDrm") || name.contains("DrmSession")) {
        return true;
      }
      if (messageLooksExpired(current)) {
        return true;
      }
      current = current.getCause();
    }
    return false;
  }

  private static boolean messageLooksExpired(Throwable error) {
    String message = error.getMessage();
    if (message == null) {
      return false;
    }
    String upper = message.toUpperCase();
    return (
      upper.contains("ERROR_KEY_EXPIRED") ||
      upper.contains("KEY_EXPIRED") ||
      upper.contains("ERROR_DRM_NO_LICENSE") ||
      upper.contains("DRM_NO_LICENSE")
    );
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
