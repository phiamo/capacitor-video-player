package com.jeep.plugin.capacitor.capacitorvideoplayer;

import com.getcapacitor.JSObject;
import java.security.cert.CertificateException;
import java.security.cert.CertPathValidatorException;
import javax.net.ssl.SSLHandshakeException;
import javax.net.ssl.SSLPeerUnverifiedException;

/**
 * Load-failure codes on {@code jeepCapVideoPlayerError} for an item that never became ready.
 * Separate from typed DRM discriminators — those stay on {@link VideoDrm}.
 */
public final class VideoPlaybackError {

  public static final String CERTIFICATE = "certificate";
  public static final String GENERIC = "generic";

  private VideoPlaybackError() {}

  public static String from(Throwable error) {
    return isCertificateFailure(error) ? CERTIFICATE : GENERIC;
  }

  public static JSObject listenerData(String fromPlayerId, String error) {
    String code = CERTIFICATE.equals(error) ? CERTIFICATE : GENERIC;
    JSObject data = new JSObject();
    data.put("fromPlayerId", fromPlayerId);
    data.put("error", code);
    data.put("code", code);
    return data;
  }

  public static boolean isCertificateFailure(Throwable error) {
    Throwable current = error;
    while (current != null) {
      if (
        current instanceof SSLHandshakeException ||
        current instanceof SSLPeerUnverifiedException ||
        current instanceof CertPathValidatorException ||
        current instanceof CertificateException
      ) {
        return true;
      }
      current = current.getCause();
    }
    return false;
  }
}
