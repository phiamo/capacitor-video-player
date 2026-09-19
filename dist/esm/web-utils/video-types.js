export const possibleQueryParameterExtensions = [
    'file',
    'extension',
    'filetype',
    'type',
    'ext',
];
export const videoTypes = {
    mp4: 'video/mp4',
    webm: 'video/mp4',
    cmaf: 'video/mp4',
    cmfv: 'video/mp4',
    m3u8: 'application/x-mpegURL',
};
const mimeTypeForExtension = (extension) => {
    if (!extension) {
        return undefined;
    }
    const lower = extension.toLowerCase();
    return lower in videoTypes ? videoTypes[lower] : null;
};
/**
 * Mime type the web player uses for `url`: the path's extension wins (`.../playlist.m3u8`,
 * `mp4:lecture.mp4/playlist.m3u8`), then an extension query parameter (`?type=m3u8`), and a URL
 * without any extension is treated as mp4. An extension the web player cannot play returns null.
 */
export const detectVideoType = (url) => {
    var _a, _b;
    if (!url) {
        return null;
    }
    let path = url;
    let query = '';
    try {
        const parsed = new URL(url, 'http://localhost');
        path = parsed.pathname;
        query = parsed.search;
    }
    catch (_c) {
        const queryStart = url.indexOf('?');
        if (queryStart >= 0) {
            path = url.substring(0, queryStart);
            query = url.substring(queryStart);
        }
    }
    const fromPath = mimeTypeForExtension((_a = path.match(/\.([a-z0-9]+)$/i)) === null || _a === void 0 ? void 0 : _a[1]);
    if (fromPath !== undefined) {
        return fromPath;
    }
    const params = new URLSearchParams(query);
    for (const key of possibleQueryParameterExtensions) {
        const value = (_b = params.get(key)) !== null && _b !== void 0 ? _b : undefined;
        const fromQuery = mimeTypeForExtension((value === null || value === void 0 ? void 0 : value.includes('.')) ? value.split('.').pop() : value);
        if (fromQuery !== undefined) {
            return fromQuery;
        }
    }
    return 'video/mp4';
};
//# sourceMappingURL=video-types.js.map