export interface CapacitorVideoPlayerPlugin {
  /**
   * Echo
   *
   */
  echo(options: capEchoOptions): Promise<capVideoPlayerResult>;
  /**
   * Initialize a video player
   *
   */
  initPlayer(options: capVideoPlayerOptions): Promise<capVideoPlayerResult>;
  /**
   * Return if a given playerId is playing
   *
   */
  isPlaying(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  /**
   * Play the current video from a given playerId
   *
   */
  play(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  /**
   * Pause the current video from a given playerId
   *
   */
  pause(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  /**
   * Get the duration of the current video from a given playerId
   *
   */
  getDuration(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  /**
   * Get the current time of the current video from a given playerId
   *
   */
  getCurrentTime(
    options: capVideoPlayerIdOptions,
  ): Promise<capVideoPlayerResult>;
  /**
   * Set the current time to seek the current video to from a given playerId
   *
   */
  setCurrentTime(options: capVideoTimeOptions): Promise<capVideoPlayerResult>;
  /**
   * Get the volume of the current video from a given playerId
   *
   */
  getVolume(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  /**
   * Set the volume of the current video to from a given playerId
   *
   */
  setVolume(options: capVideoVolumeOptions): Promise<capVideoPlayerResult>;
  /**
   * Get the muted of the current video from a given playerId
   *
   */
  getMuted(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  /**
   * Set the muted of the current video to from a given playerId
   *
   */
  setMuted(options: capVideoMutedOptions): Promise<capVideoPlayerResult>;
  /**
   * Set the rate of the current video from a given playerId
   *
   */
  setRate(options: capVideoRateOptions): Promise<capVideoPlayerResult>;
  /**
   * Get the rate of the current video from a given playerId
   *
   */
  getRate(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  /**
   * Stop all players playing
   *
   */
  stopAllPlayers(): Promise<capVideoPlayerResult>;
  /**
   * Show controller
   *
   */
  showController(): Promise<capVideoPlayerResult>;
  /**
   * isControllerIsFullyVisible
   *
   */
  isControllerIsFullyVisible(): Promise<capVideoPlayerResult>;
  /**
   * Exit player
   *
   */
  exitPlayer(): Promise<capVideoPlayerResult>;
  /**
   * Exit fullscreen mode for a given playerId
   *
   */
  exitFullScreen(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  /**
   * Get available subtitle tracks for a player
   *
   */
  getSubtitleTracks(
    options: capVideoPlayerIdOptions,
  ): Promise<capVideoPlayerResult>;
  /**
   * Select a subtitle track by ID
   *
   */
  selectSubtitleTrack(
    options: capSubtitleTrackOptions,
  ): Promise<capVideoPlayerResult>;
  /**
   * Disable subtitles (hide current track)
   *
   */
  disableSubtitles(
    options: capVideoPlayerIdOptions,
  ): Promise<capVideoPlayerResult>;
  /**
   * Get currently selected subtitle track
   *
   */
  getSelectedSubtitleTrack(
    options: capVideoPlayerIdOptions,
  ): Promise<capVideoPlayerResult>;
}
export interface capEchoOptions {
  /**
   *  String to be echoed
   */

  value?: string;
}
export interface capVideoPlayerOptions {
  /**
   * Player mode
   *  - "fullscreen"
   *  - "embedded" (Web only)
   */
  mode?: string;
  /**
   * The url of the video to play
   */
  url?: string;
  /**
   * The url of subtitle associated with the video
   * @deprecated Use subtitles array instead
   */
  subtitle?: string;
  /**
   * The language of subtitle
   * see https://github.com/libyal/libfwnt/wiki/Language-Code-identifiers
   * @deprecated Use subtitles array instead
   */
  language?: string;
  /**
   * Multiple subtitle tracks
   * Array of subtitle track definitions
   */
  subtitles?: SubtitleTrack[];
  /**
   * Initial selected subtitle track ID
   * If not specified, first track with isDefault=true is selected, or first track if none marked as default
   */
  selectedSubtitleId?: string;
  /**
   * SubTitle Options
   * Shared styling for all tracks (can be overridden per-track later)
   */
  subtitleOptions?: SubTitleOptions;
  /**
   * Id of DIV Element parent of the player
   */
  playerId?: string;
  /**
   * Initial playing rate
   */
  rate?: number;
  /**
   * Exit on VideoEnd (iOS, Android)
   * default: true
   */
  exitOnEnd?: boolean;
  /**
   * Loop on VideoEnd when exitOnEnd false (iOS, Android)
   * default: false
   */
  loopOnEnd?: boolean;
  /**
   * Picture in Picture Enable (iOS, Android)
   * default: true
   */
  pipEnabled?: boolean;
  /**
   * Background Mode Enable (iOS, Android)
   * default: true
   */
  bkmodeEnabled?: boolean;
  /**
   * Show Controls Enable (iOS, Android)
   * default: true
   */
  showControls?: boolean;
  /**
   * Display Mode ["all", "portrait", "landscape"] (iOS, Android)
   * default: "all"
   */
  displayMode?: string;
  /**
   * Component Tag or DOM Element Tag (React app)
   */
  componentTag?: string;
  /**
   * Player Width (mode "embedded" only)
   */
  width?: number;
  /**
   * Player height (mode "embedded" only)
   */
  height?: number;
  /**
   * Headers for the request (iOS, Android)
   * by Manuel García Marín (https://github.com/PhantomPainX)
   */
  headers?: {
    [key: string]: string;
  };
  /**
   * Title shown in the player (Android)
   * by Manuel García Marín (https://github.com/PhantomPainX)
   */
  title?: string;
  /**
   * Subtitle shown below the title in the player (Android)
   * by Manuel García Marín (https://github.com/PhantomPainX)
   */
  smallTitle?: string;
  /**
   * ExoPlayer Progress Bar and Spinner color (Android)
   * by Manuel García Marín (https://github.com/PhantomPainX)
   * Must be a valid hex color code
   * default: #FFFFFF
   */
  accentColor?: string;
  /**
   * Chromecast enable/disable (Android)
   * by Manuel García Marín (https://github.com/PhantomPainX)
   * default: true
   */
  chromecast?: boolean;
  /**
   * Artwork url to be shown in Chromecast player
   * by Manuel García Marín (https://github.com/PhantomPainX)
   * default: ""
   */
  artwork?: string;
  /**
   * Position update interval in seconds for periodic position events
   * default: 5
   */
  positionUpdateInterval?: number;
}
export interface capVideoPlayerIdOptions {
  /**
   * Id of DIV Element parent of the player
   */
  playerId?: string;
}
export interface capVideoRateOptions {
  /**
   * Id of DIV Element parent of the player
   */
  playerId?: string;
  /**
   * Rate value
   */
  rate?: number;
}
export interface capVideoVolumeOptions {
  /**
   * Id of DIV Element parent of the player
   */
  playerId?: string;
  /**
   * Volume value between [0 - 1]
   */
  volume?: number;
}
export interface capVideoTimeOptions {
  /**
   * Id of DIV Element parent of the player
   */
  playerId?: string;
  /**
   * Video time value you want to seek to
   */
  seektime?: number;
}
export interface capVideoMutedOptions {
  /**
   * Id of DIV Element parent of the player
   */
  playerId?: string;
  /**
   * Muted value true or false
   */
  muted?: boolean;
}
export interface capVideoListener {
  /**
   * Id of DIV Element parent of the player
   */
  playerId?: string;
  /**
   * Video current time when listener trigerred
   */
  currentTime?: number;
}
export interface capExitListener {
  /**
   * Dismiss value true or false
   */
  dismiss?: boolean;
  /**
   * Video current time when listener trigerred
   */
  currentTime?: number;
}
export interface capPositionUpdateListener {
  /**
   * Id of DIV Element parent of the player
   */
  playerId?: string;
  /**
   * Video current time when listener triggered
   */
  currentTime?: number;
  /**
   * Video duration in seconds
   */
  duration?: number;
}
export interface capVideoPlayerResult {
  /**
   * result set to true when successful else false
   */
  result?: boolean;
  /**
   * method name
   */
  method?: string;
  /**
   * value returned
   */
  value?: any;
  /**
   * message string
   */
  message?: string;
}
export interface SubTitleOptions {
  /**
   * Foreground Color in RGBA (default rgba(255,255,255,1)
   */
  foregroundColor?: string;
  /**
   * Background Color in RGBA (default rgba(0,0,0,1)
   */
  backgroundColor?: string;
  /**
   * Font Size in pixels (default 16)
   */
  fontSize?: number;
}
/**
 * Subtitle track definition
 */
export interface SubtitleTrack {
  /**
   * Unique identifier for the track
   */
  id: string;
  /**
   * Subtitle file URL/path
   */
  url: string;
  /**
   * ISO 639-1 language code (e.g., "en", "es")
   */
  language: string;
  /**
   * Display label (e.g., "English", "Spanish")
   * If not provided, language code will be used
   */
  label?: string;
  /**
   * Optional MIME type override
   * If not provided, will be detected from file extension
   */
  mimeType?: string;
  /**
   * Default track to select
   * If multiple tracks have isDefault=true, first one is selected
   */
  isDefault?: boolean;
  /**
   * Forced subtitle track
   * Forced tracks are always shown when available
   */
  isForced?: boolean;
}
/**
 * Subtitle track information (returned by getSubtitleTracks)
 */
export interface SubtitleTrackInfo {
  /**
   * Track identifier
   */
  id: string;
  /**
   * Language code
   */
  language: string;
  /**
   * Display label
   */
  label: string;
  /**
   * Whether this track is currently selected
   */
  isSelected: boolean;
  /**
   * Whether this track is available and loaded
   */
  isAvailable: boolean;
}
export interface capSubtitleTrackOptions {
  /**
   * Id of DIV Element parent of the player
   */
  playerId?: string;
  /**
   * ID of track to select, or null/empty string to disable subtitles
   */
  trackId: string | null;
}
