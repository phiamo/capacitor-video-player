package com.jeep.plugin.capacitor.capacitorvideoplayer;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertTrue;

import androidx.media3.common.MediaItem;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.drm.DrmSessionManager;
import com.getcapacitor.JSObject;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;
import org.junit.After;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 24)
@UnstableApi
public class VideoDrmTest {

  @After
  public void tearDown() {
    VideoDrm.setProvider(null);
  }

  @Test
  public void getProvider_defaultIsNull() {
    assertNull(VideoDrm.getProvider());
  }

  @Test
  public void open_withoutDrm_isPlainPlayback() {
    VideoDrm.OpenAttempt attempt = VideoDrm.open(null, error -> {});
    assertNull(attempt.failureCode);
    assertNull(attempt.session);
  }

  @Test
  public void open_drmWithoutProvider_isNoProvider() {
    JSObject drm = new JSObject();
    drm.put("widevineLicenseUrl", "https://license.example/wv");
    VideoDrm.OpenAttempt attempt = VideoDrm.open(drm, error -> {});
    assertEquals(VideoDrm.CODE_NO_PROVIDER, attempt.failureCode);
    assertNull(attempt.session);
  }

  @Test
  public void open_withProvider_returnsSession() {
    FakeVideoDrmSession session = new FakeVideoDrmSession();
    VideoDrm.setProvider((drm, onError) -> session);
    JSObject drm = new JSObject();
    drm.put("playbackSessionId", "sess-1");
    VideoDrm.OpenAttempt attempt = VideoDrm.open(drm, error -> {});
    assertNull(attempt.failureCode);
    assertSame(session, attempt.session);
  }

  @Test
  public void errorListenerData_carriesDiscriminator() {
    JSObject data = VideoDrm.errorListenerData("fullscreen", VideoDrm.ERROR_BLOCKED_BY_STREAM_LIMIT);
    assertEquals("fullscreen", data.getString("fromPlayerId"));
    assertEquals("blockedByStreamLimit", data.getString("error"));
  }

  @Test
  public void providerOnError_emitsTypedPayload() {
    List<String> errors = new ArrayList<>();
    VideoDrm.setProvider(
      (drm, onError) -> {
        FakeVideoDrmSession session = new FakeVideoDrmSession();
        session.onError = onError;
        return session;
      }
    );
    JSObject drm = new JSObject();
    VideoDrm.OpenAttempt attempt = VideoDrm.open(drm, errors::add);
    FakeVideoDrmSession session = (FakeVideoDrmSession) attempt.session;
    session.onError.accept(VideoDrm.ERROR_NOT_ENTITLED);
    JSObject payload = VideoDrm.errorListenerData("p1", errors.get(0));
    assertEquals("p1", payload.getString("fromPlayerId"));
    assertEquals("notEntitled", payload.getString("error"));
    assertTrue(errors.size() == 1);
  }

  private static final class FakeVideoDrmSession implements VideoDrmSession {

    Consumer<String> onError;

    @Override
    public void applyDrm(MediaItem.Builder builder) {
      builder.setDrmConfiguration(new MediaItem.DrmConfiguration.Builder(androidx.media3.common.C.WIDEVINE_UUID).build());
    }

    @Override
    public DrmSessionManager getDrmSessionManager() {
      return DrmSessionManager.DRM_UNSUPPORTED;
    }

    @Override
    public void start() {}

    @Override
    public void release() {}
  }
}
