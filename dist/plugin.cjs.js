'use strict';

var core = require('@capacitor/core');
var Hls = require('hls.js');

const CapacitorVideoPlayer = core.registerPlugin('CapacitorVideoPlayer', {
    web: () => Promise.resolve().then(function () { return web; }).then(m => new m.CapacitorVideoPlayerWeb()),
});

const possibleQueryParameterExtensions = [
    'file',
    'extension',
    'filetype',
    'type',
    'ext',
];
const videoTypes = {
    mp4: 'video/mp4',
    webm: 'video/mp4',
    cmaf: 'video/mp4',
    cmfv: 'video/mp4',
    m3u8: 'application/x-mpegURL',
};

class VideoPlayer {
    constructor(mode, url, playerId, rate, exitOnEnd, loopOnEnd, container, zIndex, width, height, subtitleTracks, selectedSubtitleId, subtitleOptions) {
        this.pipMode = false;
        this._videoType = null;
        this._videoContainer = null;
        this._firstReadyToPlay = true;
        this._isEnded = false;
        this._videoRate = 1.0;
        this._videoExitOnEnd = true;
        this._videoLoopOnEnd = false;
        this._subtitleTracks = null;
        this._selectedSubtitleId = null;
        this._subtitleTrackElements = [];
        this._subtitleMenuButton = null;
        this._subtitleMenu = null;
        this._url = url;
        this._container = container;
        this._mode = mode;
        this._width = width ? width : 320;
        this._height = height ? height : 180;
        this._mode = mode;
        this._videoRate = rate;
        this._zIndex = zIndex ? zIndex : 1;
        this._playerId = playerId;
        this._videoExitOnEnd = exitOnEnd;
        this._videoLoopOnEnd = loopOnEnd;
        this._subtitleTracks = subtitleTracks || null;
        this._selectedSubtitleId = selectedSubtitleId || null;
        this._subtitleOptions = subtitleOptions;
    }
    async initialize() {
        // get the video type
        const urlVideoType = this._getVideoType();
        if (urlVideoType) {
            // style the container
            if (this._mode === 'fullscreen') {
                this._container.style.position = 'absolute';
                this._container.style.width = '100vw';
                this._container.style.height = '100vh';
            }
            if (this._mode === 'embedded') {
                this._container.style.position = 'relative';
                this._container.style.width = this._width.toString() + 'px';
                this._container.style.height = this._height.toString() + 'px';
            }
            this._container.style.left = '0';
            this._container.style.top = '0';
            this._container.style.display = 'flex';
            this._container.style.alignItems = 'center';
            this._container.style.justifyContent = 'center';
            this._container.style.backgroundColor = '#000000';
            this._container.style.zIndex = this._zIndex.toString();
            const width = this._mode === 'fullscreen'
                ? window.innerWidth /*this._container.offsetWidth*/
                : this._width;
            const height = this._mode === 'fullscreen'
                ? window.innerHeight /*this._container.offsetHeight*/
                : this._height;
            const xmlns = 'http://www.w3.org/2000/svg';
            const svg = document.createElementNS(xmlns, 'svg');
            svg.setAttributeNS(null, 'width', width.toString());
            svg.setAttributeNS(null, 'height', height.toString());
            const viewbox = '0 0 ' + width.toString() + ' ' + height.toString();
            svg.setAttributeNS(null, 'viewBox', viewbox);
            svg.style.zIndex = (this._zIndex + 1).toString();
            const rect = document.createElementNS(xmlns, 'rect');
            rect.setAttributeNS(null, 'x', '0');
            rect.setAttributeNS(null, 'y', '0');
            rect.setAttributeNS(null, 'width', width.toString());
            rect.setAttributeNS(null, 'height', height.toString());
            rect.setAttributeNS(null, 'fill', '#000000');
            svg.appendChild(rect);
            this._container.appendChild(svg);
            const heightVideo = (width * this._height) / this._width;
            this._videoContainer = document.createElement('div');
            this._videoContainer.style.position = 'absolute';
            this._videoContainer.style.left = '0';
            this._videoContainer.style.width = width.toString() + 'px';
            this._videoContainer.style.height = heightVideo.toString() + 'px';
            this._videoContainer.style.zIndex = (this._zIndex + 2).toString();
            this._container.appendChild(this._videoContainer);
            /*   Create Video Element */
            const isCreated = await this.createVideoElement(width, heightVideo);
            if (!isCreated) {
                this._createEvent('Exit', this._playerId, 'Video Error: failed to create the Video Element');
            }
            else {
                // Initialize subtitles after video element is created
                if (this._subtitleTracks && this._subtitleTracks.length > 0) {
                    await this.initializeSubtitles();
                }
            }
        }
        else {
            this._createEvent('Exit', this._playerId, 'Url Error: type not supported');
        }
        return;
    }
    async createVideoElement(width, height) {
        this.videoEl = document.createElement('video');
        this.videoEl.controls = true;
        this.videoEl.style.zIndex = (this._zIndex + 3).toString();
        this.videoEl.style.width = `${width.toString()}px`;
        this.videoEl.style.height = `${height.toString()}px`;
        this.videoEl.playbackRate = this._videoRate;
        this._videoContainer.appendChild(this.videoEl);
        // set the player
        const isSet = await this._setPlayer();
        if (isSet) {
            this.videoEl.onended = async () => {
                this._isEnded = true;
                this.isPlaying = false;
                if (this.videoEl) {
                    this.videoEl.currentTime = 0;
                }
                if (this._videoExitOnEnd) {
                    if (this._mode === 'fullscreen') {
                        this._closeFullscreen();
                    }
                    this._createEvent('Ended', this._playerId);
                }
                else {
                    if (this._videoLoopOnEnd && this.videoEl != null) {
                        await this.videoEl.play();
                    }
                }
            };
            this.videoEl.oncanplay = async () => {
                if (this._firstReadyToPlay) {
                    this._createEvent('Ready', this._playerId);
                    if (this.videoEl != null) {
                        this.videoEl.muted = false;
                        if (this._mode === 'fullscreen')
                            await this.videoEl.play();
                        this._firstReadyToPlay = false;
                    }
                }
            };
            this.videoEl.onplay = () => {
                this.isPlaying = true;
                if (this._firstReadyToPlay)
                    this._firstReadyToPlay = false;
                this._createEvent('Play', this._playerId);
            };
            this.videoEl.onplaying = () => {
                this._createEvent('Playing', this._playerId);
            };
            this.videoEl.onpause = () => {
                this.isPlaying = false;
                this._createEvent('Pause', this._playerId);
            };
            if (this._mode === 'fullscreen') {
                // create the video player exit button
                const exitEl = document.createElement('button');
                exitEl.textContent = 'X';
                exitEl.style.position = 'absolute';
                exitEl.style.left = '1%';
                exitEl.style.top = '5%';
                exitEl.style.width = '5vmin';
                exitEl.style.padding = '0.5%';
                exitEl.style.fontSize = '1.2rem';
                exitEl.style.background = 'rgba(51,51,51,.4)';
                exitEl.style.color = '#fff';
                exitEl.style.visibility = 'hidden';
                exitEl.style.zIndex = (this._zIndex + 4).toString();
                exitEl.style.border = '1px solid rgba(51,51,51,.4)';
                exitEl.style.borderRadius = '20px';
                const showControls = async () => {
                    this._initial = await this._doHide(exitEl, 3000);
                    if (this._subtitleMenuButton) {
                        await this._doHide(this._subtitleMenuButton, 3000);
                    }
                };
                this._videoContainer.onclick = showControls;
                this._videoContainer.ontouchstart = showControls;
                this._videoContainer.onmousemove = showControls;
                exitEl.onclick = () => {
                    this._createEvent('Exit', this._playerId);
                };
                exitEl.ontouchstart = () => {
                    this._createEvent('Exit', this._playerId);
                };
                this._videoContainer.appendChild(exitEl);
                this._initial = await this._doHide(exitEl, 3000);
                this._goFullscreen();
            }
        }
        return isSet;
    }
    async _goFullscreen() {
        if (this._container.mozRequestFullScreen) {
            /* Firefox */
            this._container.mozRequestFullScreen();
        }
        else if (this._container.webkitRequestFullscreen) {
            /* Chrome, Safari & Opera */
            this._container.webkitRequestFullscreen();
        }
        else if (this._container.msRequestFullscreen) {
            /* IE/Edge */
            this._container.msRequestFullscreen();
        }
        else if (this._container.requestFullscreen) {
            this._container.requestFullscreen();
        }
        return;
    }
    async _setPlayer() {
        return new Promise(resolve => {
            if (this.videoEl != null) {
                if (Hls.isSupported() && this._videoType === 'application/x-mpegURL') {
                    const hls = new Hls();
                    hls.loadSource(this._url);
                    hls.attachMedia(this.videoEl);
                    hls.once(Hls.Events.FRAG_PARSED, () => {
                        if (this.videoEl != null) {
                            this.videoEl.muted = true;
                            this.videoEl.crossOrigin = 'anonymous';
                            resolve(true);
                        }
                        else {
                            resolve(false);
                        }
                    });
                }
                else if (this._videoType === 'video/mp4') {
                    // CMAF (fMP4) && MP4
                    this.videoEl.src = this._url;
                    if (this._url.substring(0, 5) != 'https' &&
                        this._url.substring(0, 4) === 'http')
                        this.videoEl.crossOrigin = 'anonymous';
                    if (this._url.substring(0, 5) === 'https' ||
                        this._url.substring(0, 4) === 'http')
                        this.videoEl.muted = true;
                    resolve(true);
                }
                else {
                    // Not Supported
                    resolve(false);
                }
                this.videoEl.addEventListener('enterpictureinpicture', (event) => {
                    this.pipWindow = event.pictureInPictureWindow;
                    this.pipMode = true;
                    this._closeFullscreen();
                });
                this.videoEl.addEventListener('leavepictureinpicture', () => {
                    this.pipMode = false;
                    if (!this._isEnded) {
                        this._goFullscreen();
                        if (this.videoEl != null)
                            this.videoEl.play();
                    }
                });
            }
            else {
                resolve(false);
            }
        });
    }
    _getVideoType() {
        const sUrl = this._url ? this._url : '';
        if (sUrl != null && sUrl.length > 0) {
            Object.entries(videoTypes).forEach(([extension, mimeType]) => {
                // we search for dot + extension (e.g. `.mp4`) for URLs that have the extension in the filename
                // e.g. https://vimeo.com/?file=my-video.mp4
                const hasDotExtension = sUrl.match(new RegExp(`.(${extension})`, 'i'));
                if (hasDotExtension) {
                    return (this._videoType = mimeType);
                }
                // we search for the extension (e.g. `m3u8`) for URLs that might have the extension as a query parameter
                // e.g. https://youtube.com/?v=7894289374&type=m3u8
                const hasExtensionInUrl = sUrl.match(new RegExp(`(${extension})`, 'i'));
                if (hasExtensionInUrl) {
                    return (this._videoType = mimeType);
                }
            });
            // we check for not supported extensions for URLs that have the extension in the filename
            // e.g. https://vimeo.com/?file=not-supported-extension-video.mkv
            const hasNotSupportedDotExtension = sUrl.match(/\.(.*)/i);
            if (hasNotSupportedDotExtension) {
                return (this._videoType = null);
            }
            // we check for not supported extensions for URLs that might have the extension as a query parameter
            // e.g. https://youtube.com/?v=3982748927&filetype=mkv
            const hasNotSupportedExtensionInUrl = sUrl.match(new RegExp(`(${possibleQueryParameterExtensions.join('|')})\=+(.*)&?(?=&|$))`, 'i'));
            if (hasNotSupportedExtensionInUrl) {
                return (this._videoType = null);
            }
            // No extension found, then we assume it's 'mp4' (Match case for '')
            return 'video/mp4';
        }
        // URL was not defined, we return null
        return null;
    }
    async _doHide(exitEl, duration) {
        clearTimeout(this._initial);
        exitEl.style.visibility = 'visible';
        const initial = setTimeout(() => {
            exitEl.style.visibility = 'hidden';
        }, duration);
        return initial;
    }
    _createEvent(ev, playerId, msg) {
        const message = msg ? msg : null;
        let event;
        if (message != null) {
            event = new CustomEvent(`videoPlayer${ev}`, {
                detail: { fromPlayerId: playerId, message: message },
            });
        }
        else {
            const currentTime = this.videoEl ? this.videoEl.currentTime : 0;
            event = new CustomEvent(`videoPlayer${ev}`, {
                detail: { fromPlayerId: playerId, currentTime: currentTime },
            });
        }
        document.dispatchEvent(event);
    }
    _closeFullscreen() {
        const mydoc = document;
        const isInFullScreen = (mydoc.fullscreenElement && mydoc.fullscreenElement !== null) ||
            (mydoc.webkitFullscreenElement &&
                mydoc.webkitFullscreenElement !== null) ||
            (mydoc.mozFullScreenElement && mydoc.mozFullScreenElement !== null) ||
            (mydoc.msFullscreenElement && mydoc.msFullscreenElement !== null);
        if (isInFullScreen) {
            if (mydoc.mozCancelFullScreen) {
                mydoc.mozCancelFullScreen();
            }
            else if (mydoc.webkitExitFullscreen) {
                mydoc.webkitExitFullscreen();
            }
            else if (mydoc.msExitFullscreen) {
                mydoc.msExitFullscreen();
            }
            else if (mydoc.exitFullscreen) {
                mydoc.exitFullscreen();
            }
        }
    }
    /**
     * Initialize subtitle tracks using HTML5 TextTrack API
     */
    async initializeSubtitles() {
        if (!this.videoEl || !this._subtitleTracks)
            return;
        // Clear any existing tracks
        this._subtitleTrackElements.forEach((track) => track.remove());
        this._subtitleTrackElements = [];
        // Create track elements for each subtitle
        for (const track of this._subtitleTracks) {
            const trackElement = document.createElement('track');
            trackElement.kind = 'subtitles';
            trackElement.src = track.url;
            trackElement.srclang = track.language;
            trackElement.label = track.label || track.language;
            trackElement.id = `track-${track.id}`;
            trackElement.default = track.isDefault || false;
            // Handle SRT files - convert to VTT if needed
            if (track.url.toLowerCase().endsWith('.srt')) {
                try {
                    const vttUrl = await this.convertSRTToVTT(track.url);
                    trackElement.src = vttUrl;
                }
                catch (error) {
                    console.warn(`Failed to convert SRT to VTT for track ${track.id}:`, error);
                    continue; // Skip this track if conversion fails
                }
            }
            this.videoEl.appendChild(trackElement);
            this._subtitleTrackElements.push(trackElement);
        }
        // Apply subtitle styling if provided
        if (this._subtitleOptions && this.videoEl) {
            this.applySubtitleStyling();
        }
        // Wait for tracks to load
        await this.waitForTracksLoaded();
        // Select initial track
        if (this._selectedSubtitleId) {
            this.selectSubtitleTrack(this._selectedSubtitleId);
        }
        else {
            // Find default track or first track
            const defaultTrack = this._subtitleTracks.find((t) => t.isDefault);
            if (defaultTrack) {
                this.selectSubtitleTrack(defaultTrack.id);
            }
            else if (this._subtitleTracks.length > 0) {
                this.selectSubtitleTrack(this._subtitleTracks[0].id);
            }
        }
        // Create subtitle selection UI
        if (this._mode === 'fullscreen') {
            this.createSubtitleSelectionUI();
        }
    }
    /**
     * Wait for text tracks to load
     */
    waitForTracksLoaded() {
        return new Promise((resolve) => {
            if (!this.videoEl) {
                resolve();
                return;
            }
            const tracks = Array.from(this.videoEl.textTracks);
            if (tracks.length === 0) {
                resolve();
                return;
            }
            let loadedCount = 0;
            const totalTracks = tracks.length;
            const checkLoaded = () => {
                loadedCount++;
                if (loadedCount >= totalTracks) {
                    resolve();
                }
            };
            tracks.forEach((track) => {
                // TextTrack doesn't have readyState, use mode instead
                if (track.mode === 'showing' || track.mode === 'hidden') {
                    // Track is loaded (mode is set)
                    checkLoaded();
                }
                else {
                    track.addEventListener('load', checkLoaded, { once: true });
                    track.addEventListener('error', checkLoaded, { once: true });
                }
            });
            // Timeout after 5 seconds
            setTimeout(() => {
                resolve();
            }, 5000);
        });
    }
    /**
     * Convert SRT format to VTT format
     */
    async convertSRTToVTT(srtUrl) {
        try {
            const response = await fetch(srtUrl);
            const srtContent = await response.text();
            // Simple SRT to VTT conversion
            let vttContent = 'WEBVTT\n\n';
            const lines = srtContent.split('\n');
            let i = 0;
            while (i < lines.length) {
                const line = lines[i].trim();
                // Skip sequence numbers
                if (line && !isNaN(Number(line))) {
                    i++;
                    continue;
                }
                // Check for timestamp line
                if (line.includes('-->')) {
                    // Replace comma with dot for milliseconds
                    const vttTime = line.replace(/,/g, '.');
                    vttContent += vttTime + '\n';
                    i++;
                    // Add subtitle text
                    while (i < lines.length && lines[i].trim()) {
                        vttContent += lines[i].trim() + '\n';
                        i++;
                    }
                    vttContent += '\n';
                }
                else {
                    i++;
                }
            }
            // Create blob URL
            const blob = new Blob([vttContent], { type: 'text/vtt' });
            return URL.createObjectURL(blob);
        }
        catch (error) {
            console.error('SRT to VTT conversion error:', error);
            throw error;
        }
    }
    /**
     * Select a subtitle track by ID
     */
    async selectSubtitleTrack(trackId) {
        if (!this.videoEl)
            return false;
        const tracks = Array.from(this.videoEl.textTracks);
        // Hide all tracks first
        tracks.forEach((track) => {
            track.mode = 'hidden';
        });
        if (trackId === null || trackId === '') {
            this._selectedSubtitleId = null;
            return true;
        }
        // Find and show the selected track
        const selectedTrack = tracks.find((track) => track.id === `track-${trackId}` || track.language === trackId);
        if (selectedTrack) {
            selectedTrack.mode = 'showing';
            this._selectedSubtitleId = trackId;
            this.updateSubtitleMenuButton();
            return true;
        }
        return false;
    }
    /**
     * Get available subtitle tracks
     */
    getSubtitleTracks() {
        if (!this.videoEl || !this._subtitleTracks)
            return [];
        const tracks = Array.from(this.videoEl.textTracks);
        const trackInfos = [];
        for (const track of this._subtitleTracks) {
            const htmlTrack = tracks.find((t) => t.id === `track-${track.id}` || t.language === track.language);
            trackInfos.push({
                id: track.id,
                language: track.language,
                label: track.label || track.language,
                isSelected: this._selectedSubtitleId === track.id,
                isAvailable: htmlTrack ? htmlTrack.mode !== 'disabled' : false,
            });
        }
        return trackInfos;
    }
    /**
     * Get currently selected subtitle track ID
     */
    getSelectedSubtitleTrack() {
        return this._selectedSubtitleId;
    }
    /**
     * Create subtitle selection UI
     */
    createSubtitleSelectionUI() {
        if (!this.videoEl || !this._subtitleTracks || this._subtitleTracks.length === 0) {
            return;
        }
        // Create subtitle button
        this._subtitleMenuButton = document.createElement('button');
        this._subtitleMenuButton.textContent = 'CC';
        this._subtitleMenuButton.style.position = 'absolute';
        this._subtitleMenuButton.style.right = '1%';
        this._subtitleMenuButton.style.top = '5%';
        this._subtitleMenuButton.style.width = '5vmin';
        this._subtitleMenuButton.style.padding = '0.5%';
        this._subtitleMenuButton.style.fontSize = '1.2rem';
        this._subtitleMenuButton.style.background = 'rgba(51,51,51,.4)';
        this._subtitleMenuButton.style.color = '#fff';
        this._subtitleMenuButton.style.zIndex = (this._zIndex + 5).toString();
        this._subtitleMenuButton.style.border = '1px solid rgba(51,51,51,.4)';
        this._subtitleMenuButton.style.borderRadius = '20px';
        this._subtitleMenuButton.style.cursor = 'pointer';
        this._subtitleMenuButton.style.visibility = 'hidden';
        this.updateSubtitleMenuButton();
        // Create subtitle menu
        this._subtitleMenu = document.createElement('div');
        this._subtitleMenu.style.position = 'absolute';
        this._subtitleMenu.style.right = '1%';
        this._subtitleMenu.style.top = '10%';
        this._subtitleMenu.style.background = 'rgba(0,0,0,0.9)';
        this._subtitleMenu.style.border = '1px solid rgba(255,255,255,0.3)';
        this._subtitleMenu.style.borderRadius = '8px';
        this._subtitleMenu.style.padding = '10px';
        this._subtitleMenu.style.zIndex = (this._zIndex + 6).toString();
        this._subtitleMenu.style.display = 'none';
        this._subtitleMenu.style.minWidth = '150px';
        this._subtitleMenu.style.maxHeight = '300px';
        this._subtitleMenu.style.overflowY = 'auto';
        // Add menu items
        const offOption = document.createElement('div');
        offOption.textContent = 'Off';
        offOption.style.padding = '8px';
        offOption.style.cursor = 'pointer';
        offOption.style.color = '#fff';
        offOption.style.borderBottom = '1px solid rgba(255,255,255,0.2)';
        offOption.addEventListener('click', () => {
            this.selectSubtitleTrack(null);
            this.hideSubtitleMenu();
        });
        this._subtitleMenu.appendChild(offOption);
        for (const track of this._subtitleTracks) {
            const menuItem = document.createElement('div');
            menuItem.textContent = track.label || track.language;
            menuItem.style.padding = '8px';
            menuItem.style.cursor = 'pointer';
            menuItem.style.color = '#fff';
            menuItem.style.borderBottom = '1px solid rgba(255,255,255,0.2)';
            menuItem.dataset.trackId = track.id;
            if (this._selectedSubtitleId === track.id) {
                menuItem.style.fontWeight = 'bold';
                menuItem.textContent += ' ✓';
            }
            menuItem.addEventListener('click', () => {
                this.selectSubtitleTrack(track.id);
                this.hideSubtitleMenu();
            });
            menuItem.addEventListener('mouseenter', () => {
                menuItem.style.background = 'rgba(255,255,255,0.1)';
            });
            menuItem.addEventListener('mouseleave', () => {
                menuItem.style.background = 'transparent';
            });
            this._subtitleMenu.appendChild(menuItem);
        }
        // Toggle menu on button click
        this._subtitleMenuButton.addEventListener('click', (e) => {
            e.stopPropagation();
            this.toggleSubtitleMenu();
        });
        // Hide menu when clicking outside
        document.addEventListener('click', (e) => {
            if (this._subtitleMenu &&
                this._subtitleMenuButton &&
                !this._subtitleMenu.contains(e.target) &&
                !this._subtitleMenuButton.contains(e.target)) {
                this.hideSubtitleMenu();
            }
        });
        // Add to container
        if (this._videoContainer) {
            this._videoContainer.appendChild(this._subtitleMenuButton);
            this._videoContainer.appendChild(this._subtitleMenu);
        }
        // Note: Show/hide is handled by the exit button handler above
    }
    /**
     * Update subtitle menu button text
     */
    updateSubtitleMenuButton() {
        var _a, _b;
        if (!this._subtitleMenuButton)
            return;
        if (this._selectedSubtitleId) {
            const track = (_a = this._subtitleTracks) === null || _a === void 0 ? void 0 : _a.find((t) => t.id === this._selectedSubtitleId);
            this._subtitleMenuButton.textContent = ((_b = track === null || track === void 0 ? void 0 : track.label) === null || _b === void 0 ? void 0 : _b.substring(0, 2).toUpperCase()) || 'CC';
        }
        else {
            this._subtitleMenuButton.textContent = 'CC';
        }
    }
    /**
     * Toggle subtitle menu visibility
     */
    toggleSubtitleMenu() {
        if (!this._subtitleMenu)
            return;
        this._subtitleMenu.style.display =
            this._subtitleMenu.style.display === 'none' ? 'block' : 'none';
    }
    /**
     * Hide subtitle menu
     */
    hideSubtitleMenu() {
        if (this._subtitleMenu) {
            this._subtitleMenu.style.display = 'none';
        }
    }
    /**
     * Apply subtitle styling from options
     */
    applySubtitleStyling() {
        if (!this.videoEl || !this._subtitleOptions)
            return;
        // Apply styling via CSS
        const style = document.createElement('style');
        style.id = 'capacitor-video-player-subtitle-style';
        // Remove existing style if any
        const existingStyle = document.getElementById('capacitor-video-player-subtitle-style');
        if (existingStyle) {
            existingStyle.remove();
        }
        let css = 'video::cue { ';
        if (this._subtitleOptions.foregroundColor) {
            css += `color: ${this._subtitleOptions.foregroundColor}; `;
        }
        if (this._subtitleOptions.backgroundColor) {
            css += `background-color: ${this._subtitleOptions.backgroundColor}; `;
        }
        if (this._subtitleOptions.fontSize) {
            css += `font-size: ${this._subtitleOptions.fontSize}px; `;
        }
        css += '}';
        style.textContent = css;
        document.head.appendChild(style);
    }
}

