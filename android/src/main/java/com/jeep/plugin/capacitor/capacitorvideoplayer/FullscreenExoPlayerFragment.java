package com.jeep.plugin.capacitor.capacitorvideoplayer;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.ActivityManager;
import android.app.PictureInPictureParams;
import android.content.ContentUris;
import android.content.Context;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffColorFilter;
import android.graphics.drawable.Drawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;
import android.util.Log;
import android.util.Rational;
import android.util.TypedValue;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;
import androidx.activity.OnBackPressedCallback;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.appcompat.view.ContextThemeWrapper;
import androidx.constraintlayout.widget.ConstraintLayout;
import androidx.core.content.ContextCompat;
import androidx.core.graphics.drawable.DrawableCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import androidx.fragment.app.Fragment;
import androidx.mediarouter.app.MediaRouteButton;
import androidx.mediarouter.media.MediaControlIntent;
import androidx.mediarouter.media.MediaRouteSelector;
import androidx.mediarouter.media.MediaRouter;
import com.getcapacitor.JSObject;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.common.C;
import androidx.media3.session.MediaSession;
import androidx.media3.exoplayer.DefaultLoadControl;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.common.Format;
import androidx.media3.exoplayer.LoadControl;
import androidx.media3.common.MediaItem;
import androidx.media3.common.MediaMetadata;
import androidx.media3.common.PlaybackParameters;
import androidx.media3.common.Player;
import androidx.media3.common.Tracks;
import androidx.media3.common.AudioAttributes;
import androidx.media3.cast.RemoteCastPlayer;
import androidx.media3.common.DeviceInfo;
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory;
import androidx.media3.exoplayer.source.MediaSource;
import androidx.media3.exoplayer.source.ProgressiveMediaSource;
import androidx.media3.exoplayer.trackselection.AdaptiveTrackSelection;
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector;
import androidx.media3.exoplayer.trackselection.ExoTrackSelection;
import androidx.media3.exoplayer.trackselection.TrackSelector;
import androidx.media3.common.TrackSelectionOverride;
import androidx.media3.common.TrackSelectionParameters;
import com.google.common.collect.ImmutableList;

import androidx.media3.ui.AspectRatioFrameLayout;
import androidx.media3.ui.CaptionStyleCompat;
import androidx.media3.ui.DefaultTimeBar;
import androidx.media3.ui.PlayerView;
import androidx.media3.datasource.DataSource;
import androidx.media3.exoplayer.upstream.DefaultBandwidthMeter;

import androidx.media3.datasource.DefaultHttpDataSource;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.VideoSize;
import com.google.android.gms.cast.framework.CastButtonFactory;
import com.google.android.gms.cast.framework.CastContext;
import com.google.android.gms.cast.framework.CastState;
import com.google.android.gms.cast.framework.CastStateListener;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.jeep.plugin.capacitor.capacitorvideoplayer.Notifications.NotificationCenter;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.Executor;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.json.JSONException;

@UnstableApi
public class FullscreenExoPlayerFragment extends Fragment {

  public String videoPath;
  public Float videoRate;
  public String playerId;
  public String subTitle;
  public String language;
  public JSObject subTitleOptions;
  public JSObject headers;
  public Boolean isTV = false;
  public Boolean isInternal = false;
  public Long videoId;
  public Boolean exitOnEnd = true;
  public Boolean loopOnEnd = false;
  public Boolean pipEnabled = true;
  public Boolean bkModeEnabled = true;
  public Boolean showControls = true;
  public String displayMode = "all";
  public String title;
  public String smallTitle;
  public String accentColor;
  public Boolean chromecast = true;
  public String artwork;
  public List<SubtitleTrack> subtitleTracks;
  public String selectedSubtitleId;
  public int positionUpdateInterval = 5; // Default 5 seconds

  private static final String TAG = FullscreenExoPlayerFragment.class.getName();
  public static final long UNKNOWN_TIME = -1L;
  private final List<String> supportedFormat = Arrays.asList(
    new String[] { "mp4", "webm", "ogv", "3gp", "flv", "dash", "mpd", "m3u8", "ism", "ytube", "" }
  );
  private Player.Listener listener;
  private PlayerView styledPlayerView;
  private String vType = null;
  private static ExoPlayer player;
  private boolean playWhenReady = true;
  private boolean firstReadyToPlay = true;
  private boolean isEnded = false;
  /** Mirrors ExoPlayer playback; used to avoid background events when paused. */
  private boolean isVideoPlaying = false;
  private int currentWindow = 0;
  private long playbackPosition = 0;
  private Uri uri = null;
  private Uri sturi = null;
  private ProgressBar Pbar;
  private View view;
  private ImageButton closeBtn;
  private ImageButton pipBtn;
  private ImageButton resizeBtn;
  private ConstraintLayout constLayout;
  private LinearLayout linearLayout;
  private TextView header_tv;
  private TextView header_below;
  private static ImageView cast_image;
  private DefaultTimeBar exo_progress;
  private TextView exo_position;
  private TextView exo_duration;
  private TextView exo_label_separation;
  private TextView live_text;
  private Context context;
  private boolean isMuted = false;
  private float curVolume = (float) 0.5;
  private String stForeColor = "";
  private String stBackColor = "";
  private Integer stFontSize = 16;
  private boolean isInPictureInPictureMode = false;
  private TrackSelector trackSelector;
  // Current playback position (in milliseconds).
  private int mCurrentPosition;
  private int mDuration;
  private static final int videoStep = 10000;
  private boolean isCastSession = false;

  // Tag for the instance state bundle.
  private static final String PLAYBACK_TIME = "play_time";

  private PictureInPictureParams.Builder pictureInPictureParams;
  private MediaSession mediaSession;

  private PackageManager packageManager;
  private Boolean isPIPModeeEnabled = true;
  final Handler handler = new Handler(Looper.getMainLooper());
  final Runnable mRunnable = new Runnable() {
    @RequiresApi(api = Build.VERSION_CODES.N)
    public void run() {
      checkPIPPermission();
    }
  };
  private Handler positionUpdateHandler = new Handler(Looper.getMainLooper());
  private Runnable positionUpdateRunnable;
  private long bridgeReadyAtMs = 0L;
  private String lastEmittedSubtitleLanguage = null;
  private String lastEmittedSubtitleTrackId = null;

  private Integer resizeStatus = AspectRatioFrameLayout.RESIZE_MODE_FIT;
  private MediaRouteButton mediaRouteButton;
  private CastContext castContext;
  private Player castPlayer;
  private MediaItem mediaItem;
  private MediaRouter mRouter;
  private MediaRouter.Callback mCallback = new EmptyCallback();
  private MediaRouteSelector mSelector;
  private CastStateListener castStateListener = null;
  private Boolean playerReady = false;

  /**
   * Create Fragment View
   * @param inflater
   * @param container
   * @param savedInstanceState
   * @return View
   */
  public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
    // Fix: Handle null container - can occur when fragment is detached or during lifecycle transitions
    if (container != null) {
      context = container.getContext();
    } else {
      context = getContext();
    }
    
    // Fix: Return null if fragment is detached (no valid context available)
    if (context == null) {
      Log.w(TAG, "Fragment is detached, cannot create view");
      return null;
    }

    // Orphaned fragment after process death — fields were never re-populated by the plugin
    if (playerId == null) {
      Log.w(TAG, "Orphaned fragment after process death — no playerId");
      Activity act = getActivity();
      if (act != null) {
        act.finishAndRemoveTask();
      }
      return null;
    }

