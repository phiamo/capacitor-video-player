package com.jeep.plugin.capacitor.capacitorvideoplayer;

import androidx.media3.common.Player;

/**
 * Optional link to the playlist plugin so the audio FGS notification controls video during handoff.
 * Uses reflection so this module does not depend on capacitor-plugin-playlist.
 */
final class DwbnVideoHandoffBridge {

  private static final String BRIDGE_CLASS = "org.dwbn.plugins.playlist.handoff.VideoPlayerBridge";

  private DwbnVideoHandoffBridge() {}

  static void attach(Player player) {
    invoke("attach", player);
  }

  static void detach(Player player) {
    invoke("detach", player);
  }

  private static void invoke(String methodName, Player player) {
    try {
      Class<?> bridge = Class.forName(BRIDGE_CLASS);
      bridge.getMethod(methodName, Player.class).invoke(null, player);
    } catch (Throwable ignored) {
      // Playlist plugin not on classpath (standalone video plugin builds).
    }
  }
}
