import type { SubtitleTrack, SubtitleTrackInfo, SubTitleOptions } from '../definitions';
export declare class VideoPlayer {
    videoEl: HTMLVideoElement | undefined;
    pipMode: boolean;
    pipWindow: Window | undefined;
    isPlaying: boolean | undefined;
    private _url;
    private _playerId;
    private _container;
    private _mode;
    private _width;
    private _height;
    private _zIndex;
    private _initial;
    private _videoType;
    private _videoContainer;
    private _firstReadyToPlay;
    private _isEnded;
    private _videoRate;
    private _videoExitOnEnd;
    private _videoLoopOnEnd;
    private _subtitleTracks;
    private _selectedSubtitleId;
    private _subtitleOptions?;
    private _subtitleTrackElements;
    private _subtitleMenuButton;
    private _subtitleMenu;
    private _positionUpdateInterval;
    private _positionUpdateTimer?;
    constructor(mode: string, url: string, playerId: string, rate: number, exitOnEnd: boolean, loopOnEnd: boolean, container: any, zIndex: number, width?: number, height?: number, subtitleTracks?: SubtitleTrack[] | null, selectedSubtitleId?: string | null, subtitleOptions?: SubTitleOptions, positionUpdateInterval?: number);
    initialize(): Promise<void>;
    private createVideoElement;
    private _goFullscreen;
    private _setPlayer;
    private _getVideoType;
    private _doHide;
    private _createEvent;
    private _createPositionUpdateEvent;
    private _startPositionUpdates;
    private _stopPositionUpdates;
    private _closeFullscreen;
    /**
     * Initialize subtitle tracks using HTML5 TextTrack API
     */
    private initializeSubtitles;
    /**
     * Wait for text tracks to load
     */
    private waitForTracksLoaded;
    /**
     * Convert SRT format to VTT format
     */
    private convertSRTToVTT;
    /**
     * Select a subtitle track by ID
     */
    selectSubtitleTrack(trackId: string | null): Promise<boolean>;
    /**
     * Get available subtitle tracks
     */
    getSubtitleTracks(): SubtitleTrackInfo[];
    /**
     * Get currently selected subtitle track ID
     */
    getSelectedSubtitleTrack(): string | null;
    /**
     * Create subtitle selection UI
     */
    private createSubtitleSelectionUI;
    /**
     * Update subtitle menu button text
     */
    private updateSubtitleMenuButton;
    /**
     * Toggle subtitle menu visibility
     */
    private toggleSubtitleMenu;
    /**
     * Hide subtitle menu
     */
    private hideSubtitleMenu;
    /**
     * Apply subtitle styling from options
     */
    private applySubtitleStyling;
}