    packageManager = context.getPackageManager();
    view = inflater.inflate(R.layout.fragment_fs_exoplayer, container, false);
    constLayout = view.findViewById(R.id.fsExoPlayer);
    linearLayout = view.findViewById(R.id.linearLayout);
    styledPlayerView = view.findViewById(R.id.videoViewId);
    header_tv = view.findViewById(R.id.header_tv);
    header_below = view.findViewById(R.id.header_below);
    Pbar = view.findViewById(R.id.indeterminateBar);
    exo_progress = view.findViewById(R.id.exo_progress);
    exo_progress.setVisibility(View.GONE);
    exo_position = view.findViewById(R.id.exo_position);
    exo_position.setVisibility(View.GONE);
    exo_duration = view.findViewById(R.id.exo_duration);
    exo_duration.setVisibility(View.GONE);
    exo_label_separation = view.findViewById(R.id.exo_label_separation);
    exo_label_separation.setVisibility(View.GONE);
    live_text = view.findViewById(R.id.live_text);
    resizeBtn = view.findViewById(R.id.exo_resize);
    cast_image = view.findViewById(R.id.cast_image);
    mediaRouteButton = view.findViewById(R.id.media_route_button);
    styledPlayerView.setShowPreviousButton(false);
    styledPlayerView.setShowNextButton(false);
    styledPlayerView.setShowFastForwardButton(false);
    styledPlayerView.setShowRewindButton(false);

