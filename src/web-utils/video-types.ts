export type videoExtension = 'mp4' | 'webm' | 'cmaf' | 'cmfv' | 'm3u8';
export type videoMimeType = 'video/mp4' | 'application/x-mpegURL';
export const possibleQueryParameterExtensions: string[] = [
  'file',
  'extension',
  'filetype',
  'type',
  'ext',
];

export const videoTypes: Record<videoExtension, videoMimeType> = {
  mp4: 'video/mp4',
  webm: 'video/mp4',
  cmaf: 'video/mp4',
  cmfv: 'video/mp4',
  m3u8: 'application/x-mpegURL',
};

const mimeTypeForExtension = (extension: string | undefined): videoMimeType | null | undefined => {
  if (!extension) {
    return undefined;
  }
  const lower = extension.toLowerCase();
  return lower in videoTypes ? videoTypes[lower as videoExtension] : null;
};

/**
 * Mime type the web player uses for `url`: the path's extension wins (`.../playlist.m3u8`,
 * `mp4:lecture.mp4/playlist.m3u8`), then an extension query parameter (`?type=m3u8`), and a URL
 * without any extension is treated as mp4. An extension the web player cannot play returns null.
 */
export const detectVideoType = (url: string | null | undefined): videoMimeType | null => {
  if (!url) {
    return null;
  }
  let path = url;
  let query = '';
  try {
    const parsed = new URL(url, 'http://localhost');
    path = parsed.pathname;
    query = parsed.search;
  } catch {
    const queryStart = url.indexOf('?');
    if (queryStart >= 0) {
      path = url.substring(0, queryStart);
      query = url.substring(queryStart);
    }
  }
  const fromPath = mimeTypeForExtension(path.match(/\.([a-z0-9]+)$/i)?.[1]);
  if (fromPath !== undefined) {
    return fromPath;
  }
  const params = new URLSearchParams(query);
  for (const key of possibleQueryParameterExtensions) {
    const value = params.get(key) ?? undefined;
    const fromQuery = mimeTypeForExtension(value?.includes('.') ? value.split('.').pop() : value);
    if (fromQuery !== undefined) {
      return fromQuery;
    }
  }
  return 'video/mp4';
};
