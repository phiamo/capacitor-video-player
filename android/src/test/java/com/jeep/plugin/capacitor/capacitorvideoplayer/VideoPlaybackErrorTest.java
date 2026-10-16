package com.jeep.plugin.capacitor.capacitorvideoplayer;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import androidx.media3.common.PlaybackException;
import com.getcapacitor.JSObject;
import java.security.cert.CertificateException;
import javax.net.ssl.SSLHandshakeException;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 24)
public class VideoPlaybackErrorTest {

  @Test
  public void from_mapsSslHandshakeInCauseChain() {
    PlaybackException error = new PlaybackException(
      "ssl",
      new SSLHandshakeException("untrusted"),
      PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED
    );
    assertEquals(VideoPlaybackError.CERTIFICATE, VideoPlaybackError.from(error));
    assertTrue(VideoPlaybackError.isCertificateFailure(error));
  }

  @Test
  public void from_mapsCertificateException() {
    PlaybackException error = new PlaybackException(
      "cert",
      new CertificateException("path"),
      PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED
    );
    assertEquals(VideoPlaybackError.CERTIFICATE, VideoPlaybackError.from(error));
  }

  @Test
  public void from_httpFailureIsGeneric() {
    PlaybackException error = new PlaybackException(
      "404",
      null,
      PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS
    );
    assertEquals(VideoPlaybackError.GENERIC, VideoPlaybackError.from(error));
    assertFalse(VideoPlaybackError.isCertificateFailure(error));
  }

  @Test
  public void listenerData_usesCodeAndError() {
    JSObject data = VideoPlaybackError.listenerData("fullscreen", VideoPlaybackError.CERTIFICATE);
    assertEquals("fullscreen", data.getString("fromPlayerId"));
    assertEquals("certificate", data.getString("error"));
    assertEquals("certificate", data.getString("code"));
  }
}
