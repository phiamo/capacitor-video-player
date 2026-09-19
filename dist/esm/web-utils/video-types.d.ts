export type videoExtension = 'mp4' | 'webm' | 'cmaf' | 'cmfv' | 'm3u8';
export type videoMimeType = 'video/mp4' | 'application/x-mpegURL';
export declare const possibleQueryParameterExtensions: string[];
export declare const videoTypes: Record<videoExtension, videoMimeType>;
/**
 * Mime type the web player uses for `url`: the path's extension wins (`.../playlist.m3u8`,
 * `mp4:lecture.mp4/playlist.m3u8`), then an extension query parameter (`?type=m3u8`), and a URL
 * without any extension is treated as mp4. An extension the web player cannot play returns null.
 */
export declare const detectVideoType: (url: string | null | undefined) => videoMimeType | null;
