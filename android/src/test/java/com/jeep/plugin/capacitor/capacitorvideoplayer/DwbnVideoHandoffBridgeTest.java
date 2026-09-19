package com.jeep.plugin.capacitor.capacitorvideoplayer;

import androidx.media3.common.Player;
import java.lang.reflect.Proxy;
import org.junit.Test;

public class DwbnVideoHandoffBridgeTest {

  @Test
  public void attachAndDetach_doNotThrowWhenPlaylistBridgeAbsent() {
    Player player = dummyPlayer();
    DwbnVideoHandoffBridge.attach(player);
    DwbnVideoHandoffBridge.detach(player);
  }

  private static Player dummyPlayer() {
    return (Player)
      Proxy.newProxyInstance(
        Player.class.getClassLoader(),
        new Class<?>[] { Player.class },
        (proxy, method, args) -> {
          Class<?> returnType = method.getReturnType();
          if (returnType == boolean.class) {
            return false;
          }
          if (returnType == int.class) {
            return 0;
          }
          if (returnType == long.class) {
            return 0L;
          }
          if (returnType == void.class) {
            return null;
          }
          return null;
        }
      );
  }
}
