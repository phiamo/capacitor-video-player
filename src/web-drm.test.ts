import { describe, expect, it } from 'vitest';

import { webDrmNotSupported } from './web';

describe('webDrmNotSupported', () => {
  it('allows initPlayer without drm', () => {
    expect(webDrmNotSupported({ url: 'https://example.com/lecture.mp4' })).toBeNull();
  });

  it('refuses drm before a player is created', () => {
    expect(
      webDrmNotSupported({
        url: 'https://cdn.example/drm/video.m3u8',
        drm: {
          widevineLicenseUrl: 'https://license.example/wv',
          playbackSessionId: 'sess-1',
          renewalCredential: 'cred',
          streamLimit: { mode: 'axinom_csl', renewalIntervalSeconds: 300 },
        },
      }),
    ).toEqual({
      result: false,
      method: 'initPlayer',
      code: 'notSupported',
      message: 'DRM not supported on this platform yet',
    });
  });
});
