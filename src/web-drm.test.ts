import { beforeEach, describe, expect, it } from 'vitest';

import { CapacitorVideoPlayerWeb } from './web';

function stubDocument(): void {
  const g = globalThis as typeof globalThis & { document?: unknown };
  g.document = {
    addEventListener(): void {},
    removeEventListener(): void {},
    querySelector(): null {
      return null;
    },
    createElement(): Record<string, unknown> {
      return { id: '', appendChild(): void {} };
    },
  };
}

describe('CapacitorVideoPlayerWeb.initPlayer drm', () => {
  beforeEach(() => {
    stubDocument();
  });

  it('resolves notSupported and does not create a player', async () => {
    const player = new CapacitorVideoPlayerWeb();
    const result = await player.initPlayer({
      mode: 'fullscreen',
      url: 'https://cdn.example/drm/video.m3u8',
      playerId: 'fullscreen',
      drm: {
        widevineLicenseUrl: 'https://license.example/wv',
        playbackSessionId: 'sess-1',
        renewalCredential: 'cred',
        streamLimit: { mode: 'axinom_csl', renewalIntervalSeconds: 300 },
      },
    });
    expect(result).toEqual({
      result: false,
      method: 'initPlayer',
      code: 'notSupported',
      message: 'DRM not supported on this platform yet',
    });
    expect((player as unknown as { _players: unknown })._players).toEqual([]);
  });
});
