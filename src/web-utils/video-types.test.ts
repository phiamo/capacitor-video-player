import { describe, expect, it } from 'vitest';

import { detectVideoType } from './video-types';

describe('detectVideoType', () => {
  it('reads the extension from the path, not the host name', () => {
    expect(detectVideoType('https://vod.example.org/lecture.mp4')).toBe('video/mp4');
    expect(detectVideoType('https://vod.example.org/live/playlist.m3u8?token=abc')).toBe('application/x-mpegURL');
  });

  it('treats a Wowza mp4 VOD playlist as HLS', () => {
    expect(detectVideoType('https://vod.example.org/vod/mp4:lecture.mp4/playlist.m3u8')).toBe('application/x-mpegURL');
  });

  it('reads the extension from a query parameter', () => {
    expect(detectVideoType('https://youtube.example.org/?v=7894289374&type=m3u8')).toBe('application/x-mpegURL');
    expect(detectVideoType('https://vimeo.example.org/?file=my-video.mp4')).toBe('video/mp4');
    expect(detectVideoType('https://vimeo.example.org/?file=clip.mkv')).toBe(null);
    expect(detectVideoType('https://vimeo.example.org/?ext=webm')).toBe('video/mp4');
  });

  it('rejects extensions the web player cannot play', () => {
    expect(detectVideoType('https://vimeo.example.org/not-supported.mkv')).toBe(null);
    expect(detectVideoType('https://youtube.example.org/?v=3982748927&filetype=mkv')).toBe(null);
  });

  it('assumes mp4 when the URL has no extension', () => {
    expect(detectVideoType('https://stream.example.org/video/42')).toBe('video/mp4');
    expect(detectVideoType('blob:https://app.example.org/6f1c')).toBe('video/mp4');
  });

  it('returns null without a URL', () => {
    expect(detectVideoType('')).toBe(null);
    expect(detectVideoType(undefined)).toBe(null);
  });

  it('accepts uppercase path extensions', () => {
    expect(detectVideoType('https://vod.example.org/lecture.M3U8')).toBe('application/x-mpegURL');
  });

  it('parses relative paths with a base URL', () => {
    expect(detectVideoType('/media/clip.mp4')).toBe('video/mp4');
  });

  it('ignores URL fragments when reading the path extension', () => {
    expect(detectVideoType('https://vod.example.org/lecture.mp4#t=120')).toBe('video/mp4');
  });
});