class CapacitorVideoPlayerWeb extends core.WebPlugin {
    constructor() {
        super();
        this._players = [];
        this.addListeners();
    }
    /**
     * Convert legacy single subtitle API to new array format
     * @private
     */
    normalizeSubtitleTracks(options) {
        // If new API is used, return as-is
        if (options.subtitles && options.subtitles.length > 0) {
            return options.subtitles;
        }
        // Backward compatibility: convert old API to new format
        if (options.subtitle) {
            console.warn('[CapacitorVideoPlayer] The "subtitle" option is deprecated. Use "subtitles" array instead.');
            const track = {
                id: options.language || 'default',
                url: options.subtitle,
                language: options.language || 'en',
                label: options.language
                    ? new Intl.DisplayNames(['en'], { type: 'language' }).of(options.language) || options.language
                    : 'Subtitle',
                isDefault: true,
            };
            return [track];
        }
        return null;
    }
    async echo(options) {
        return Promise.resolve({ result: true, method: 'echo', value: options });
    }
    /**
     *  Player initialization
     *
     * @param options
     */
    async initPlayer(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'initPlayer',
                message: 'Must provide a capVideoPlayerOptions object',
            });
        }
        this.mode = options.mode ? options.mode : '';
        if (this.mode == null || this.mode.length === 0) {
            return Promise.resolve({
                result: false,
                method: 'initPlayer',
                message: 'Must provide a Mode (fullscreen/embedded)',
            });
        }
        if (this.mode === 'fullscreen' || this.mode === 'embedded') {
            const url = options.url ? options.url : '';
            if (url == null || url.length === 0) {
                return Promise.resolve({
                    result: false,
                    method: 'initPlayer',
                    message: 'Must provide a Video Url',
                });
            }
            if (url == 'internal') {
                return Promise.resolve({
                    result: false,
                    method: 'initPlayer',
                    message: 'Internal Videos not supported on Web Platform',
                });
            }
            const playerId = options.playerId ? options.playerId : '';
            if (playerId == null || playerId.length === 0) {
                return Promise.resolve({
                    result: false,
                    method: 'initPlayer',
                    message: 'Must provide a Player Id',
                });
            }
            const rate = options.rate ? options.rate : 1.0;
            let exitOnEnd = true;
            if (Object.keys(options).includes('exitOnEnd')) {
                const exitRet = options.exitOnEnd;
                exitOnEnd = exitRet != null ? exitRet : true;
            }
            let loopOnEnd = false;
            if (Object.keys(options).includes('loopOnEnd') && !exitOnEnd) {
                const loopRet = options.loopOnEnd;
                loopOnEnd = loopRet != null ? loopRet : false;
            }
            const componentTag = options.componentTag
                ? options.componentTag
                : '';
            if (componentTag == null || componentTag.length === 0) {
                return Promise.resolve({
                    result: false,
                    method: 'initPlayer',
                    message: 'Must provide a Component Tag',
                });
            }
            let playerSize = null;
            if (this.mode === 'embedded') {
                playerSize = this.checkSize(options);
            }
            // Normalize subtitle tracks (backward compatibility)
            const subtitleTracks = this.normalizeSubtitleTracks(options);
            const selectedSubtitleId = options.selectedSubtitleId || null;
            const result = await this._initializeVideoPlayer(url, playerId, this.mode, rate, exitOnEnd, loopOnEnd, componentTag, playerSize, subtitleTracks, selectedSubtitleId, options.subtitleOptions);
            return Promise.resolve({ result: result });
        }
        else {
            return Promise.resolve({
                result: false,
                method: 'initPlayer',
                message: 'Must provide a Mode either fullscreen or embedded)',
            });
        }
    }
    /**
     * Return if a given playerId is playing
     *
     * @param options
     */
    async isPlaying(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'isPlaying',
                message: 'Must provide a capVideoPlayerIdOptions object',
            });
        }
        let playerId = options.playerId ? options.playerId : '';
        if (playerId == null || playerId.length === 0) {
            playerId = 'fullscreen';
        }
        if (this._players[playerId]) {
            const playing = this._players[playerId].isPlaying;
            return Promise.resolve({
                method: 'isPlaying',
                result: true,
                value: playing,
            });
        }
        else {
            return Promise.resolve({
                method: 'isPlaying',
                result: false,
                message: 'Given PlayerId does not exist)',
            });
        }
    }
    /**
     * Play the current video from a given playerId
     *
     * @param options
     */
    async play(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'play',
                message: 'Must provide a capVideoPlayerIdOptions object',
            });
        }
        let playerId = options.playerId ? options.playerId : '';
        if (playerId == null || playerId.length === 0) {
            playerId = 'fullscreen';
        }
        if (this._players[playerId]) {
            await this._players[playerId].videoEl.play();
            return Promise.resolve({ method: 'play', result: true, value: true });
        }
        else {
            return Promise.resolve({
                method: 'play',
                result: false,
                message: 'Given PlayerId does not exist)',
            });
        }
    }
    /**
     * Pause the current video from a given playerId
     *
     * @param options
     */
    async pause(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'pause',
                message: 'Must provide a capVideoPlayerIdOptions object',
            });
        }
        let playerId = options.playerId ? options.playerId : '';
        if (playerId == null || playerId.length === 0) {
            playerId = 'fullscreen';
        }
        if (this._players[playerId]) {
            if (this._players[playerId].isPlaying)
                await this._players[playerId].videoEl.pause();
            return Promise.resolve({ method: 'pause', result: true, value: true });
        }
        else {
            return Promise.resolve({
                method: 'pause',
                result: false,
                message: 'Given PlayerId does not exist)',
            });
        }
    }
    /**
     * Get the duration of the current video from a given playerId
     *
     * @param options
     */
    async getDuration(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'getDuration',
                message: 'Must provide a capVideoPlayerIdOptions object',
            });
        }
        let playerId = options.playerId ? options.playerId : '';
        if (playerId == null || playerId.length === 0) {
            playerId = 'fullscreen';
        }
        if (this._players[playerId]) {
            const duration = this._players[playerId].videoEl.duration;
            return Promise.resolve({
                method: 'getDuration',
                result: true,
                value: duration,
            });
        }
        else {
            return Promise.resolve({
                method: 'getDuration',
                result: false,
                message: 'Given PlayerId does not exist)',
            });
        }
    }
    /**
     * Set the rate of the current video from a given playerId
     *
     * @param options
     */
    async setRate(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'setRate',
                message: 'Must provide a capVideoRateOptions object',
            });
        }
        let playerId = options.playerId ? options.playerId : '';
        if (playerId == null || playerId.length === 0) {
            playerId = 'fullscreen';
        }
        const rateList = [0.25, 0.5, 0.75, 1.0, 2.0, 4.0];
        const rate = options.rate && rateList.includes(options.rate) ? options.rate : 1.0;
        if (this._players[playerId]) {
            this._players[playerId].videoEl.playbackRate = rate;
            return Promise.resolve({
                method: 'setRate',
                result: true,
                value: rate,
            });
        }
        else {
            return Promise.resolve({
                method: 'setRate',
                result: false,
                message: 'Given PlayerId does not exist)',
            });
        }
    }
    /**
     * Get the volume of the current video from a given playerId
     *
     * @param options
     */
    async getRate(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'getRate',
                message: 'Must provide a capVideoPlayerIdOptions object',
            });
        }
        let playerId = options.playerId ? options.playerId : '';
        if (playerId == null || playerId.length === 0) {
            playerId = 'fullscreen';
        }
        if (this._players[playerId]) {
            const rate = this._players[playerId].videoEl.playbackRate;
            return Promise.resolve({
                method: 'getRate',
                result: true,
                value: rate,
            });
        }
        else {
            return Promise.resolve({
                method: 'getRate',
                result: false,
                message: 'Given PlayerId does not exist)',
            });
        }
    }
    /**
     * Set the volume of the current video from a given playerId
     *
     * @param options
     */
    async setVolume(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'setVolume',
                message: 'Must provide a capVideoVolumeOptions object',
            });
        }
        let playerId = options.playerId ? options.playerId : '';
        if (playerId == null || playerId.length === 0) {
            playerId = 'fullscreen';
        }
        const volume = options.volume ? options.volume : 0.5;
        if (this._players[playerId]) {
            this._players[playerId].videoEl.volume = volume;
            return Promise.resolve({
                method: 'setVolume',
                result: true,
                value: volume,
            });
        }
        else {
            return Promise.resolve({
                method: 'setVolume',
                result: false,
                message: 'Given PlayerId does not exist)',
            });
        }
    }
    /**
     * Get the volume of the current video from a given playerId
     *
     * @param options
     */
    async getVolume(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'getVolume',
                message: 'Must provide a capVideoPlayerIdOptions object',
            });
        }
        let playerId = options.playerId ? options.playerId : '';
        if (playerId == null || playerId.length === 0) {
            playerId = 'fullscreen';
        }
        if (this._players[playerId]) {
            const volume = this._players[playerId].videoEl.volume;
            return Promise.resolve({
                method: 'getVolume',
                result: true,
                value: volume,
            });
        }
        else {
            return Promise.resolve({
                method: 'getVolume',
                result: false,
                message: 'Given PlayerId does not exist)',
            });
        }
    }
    /**
     * Set the muted property of the current video from a given playerId
     *
     * @param options
     */
    async setMuted(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'setMuted',
                message: 'Must provide a capVideoMutedOptions object',
            });
        }
        let playerId = options.playerId ? options.playerId : '';
        if (playerId == null || playerId.length === 0) {
            playerId = 'fullscreen';
        }
        const muted = options.muted ? options.muted : false;
        if (this._players[playerId]) {
            this._players[playerId].videoEl.muted = muted;
            return Promise.resolve({
                method: 'setMuted',
                result: true,
                value: muted,
            });
        }
        else {
            return Promise.resolve({
                method: 'setMuted',
                result: false,
                message: 'Given PlayerId does not exist)',
            });
        }
    }
    /**
     * Get the muted property of the current video from a given playerId
     *
     * @param options
     */
    async getMuted(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'getMuted',
                message: 'Must provide a capVideoPlayerIdOptions object',
            });
        }
        let playerId = options.playerId ? options.playerId : '';
        if (playerId == null || playerId.length === 0) {
            playerId = 'fullscreen';
        }
        if (this._players[playerId]) {
            const muted = this._players[playerId].videoEl.muted;
            return Promise.resolve({
                method: 'getMuted',
                result: true,
                value: muted,
            });
        }
        else {
            return Promise.resolve({
                method: 'getMuted',
                result: false,
                message: 'Given PlayerId does not exist)',
            });
        }
    }
    /**
     * Set the current time of the current video from a given playerId
     *
     * @param options
     */
    async setCurrentTime(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'setCurrentTime',
                message: 'Must provide a capVideoTimeOptions object',
            });
        }
        let playerId = options.playerId ? options.playerId : '';
        if (playerId == null || playerId.length === 0) {
            playerId = 'fullscreen';
        }
        let seekTime = options.seektime ? options.seektime : 0;
        if (this._players[playerId]) {
            const duration = this._players[playerId].videoEl.duration;
            seekTime =
                seekTime <= duration && seekTime >= 0 ? seekTime : duration / 2;
            this._players[playerId].videoEl.currentTime = seekTime;
            return Promise.resolve({
                method: 'setCurrentTime',
                result: true,
                value: seekTime,
            });
        }
        else {
            return Promise.resolve({
                method: 'setCurrentTime',
                result: false,
                message: 'Given PlayerId does not exist)',
            });
        }
    }
    /**
     * Get the current time of the current video from a given playerId
     *
     * @param options
     */
    async getCurrentTime(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'getCurrentTime',
                message: 'Must provide a capVideoPlayerIdOptions object',
            });
        }
        let playerId = options.playerId ? options.playerId : '';
        if (playerId == null || playerId.length === 0) {
            playerId = 'fullscreen';
        }
        if (this._players[playerId]) {
            const seekTime = this._players[playerId].videoEl.currentTime;
            return Promise.resolve({
                method: 'getCurrentTime',
                result: true,
                value: seekTime,
            });
        }
        else {
            return Promise.resolve({
                method: 'getCurrentTime',
                result: false,
                message: 'Given PlayerId does not exist)',
            });
        }
    }
    /**
     * Get the current time of the current video from a given playerId
     *
     */
    async stopAllPlayers() {
        for (const i in this._players) {
            if (this._players[i].pipMode) {
                const doc = document;
                if (doc.pictureInPictureElement) {
                    await doc.exitPictureInPicture();
                }
            }
            if (!this._players[i].videoEl.paused)
                this._players[i].videoEl.pause();
        }
        return Promise.resolve({
            method: 'stopAllPlayers',
            result: true,
            value: true,
        });
    }
    /**
     * Show controller
     *
     */
    async showController() {
        return Promise.resolve({
            method: 'showController',
            result: true,
            value: true,
        });
    }
    /**
     * isControllerIsFullyVisible
     *
     */
    async isControllerIsFullyVisible() {
        return Promise.resolve({
            method: 'isControllerIsFullyVisible',
            result: true,
            value: true,
        });
    }
    /**
     * Exit the current player
     *
     */
    async exitPlayer() {
        return Promise.resolve({
            method: 'exitPlayer',
            result: true,
            value: true,
        });
    }
    /**
     * Exit fullscreen mode for a given playerId
     *
     */
    async exitFullScreen(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'exitFullScreen',
                message: 'Must provide a capVideoPlayerIdOptions object',
            });
        }
        let playerId = options.playerId ? options.playerId : '';
        if (playerId == null || playerId.length === 0) {
            playerId = 'fullscreen';
        }
        if (this._players[playerId]) {
            // Pause the video if it's playing
            if (!this._players[playerId].videoEl.paused) {
                this._players[playerId].videoEl.pause();
            }
            // Remove the player from the array
            delete this._players[playerId];
            // Remove the video container if it exists
            if (this.videoContainer) {
                this.videoContainer.remove();
                this.videoContainer = null;
            }
            return Promise.resolve({
                method: 'exitFullScreen',
                result: true,
                value: true,
            });
        }
        else {
            return Promise.resolve({
                method: 'exitFullScreen',
                result: false,
                message: 'Given PlayerId does not exist',
            });
        }
    }
    /**
     * Get available subtitle tracks for a player
     */
    async getSubtitleTracks(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'getSubtitleTracks',
                message: 'Must provide a capVideoPlayerIdOptions object',
            });
        }
        let playerId = options.playerId ? options.playerId : '';
        if (playerId == null || playerId.length === 0) {
            playerId = 'fullscreen';
        }
        if (this._players[playerId]) {
            const tracks = this._players[playerId].getSubtitleTracks();
            return Promise.resolve({
                method: 'getSubtitleTracks',
                result: true,
                value: tracks,
            });
        }
        else {
            return Promise.resolve({
                method: 'getSubtitleTracks',
                result: false,
                message: 'Given PlayerId does not exist',
            });
        }
    }
    /**
     * Select a subtitle track by ID
     */
    async selectSubtitleTrack(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'selectSubtitleTrack',
                message: 'Must provide a capSubtitleTrackOptions object',
            });
        }
        let playerId = options.playerId ? options.playerId : '';
        if (playerId == null || playerId.length === 0) {
            playerId = 'fullscreen';
        }
        if (this._players[playerId]) {
            const success = await this._players[playerId].selectSubtitleTrack(options.trackId);
            return Promise.resolve({
                method: 'selectSubtitleTrack',
                result: success,
                value: options.trackId,
            });
        }
        else {
            return Promise.resolve({
                method: 'selectSubtitleTrack',
                result: false,
                message: 'Given PlayerId does not exist',
            });
        }
    }
    /**
     * Disable subtitles (hide current track)
     */
    async disableSubtitles(options) {
        return this.selectSubtitleTrack({
            playerId: options.playerId,
            trackId: null,
        });
    }
    /**
     * Get currently selected subtitle track
     */
    async getSelectedSubtitleTrack(options) {
        if (options == null) {
            return Promise.resolve({
                result: false,
                method: 'getSelectedSubtitleTrack',
                message: 'Must provide a capVideoPlayerIdOptions object',
            });
        }
        let playerId = options.playerId ? options.playerId : '';
        if (playerId == null || playerId.length === 0) {
            playerId = 'fullscreen';
        }
        if (this._players[playerId]) {
            const trackId = this._players[playerId].getSelectedSubtitleTrack();
            return Promise.resolve({
                method: 'getSelectedSubtitleTrack',
                result: true,
                value: trackId,
            });
        }
        else {
            return Promise.resolve({
                method: 'getSelectedSubtitleTrack',
                result: false,
                message: 'Given PlayerId does not exist',
            });
        }
    }
    checkSize(options) {
        const playerSize = {
            width: options.width ? options.width : 320,
            height: options.height ? options.height : 180,
        };
        const ratio = playerSize.height / playerSize.width;
        if (playerSize.width > window.innerWidth) {
            playerSize.width = window.innerWidth;
            playerSize.height = Math.floor(playerSize.width * ratio);
        }
        if (playerSize.height > window.innerHeight) {
            playerSize.height = window.innerHeight;
            playerSize.width = Math.floor(playerSize.height / ratio);
        }
        return playerSize;
    }
    async _initializeVideoPlayer(url, playerId, mode, rate, exitOnEnd, loopOnEnd, componentTag, playerSize, subtitleTracks, selectedSubtitleId, subtitleOptions) {
        const videoURL = url
            ? url.indexOf('%2F') == -1
                ? encodeURI(url)
                : url
            : null;
        if (videoURL === null)
            return Promise.resolve(false);
        this.videoContainer =
            await this._getContainerElement(playerId, componentTag);
        if (this.videoContainer === null)
            return Promise.resolve({
                method: 'initPlayer',
                result: false,
                message: 'componentTag or divContainerElement must be provided',
            });
        if (mode === 'embedded' && playerSize == null)
            return Promise.resolve({
                method: 'initPlayer',
                result: false,
                message: 'playerSize must be defined in embedded mode',
            });
        if (mode === 'embedded') {
            this._players[playerId] = new VideoPlayer('embedded', videoURL, playerId, rate, exitOnEnd, loopOnEnd, this.videoContainer, 2, playerSize.width, playerSize.height, subtitleTracks, selectedSubtitleId, subtitleOptions);
            await this._players[playerId].initialize();
        }
        else if (mode === 'fullscreen') {
            this._players['fullscreen'] = new VideoPlayer('fullscreen', videoURL, 'fullscreen', rate, exitOnEnd, loopOnEnd, this.videoContainer, 99995, undefined, undefined, subtitleTracks, selectedSubtitleId, subtitleOptions);
            await this._players['fullscreen'].initialize();
        }
        else {
            return Promise.resolve({
                method: 'initPlayer',
                result: false,
                message: 'mode not supported',
            });
        }
        return Promise.resolve({ method: 'initPlayer', result: true, value: true });
    }
    async _getContainerElement(playerId, componentTag) {
        const videoContainer = document.createElement('div');
        videoContainer.id = `vc_${playerId}`;
        if (componentTag != null && componentTag.length > 0) {
            const cmpTagEl = document.querySelector(`${componentTag}`);
            if (cmpTagEl === null)
                return Promise.resolve(null);
            let container = null;
            const shadowRoot = cmpTagEl.shadowRoot ? cmpTagEl.shadowRoot : null;
            if (shadowRoot != null) {
                container = shadowRoot.querySelector(`[id='${playerId}']`);
            }
            else {
                container = cmpTagEl.querySelector(`[id='${playerId}']`);
            }
            if (container != null)
                container.appendChild(videoContainer);
            return Promise.resolve(videoContainer);
        }
        else {
            return Promise.resolve(null);
        }
    }
    handlePlayerPlay(data) {
        this.notifyListeners('jeepCapVideoPlayerPlay', data);
    }
    handlePlayerPause(data) {
        this.notifyListeners('jeepCapVideoPlayerPause', data);
    }
    handlePlayerEnded(data) {
        var _a;
        if (this.mode === 'fullscreen') {
            (_a = this.videoContainer) === null || _a === void 0 ? void 0 : _a.remove();
        }
        this.removeListeners();
        this.notifyListeners('jeepCapVideoPlayerEnded', data);
    }
    handlePlayerExit() {
        var _a;
        if (this.mode === 'fullscreen') {
            (_a = this.videoContainer) === null || _a === void 0 ? void 0 : _a.remove();
        }
        const retData = { dismiss: true };
        this.removeListeners();
        this.notifyListeners('jeepCapVideoPlayerExit', retData);
    }
    handlePlayerReady(data) {
        this.notifyListeners('jeepCapVideoPlayerReady', data);
    }
    addListeners() {
        document.addEventListener('videoPlayerPlay', (ev) => {
            this.handlePlayerPlay(ev.detail);
        }, false);
        document.addEventListener('videoPlayerPause', (ev) => {
            this.handlePlayerPause(ev.detail);
        }, false);
        document.addEventListener('videoPlayerEnded', (ev) => {
            this.handlePlayerEnded(ev.detail);
        }, false);
        document.addEventListener('videoPlayerReady', (ev) => {
            this.handlePlayerReady(ev.detail);
        }, false);
        document.addEventListener('videoPlayerExit', () => {
            this.handlePlayerExit();
        }, false);
    }
    removeListeners() {
        document.removeEventListener('videoPlayerPlay', (ev) => {
            this.handlePlayerPlay(ev.detail);
        }, false);
        document.removeEventListener('videoPlayerPause', (ev) => {
            this.handlePlayerPause(ev.detail);
        }, false);
        document.removeEventListener('videoPlayerEnded', (ev) => {
            this.handlePlayerEnded(ev.detail);
        }, false);
        document.removeEventListener('videoPlayerReady', (ev) => {
            this.handlePlayerReady(ev.detail);
        }, false);
        document.removeEventListener('videoPlayerExit', () => {
            this.handlePlayerExit();
        }, false);
    }
}

var web = /*#__PURE__*/Object.freeze({
    __proto__: null,
    CapacitorVideoPlayerWeb: CapacitorVideoPlayerWeb
});

exports.CapacitorVideoPlayer = CapacitorVideoPlayer;
//# sourceMappingURL=plugin.cjs.js.map
