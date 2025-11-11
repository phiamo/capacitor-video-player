import Hls from 'hls.js';

import type { videoMimeType } from './video-types';
import { videoTypes, possibleQueryParameterExtensions } from './video-types';
import type {
  SubtitleTrack,
  SubtitleTrackInfo,
  SubTitleOptions,
} from '../definitions';

export class VideoPlayer {
  public videoEl: HTMLVideoElement | undefined;
  public pipMode = false;
  public pipWindow: Window | undefined;
  public isPlaying: boolean | undefined;

  private _url: string;
  private _playerId: string;
  private _container: any;
  private _mode: string;
  private _width: number;
  private _height: number;
  private _zIndex: number;
  private _initial: any;
  private _videoType: videoMimeType | null = null;
  private _videoContainer: any = null;
  private _firstReadyToPlay = true;
  private _isEnded = false;
  private _videoRate = 1.0;
  private _videoExitOnEnd = true;
  private _videoLoopOnEnd = false;
  private _subtitleTracks: SubtitleTrack[] | null = null;
  private _selectedSubtitleId: string | null = null;
  private _subtitleOptions?: SubTitleOptions;
  private _subtitleTrackElements: HTMLTrackElement[] = [];
  private _subtitleMenuButton: HTMLButtonElement | null = null;
  private _subtitleMenu: HTMLDivElement | null = null;