    Activity mAct = getActivity();
    // Fix: Check if activity is null before using it (can be null if fragment is detached)
    if (mAct != null) {
      // Android 16 (API 36) and above ignores orientation restrictions on large displays (foldables, tablets)
      // For Android 16+, rely on adjustAspectRatio() to handle orientation changes gracefully
      // This prevents Play Store warnings about ignored orientation restrictions
      if (Build.VERSION.SDK_INT < 36) {
        if (displayMode.equals("landscape")) {
          mAct.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_USER_LANDSCAPE);
        }
        if (displayMode.equals("portrait")) {
          mAct.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_USER_PORTRAIT);
        }
      }
    } else {
      Log.w(TAG, "Activity is null, cannot set orientation");
    }
    if (!showControls) {
      styledPlayerView.setUseController(false);
    } else {
      styledPlayerView.setUseController(true);
    }

    if (!chromecast) {
      mediaRouteButton.setVisibility(View.GONE);
    } else {
      initializeCastService();
    }

    if (title != "") {
      header_tv.setText(title);
    }
    if (smallTitle != "") {
      header_below.setText(smallTitle);
    }
    if (accentColor != "") {
      Pbar.getIndeterminateDrawable().setColorFilter(
        new PorterDuffColorFilter(Color.parseColor(accentColor), PorterDuff.Mode.MULTIPLY)
      );
      exo_progress.setPlayedColor(Color.parseColor(accentColor));
      exo_progress.setScrubberColor(Color.parseColor(accentColor));
    }

    closeBtn = view.findViewById(R.id.exo_close);
    pipBtn = view.findViewById(R.id.exo_pip);
    styledPlayerView.requestFocus();
    linearLayout.setVisibility(View.INVISIBLE);
    styledPlayerView.setControllerShowTimeoutMs(3000);
    styledPlayerView.setControllerVisibilityListener(
      new PlayerView.ControllerVisibilityListener() {
        @Override
        public void onVisibilityChanged(int visibility) {
          linearLayout.setVisibility(visibility);
        }
      }
    );

    listener =
      new Player.Listener() {
        @Override
        public void onIsPlayingChanged(boolean playing) {
          isVideoPlaying = playing;
        }

        @Override
        public void onVideoSizeChanged(VideoSize videoSize) {
          if (styledPlayerView == null || videoSize.width <= 0 || videoSize.height <= 0) {
            return;
          }
          styledPlayerView.post(() -> adjustAspectRatio());
        }

        private Map<String, Object> playbackInfo() {
          return new HashMap<String, Object>() {
            {
              put("fromPlayerId", playerId);
              put("currentTime", String.valueOf(player.getCurrentPosition() / 1000));
            }
          };
        }

        private void notifyReadyPlayPause() {
          Map<String, Object> info = playbackInfo();
          Log.v(TAG, "**** in ExoPlayer.STATE_READY isPlaying " + player.isPlaying());
          if (player.isPlaying()) {
            Log.v(TAG, "**** in ExoPlayer.STATE_READY going to notify playerItemPlay ");
            NotificationCenter.defaultCenter().postNotification("playerItemPlay", info);
            resizeBtn.setVisibility(View.VISIBLE);
            startPositionUpdates();

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && pipEnabled) {
              pipBtn.setVisibility(View.VISIBLE);
            }
          } else {
            Log.v(TAG, "**** in ExoPlayer.STATE_READY going to notify playerItemPause ");
            NotificationCenter.defaultCenter().postNotification("playerItemPause", info);
            stopPositionUpdates();
          }
        }

        @Override
        public void onPlaybackStateChanged(int state) {
          String stateString;
          Map<String, Object> info = playbackInfo();

          switch (state) {
            case Player.STATE_IDLE:
              stateString = "ExoPlayer.STATE_IDLE      -";
              Toast.makeText(context, "Video Url not found", Toast.LENGTH_SHORT).show();
              playerExit();
              break;
            case Player.STATE_BUFFERING:
              stateString = "ExoPlayer.STATE_BUFFERING -";
              Pbar.setVisibility(View.VISIBLE);
              break;
            case Player.STATE_READY:
              stateString = "ExoPlayer.STATE_READY     -";
              Pbar.setVisibility(View.GONE);
              playerReady = true;
              if (!showControls) {
                styledPlayerView.setUseController(false);
              } else {
                styledPlayerView.setUseController(true);
              }
              linearLayout.setVisibility(View.INVISIBLE);
              Log.v(TAG, "**** in ExoPlayer.STATE_READY firstReadyToPlay " + firstReadyToPlay);

              if (firstReadyToPlay) {
                firstReadyToPlay = false;
                bridgeReadyAtMs = System.currentTimeMillis();
                NotificationCenter.defaultCenter().postNotification("playerItemReady", info);
                
                // Select initial subtitle track if specified (after player is ready)
                if (selectedSubtitleId != null && !selectedSubtitleId.isEmpty()) {
                  // Use post to ensure tracks are available
                  styledPlayerView.post(() -> {
                    selectSubtitleTrack(selectedSubtitleId);
                  });
                }
                
                play();
                Log.v(TAG, "**** in ExoPlayer.STATE_READY firstReadyToPlay player.isPlaying" + player.isPlaying());
                player.seekTo(currentWindow, playbackPosition);
                styledPlayerView.post(() -> adjustAspectRatio());

                // We show progress bar, position and duration only when the video is not live
                if (!player.isCurrentMediaItemLive()) {
                  exo_progress.setVisibility(View.VISIBLE);
                  exo_position.setVisibility(View.VISIBLE);
                  exo_duration.setVisibility(View.VISIBLE);
                  exo_label_separation.setVisibility(View.VISIBLE);
                  styledPlayerView.setShowFastForwardButton(true);
                  styledPlayerView.setShowRewindButton(true);
                } else {
                  live_text.setVisibility(View.VISIBLE);
                }
              } else {
                notifyReadyPlayPause();
              }
              break;
            case Player.STATE_ENDED:
              stateString = "ExoPlayer.STATE_ENDED     -";
              Log.v(TAG, "**** in ExoPlayer.STATE_ENDED going to notify playerItemEnd ");

              player.seekTo(0);
              player.setVolume(curVolume);
              player.setPlayWhenReady(false);
              if (exitOnEnd) {
                releasePlayer();
/*
                Activity mAct = getActivity();
                int mOrient = mAct.getRequestedOrientation();
                if (mOrient == ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE) {
                  mAct.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
                }
*/
                NotificationCenter.defaultCenter().postNotification("playerItemEnd", info);
              }
              break;
            default:
              stateString = "UNKNOWN_STATE             -";
              break;
          }
        }

        @Override
        public void onPlayWhenReadyChanged(boolean playWhenReady, int reason) {
          if (
            player.getPlaybackState() == Player.STATE_READY &&
            !firstReadyToPlay &&
            reason == Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST
          ) {
            notifyReadyPlayPause();
          }
        }

        @Override
        public void onPositionDiscontinuity(
          Player.PositionInfo oldPosition,
          Player.PositionInfo newPosition,
          @Player.DiscontinuityReason int reason
        ) {
          if (reason != Player.DISCONTINUITY_REASON_SEEK) {
            return;
          }
          if (System.currentTimeMillis() - bridgeReadyAtMs < 800) {
            return;
          }
          postSeekCompletedNs(oldPosition.positionMs, newPosition.positionMs);
        }

        @Override
        public void onTracksChanged(Tracks tracks) {
          maybeEmitSubtitleFromTracks();
        }
      };

    if (isTV) {
      Toast.makeText(context, "Device is a TV ", Toast.LENGTH_SHORT).show();
    }

    if (!isInternal) {
      uri = Uri.parse(videoPath);
      
      // Handle multiple subtitle tracks or backward compatibility
      if (subtitleTracks != null && !subtitleTracks.isEmpty()) {
        // New API: multiple tracks - sturi will be set to first track for backward compatibility
        if (!subtitleTracks.isEmpty()) {
          sturi = Uri.parse(subtitleTracks.get(0).getUrl());
        }
      } else {
        // Backward compatibility: single subtitle
        sturi = subTitle != null ? Uri.parse(subTitle) : null;
      }

      stForeColor = subTitleOptions.has("foregroundColor") ? subTitleOptions.getString("foregroundColor") : "rgba(255,255,255,1)";
      stBackColor = subTitleOptions.has("backgroundColor") ? subTitleOptions.getString("backgroundColor") : "rgba(0,0,0,1)";
      stFontSize = subTitleOptions.has("fontSize") ? subTitleOptions.getInteger("fontSize") : 16;
      // get video type
      vType = getVideoType(uri);
      Log.v(TAG, "display url: " + uri);
      Log.v(TAG, "display subtitle url: " + sturi);
      Log.v(TAG, "display isTV: " + isTV);
      Log.v(TAG, "display vType: " + vType);
    }
    if (uri != null || isInternal) {
      // go fullscreen (edge-to-edge; legacy FLAG_FULLSCREEN is ignored on targetSdk 35+)
      hideSystemUi();
      if (savedInstanceState != null) {
        mCurrentPosition = savedInstanceState.getInt(PLAYBACK_TIME);
      }

      getActivity()
        .runOnUiThread(
          new Runnable() {
            @Override
            public void run() {
              // Set the onKey listener
              view.setFocusableInTouchMode(true);
              view.requestFocus();
              view.setOnKeyListener(
                new View.OnKeyListener() {
                  @Override
                  public boolean onKey(View v, int keyCode, KeyEvent event) {
                    if (event.getAction() == KeyEvent.ACTION_UP) {
                      long videoPosition = player.getCurrentPosition();
                      Log.v(TAG, "$$$$ onKey " + keyCode + " $$$$");
                      if (keyCode == KeyEvent.KEYCODE_BACK || keyCode == KeyEvent.KEYCODE_HOME) {
                        Log.v(TAG, "$$$$ Going to backpress $$$$");
                        backPressed();
                      } else if (isTV) {
                        switch (keyCode) {
                          case KeyEvent.KEYCODE_DPAD_RIGHT:
                            fastForward(videoPosition, 1);
                            break;
                          case KeyEvent.KEYCODE_DPAD_LEFT:
                            rewind(videoPosition, 1);
                            break;
                          case KeyEvent.KEYCODE_DPAD_CENTER:
                            play_pause();
                            break;
                          case KeyEvent.KEYCODE_MEDIA_FAST_FORWARD:
                            fastForward(videoPosition, 2);
                            break;
                          case KeyEvent.KEYCODE_MEDIA_REWIND:
                            rewind(videoPosition, 2);
                            break;
                        }
                      }
                      return true;
                    } else {
                      return false;
                    }
                  }
                }
              );

              // initialize the player
              initializePlayer();

              closeBtn.setOnClickListener(
                new View.OnClickListener() {
                  @Override
                  public void onClick(View view) {
                    playerExit();
                  }
                }
              );
              pipBtn.setOnClickListener(
                new View.OnClickListener() {
                  @Override
                  public void onClick(View view) {
                    pictureInPictureMode();
                  }
                }
              );
              resizeBtn.setOnClickListener(
                new View.OnClickListener() {
                  @Override
                  public void onClick(View view) {
                    resizePressed();
                  }
                }
              );
            }
          }
        );
    } else {
      Log.d(TAG, "Video path wrong or type not supported");
      Toast.makeText(context, "Video path wrong or type not supported", Toast.LENGTH_SHORT).show();
    }
    return view;
  }

  /**
   * Predictive Back (targetSdk 33+): gesture swipe and 3-button back both route through
   * OnBackPressedDispatcher and no longer deliver KeyEvent.KEYCODE_BACK to View.OnKeyListener.
   * Scoped to the view lifecycle so the callback is removed when fullscreen closes.
   */
  @Override
  public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
    super.onViewCreated(view, savedInstanceState);
    requireActivity()
      .getOnBackPressedDispatcher()
      .addCallback(
        getViewLifecycleOwner(),
        new OnBackPressedCallback(true) {
          @Override
          public void handleOnBackPressed() {
            backPressed();
          }
        }
      );
  }

  /**
   * Sets the cast image in playerView when it is connected to a cast device
   */
  private void loadCastImage() {
    final String image = artwork;
    if (image == null || image.isEmpty()) {
      return;
    }
    ExecutorService executor = Executors.newSingleThreadExecutor();
    executor.execute(() -> {
      try {
        Bitmap bitmap = null;
        try {
          URL url = new URL(image);
          HttpURLConnection connection = (HttpURLConnection) url.openConnection();
          connection.setDoInput(true);
          connection.connect();
          InputStream input = connection.getInputStream();
          bitmap = BitmapFactory.decodeStream(input);
        } catch (IOException e) {
          e.printStackTrace();
        }
        final Bitmap result = bitmap;
        new Handler(Looper.getMainLooper()).post(() -> {
          if (cast_image != null) {
            cast_image.setImageBitmap(result);
          }
        });
      } finally {
        executor.shutdown();
      }
    });
  }

  /**
   * Show controller
   */
  public void showController() {
    styledPlayerView.showController();
  }

  /**
   * isControllerIsFullyVisible
   */
  public boolean isControllerIsFullyVisible() {
    return styledPlayerView.isControllerFullyVisible();
  }

  /**
   * Perform backPressed Action
   */
  private void backPressed() {
    if (isCastSession) {
      playerExit();
      return;
    }
    if (
      !isInPictureInPictureMode &&
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
        packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE) &&
        isPIPModeeEnabled &&
        pipEnabled &&
        playerReady // <- playerReady: this prevents a crash if the user presses back before the player is ready (when enters in pip mode and tries to get the aspect ratio)
    ) {
      pictureInPictureMode();
    } else {
      playerExit();
    }
  }

  private void resizePressed() {
    if (resizeStatus == AspectRatioFrameLayout.RESIZE_MODE_FIT) {
      styledPlayerView.setResizeMode(AspectRatioFrameLayout.RESIZE_MODE_FILL);
      resizeStatus = AspectRatioFrameLayout.RESIZE_MODE_FILL;
      resizeBtn.setImageResource(R.drawable.ic_zoom);
    } else if (resizeStatus == AspectRatioFrameLayout.RESIZE_MODE_FILL) {
      styledPlayerView.setResizeMode(AspectRatioFrameLayout.RESIZE_MODE_ZOOM);
      resizeStatus = AspectRatioFrameLayout.RESIZE_MODE_ZOOM;
      resizeBtn.setImageResource(R.drawable.ic_fit);
    } else {
      styledPlayerView.setResizeMode(AspectRatioFrameLayout.RESIZE_MODE_FIT);
      resizeStatus = AspectRatioFrameLayout.RESIZE_MODE_FIT;
      resizeBtn.setImageResource(R.drawable.ic_expand);
    }
  }

  public void playerExit() {
    // Capture head before teardown. Do not seekTo(0) — that races position ticks and can
    // poison Epic 45 video→audio handoff with position 0 / stale open position.
    final double exitTimeSec = player != null ? (player.getCurrentPosition() == UNKNOWN_TIME
      ? 0.0
      : player.getCurrentPosition() / 1000.0) : 0.0;
    Map<String, Object> info = new HashMap<String, Object>() {
      {
        put("dismiss", "1");
        put("currentTime", exitTimeSec);
      }
    };
    if (player != null) {
      player.setVolume(curVolume);
    }
    releasePlayer();
/* 
    Activity mAct = getActivity();
    int mOrient = mAct.getRequestedOrientation();
    if (mOrient == ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE) {
      mAct.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
    }
*/
    // We control if the user lock the screen when the player is in pip mode
    try {
      NotificationCenter.defaultCenter().postNotification("playerFullscreenDismiss", info);
    } catch (Exception e) {
      Log.e(TAG, "Error in posting notification");
    }
  }

  /**
   * Perform pictureInPictureMode Action
   */
  private void pictureInPictureMode() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O
        || !packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
      return;
    }
    styledPlayerView.setUseController(false);
    styledPlayerView.setControllerAutoShow(false);
    linearLayout.setVisibility(View.INVISIBLE);
    Log.v(TAG, "PIP break 1");
    pictureInPictureParams = new PictureInPictureParams.Builder();
    Rational aspectRatio = new Rational(player.getVideoFormat().width, player.getVideoFormat().height);
    getActivity().enterPictureInPictureMode(pictureInPictureParams.setAspectRatio(aspectRatio).build());
    Log.v(TAG, "PIP break 2");
    isInPictureInPictureMode = getActivity().isInPictureInPictureMode();
    CapacitorVideoPlayerPlugin plugin = CapacitorVideoPlayerPlugin.getInstance();
    if (plugin != null) {
      JSObject pipData = new JSObject();
      pipData.put("fromPlayerId", playerId != null ? playerId : "fullscreen");
      pipData.put("currentTime", getCurrentTime());
      plugin.notifyJeepCapVideoPlayerPipStart(pipData);
    }
    if (sturi != null) {
      setSubtitle(true);
    }
    if (player != null) play();

    handler.postDelayed(mRunnable, 100);
    Log.v(TAG, "PIP break 4");
  }

  @RequiresApi(api = Build.VERSION_CODES.N)
  private void checkPIPPermission() {
    isPIPModeeEnabled = isInPictureInPictureMode;
    if (!isInPictureInPictureMode) {
      backPressed();
    }
  }

  /**
   * When the activity stops (e.g. app backgrounded), notify JS if ExoPlayer is actively playing.
   * Skips Picture-in-Picture where {@link Activity#isInPictureInPictureMode()} is true.
   */
  private void notifyAppBackgroundWhilePlayingIfNeeded() {
    if (!isVideoPlaying || player == null) {
      return;
    }
    Activity activity = getActivity();
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && activity != null && activity.isInPictureInPictureMode()) {
      return;
    }
    CapacitorVideoPlayerPlugin plugin = CapacitorVideoPlayerPlugin.getInstance();
    if (plugin == null) {
      return;
    }
    JSObject data = new JSObject();
    data.put("fromPlayerId", playerId != null ? playerId : "fullscreen");
    data.put("currentTime", player.getCurrentPosition() / 1000.0);
    plugin.notifyJeepCapVideoPlayerBackground(data);
  }

  private void notifyPictureInPictureStopIfNeeded() {
    CapacitorVideoPlayerPlugin plugin = CapacitorVideoPlayerPlugin.getInstance();
    if (plugin == null) {
      return;
    }
    JSObject data = new JSObject();
    data.put("fromPlayerId", playerId != null ? playerId : "fullscreen");
    data.put("currentTime", getCurrentTime());
    plugin.notifyJeepCapVideoPlayerPipStop(data);
  }

  /**
   * Perform onStart Action
   */
  @Override
  public void onStart() {
    super.onStart();
    //if (chromecast && castContext != null) mRouter.addCallback(mSelector, mCallback, MediaRouter.CALLBACK_FLAG_REQUEST_DISCOVERY);

    if (Build.VERSION.SDK_INT >= 24) {
      if (styledPlayerView != null) {
        // If cast is playing then it doesn't start the local player once get backs from background
        if (castContext != null && Boolean.TRUE.equals(chromecast) && isRemoteCastConnected(castPlayer)) return;

        initializePlayer();
        if (player != null && player.getCurrentPosition() != 0) {
          firstReadyToPlay = false;
          play();
        }
      } else {
        // Story 45.x: avoid finishAndRemoveTask — same class of bug as PiP onStop (kills the whole Capacitor activity).
        Log.w(TAG, "onStart: styledPlayerView is null — dismissing via playerExit() only");
        playerExit();
      }
    }
  }

  /**
   * Perform onStop Action
   */
  @Override
  public void onStop() {
    super.onStop();
    notifyAppBackgroundWhilePlayingIfNeeded();
    if (isInPictureInPictureMode) {
      notifyPictureInPictureStopIfNeeded();
      linearLayout.setVisibility(View.VISIBLE);
      playerExit();
      // Story 45.x: do NOT call finishAndRemoveTask() here — it kills the entire Capacitor
      // Activity before JS can run endVideoSession(). The playerFullscreenDismiss notification
      // (fired inside playerExit -> backPressed -> ... CapacitorVideoPlayerPlugin) already
      // emits jeepCapVideoPlayerExit which gives the WebView layer a chance to call
      // endVideoSession and restore the audio session cleanly.
      isInPictureInPictureMode = false;
      return;
    }
    // Epic 45 handoff (bkmodeEnabled=false): dismiss fullscreen when the app backgrounds so the
    // native overlay cannot survive a foreground return if JS is throttled in the WebView.
    if (!bkModeEnabled && isApplicationSentToBackground(context)) {
      playerExit();
    }
  }

  /**
   * Perform onDestroy Action
   */
  @Override
  public void onDestroy() {
    super.onDestroy();
    if (chromecast && mRouter != null) {
      mRouter.removeCallback(mCallback);
    }
    releasePlayer();
  }

  /**
   * Perform onPause Action
   */
  @Override
  public void onPause() {
    super.onPause();
    if (chromecast && castContext != null) {
      castContext.removeCastStateListener(castStateListener);
    }
    boolean isAppBackground = false;
    if (bkModeEnabled) isAppBackground = isApplicationSentToBackground(context);

    if (!isInPictureInPictureMode) {
      if (Build.VERSION.SDK_INT < 24) {
        if (player != null) player.setPlayWhenReady(false);
        releasePlayer();
      } else {
        if (isAppBackground) {
          if (player != null) {
            if (player.isPlaying()) play();
          }
        } else {
          pause();
        }
      }
    } else {
      if (linearLayout.getVisibility() == View.VISIBLE) {
        linearLayout.setVisibility(View.INVISIBLE);
      }
      if ((isInPictureInPictureMode || isAppBackground) && player != null) play();
    }
  }

  /**
   * Release the player
   */
  public void releasePlayer() {
    stopPositionUpdates();
    isVideoPlaying = false;
    if (player != null) {
      playWhenReady = player.getPlayWhenReady();
      playbackPosition = player.getCurrentPosition();
      currentWindow = player.getCurrentMediaItemIndex();
      DwbnVideoHandoffBridge.detach(player);
      if (mediaSession != null) {
        mediaSession.release();
        mediaSession = null;
      }
      player.setRepeatMode(player.REPEAT_MODE_OFF);
      player.removeListener(listener);
      player.release();
      player = null;
      showSystemUI();
      resetVariables();
      if (chromecast && castPlayer != null) {
        castPlayer.release();
        castPlayer = null;
      }
    }
  }

  /**
   * Perform onResume Action
   */
  @Override
  public void onResume() {
    super.onResume();
    //if (chromecast && castContext != null) castContext.addCastStateListener(castStateListener);
    if (!isInPictureInPictureMode) {
      hideSystemUi();
      if ((Build.VERSION.SDK_INT < 24 || player == null)) {
        initializePlayer();
      }
    } else {
      notifyPictureInPictureStopIfNeeded();
      isInPictureInPictureMode = false;
      if (
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
      ) {
        if (!showControls) {
          styledPlayerView.setUseController(false);
        } else {
          styledPlayerView.setUseController(true);
        }
      }
      if (sturi != null) {
        setSubtitle(false);
      }
    }
  }

  /**
   * Hide System UI using edge-to-edge APIs (required for targetSdk 35+/36).
   */
  @SuppressLint("InlinedApi")
  private void hideSystemUi() {
    Activity activity = getActivity();
    if (activity == null) {
      return;
    }
    Window window = activity.getWindow();
    if (window == null) {
      return;
    }

    WindowCompat.setDecorFitsSystemWindows(window, false);
    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      WindowManager.LayoutParams attrs = window.getAttributes();
      attrs.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS;
      window.setAttributes(attrs);
    }

    View decorView = window.getDecorView();
    WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(window, decorView);
    if (controller != null) {
      controller.hide(WindowInsetsCompat.Type.systemBars());
      controller.setSystemBarsBehavior(WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
    }
  }

  /**
   * Leave the fullscreen mode and restore system bars.
   */
  private void showSystemUI() {
    Activity activity = getActivity();
    if (activity == null) {
      return;
    }
    Window window = activity.getWindow();
    if (window == null) {
      return;
    }

    WindowCompat.setDecorFitsSystemWindows(window, true);
    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      WindowManager.LayoutParams attrs = window.getAttributes();
      attrs.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_DEFAULT;
      window.setAttributes(attrs);
    }

    View decorView = window.getDecorView();
    WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(window, decorView);
    if (controller != null) {
      controller.show(WindowInsetsCompat.Type.systemBars());
    }
  }

  /**
   * Initialize the player
   */
  private void initializePlayer() {
    if (player == null) {
      DefaultBandwidthMeter bandwidthMeter = new DefaultBandwidthMeter.Builder(context).build();
      ExoTrackSelection.Factory videoTrackSelectionFactory = new AdaptiveTrackSelection.Factory();
      trackSelector = new DefaultTrackSelector(context, videoTrackSelectionFactory);
      LoadControl loadControl = new DefaultLoadControl();
      player =
        new ExoPlayer.Builder(context)
          .setSeekBackIncrementMs(10000)
          .setSeekForwardIncrementMs(10000)
          .setTrackSelector(trackSelector)
          .setLoadControl(loadControl)
          .setBandwidthMeter(bandwidthMeter)
          .build();
    }

    styledPlayerView.setPlayer(player);

    MediaSource mediaSource;
    if (!isInternal) {
      if (videoPath.substring(0, 21).equals("file:///android_asset") || videoPath.substring(0, 15).equals("content://media")) {
        mediaSource = buildAssetMediaSource(uri);
      } else {
        mediaSource = buildHttpMediaSource();
      }
    } else {
      Uri videoUri = ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, videoId);
      mediaSource = buildInternalMediaSource(videoUri);
    }

    if (mediaSource != null) {
      player.setAudioAttributes(AudioAttributes.DEFAULT, true);
      player.addListener(listener);
      player.setMediaSource(mediaSource);
      player.prepare();
      if (loopOnEnd) {
        player.setRepeatMode(player.REPEAT_MODE_ONE);
      } else {
        player.setRepeatMode(player.REPEAT_MODE_OFF);
      }
    }
    Map<String, Object> info = new HashMap<String, Object>() {
      {
        put("fromPlayerId", playerId);
      }
    };
    if (sturi != null || (subtitleTracks != null && !subtitleTracks.isEmpty())) {
      setSubtitle(false);
    }
    if (mediaSession != null) {
      mediaSession.release();
      mediaSession = null;
    }
    // Must not share Media3's default empty session id with the playlist plugin (handoff keeps audio session alive).
    mediaSession = new MediaSession.Builder(context, player).setId("org.dwbn.video").build();
    DwbnVideoHandoffBridge.attach(player);

    NotificationCenter.defaultCenter().postNotification("initializePlayer", info);
  }

  private void setSubtitle(boolean transparent) {
    int foreground;
    int background;
    if (!transparent) {
      foreground = Color.WHITE;
      background = Color.BLACK;
      if (stForeColor.length() > 4 && stForeColor.substring(0, 4).equals("rgba")) {
        foreground = getColorFromRGBA(stForeColor);
      }
      if (stBackColor.length() > 4 && stBackColor.substring(0, 4).equals("rgba")) {
        background = getColorFromRGBA(stBackColor);
      }
    } else {
      foreground = Color.TRANSPARENT;
      background = Color.TRANSPARENT;
    }
    styledPlayerView
      .getSubtitleView()
      .setStyle(
        new CaptionStyleCompat(foreground, background, Color.TRANSPARENT, CaptionStyleCompat.EDGE_TYPE_NONE, Color.WHITE, null)
      );
    styledPlayerView.getSubtitleView().setFixedTextSize(TypedValue.COMPLEX_UNIT_DIP, stFontSize);
    styledPlayerView.setShowSubtitleButton(true);
  }

  /**
   * Build the Asset MediaSource
   */
  private DataSource.Factory createDefaultDataSourceFactory() {
    DefaultHttpDataSource.Factory httpFactory = new DefaultHttpDataSource.Factory();
    httpFactory.setUserAgent("jeep-exoplayer-plugin");
    return new androidx.media3.datasource.DefaultDataSource.Factory(context, httpFactory);
  }

  private MediaSource buildAssetMediaSource(Uri uri) {
    DataSource.Factory dataSourceFactory = createDefaultDataSourceFactory();
    return new DefaultMediaSourceFactory(dataSourceFactory)
      .createMediaSource(VideoMediaItemFactory.fromUri(uri, sidecarSubtitleTracks()));
  }

  /**
   * Build the Internal MediaSource
   */
  private MediaSource buildInternalMediaSource(Uri uri) {
    DataSource.Factory dataSourceFactory = createDefaultDataSourceFactory();
    return new ProgressiveMediaSource.Factory(dataSourceFactory).createMediaSource(VideoMediaItemFactory.fromUri(uri));
  }

  /**
   * Build the Http MediaSource
   * @return MediaSource
   */
  private MediaSource buildHttpMediaSource() {
    DefaultHttpDataSource.Factory httpDataSourceFactory = new DefaultHttpDataSource.Factory();
    httpDataSourceFactory.setUserAgent("jeep-exoplayer-plugin");
    httpDataSourceFactory.setConnectTimeoutMs(DefaultHttpDataSource.DEFAULT_CONNECT_TIMEOUT_MILLIS);
    httpDataSourceFactory.setReadTimeoutMs(1800000);
    httpDataSourceFactory.setAllowCrossProtocolRedirects(true);

    // If headers is not null and has data we pass them to the HttpDataSourceFactory
    if (headers != null && headers.length() > 0) {
      // We map the headers(JSObject) to a Map<String, String>
      Map<String, String> headersMap = new HashMap<String, String>();
      for (int i = 0; i < headers.names().length(); i++) {
        try {
          headersMap.put(headers.names().getString(i), headers.get(headers.names().getString(i)).toString());
        } catch (JSONException e) {
          e.printStackTrace();
        }
      }
      httpDataSourceFactory.setDefaultRequestProperties(headersMap);
    }

    DataSource.Factory dataSourceFactory = new androidx.media3.datasource.DefaultDataSource.Factory(context, httpDataSourceFactory);
    MediaItem mediaItem = VideoMediaItemFactory.fromUriAndType(uri, vType, sidecarSubtitleTracks());
    return new DefaultMediaSourceFactory(dataSourceFactory).createMediaSource(mediaItem);
  }

  /**
   * Save instance state
   */
  @Override
  public void onSaveInstanceState(Bundle outState) {
    super.onSaveInstanceState(outState);

    // Save the current playback position (in milliseconds) to the
    // instance state bundle.
    if (player != null) {
      outState.putInt(PLAYBACK_TIME, (int) player.getCurrentPosition());
    }
  }

  private int getColorFromRGBA(String rgbaColor) {
    int ret = 0;
    String color = rgbaColor.substring(rgbaColor.indexOf("(") + 1, rgbaColor.indexOf(")"));
    List<String> colors = Arrays.asList(color.split(","));
    if (colors.size() == 4) {
      ret =
        (Math.round(Float.parseFloat(colors.get(3).trim()) * 255) & 0xff) << 24 |
          (Integer.parseInt(colors.get(0).trim()) & 0xff) << 16 |
          (Integer.parseInt(colors.get(1).trim()) & 0xff) << 8 |
          (Integer.parseInt(colors.get(2).trim()) & 0xff);
    }
    return ret;
  }

  private List<SubtitleTrack> sidecarSubtitleTracks() {
    if (subtitleTracks != null && !subtitleTracks.isEmpty()) {
      return subtitleTracks;
    }
    if (sturi != null) {
      return VideoMediaItemFactory.singleTrackFromUri(sturi, language);
    }
    return new ArrayList<>();
  }

  /**
   * Select a subtitle track by ID
   */
  public void selectSubtitleTrack(String trackId) {
    if (player == null) {
      return;
    }

    try {
      String trackLanguage = null;
      if (subtitleTracks != null) {
        for (SubtitleTrack track : subtitleTracks) {
          if (track.getId().equals(trackId)) {
            trackLanguage = track.getLanguage();
            break;
          }
        }
      }

      Tracks tracks = player.getCurrentTracks();
      if (tracks == null) {
        Log.w(TAG, "Could not find subtitle track with ID: " + trackId);
        return;
      }

      for (Tracks.Group trackGroup : tracks.getGroups()) {
        if (trackGroup.getType() != C.TRACK_TYPE_TEXT) {
          continue;
        }
        for (int i = 0; i < trackGroup.length; i++) {
          Format format = trackGroup.getTrackFormat(i);
          if (SubtitleTrackSelection.formatMatches(format, trackId, trackLanguage)) {
            TrackSelectionOverride override = new TrackSelectionOverride(trackGroup.getMediaTrackGroup(), ImmutableList.of(i));
            player.setTrackSelectionParameters(
              SubtitleTrackSelection.withTextOverride(player.getTrackSelectionParameters(), override)
            );
            selectedSubtitleId = trackId;
            Log.v(TAG, "Selected subtitle track: " + trackId);
            return;
          }
        }
      }
      Log.w(TAG, "Could not find subtitle track with ID: " + trackId);
    } catch (Exception e) {
      Log.e(TAG, "Error selecting subtitle track: " + e.getMessage());
    }
  }

  /**
   * Disable subtitles
   */
  public void disableSubtitles() {
    if (player == null) {
      return;
    }
    try {
      player.setTrackSelectionParameters(SubtitleTrackSelection.withTextDisabled(player.getTrackSelectionParameters()));
      selectedSubtitleId = null;
    } catch (Exception e) {
      Log.e(TAG, "Error disabling subtitles: " + e.getMessage());
    }
  }

  /**
   * Fast Forward TV
   */
  private void fastForward(long position, int times) {
    if (player == null) {
      return;
    }
    if (position < mDuration - videoStep) {
      if (player.isPlaying()) {
        player.setPlayWhenReady(false);
      }
      player.seekTo(position + (long) times * videoStep);
      play();
    }
  }

  /**
   * Rewind TV
   */
  private void rewind(long position, int times) {
    if (player == null) {
      return;
    }
    if (position > videoStep) {
      if (player.isPlaying()) {
        player.setPlayWhenReady(false);
      }
      player.seekTo(position - (long) times * videoStep);
      play();
    }
  }

  /**
   * Play Pause TV
   */
  private void play_pause() {
    if (player == null) {
      return;
    }
    player.setPlayWhenReady(!player.isPlaying());
  }

  /**
   * Check if the player is playing
   * @return boolean
   */
  public boolean isPlaying() {
    return player != null && player.isPlaying();
  }

  /**
   * Start the player
   */
  public void play() {
    if (player == null) {
      return;
    }
    PlaybackParameters param = new PlaybackParameters(videoRate);
    player.setPlaybackParameters(param);

        /* If the user start the cast before the player is ready and playing, then the video will start
          in the device and chromecast at the same time. This is to avoid that behaviour.*/
    if (!isCastSession) {
      player.setPlayWhenReady(true);
      startPositionUpdates();
    }
  }

  /**
   * Pause the player
   */
  public void pause() {
    if (player != null) {
      player.setPlayWhenReady(false);
      stopPositionUpdates();
    }
  }
  
  /**
   * Start periodic position updates
   */
  private void startPositionUpdates() {
    stopPositionUpdates(); // Stop any existing updates
    
    if (positionUpdateInterval <= 0 || player == null) {
      return;
    }
    
    positionUpdateRunnable = new Runnable() {
      @Override
      public void run() {
        // Check if player is still valid before accessing it
        if (player == null || positionUpdateRunnable == null) {
          return;
        }
        
        try {
          if (player.isPlaying()) {
            Map<String, Object> info = new HashMap<String, Object>() {
              {
                put("fromPlayerId", playerId);
                put("currentTime", String.valueOf(player.getCurrentPosition() / 1000.0));
                long duration = player.getDuration();
                put("duration", String.valueOf(duration == UNKNOWN_TIME ? 0.0 : duration / 1000.0));
              }
            };
            NotificationCenter.defaultCenter().postNotification("playerItemPositionUpdate", info);
            // Only reschedule if player is still valid
            if (player != null && positionUpdateRunnable != null) {
              positionUpdateHandler.postDelayed(this, (long)(positionUpdateInterval * 1000));
            }
          }
        } catch (Exception e) {
          // Player might have been released, stop updates
          positionUpdateRunnable = null;
        }
      }
    };
    positionUpdateHandler.post(positionUpdateRunnable);
  }
  
  /**
   * Stop periodic position updates
   */
  private void stopPositionUpdates() {
    if (positionUpdateRunnable != null) {
      positionUpdateHandler.removeCallbacks(positionUpdateRunnable);
      positionUpdateRunnable = null;
    }
  }

  /**
   * Get the player duration
   * @return int in seconds
   */
  public int getDuration() {
    if (player == null) {
      return 0;
    }
    return player.getDuration() == UNKNOWN_TIME ? 0 : (int) (player.getDuration() / 1000);
  }

  /**
   * Get the player current position
   * @return int in seconds
   */
  public int getCurrentTime() {
    if (player == null) {
      return 0;
    }
    return player.getCurrentPosition() == UNKNOWN_TIME ? 0 : (int) (player.getCurrentPosition() / 1000);
  }

  private void postSeekCompletedNs(long fromMs, long toMs) {
    if (player == null) {
      return;
    }
    long dur = player.getDuration();
    Map<String, Object> info = new HashMap<>();
    info.put("fromPlayerId", playerId);
    info.put("fromPosition", fromMs / 1000.0);
    info.put("toPosition", toMs / 1000.0);
    if (dur != UNKNOWN_TIME && dur > 0) {
      info.put("duration", dur / 1000.0);
    }
    NotificationCenter.defaultCenter().postNotification("playerItemSeekCompleted", info);
  }

  private void postSubtitleChange(String language, String trackId) {
    Map<String, Object> info = new HashMap<>();
    info.put("fromPlayerId", playerId);
    info.put("language", language);
    if (trackId != null) {
      info.put("trackId", trackId);
    }
    NotificationCenter.defaultCenter().postNotification("playerItemSubtitleChange", info);
  }

  private void maybeEmitSubtitleFromTracks() {
    if (player == null) {
      return;
    }
    if (System.currentTimeMillis() - bridgeReadyAtMs < 800) {
      return;
    }
    TrackSelectionParameters selectionParameters = player.getTrackSelectionParameters();
    String offLanguage = SubtitleTrackSelection.offLanguageIfDisabled(selectionParameters);
    if (offLanguage != null) {
      if (!Objects.equals(offLanguage, lastEmittedSubtitleLanguage)) {
        lastEmittedSubtitleLanguage = offLanguage;
        lastEmittedSubtitleTrackId = null;
        postSubtitleChange(offLanguage, null);
      }
      return;
    }
    Tracks tracks = player.getCurrentTracks();
    String lang = "und";
    String tid = null;
    boolean found = false;
    for (Tracks.Group g : tracks.getGroups()) {
      if (g.getType() != C.TRACK_TYPE_TEXT) {
        continue;
      }
      for (int i = 0; i < g.length; i++) {
        if (g.isTrackSelected(i)) {
          Format f = g.getTrackFormat(i);
          if (f.language != null && !f.language.isEmpty()) {
            lang = f.language;
          } else {
            lang = "und";
          }
          tid = f.id;
          found = true;
          break;
        }
      }
      if (found) {
        break;
      }
    }
    if (Objects.equals(lang, lastEmittedSubtitleLanguage) && Objects.equals(tid, lastEmittedSubtitleTrackId)) {
      return;
    }
    lastEmittedSubtitleLanguage = lang;
    lastEmittedSubtitleTrackId = tid;
    postSubtitleChange(lang, tid);
  }

  /**
   * Set the player current position
   * @param timeSecond int
   */
  public void setCurrentTime(int timeSecond) {
    if (player == null) {
      return;
    }
    if (isInPictureInPictureMode) {
      styledPlayerView.setUseController(false);
      linearLayout.setVisibility(View.INVISIBLE);
    }
    long seekPosition = player.getCurrentPosition() == UNKNOWN_TIME
      ? 0
      : Math.min(Math.max(0, timeSecond * 1000), player.getDuration());
    player.seekTo(seekPosition);
  }

  /**
   * Return the player volume
   * @return float
   */
  public float getVolume() {
    if (player == null) {
      return curVolume;
    }
    return player.getVolume();
  }

  /**
   * Set the player volume
   * @param _volume float range 0,1
   */
  public void setVolume(float _volume) {
    if (player == null) {
      return;
    }
    float volume = Math.min(Math.max(0, _volume), 1L);
    player.setVolume(volume);
  }

  /**
   * Return the player rate
   * @return float
   */
  public float getRate() {
    return videoRate;
  }

  /**
   * Set the player rate
   * @param _rate float range [0.25f, 0.5f, 0.75f, 1f, 2f, 4f]
   */
  public void setRate(float _rate) {
    videoRate = _rate;
    if (player == null) {
      return;
    }
    PlaybackParameters param = new PlaybackParameters(videoRate);
    player.setPlaybackParameters(param);
  }

  /**
   * Switch Off/On the player volume
   * @param _isMuted boolean
   */
  public void setMuted(boolean _isMuted) {
    isMuted = _isMuted;
    if (player == null) {
      return;
    }
    if (isMuted) {
      curVolume = player.getVolume();
      player.setVolume(0L);
    } else {
      player.setVolume(curVolume);
    }
  }

  /**
   * Check if the player is muted
   * @return boolean
   */
  public boolean getMuted() {
    return isMuted;
  }

  /**
   * Apply white color to MediaRouteButton
   * @param button
   */
  private void mediaRouteButtonColorWhite(MediaRouteButton button) {
    if (button == null) return;
    Context castContext = new ContextThemeWrapper(getContext(), androidx.mediarouter.R.style.Theme_MediaRouter);

    TypedArray a = castContext.obtainStyledAttributes(
      null,
      androidx.mediarouter.R.styleable.MediaRouteButton,
      androidx.mediarouter.R.attr.mediaRouteButtonStyle,
      0
    );
    Drawable drawable = a.getDrawable(androidx.mediarouter.R.styleable.MediaRouteButton_externalRouteEnabledDrawable);
    a.recycle();
    DrawableCompat.setTint(drawable, ContextCompat.getColor(getContext(), R.color.white));
    drawable.setState(button.getDrawableState());
    button.setRemoteIndicatorDrawable(drawable);
  }

  /**
   * Get video Type from Uri
   * @param uri
   * @return video type
   */
  private String getVideoType(Uri uri) {
    String ret = null;
    Object obj = uri.getLastPathSegment();
    String lastSegment = (obj == null) ? "" : uri.getLastPathSegment();
    for (String type : supportedFormat) {
      if (ret != null) break;
      if (lastSegment.length() > 0 && lastSegment.contains(type)) ret = type;
      if (ret == null) {
        List<String> segments = uri.getPathSegments();
        if (segments.size() > 0) {
          String segment;
          if (segments.get(segments.size() - 1).equals("manifest")) {
            segment = segments.get(segments.size() - 2);
          } else {
            segment = segments.get(segments.size() - 1);
          }
          for (String sType : supportedFormat) {
            if (segment.contains(sType)) {
              ret = sType;
              break;
            }
          }
        }
      }
    }
    ret = (ret != null) ? ret : "";
    return ret;
  }

  /**
   * Reset Variables for multiple runs
   */
  private void resetVariables() {
    vType = null;
    styledPlayerView = null;
    playWhenReady = true;
    firstReadyToPlay = true;
    isEnded = false;
    currentWindow = 0;
    playbackPosition = 0;
    uri = null;
    isMuted = false;
    curVolume = (float) 0.5;
    mCurrentPosition = 0;
  }

  /**
   * Check if the application has been sent to the background
   * @param context
   * @return boolean
   */
  public boolean isApplicationSentToBackground(final Context context) {
    int pid = android.os.Process.myPid();
    ActivityManager am = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
    List<ActivityManager.RunningAppProcessInfo> procInfos = am.getRunningAppProcesses();
    if (procInfos != null) {
      for (ActivityManager.RunningAppProcessInfo appProcess : procInfos) {
        if (appProcess.pid == pid) {
          return true;
        }
      }
    }
    return false;
  }

  /**
   * Function to initialize the cast service and everything related to it
   * @return void
   */
  private void initializeCastService() {
    try {
      Executor executor = Executors.newSingleThreadExecutor();
      Task<CastContext> task = CastContext.getSharedInstance(context, executor);

      task.addOnCompleteListener(new OnCompleteListener<CastContext>() {
        @Override
        public void onComplete(Task<CastContext> task) {
          if (task.isSuccessful()) {
          castContext = task.getResult();
          castPlayer = new RemoteCastPlayer.Builder(context).build();
          mRouter = MediaRouter.getInstance(context);
          mSelector =
                  new MediaRouteSelector.Builder()
                          .addControlCategories(Arrays.asList(MediaControlIntent.CATEGORY_LIVE_AUDIO, MediaControlIntent.CATEGORY_LIVE_VIDEO))
                          .build();

          mediaRouteButtonColorWhite(mediaRouteButton);
          if (castContext != null && castContext.getCastState() != CastState.NO_DEVICES_AVAILABLE) mediaRouteButton.setVisibility(
                  View.VISIBLE
          );

          castStateListener =
                  state -> {
                    if (state == CastState.NO_DEVICES_AVAILABLE) {
                      mediaRouteButton.setVisibility(View.GONE);
                    } else {
                      if (mediaRouteButton.getVisibility() == View.GONE) {
                        mediaRouteButton.setVisibility(View.VISIBLE);
                      }
                    }
                  };
          CastButtonFactory.setUpMediaRouteButton(context, mediaRouteButton);

          MediaMetadata movieMetadata;
          if (artwork != "") {
            movieMetadata = new MediaMetadata.Builder()
                    .setTitle(title)
                    .setSubtitle(smallTitle)
                    .setMediaType(MediaMetadata.MEDIA_TYPE_VIDEO)
                    .setArtworkUri(Uri.parse(artwork))
                    .build();
            loadCastImage();
          } else {
            movieMetadata = new MediaMetadata.Builder()
                    .setTitle(title)
                    .setSubtitle(smallTitle)
                    .build();
          }
          mediaItem =
                  new MediaItem.Builder()
                          .setUri(videoPath)
                          .setMimeType(MimeTypes.VIDEO_UNKNOWN)
                          .setMediaMetadata(movieMetadata)
                          .build();

          castPlayer.addListener(
                  new Player.Listener() {
                    private boolean lastCastSessionAvailable = isRemoteCastConnected(castPlayer);

                    @Override
                    public void onDeviceInfoChanged(DeviceInfo deviceInfo) {
                      boolean available = isRemoteCastConnected(castPlayer);
                      if (available == lastCastSessionAvailable) {
                        return;
                      }
                      lastCastSessionAvailable = available;
                      if (available) {
                        isCastSession = true;
                        final Long videoPosition = player.getCurrentPosition();
                        if (pipEnabled) {
                          pipBtn.setVisibility(View.GONE);
                        }
                        resizeBtn.setVisibility(View.GONE);
                        player.setPlayWhenReady(false);
                        cast_image.setVisibility(View.VISIBLE);
                        castPlayer.setMediaItem(mediaItem, videoPosition);
                        styledPlayerView.setPlayer(castPlayer);
                        styledPlayerView.setControllerShowTimeoutMs(0);
                        styledPlayerView.setControllerHideOnTouch(false);
                        styledPlayerView.performClick();
                      } else {
                        isCastSession = false;
                        final Long videoPosition = castPlayer.getCurrentPosition();
                        if (pipEnabled) {
                          pipBtn.setVisibility(View.VISIBLE);
                        }
                        resizeBtn.setVisibility(View.VISIBLE);
                        cast_image.setVisibility(View.GONE);
                        styledPlayerView.setPlayer(player);
                        player.setPlayWhenReady(true);
                        player.seekTo(videoPosition);
                        styledPlayerView.setControllerShowTimeoutMs(3000);
                        styledPlayerView.setControllerHideOnTouch(true);
                      }
                    }

                    private void notifyCastPlayPause() {
                      Map<String, Object> info = new HashMap<String, Object>() {
                        {
                          put("fromPlayerId", playerId);
                          put("currentTime", String.valueOf(castPlayer.getCurrentPosition() / 1000));
                        }
                      };
                      if (castPlayer.isPlaying()) {
                        NotificationCenter.defaultCenter().postNotification("playerItemPlay", info);
                      } else {
                        NotificationCenter.defaultCenter().postNotification("playerItemPause", info);
                      }
                    }

                    @Override
                    public void onPlaybackStateChanged(int state) {
                      if (state == Player.STATE_READY && !firstReadyToPlay) {
                        notifyCastPlayPause();
                      }
                    }

                    @Override
                    public void onPlayWhenReadyChanged(boolean playWhenReady, int reason) {
                      if (
                        castPlayer.getPlaybackState() == Player.STATE_READY &&
                        reason == Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST
                      ) {
                        notifyCastPlayPause();
                      }
                    }
                  }
          );

          castContext.addCastStateListener(castStateListener);
          mRouter.addCallback(mSelector, mCallback, MediaRouter.CALLBACK_FLAG_REQUEST_DISCOVERY);

          } else {
            Log.w(TAG, "Cast unavailable, disabling chromecast", task.getException());
            disableChromecastUi();
          }
        }
      });
    } catch (Exception e) {
      Log.w(TAG, "Cast init failed, disabling chromecast", e);
      disableChromecastUi();
    }
  }

  static boolean isRemoteCastConnected(Player player) {
    if (player == null) {
      return false;
    }
    return isRemoteCastConnected(player.getDeviceInfo());
  }

  static boolean isRemoteCastConnected(DeviceInfo info) {
    return info != null
        && info.playbackType == DeviceInfo.PLAYBACK_TYPE_REMOTE
        && !RemoteCastPlayer.DEVICE_INFO_REMOTE_EMPTY.equals(info);
  }

  private void disableChromecastUi() {
    chromecast = false;
    if (mediaRouteButton != null) {
      mediaRouteButton.setVisibility(View.GONE);
    }
  }

  private final class EmptyCallback extends MediaRouter.Callback {}

  @Override
  public void onConfigurationChanged(Configuration newConfig) {
    super.onConfigurationChanged(newConfig);
    adjustAspectRatio();
  }

  /**
   * Re-applies the current resize mode (does NOT change it based on device orientation —
   * switching FIT/FILL on rotation caused unwanted cropping for non-16:9 source video).
   * Only forces a fresh layout pass so the AspectRatioFrameLayout picks up the settled
   * container size / known video dimensions after rotation, first-ready, etc.
   */
  private void adjustAspectRatio() {
    if (!isAdded() || getView() == null || styledPlayerView == null || resizeBtn == null) {
      return;
    }
    if (!hasValidVideoSize()) {
      return;
    }
    styledPlayerView.setResizeMode(resizeStatus);
    styledPlayerView.requestLayout();
  }

  private boolean hasValidVideoSize() {
    if (player == null) {
      return false;
    }
    Format format = player.getVideoFormat();
    return format != null && format.width > 0 && format.height > 0;
  }
}