  constructor(
    mode: string,
    url: string,
    playerId: string,
    rate: number,
    exitOnEnd: boolean,
    loopOnEnd: boolean,
    container: any,
    zIndex: number,
    width?: number,
    height?: number,
    subtitleTracks?: SubtitleTrack[] | null,
    selectedSubtitleId?: string | null,
    subtitleOptions?: SubTitleOptions,
  ) {
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

  public async initialize(): Promise<void> {
    // get the video type
    const urlVideoType: videoMimeType | null = this._getVideoType();
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
      const width: number =
        this._mode === 'fullscreen'
          ? window.innerWidth /*this._container.offsetWidth*/
          : this._width;
      const height: number =
        this._mode === 'fullscreen'
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

      const heightVideo: number = (width * this._height) / this._width;
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
        this._createEvent(
          'Exit',
          this._playerId,
          'Video Error: failed to create the Video Element',
        );
      } else {
        // Initialize subtitles after video element is created
        if (this._subtitleTracks && this._subtitleTracks.length > 0) {
          await this.initializeSubtitles();
        }
      }
    } else {
      this._createEvent(
        'Exit',
        this._playerId,
        'Url Error: type not supported',
      );
    }
    return;
  }

  private async createVideoElement(
    width: number,
    height: number,
  ): Promise<boolean> {
    this.videoEl = document.createElement('video');
    this.videoEl.controls = true;
    this.videoEl.style.zIndex = (this._zIndex + 3).toString();
    this.videoEl.style.width = `${width.toString()}px`;
    this.videoEl.style.height = `${height.toString()}px`;
    this.videoEl.playbackRate = this._videoRate;
    this._videoContainer.appendChild(this.videoEl);
    // set the player
    const isSet: boolean = await this._setPlayer();
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
        } else {
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
            if (this._mode === 'fullscreen') await this.videoEl.play();
            this._firstReadyToPlay = false;
          }
        }
      };
      this.videoEl.onplay = () => {
        this.isPlaying = true;
        if (this._firstReadyToPlay) this._firstReadyToPlay = false;
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
        const exitEl: HTMLButtonElement = document.createElement('button');
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

  private async _goFullscreen(): Promise<void> {
    if (this._container.mozRequestFullScreen) {
      /* Firefox */
      this._container.mozRequestFullScreen();
    } else if (this._container.webkitRequestFullscreen) {
      /* Chrome, Safari & Opera */
      this._container.webkitRequestFullscreen();
    } else if (this._container.msRequestFullscreen) {
      /* IE/Edge */
      this._container.msRequestFullscreen();
    } else if (this._container.requestFullscreen) {
      this._container.requestFullscreen();
    }
    return;
  }

  private async _setPlayer(): Promise<boolean> {
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
            } else {
              resolve(false);
            }
          });
        } else if (this._videoType === 'video/mp4') {
          // CMAF (fMP4) && MP4
          this.videoEl.src = this._url;
          if (
            this._url.substring(0, 5) != 'https' &&
            this._url.substring(0, 4) === 'http'
          )
            this.videoEl.crossOrigin = 'anonymous';
          if (
            this._url.substring(0, 5) === 'https' ||
            this._url.substring(0, 4) === 'http'
          )
            this.videoEl.muted = true;
          resolve(true);
        } else {
          // Not Supported
          resolve(false);
        }
        this.videoEl.addEventListener('enterpictureinpicture', (event: any) => {
          this.pipWindow = event.pictureInPictureWindow;
          this.pipMode = true;
          this._closeFullscreen();
        });

        this.videoEl.addEventListener('leavepictureinpicture', () => {
          this.pipMode = false;
          if (!this._isEnded) {
            this._goFullscreen();
            if (this.videoEl != null) this.videoEl.play();
          }
        });
      } else {
        resolve(false);
      }
    });
  }

  private _getVideoType(): videoMimeType | null {
    const sUrl: string = this._url ? this._url : '';
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
      const hasNotSupportedExtensionInUrl = sUrl.match(
        new RegExp(
          `(${possibleQueryParameterExtensions.join('|')})\=+(.*)&?(?=&|$))`,
          'i',
        ),
      );
      if (hasNotSupportedExtensionInUrl) {
        return (this._videoType = null);
      }
      // No extension found, then we assume it's 'mp4' (Match case for '')
      return 'video/mp4';
    }
    // URL was not defined, we return null
    return null;
  }

  private async _doHide(exitEl: HTMLButtonElement, duration: number) {
    clearTimeout(this._initial);
    exitEl.style.visibility = 'visible';
    const initial = setTimeout(() => {
      exitEl.style.visibility = 'hidden';
    }, duration);
    return initial;
  }
  private _createEvent(ev: string, playerId: string, msg?: string) {
    const message = msg ? msg : null;
    let event: CustomEvent;
    if (message != null) {
      event = new CustomEvent(`videoPlayer${ev}`, {
        detail: { fromPlayerId: playerId, message: message },
      });
    } else {
      const currentTime: number = this.videoEl ? this.videoEl.currentTime : 0;
      event = new CustomEvent(`videoPlayer${ev}`, {
        detail: { fromPlayerId: playerId, currentTime: currentTime },
      });
    }
    document.dispatchEvent(event);
  }
  private _closeFullscreen() {
    const mydoc: any = document;
    const isInFullScreen: boolean =
      (mydoc.fullscreenElement && mydoc.fullscreenElement !== null) ||
      (mydoc.webkitFullscreenElement &&
        mydoc.webkitFullscreenElement !== null) ||
      (mydoc.mozFullScreenElement && mydoc.mozFullScreenElement !== null) ||
      (mydoc.msFullscreenElement && mydoc.msFullscreenElement !== null);
    if (isInFullScreen) {
      if (mydoc.mozCancelFullScreen) {
        mydoc.mozCancelFullScreen();
      } else if (mydoc.webkitExitFullscreen) {
        mydoc.webkitExitFullscreen();
      } else if (mydoc.msExitFullscreen) {
        mydoc.msExitFullscreen();
      } else if (mydoc.exitFullscreen) {
        mydoc.exitFullscreen();
      }
    }
  }

  /**
   * Initialize subtitle tracks using HTML5 TextTrack API
   */
  private async initializeSubtitles(): Promise<void> {
    if (!this.videoEl || !this._subtitleTracks) return;

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
        } catch (error) {
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
    } else {
      // Find default track or first track
      const defaultTrack = this._subtitleTracks.find((t) => t.isDefault);
      if (defaultTrack) {
        this.selectSubtitleTrack(defaultTrack.id);
      } else if (this._subtitleTracks.length > 0) {
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
  private waitForTracksLoaded(): Promise<void> {
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
        } else {
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
  private async convertSRTToVTT(srtUrl: string): Promise<string> {
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
        } else {
          i++;
        }
      }

      // Create blob URL
      const blob = new Blob([vttContent], { type: 'text/vtt' });
      return URL.createObjectURL(blob);
    } catch (error) {
      console.error('SRT to VTT conversion error:', error);
      throw error;
    }
  }

  /**
   * Select a subtitle track by ID
   */
  public async selectSubtitleTrack(trackId: string | null): Promise<boolean> {
    if (!this.videoEl) return false;

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
    const selectedTrack = tracks.find(
      (track) => track.id === `track-${trackId}` || track.language === trackId,
    );

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
  public getSubtitleTracks(): SubtitleTrackInfo[] {
    if (!this.videoEl || !this._subtitleTracks) return [];

    const tracks = Array.from(this.videoEl.textTracks);
    const trackInfos: SubtitleTrackInfo[] = [];

    for (const track of this._subtitleTracks) {
      const htmlTrack = tracks.find(
        (t) => t.id === `track-${track.id}` || t.language === track.language,
      );

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
  public getSelectedSubtitleTrack(): string | null {
    return this._selectedSubtitleId;
  }

  /**
   * Create subtitle selection UI
   */
  private createSubtitleSelectionUI(): void {
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
      if (
        this._subtitleMenu &&
        this._subtitleMenuButton &&
        !this._subtitleMenu.contains(e.target as Node) &&
        !this._subtitleMenuButton.contains(e.target as Node)
      ) {
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
  private updateSubtitleMenuButton(): void {
    if (!this._subtitleMenuButton) return;

    if (this._selectedSubtitleId) {
      const track = this._subtitleTracks?.find((t) => t.id === this._selectedSubtitleId);
      this._subtitleMenuButton.textContent = track?.label?.substring(0, 2).toUpperCase() || 'CC';
    } else {
      this._subtitleMenuButton.textContent = 'CC';
    }
  }

  /**
   * Toggle subtitle menu visibility
   */
  private toggleSubtitleMenu(): void {
    if (!this._subtitleMenu) return;
    this._subtitleMenu.style.display =
      this._subtitleMenu.style.display === 'none' ? 'block' : 'none';
  }

  /**
   * Hide subtitle menu
   */
  private hideSubtitleMenu(): void {
    if (this._subtitleMenu) {
      this._subtitleMenu.style.display = 'none';
    }
  }

  /**
   * Apply subtitle styling from options
   */
  private applySubtitleStyling(): void {
    if (!this.videoEl || !this._subtitleOptions) return;

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
