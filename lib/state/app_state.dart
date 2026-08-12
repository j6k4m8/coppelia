import 'dart:async';
import 'dart:math';
import 'package:flutter/scheduler.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';

import '../core/app_palette.dart';
import '../core/app_info.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/auth_session.dart';
import '../models/cached_audio_entry.dart';
import '../models/download_task.dart';
import '../models/genre.dart';
import '../models/library_stats.dart';
import '../models/media_item.dart';
import '../models/playback_resume_state.dart';
import '../models/playlist.dart';
import '../models/search_results.dart';
import '../models/saved_server.dart';
import '../models/smart_list.dart';
import '../models/track_status_icon_state.dart';
import '../models/whole_library_offline.dart';
import '../services/cache_store.dart';
import '../services/jellyfin_client.dart';
import '../services/log_service.dart';
import '../services/now_playing_service.dart';
import '../services/playback_controller.dart';
import '../services/search_service.dart';
import '../services/server_store.dart';
import '../services/settings_store.dart';
import 'browse_layout.dart';
import 'accent_color_source.dart';
import 'home_section.dart';
import 'home_shelf_layout.dart';
import 'keyboard_shortcut.dart';
import 'layout_density.dart';
import 'library_view.dart';
import 'corner_radius_style.dart';
import 'now_playing_layout.dart';
import 'sidebar_item.dart';
import 'theme_palette_source.dart';
import 'track_list_style.dart';

part 'app_state_session.dart';
part 'app_state_library.dart';
part 'app_state_preferences.dart';
part 'app_state_offline.dart';
part 'app_state_favorites.dart';

const Set<ConnectivityResult> _networkConnectivityWhitelist = {
  ConnectivityResult.wifi,
  ConnectivityResult.ethernet,
};

/// Central application state and Jellyfin coordination.
class AppState extends ChangeNotifier {
  /// Creates the shared application state.
  AppState({
    required CacheStore cacheStore,
    required JellyfinClient client,
    required PlaybackController playback,
    required ServerStore serverStore,
    required SettingsStore settingsStore,
  })  : _cacheStore = cacheStore,
        _client = client,
        _playback = playback,
        _serverStore = serverStore,
        _settingsStore = settingsStore {
    _bindPlayback();
    _bindNowPlaying();
  }

  final CacheStore _cacheStore;
  final JellyfinClient _client;
  final PlaybackController _playback;
  final NowPlayingService _nowPlayingService = NowPlayingService();
  final ServerStore _serverStore;
  final SettingsStore _settingsStore;

  AuthSession? _session;
  List<SavedServer> _savedServers = [];
  SavedServer? _activeServer;
  int _serverGeneration = 0;
  bool _isBootstrapping = true;
  bool _isLoadingLibrary = false;
  String? _authError;
  String? _libraryError;
  Playlist? _selectedPlaylist;
  LibraryView _selectedView = LibraryView.home;
  Album? _selectedAlbum;
  Artist? _selectedArtist;
  Genre? _selectedGenre;
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isSearchLoading = false;
  SearchResults? _searchResults;
  int _searchFocusRequest = 0;
  int _searchRequestId = 0;
  LoopMode _repeatMode = LoopMode.off;

  void _notifyListenersLater() {
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  void _notify() {
    notifyListeners();
  }

  List<Playlist> _playlists = [];
  List<MediaItem> _playlistTracks = [];
  List<MediaItem> _featuredTracks = [];
  List<Album> _recentlyAddedAlbums = [];
  List<MediaItem> _queue = [];
  List<Album> _albums = [];
  List<Artist> _artists = [];
  List<Genre> _genres = [];
  List<MediaItem> _libraryTracks = [];
  String? _trackBrowseLetter;
  Completer<void>? _tracksLoadCompleter;
  bool _isLoadingTracks = false;
  bool _hasMoreTracks = true;
  int _tracksOffset = 0;
  bool _libraryTracksFromOfflineSnapshot = false;
  List<MediaItem> _albumTracks = [];
  List<MediaItem> _artistTracks = [];
  List<MediaItem> _genreTracks = [];
  List<Album> _favoriteAlbums = [];
  List<Artist> _favoriteArtists = [];
  List<MediaItem> _favoriteTracks = [];
  List<SmartList> _smartLists = [];
  SmartList? _selectedSmartList;
  List<MediaItem> _smartListTracks = [];
  bool _isLoadingSmartList = false;
  final Set<String> _favoriteAlbumUpdatesInFlight = {};
  final Set<String> _favoriteArtistUpdatesInFlight = {};
  final Set<String> _favoriteTrackUpdatesInFlight = {};
  Set<String> _pinnedAudio = {};
  Set<String> _cachedAudio = {};
  final List<DownloadTask> _downloadQueue = [];
  final Map<String, DownloadStatus> _downloadStatusByUrl = {};
  final Map<String, DateTime> _downloadProgressTimestamps = {};
  final Set<String> _cancelledOfflineRequests = {};
  bool _isProcessingDownloads = false;
  List<MediaItem> _recentTracks = [];
  List<MediaItem> _playHistory = [];

  LibraryStats? _libraryStats;

  MediaItem? _nowPlaying;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isDurationAuthoritative = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isNowPlayingCached = false;
  bool _isPreparingPlayback = false;
  bool _isApplyingQueueUpdate = false;
  int? _lastHandledCurrentIndex;
  String? _lastHandledCurrentTrackId;
  final ValueNotifier<Duration> _positionNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isBufferingNotifier = ValueNotifier(false);
  final ValueNotifier<int> _mediaCacheBytesNotifier = ValueNotifier(0);
  final ValueNotifier<int> _pinnedCacheBytesNotifier = ValueNotifier(0);
  final Random _random = Random();
  int _playRequestId = 0;

  /// Invalidates asynchronous work owned by the previous server profile.
  int _beginServerTransition() {
    _serverGeneration += 1;
    return _serverGeneration;
  }

  int _captureServerGeneration() => _serverGeneration;

  bool _isCurrentServerGeneration(int generation) =>
      generation == _serverGeneration;

  void _updatePlaybackProgress({
    Duration? position,
    Duration? duration,
    bool durationIsAuthoritative = false,
  }) {
    var nextDuration = duration ?? _duration;
    final nextPosition = position ?? _position;
    if (duration != null) {
      if (duration <= Duration.zero) {
        _isDurationAuthoritative = false;
      } else {
        _isDurationAuthoritative = durationIsAuthoritative;
      }
    }
    var clampedPosition = nextPosition;
    if (nextDuration > Duration.zero && nextPosition > nextDuration) {
      if (_isDurationAuthoritative) {
        clampedPosition = nextDuration;
      } else {
        // Metadata durations can be wrong. Keep progress advancing until
        // player-reported duration catches up.
        nextDuration = nextPosition;
      }
    }
    _duration = nextDuration;
    _position = clampedPosition;
    _durationNotifier.value = _duration;
    _positionNotifier.value = _position;
  }

  void _resetPlaybackRuntimeState({
    bool clearNowPlaying = false,
    bool clearReporting = false,
  }) {
    _updatePlaybackProgress(
      position: Duration.zero,
      duration: Duration.zero,
    );
    _isPlaying = false;
    _isBuffering = false;
    _isDurationAuthoritative = false;
    _isNowPlayingCached = false;
    _isPreparingPlayback = false;
    _isPlayingNotifier.value = false;
    _isBufferingNotifier.value = false;
    _lastNowPlayingUpdateAt = null;
    _lastHandledCurrentIndex = null;
    _lastHandledCurrentTrackId = null;
    if (clearNowPlaying) {
      _nowPlaying = null;
      unawaited(_maybeUpdateNowPlayingPalette(null));
    }
    if (clearReporting) {
      _playSessionId = null;
      _reportedStartSessionId = null;
      _reportedStopSessionId = null;
      _lastProgressReportAt = null;
      _activeSessionHasPlayed = false;
    }
  }

  bool _isPlayRequestStale(int requestId) => requestId != _playRequestId;

  void _rememberCurrentIndexEvent(int index, MediaItem track) {
    _lastHandledCurrentIndex = index;
    _lastHandledCurrentTrackId = track.id;
  }

  bool _isDuplicateCurrentIndexEvent(int index, MediaItem track) {
    return _lastHandledCurrentIndex == index &&
        _lastHandledCurrentTrackId == track.id &&
        _nowPlaying?.id == track.id;
  }

  bool _syncNowPlayingFromCurrentIndex({
    bool notify = true,
    int? indexOverride,
    bool skipDuplicate = false,
    bool logTrackChange = false,
  }) {
    final index = indexOverride ?? _playback.currentIndex;
    if (index == null || index < 0 || index >= _queue.length) {
      return false;
    }
    final next = _queue[index];
    if (skipDuplicate && _isDuplicateCurrentIndexEvent(index, next)) {
      return false;
    }
    if (logTrackChange && _nowPlaying?.id != next.id) {
      final formatInfo = next.container != null || next.codec != null
          ? ' [${next.container ?? "unknown"}/${next.codec ?? "unknown"}]'
          : '';
      LogService.instance.then((log) => log.info(
          'Current index changed to $index (queue size: ${_queue.length})'));
      LogService.instance.then((log) => log.info(
          'Now playing: "${next.title}" by ${next.artists.join(", ")}$formatInfo'));
    }
    _rememberCurrentIndexEvent(index, next);
    if (_nowPlaying?.id != next.id) {
      _setNowPlaying(next, notify: notify);
      return true;
    }
    if (_duration == Duration.zero && next.duration > Duration.zero) {
      _updatePlaybackProgress(duration: next.duration);
      _updateNowPlayingInfo(force: true);
      if (notify) {
        notifyListeners();
      }
    }
    return true;
  }

  void _applyPlayerStateSnapshot(PlayerState state) {
    final nextPlaying = state.playing;
    final nextBuffering = state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering;
    final playingChanged = _isPlaying != nextPlaying;
    final bufferingChanged = _isBuffering != nextBuffering;
    final shouldStopPreparing = _isPreparingPlayback &&
        (state.processingState == ProcessingState.ready ||
            state.processingState == ProcessingState.completed);
    _isPlaying = nextPlaying;
    if (_isPlaying) {
      _activeSessionHasPlayed = true;
    }
    _isBuffering = nextBuffering;
    if (shouldStopPreparing) {
      _isPreparingPlayback = false;
    }
    _isPlayingNotifier.value = _isPlaying;
    _isBufferingNotifier.value = _isBuffering;
    if (playingChanged || bufferingChanged || shouldStopPreparing) {
      notifyListeners();
      _updateNowPlayingInfo(force: true);
    }
    if (playingChanged) {
      _maybeReportPlaybackState();
    }
    if (state.processingState == ProcessingState.completed) {
      _maybeReportStopped(completed: true);
    }
  }

  ThemeMode _themeMode = ThemeMode.dark;
  String? _fontFamily = 'SF Pro Display';
  double _fontScale = 1.0;
  int _accentColorValue = 0xFF6F7BFF;
  AccentColorSource _accentColorSource = AccentColorSource.preset;
  ThemePaletteSource _themePaletteSource = ThemePaletteSource.defaultPalette;
  bool _telemetryPlayback = true;
  bool _telemetryProgress = true;
  bool _telemetryHistory = true;
  bool _gaplessPlayback = true;
  bool _downloadsWifiOnly = false;
  bool _downloadsPaused = false;
  bool _autoDownloadFavoritesEnabled = false;
  bool _autoDownloadFavoriteAlbums = true;
  bool _autoDownloadFavoriteArtists = true;
  bool _autoDownloadFavoriteTracks = true;
  bool _autoDownloadFavoritesWifiOnly = false;
  bool _settingsShortcutEnabled = true;
  KeyboardShortcut _settingsShortcut = KeyboardShortcut.defaultForPlatform();
  bool _searchShortcutEnabled = true;
  KeyboardShortcut _searchShortcut = KeyboardShortcut.searchForPlatform();
  bool _sidebarSwipeEnabled = true;
  bool _nowPlayingSwipeEnabled = true;
  bool _nowPlayingExpandGestureEnabled = true;
  bool _preferLocalSearch = false;
  LayoutDensity _layoutDensity = LayoutDensity.comfortable;
  CornerRadiusStyle _cornerRadiusStyle = CornerRadiusStyle.babyProofed;
  TrackListStyle _trackListStyle = TrackListStyle.card;
  bool _trackStatusIconsEnabled = true;
  NowPlayingLayout _nowPlayingLayout = NowPlayingLayout.bottom;
  HomeShelfLayout _homeShelfLayout = HomeShelfLayout.whooshy;
  int _homeShelfGridRows = 2;
  Map<HomeSection, bool> _homeSectionVisibility = {
    for (final section in HomeSection.values) section: true,
  };
  List<HomeSection> _homeSectionOrder = List<HomeSection>.from(
    HomeSection.values,
  );
  Map<SidebarItem, bool> _sidebarVisibility = {
    for (final item in SidebarItem.values)
      if (item != SidebarItem.servers) item: true,
  };
  double _sidebarWidth = 240;
  bool _sidebarCollapsed = false;
  bool _sidebarOverlayOpen = false;
  final List<LibraryView> _viewHistory = [];
  final Map<LibraryView, BrowseLayout> _browseLayouts = {};
  final Map<String, double> _scrollOffsets = {};

  MediaItem? _jumpInTrack;
  Album? _jumpInAlbum;
  Artist? _jumpInArtist;
  bool _isLoadingJumpIn = false;
  DateTime? _lastJumpInRefreshAt;
  int _cacheMaxBytes = CacheStore.defaultCacheMaxBytes;
  bool _offlineMode = false;
  bool _offlineOnlyFilter = false;

  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<int?>? _currentIndexSubscription;
  Timer? _positionPollTimer;

  static const int _tracksPageSize = 100;

  String? _playSessionId;
  String? _reportedStartSessionId;
  String? _reportedStopSessionId;
  DateTime? _lastProgressReportAt;
  DateTime? _lastPlaybackPersistAt;
  bool _activeSessionHasPlayed = false;
  DateTime? _lastNowPlayingUpdateAt;
  NowPlayingPalette? _nowPlayingPalette;
  final Map<String, NowPlayingPalette> _paletteCache = {};

  /// Current authenticated session.
  AuthSession? get session => _session;

  /// Saved Jellyfin servers available on this device.
  List<SavedServer> get savedServers => List.unmodifiable(_savedServers);

  /// Active saved server, when a session is available.
  SavedServer? get activeServer => _activeServer;

  /// Number of selectable server and address destinations.
  int get savedDestinationCount => _savedServers.fold<int>(
        0,
        (count, server) => count + server.addresses.length,
      );

  /// True while the app restores cached state.
  bool get isBootstrapping => _isBootstrapping;

  /// True while Jellyfin data is loading.
  bool get isLoadingLibrary => _isLoadingLibrary;

  /// Error message from the last authentication attempt.
  String? get authError => _authError;

  /// Most recent non-auth library refresh failure for the active server.
  String? get libraryError => _libraryError;

  /// Available playlists for the user.
  List<Playlist> get playlists => List.unmodifiable(_playlists);

  /// Tracks for the selected playlist.
  List<MediaItem> get playlistTracks => List.unmodifiable(_playlistTracks);

  /// Tracks spotlighted on the home shelf.
  List<MediaItem> get featuredTracks => List.unmodifiable(_featuredTracks);

  /// Currently selected playlist.
  Playlist? get selectedPlaylist => _selectedPlaylist;

  /// Currently selected library view.
  LibraryView get selectedView => _selectedView;

  /// Currently selected album.
  Album? get selectedAlbum => _selectedAlbum;

  /// Currently selected artist.
  Artist? get selectedArtist => _selectedArtist;

  /// Currently selected genre.
  Genre? get selectedGenre => _selectedGenre;

  /// Playback queue of tracks.
  List<MediaItem> get queue => List.unmodifiable(_queue);

  /// Available albums.
  List<Album> get albums => List.unmodifiable(_albums);

  /// Albums most recently added to the Jellyfin library.
  List<Album> get recentlyAddedAlbums =>
      List.unmodifiable(_recentlyAddedAlbums);

  /// Available artists.
  List<Artist> get artists => List.unmodifiable(_artists);

  /// Available genres.
  List<Genre> get genres => List.unmodifiable(_genres);

  /// All tracks in the library browse view.
  List<MediaItem> get libraryTracks => List.unmodifiable(_libraryTracks);

  /// Tracks for the selected album.
  List<MediaItem> get albumTracks => List.unmodifiable(_albumTracks);

  /// Tracks for the selected artist.
  List<MediaItem> get artistTracks => List.unmodifiable(_artistTracks);

  /// Tracks for the selected genre.
  List<MediaItem> get genreTracks => List.unmodifiable(_genreTracks);

  /// Favorite albums.
  List<Album> get favoriteAlbums => List.unmodifiable(_favoriteAlbums);

  /// Favorite artists.
  List<Artist> get favoriteArtists => List.unmodifiable(_favoriteArtists);

  /// Favorite tracks.
  List<MediaItem> get favoriteTracks => List.unmodifiable(_favoriteTracks);

  /// All Smart Lists.
  List<SmartList> get smartLists => List.unmodifiable(_smartLists);

  /// Smart Lists marked to appear on Home.
  List<SmartList> get smartListsOnHome =>
      _smartLists.where((list) => list.showOnHome).toList();

  /// Selected Smart List when viewing its results.
  SmartList? get selectedSmartList => _selectedSmartList;

  /// Tracks for the selected Smart List.
  List<MediaItem> get smartListTracks => List.unmodifiable(_smartListTracks);

  /// True while Smart List results are loading.
  bool get isLoadingSmartList => _isLoadingSmartList;

  /// Pinned audio stream URLs.
  Set<String> get pinnedAudio => Set.unmodifiable(_pinnedAudio);

  /// Active download queue for offline audio.
  List<DownloadTask> get downloadQueue => List.unmodifiable(_downloadQueue);

  /// Stream of cached media size updates.
  ValueListenable<int> get mediaCacheBytesListenable =>
      _mediaCacheBytesNotifier;

  /// Stream of pinned media size updates.
  ValueListenable<int> get pinnedCacheBytesListenable =>
      _pinnedCacheBytesNotifier;

  /// True when downloads are limited to Wi-Fi.
  bool get downloadsWifiOnly => _downloadsWifiOnly;

  /// True when downloads are paused.
  bool get downloadsPaused => _downloadsPaused;

  /// Returns true when the album is marked as a favorite.
  bool isFavoriteAlbum(String albumId) =>
      _favoriteAlbums.any((album) => album.id == albumId);

  /// Returns true when the artist is marked as a favorite.
  bool isFavoriteArtist(String artistId) =>
      _favoriteArtists.any((artist) => artist.id == artistId);

  /// Returns true when the track is marked as a favorite.
  bool isFavoriteTrack(String trackId) =>
      _favoriteTracks.any((track) => track.id == trackId);

  /// Returns true when an album favorite update is in flight.
  bool isFavoriteAlbumUpdating(String albumId) =>
      _favoriteAlbumUpdatesInFlight.contains(albumId);

  /// Returns true when an artist favorite update is in flight.
  bool isFavoriteArtistUpdating(String artistId) =>
      _favoriteArtistUpdatesInFlight.contains(artistId);

  /// Returns true when a track favorite update is in flight.
  bool isFavoriteTrackUpdating(String trackId) =>
      _favoriteTrackUpdatesInFlight.contains(trackId);

  /// Recently played tracks.
  List<MediaItem> get recentTracks => List.unmodifiable(_recentTracks);

  /// Playback history (most recent first).
  List<MediaItem> get playHistory => List.unmodifiable(_playHistory);

  /// Aggregated library stats.
  LibraryStats? get libraryStats => _libraryStats;

  /// Current search query.
  String get searchQuery => _searchQuery;

  /// Active track browse letter filter.
  String? get trackBrowseLetter => _trackBrowseLetter;

  /// True while search results are loading.
  bool get isSearching => _isSearching;

  /// True while a search request is actively loading data.
  bool get isSearchLoading => _isSearchLoading;

  /// Search results, when available.
  SearchResults? get searchResults => _searchResults;

  /// Search focus request token.
  int get searchFocusRequest => _searchFocusRequest;

  /// Currently playing track.
  MediaItem? get nowPlaying => _nowPlaying;

  /// Current repeat mode for playback.
  LoopMode get repeatMode => _repeatMode;

  /// Current playback position.
  Duration get position => _position;

  /// Listenable playback position updates.
  ValueListenable<Duration> get positionListenable => _positionNotifier;

  /// Duration of the current track.
  Duration get duration => _duration;

  /// Listenable duration updates.
  ValueListenable<Duration> get durationListenable => _durationNotifier;

  /// True when audio is playing.
  bool get isPlaying => _isPlaying;

  /// Listenable play/pause updates.
  ValueListenable<bool> get isPlayingListenable => _isPlayingNotifier;

  /// True when buffering audio.
  bool get isBuffering => _isBuffering;

  /// Listenable buffering updates.
  ValueListenable<bool> get isBufferingListenable => _isBufferingNotifier;

  /// True when the current track is cached locally.
  bool get isNowPlayingCached => _isNowPlayingCached;

  /// True while a track is preparing to play.
  bool get isPreparingPlayback => _isPreparingPlayback;

  /// True while the full track list is loading.
  bool get isLoadingTracks => _isLoadingTracks;

  /// True when there are more tracks to load.
  bool get hasMoreTracks => _hasMoreTracks;

  /// Active theme mode.
  ThemeMode get themeMode => _themeMode;

  /// Preferred font family.
  String? get fontFamily => _fontFamily;

  /// Preferred font scale.
  double get fontScale => _fontScale;

  /// Selected accent color source.
  AccentColorSource get accentColorSource => _accentColorSource;

  /// Selected theme palette source.
  ThemePaletteSource get themePaletteSource => _themePaletteSource;

  /// Raw accent color value.
  int get accentColorValue => _accentColorValue;

  /// Current accent color for the theme.
  Color get accentColor {
    if (_accentColorSource == AccentColorSource.nowPlaying) {
      return _nowPlayingPalette?.primary ?? Color(_accentColorValue);
    }
    return Color(_accentColorValue);
  }

  /// Now playing palette, when available.
  NowPlayingPalette? get nowPlayingPalette => _nowPlayingPalette;

  /// True when using the now playing palette for the theme.
  bool get useNowPlayingPalette =>
      _themePaletteSource == ThemePaletteSource.nowPlaying;

  /// True when the settings shortcut is enabled.
  bool get settingsShortcutEnabled => _settingsShortcutEnabled;

  /// Preferred keyboard shortcut for opening settings.
  KeyboardShortcut get settingsShortcut => _settingsShortcut;

  /// True when the search shortcut is enabled.
  bool get searchShortcutEnabled => _searchShortcutEnabled;

  /// Preferred keyboard shortcut for focusing search.
  KeyboardShortcut get searchShortcut => _searchShortcut;

  /// True when swiping inward from the edge can open the sidebar.
  bool get sidebarSwipeEnabled => _sidebarSwipeEnabled;

  /// True when swiping now-playing artwork can change tracks.
  bool get nowPlayingSwipeEnabled => _nowPlayingSwipeEnabled;

  /// True when swiping up expands the compact now-playing player.
  bool get nowPlayingExpandGestureEnabled => _nowPlayingExpandGestureEnabled;

  /// True when local search should be used even when online.
  bool get preferLocalSearch => _preferLocalSearch;

  /// Preferred layout density.
  LayoutDensity get layoutDensity => _layoutDensity;

  /// Preferred corner radius style.
  CornerRadiusStyle get cornerRadiusStyle => _cornerRadiusStyle;

  /// Scalar for corner radius sizing.
  double get cornerRadiusScale => _cornerRadiusStyle.scale;

  /// Preferred track list style.
  TrackListStyle get trackListStyle => _trackListStyle;

  /// Whether track timestamp status icons are shown.
  bool get trackStatusIconsEnabled => _trackStatusIconsEnabled;

  /// O(1) lookup for timestamp status icon state by stream URL.
  TrackStatusIconState trackStatusForStreamUrl(String streamUrl) {
    final keys = _offlineKeysForStreamUrl(streamUrl);
    for (final key in keys) {
      final status = _downloadStatusByUrl[key];
      if (status == null) {
        continue;
      }
      return status == DownloadStatus.failed
          ? TrackStatusIconState.none
          : TrackStatusIconState.inQueue;
    }
    final isPinned = keys.any(_pinnedAudio.contains);
    final isCached = keys.any(_cachedAudio.contains);
    if (isPinned && isCached) {
      return TrackStatusIconState.downloaded;
    }
    if (isPinned) {
      return TrackStatusIconState.inQueue;
    }
    return TrackStatusIconState.none;
  }

  /// O(1) lookup for timestamp status icon state by track.
  TrackStatusIconState trackStatusForTrack(MediaItem track) {
    final keys = _offlineKeysForTrack(track);
    for (final key in keys) {
      final status = _downloadStatusByUrl[key];
      if (status == null) {
        continue;
      }
      return status == DownloadStatus.failed
          ? TrackStatusIconState.none
          : TrackStatusIconState.inQueue;
    }
    final isPinned = keys.any(_pinnedAudio.contains);
    final isCached = keys.any(_cachedAudio.contains);
    if (isPinned && isCached) {
      return TrackStatusIconState.downloaded;
    }
    if (isPinned) {
      return TrackStatusIconState.inQueue;
    }
    return TrackStatusIconState.none;
  }

  /// True when playback telemetry is enabled.
  bool get telemetryPlaybackEnabled => _telemetryPlayback;

  /// True when playback progress telemetry is enabled.
  bool get telemetryProgressEnabled => _telemetryProgress;

  /// True when play history telemetry is enabled.
  bool get telemetryHistoryEnabled => _telemetryHistory;

  /// True when gapless playback is enabled.
  bool get gaplessPlaybackEnabled => _gaplessPlayback;

  /// True when favorites should be auto-downloaded for offline playback.
  bool get autoDownloadFavoritesEnabled => _autoDownloadFavoritesEnabled;

  /// True when favorited albums should be auto-downloaded.
  bool get autoDownloadFavoriteAlbums => _autoDownloadFavoriteAlbums;

  /// True when favorited artists should be auto-downloaded.
  bool get autoDownloadFavoriteArtists => _autoDownloadFavoriteArtists;

  /// True when favorited tracks should be auto-downloaded.
  bool get autoDownloadFavoriteTracks => _autoDownloadFavoriteTracks;

  /// True when auto-downloads are restricted to Wi-Fi.
  bool get autoDownloadFavoritesWifiOnly => _autoDownloadFavoritesWifiOnly;

  /// True when offline mode is enabled.
  bool get offlineMode => _offlineMode;

  /// True when the offline-only filter is active.
  bool get offlineOnlyFilter => _offlineMode || _offlineOnlyFilter;

  /// Preferred layout for now playing.
  NowPlayingLayout get nowPlayingLayout => _nowPlayingLayout;

  /// Preferred layout for home shelves.
  HomeShelfLayout get homeShelfLayout => _homeShelfLayout;

  /// Preferred row count for home shelf grids.
  int get homeShelfGridRows => _homeShelfGridRows;

  /// Home section visibility settings.
  Map<HomeSection, bool> get homeSectionVisibility =>
      Map.unmodifiable(_homeSectionVisibility);

  /// Preferred home section order.
  List<HomeSection> get homeSectionOrder =>
      List.unmodifiable(_homeSectionOrder);

  /// Random track for the Jump in shelf.
  MediaItem? get jumpInTrack => _jumpInTrack;

  /// Random album for the Jump in shelf.
  Album? get jumpInAlbum => _jumpInAlbum;

  /// Random artist for the Jump in shelf.
  Artist? get jumpInArtist => _jumpInArtist;

  /// True while Jump in picks are loading.
  bool get isLoadingJumpIn => _isLoadingJumpIn;

  /// Current cache size limit in bytes.
  int get cacheMaxBytes => _cacheMaxBytes;

  /// True when Jump in should auto-refresh.
  bool get shouldRefreshJumpIn {
    final last = _lastJumpInRefreshAt;
    if (last == null) {
      return true;
    }
    return DateTime.now().difference(last) >= const Duration(minutes: 5);
  }

  /// Sidebar item visibility settings.
  Map<SidebarItem, bool> get sidebarVisibility =>
      Map.unmodifiable(_sidebarVisibility);

  /// Current sidebar width.
  double get sidebarWidth => _sidebarWidth;

  /// True when the sidebar is collapsed.
  bool get isSidebarCollapsed => _sidebarCollapsed;

  /// True when the sidebar overlay is open.
  bool get isSidebarOverlayOpen => _sidebarOverlayOpen;

  /// True when there is a previous view in history.
  bool get canGoBack => _viewHistory.isNotEmpty;

  /// Preferred browse layout for a library view.
  BrowseLayout browseLayoutFor(LibraryView view) =>
      _browseLayouts[view] ?? BrowseLayout.grid;

  /// Returns whether a home section should be shown.
  bool isHomeSectionVisible(HomeSection section) =>
      _homeSectionVisibility[section] ?? true;

  /// Returns whether a sidebar item should be shown.
  bool isSidebarItemVisible(SidebarItem item) {
    if (item == SidebarItem.servers && !_sidebarVisibility.containsKey(item)) {
      return savedDestinationCount > 1;
    }
    return _sidebarVisibility[item] ?? true;
  }

  /// Returns a saved scroll offset for a key.
  double loadScrollOffset(String key) => _scrollOffsets[key] ?? 0;

  /// Saves a scroll offset for a key.
  void saveScrollOffset(String key, double offset) {
    _scrollOffsets[key] = offset;
  }

  void _recordViewHistory(LibraryView view) {
    if (_viewHistory.isNotEmpty && _viewHistory.last == view) {
      return;
    }
    _viewHistory.add(view);
    if (_viewHistory.length > 20) {
      _viewHistory.removeAt(0);
    }
  }

  bool get _hasSelectedDetail =>
      _selectedPlaylist != null ||
      _selectedSmartList != null ||
      _selectedAlbum != null ||
      _selectedArtist != null ||
      _selectedGenre != null;

  /// Records the list or Home view that opened a detail screen.
  void _recordDetailEntry() {
    if (!_hasSelectedDetail) {
      _recordViewHistory(_selectedView);
    }
  }

  int _comparePlaylists(Playlist a, Playlist b) {
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  String _requestErrorMessage(Object error, {required String fallback}) {
    if (error is JellyfinRequestException) {
      return error.message;
    }
    return fallback;
  }

  bool _isPlaylistOrderUnsupported(Object error) {
    if (error is! JellyfinRequestException) {
      return false;
    }
    final message = error.message.toLowerCase();
    return message.contains('404') || message.contains('not found');
  }

  Future<String?> _attemptPlaylistRebuildReorder(
    Playlist playlist,
    List<MediaItem> orderedTracks,
    Object error,
  ) async {
    if (!_isPlaylistOrderUnsupported(error)) {
      return _requestErrorMessage(
        error,
        fallback: 'Unable to reorder playlist.',
      );
    }
    final entryIds = orderedTracks
        .map((track) => track.playlistItemId)
        .whereType<String>()
        .toList();
    if (entryIds.length != orderedTracks.length) {
      return 'Unable to reorder this playlist.';
    }
    try {
      await _client.removeFromPlaylist(
        playlistId: playlist.id,
        entryIds: entryIds,
      );
      await _client.addToPlaylist(
        playlistId: playlist.id,
        itemIds: orderedTracks.map((track) => track.id).toList(),
      );
      final refreshed = await _client.fetchPlaylistTracks(playlist.id);
      _playlistTracks = refreshed;
      await _cacheStore.savePlaylistTracks(playlist.id, refreshed);
      notifyListeners();
      return null;
    } catch (fallbackError) {
      return _requestErrorMessage(
        fallbackError,
        fallback: 'Unable to reorder playlist.',
      );
    }
  }

  void _updatePlaylistTrackCount(Playlist playlist, int delta) {
    final updated = Playlist(
      id: playlist.id,
      name: playlist.name,
      trackCount: (playlist.trackCount + delta).clamp(0, 1 << 31),
      imageUrl: playlist.imageUrl,
    );
    _playlists = _playlists
        .map((item) => item.id == playlist.id ? updated : item)
        .toList()
      ..sort(_comparePlaylists);
    if (_selectedPlaylist?.id == playlist.id) {
      _selectedPlaylist = updated;
    }
    unawaited(_cacheStore.savePlaylists(_playlists));
    notifyListeners();
  }

  void _updatePlaylistStats(int delta) {
    final stats = _libraryStats;
    if (stats == null) {
      return;
    }
    final next = LibraryStats(
      trackCount: stats.trackCount,
      albumCount: stats.albumCount,
      artistCount: stats.artistCount,
      playlistCount: (stats.playlistCount + delta).clamp(0, 1 << 31),
    );
    _libraryStats = next;
    unawaited(_cacheStore.saveLibraryStats(next));
  }

  bool _isOfflineLibraryView(LibraryView view) {
    return view == LibraryView.offlineAlbums ||
        view == LibraryView.offlineArtists ||
        view == LibraryView.offlinePlaylists ||
        view == LibraryView.offlineTracks;
  }

  void _refreshSelectedSmartList() {
    final selected = _selectedSmartList;
    if (selected == null) {
      return;
    }
    unawaited(_loadSmartListTracks(selected));
  }

  /// Toggles between play and pause states.
  Future<void> togglePlayback() async {
    final logService = await LogService.instance;
    if (_playback.isPlaying) {
      await logService.info('togglePlayback: Pausing');
      await _performPlaybackAction(
        () => _playback.pause(),
        'pause',
      );
    } else {
      await logService.info('togglePlayback: Resuming playback');
      await _performPlaybackAction(
        () => _playback.play(),
        'play',
      );
    }
  }

  /// Skips to the next track.
  Future<void> nextTrack() async {
    await _performPlaybackAction(
      () => _playback.skipNext(),
      'skip next',
    );
  }

  /// Skips to the previous track.
  Future<void> previousTrack() async {
    const restartThreshold = Duration(seconds: 5);
    if (_position > restartThreshold) {
      await seek(Duration.zero);
      return;
    }
    await _performPlaybackAction(
      () => _playback.skipPrevious(),
      'skip previous',
    );
  }

  /// Jumps to a specific position in the queue.
  Future<void> playQueueIndex(int index) async {
    if (index < 0 || index >= _queue.length) {
      return;
    }
    final didSeek = await _performPlaybackAction(
      () => _playback.seekToIndex(index),
      'seek to index',
    );
    if (!didSeek) {
      return;
    }
    await _performPlaybackAction(
      () => _playback.play(),
      'play',
    );
  }

  /// Reorders the playback queue.
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (_queue.isEmpty) {
      return;
    }
    final from = oldIndex.clamp(0, _queue.length - 1);
    var to = newIndex.clamp(0, _queue.length);
    if (from < to) {
      to -= 1;
    }
    if (from == to) {
      return;
    }
    final previousQueue = List<MediaItem>.from(_queue);
    final updated = List<MediaItem>.from(_queue);
    final moved = updated.removeAt(from);
    updated.insert(to, moved);

    final currentTrack = _nowPlaying;
    final startPosition = _position;
    final wasPlaying = _isPlaying;
    _queue = updated;
    notifyListeners();

    if (currentTrack == null) {
      return;
    }
    final targetIndex = updated.indexWhere(
      (track) => identical(track, currentTrack),
    );
    final startIndex = targetIndex < 0 ? 0 : targetIndex;
    final didSetQueue = await _performPlaybackAction(
      () => _playback.setQueue(
        updated,
        startIndex: startIndex,
        startPosition: startPosition,
        cacheStore: _cacheStore,
        headers: _playbackHeaders(),
      ),
      'reorder queue',
    );
    if (!didSetQueue) {
      _queue = previousQueue;
      notifyListeners();
      return;
    }
    if (wasPlaying) {
      await _performPlaybackAction(
        () => _playback.play(),
        'play',
      );
    }
  }

  /// Adds a track to the end of the queue.
  Future<void> enqueueTrack(MediaItem track) async {
    if (_offlineMode && !_isTrackPinnedInMemory(track)) {
      return;
    }
    if (_queue.isEmpty) {
      await _playFromList([track], track);
      return;
    }
    final normalized = _normalizeTrackForPlayback(track);
    _queue.add(normalized);
    await _playback.appendToQueue(
      normalized,
      cacheStore: _cacheStore,
      headers: _playbackHeaders(),
    );
    notifyListeners();
  }

  /// Inserts a track to play next.
  Future<void> playNext(MediaItem track) async {
    if (_offlineMode && !_isTrackPinnedInMemory(track)) {
      return;
    }
    if (_queue.isEmpty) {
      await enqueueTrack(track);
      return;
    }
    final currentIndex = _playback.currentIndex ?? -1;
    final insertIndex = (currentIndex + 1).clamp(0, _queue.length);
    final normalized = _normalizeTrackForPlayback(track);
    _queue.insert(insertIndex, normalized);
    await _playback.insertNext(
      normalized,
      cacheStore: _cacheStore,
      headers: _playbackHeaders(),
    );
    notifyListeners();
  }

  /// Clears the current playback queue.
  Future<void> clearQueue() async {
    _maybeReportStoppedForSession(
      track: _nowPlaying,
      sessionId: _playSessionId,
      completed: false,
    );
    await _cacheStore.savePlaybackResumeState(null);
    final currentIndex = _playback.currentIndex;
    if (_queue.isEmpty || currentIndex == null || currentIndex < 0) {
      await _playback.clearQueue(keepCurrent: false);
      _queue = [];
      _resetPlaybackRuntimeState(clearNowPlaying: true, clearReporting: true);
      unawaited(_nowPlayingService.clear());
      notifyListeners();
      return;
    }
    await _playback.clearQueue(keepCurrent: true);
    if (currentIndex + 1 < _queue.length) {
      _queue = _queue.sublist(0, currentIndex + 1);
    }
    notifyListeners();
  }

  /// Seeks to a specific playback position.
  Future<void> seek(Duration position) async {
    final didSeek = await _performPlaybackAction(
      () => _playback.seek(position),
      'seek',
    );
    if (didSeek) {
      _updatePlaybackProgress(position: position);
    }
  }

  String _extractStreamItemId(String streamUrl) {
    final uri = Uri.tryParse(streamUrl);
    if (uri == null) {
      return streamUrl;
    }
    final segments = uri.pathSegments;
    final index = segments.indexOf('Audio');
    if (index == -1 || segments.length <= index + 1) {
      return streamUrl;
    }
    return segments[index + 1];
  }

  String _canonicalStreamUrlForStreamUrl(String streamUrl) {
    return _cacheStore.audioKeyForStreamUrl(streamUrl);
  }

  MediaItem _normalizeTrackForOffline(MediaItem track) {
    return _normalizeTrackForPlayback(track);
  }

  Set<String> _offlineKeysForStreamUrl(String streamUrl) {
    final canonical = _canonicalStreamUrlForStreamUrl(streamUrl);
    return {streamUrl, canonical};
  }

  Set<String> _offlineKeysForTrack(MediaItem track) {
    final canonical = _canonicalStreamUrlForStreamUrl(track.streamUrl);
    return {track.streamUrl, canonical};
  }

  bool _isTrackPinnedInMemory(MediaItem track) {
    return _offlineKeysForTrack(track).any(_pinnedAudio.contains);
  }

  bool _isTrackOfflineReadyInMemory(MediaItem track) {
    final keys = _offlineKeysForTrack(track);
    return keys.any(_pinnedAudio.contains) && keys.any(_cachedAudio.contains);
  }

  MediaItem _mediaItemFromCachedEntry(CachedAudioEntry entry) {
    final mediaItem = entry.mediaItem;
    if (mediaItem != null) {
      return mediaItem;
    }
    final uri = Uri.tryParse(entry.streamUrl);
    final itemId = _extractStreamItemId(entry.streamUrl);
    final origin = uri?.origin ?? '';
    final imageUrl = origin.isNotEmpty
        ? '$origin/Items/$itemId/Images/Primary?fillWidth=500&quality=90'
        : null;
    return MediaItem(
      id: itemId,
      title: entry.title,
      album: entry.album,
      artists: entry.artists,
      duration: Duration.zero,
      imageUrl: imageUrl,
      streamUrl: entry.streamUrl,
    );
  }

  /// Releases audio resources.
  @override
  void dispose() {
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _currentIndexSubscription?.cancel();
    _positionPollTimer?.cancel();
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    _isPlayingNotifier.dispose();
    _isBufferingNotifier.dispose();
    _mediaCacheBytesNotifier.dispose();
    _pinnedCacheBytesNotifier.dispose();
    unawaited(_playback.dispose());
    super.dispose();
  }

  void _bindPlayback() {
    _positionPollTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final position = _playback.position;
      _syncPlaybackIndexSnapshot();
      if (_position == position) {
        return;
      }
      _updatePlaybackProgress(position: position);
      _maybeReportProgress();
      _persistPlaybackResumeState();
      _updateNowPlayingInfo();
    });
    _durationSubscription = _playback.durationStream.listen((duration) {
      if (duration != null && duration > Duration.zero) {
        _updatePlaybackProgress(
          duration: duration,
          durationIsAuthoritative: true,
        );
        _updateNowPlayingInfo(force: true);
      }
    });
    _playerStateSubscription = _playback.playerStateStream.listen((state) {
      LogService.instance.then((log) => log.info(
          'Player state: playing=${state.playing}, processingState=${state.processingState}'));
      _applyPlayerStateSnapshot(state);
    });
    _currentIndexSubscription = _playback.currentIndexStream.listen((_) {
      if (_isApplyingQueueUpdate) {
        return;
      }
      _syncPlaybackIndexSnapshot();
    });
  }

  void _syncPlaybackIndexSnapshot() {
    if (_isApplyingQueueUpdate) {
      return;
    }
    final previousIndex = _lastHandledCurrentIndex;
    final didApply = _syncNowPlayingFromCurrentIndex(
      notify: true,
      skipDuplicate: true,
      logTrackChange: true,
    );
    final index = _lastHandledCurrentIndex;
    if (!didApply ||
        index == null ||
        index < 0 ||
        index >= _queue.length ||
        index == previousIndex) {
      return;
    }
    unawaited(
      _cacheStore.handlePlaybackAdvance(
        _queue,
        index,
        headers: _playbackHeaders(),
      ),
    );
  }

  void _bindNowPlaying() {
    _nowPlayingService.bind(
      onPlay: () => unawaited(_playback.play()),
      onPause: () => unawaited(_playback.pause()),
      onToggle: () => unawaited(togglePlayback()),
      onNext: () => unawaited(nextTrack()),
      onPrevious: () => unawaited(previousTrack()),
      onSeek: (position) => unawaited(seek(position)),
    );
  }

  void _recordPlayHistory(MediaItem track) {
    _playHistory.removeWhere((item) => item.id == track.id);
    _playHistory.insert(0, track);
    if (_playHistory.length > 50) {
      _playHistory = _playHistory.sublist(0, 50);
    }
    unawaited(_cacheStore.savePlayHistory(_playHistory));
  }

  Future<void> _restorePlaybackResumeState() async {
    if (_session == null) {
      return;
    }
    final resume = await _cacheStore.loadPlaybackResumeState();
    if (resume == null) {
      return;
    }
    _queue = [resume.track];
    _nowPlaying = resume.track;
    _updatePlaybackProgress(
      position: resume.position,
      duration: resume.track.duration,
    );
    _playSessionId = _buildPlaySessionId(resume.track);
    _reportedStartSessionId = null;
    _reportedStopSessionId = null;
    _lastProgressReportAt = null;
    _lastPlaybackPersistAt = DateTime.now();
    _activeSessionHasPlayed = false;
    try {
      await _playback.setQueue(
        _queue,
        startIndex: 0,
        startPosition: _position,
        cacheStore: _cacheStore,
        headers: _playbackHeaders(),
      );
    } catch (_) {
      // Ignore failures when restoring playback state.
    }
    _updateNowPlayingInfo(force: true);
  }

  void _persistPlaybackResumeState({bool force = false}) {
    final track = _nowPlaying;
    if (track == null) {
      return;
    }
    final now = DateTime.now();
    if (!force) {
      final last = _lastPlaybackPersistAt;
      if (last != null && now.difference(last) < const Duration(seconds: 5)) {
        return;
      }
    }
    _lastPlaybackPersistAt = now;
    unawaited(
      _cacheStore.savePlaybackResumeState(
        PlaybackResumeState(track: track, position: _position),
      ),
    );
  }

  void _setNowPlaying(
    MediaItem track, {
    bool notify = true,
    bool recordHistory = true,
    bool forceRestart = false,
  }) {
    if (!forceRestart && _nowPlaying?.id == track.id) {
      if (_duration == Duration.zero && track.duration > Duration.zero) {
        _updatePlaybackProgress(duration: track.duration);
        _updateNowPlayingInfo(force: true);
        if (notify) {
          notifyListeners();
        }
      }
      return;
    }
    final previousTrack = _nowPlaying;
    final previousSession = _playSessionId;
    if (_activeSessionHasPlayed) {
      _maybeReportStoppedForSession(
        track: previousTrack,
        sessionId: previousSession,
        completed: false,
      );
    }
    _nowPlaying = track;
    _updatePlaybackProgress(position: Duration.zero);
    if (track.duration > Duration.zero) {
      _updatePlaybackProgress(duration: track.duration);
    }
    unawaited(_refreshNowPlayingCacheStatus(track));
    unawaited(_maybeUpdateNowPlayingPalette(track));
    if (recordHistory) {
      _recordPlayHistory(track);
    }
    _playSessionId = _buildPlaySessionId(track);
    _reportedStartSessionId = null;
    _reportedStopSessionId = null;
    _lastProgressReportAt = null;
    _activeSessionHasPlayed = _isPlaying;
    _persistPlaybackResumeState(force: true);
    if (_isPlaying && _telemetryPlayback) {
      _reportPlaybackStart();
    }
    _updateNowPlayingInfo(force: true);
    if (notify) {
      notifyListeners();
    }
  }

  void _updateNowPlayingInfo({bool force = false}) {
    final track = _nowPlaying;
    if (track == null) {
      return;
    }
    final now = DateTime.now();
    const interval = Duration(seconds: 1);
    if (!force) {
      final last = _lastNowPlayingUpdateAt;
      if (last != null && now.difference(last) < interval) {
        return;
      }
    }
    _lastNowPlayingUpdateAt = now;
    final duration = _duration == Duration.zero ? track.duration : _duration;
    final position = duration.inMilliseconds > 0 && _position > duration
        ? duration
        : _position;
    unawaited(
      _nowPlayingService.update(
        track: track,
        position: position,
        duration: duration,
        isPlaying: _isPlaying,
      ),
    );
  }

  bool _needsNowPlayingPalette() {
    return _accentColorSource == AccentColorSource.nowPlaying ||
        _themePaletteSource == ThemePaletteSource.nowPlaying;
  }

  Future<void> _maybeUpdateNowPlayingPalette(MediaItem? track) async {
    if (!_needsNowPlayingPalette()) {
      return;
    }
    final imageUrl = track?.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      if (_nowPlayingPalette != null) {
        _nowPlayingPalette = null;
        notifyListeners();
      }
      return;
    }
    final cached = _paletteCache[imageUrl];
    if (cached != null) {
      if (_nowPlayingPalette != cached) {
        _nowPlayingPalette = cached;
        notifyListeners();
      }
      return;
    }
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(imageUrl),
        size: const Size(160, 160),
        maximumColorCount: 12,
      );
      final palette = _buildNowPlayingPalette(generator);
      _paletteCache[imageUrl] = palette;
      _nowPlayingPalette = palette;
      notifyListeners();
    } catch (_) {
      // Ignore palette extraction failures.
    }
  }

  NowPlayingPalette _buildNowPlayingPalette(PaletteGenerator generator) {
    final dominant =
        generator.vibrantColor?.color ?? generator.dominantColor?.color;
    final secondary = generator.darkMutedColor?.color ??
        generator.mutedColor?.color ??
        generator.lightMutedColor?.color;
    final tertiary = generator.lightVibrantColor?.color ??
        generator.darkVibrantColor?.color ??
        generator.lightMutedColor?.color;
    final fallback = Color(_accentColorValue);
    return NowPlayingPalette(
      primary: dominant ?? fallback,
      secondary: secondary ?? dominant ?? fallback,
      tertiary: tertiary ?? secondary ?? dominant ?? fallback,
    );
  }

  String _buildPlaySessionId(MediaItem track) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return '${track.id}-$timestamp';
  }

  String _platformDeviceName() {
    if (kIsWeb) {
      return 'Coppelia Web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'Coppelia iOS';
      case TargetPlatform.android:
        return 'Coppelia Android';
      case TargetPlatform.macOS:
        return 'Coppelia macOS';
      case TargetPlatform.windows:
        return 'Coppelia Windows';
      case TargetPlatform.linux:
        return 'Coppelia Linux';
      case TargetPlatform.fuchsia:
        return 'Coppelia Fuchsia';
    }
  }

  void _maybeReportPlaybackState() {
    if (!_telemetryPlayback) {
      return;
    }
    if (_isPlaying) {
      if (_reportedStartSessionId != _playSessionId) {
        _reportPlaybackStart();
      } else {
        _reportPlaybackProgress(isPaused: false, force: true);
      }
      return;
    }
    _reportPlaybackProgress(isPaused: true, force: true);
  }

  void _maybeReportProgress() {
    if (!_telemetryProgress) {
      return;
    }
    if (!_isPlaying) {
      return;
    }
    final now = DateTime.now();
    final last = _lastProgressReportAt;
    const interval = Duration(seconds: 15);
    if (last != null && now.difference(last) < interval) {
      return;
    }
    _lastProgressReportAt = now;
    _reportPlaybackProgress(isPaused: false, force: false);
  }

  void _maybeReportStopped({required bool completed}) {
    _maybeReportStoppedForSession(
      track: _nowPlaying,
      sessionId: _playSessionId,
      completed: completed,
    );
  }

  void _maybeReportStoppedForSession({
    required MediaItem? track,
    required String? sessionId,
    required bool completed,
  }) {
    if (!_telemetryHistory) {
      return;
    }
    if (track == null || sessionId == null) {
      return;
    }
    if (_reportedStopSessionId == sessionId) {
      return;
    }
    _reportedStopSessionId = sessionId;
    _reportPlaybackStopped(
      track,
      sessionId: sessionId,
      completed: completed,
    );
  }

  void _reportPlaybackStart() {
    if (_offlineMode) {
      return;
    }
    final track = _nowPlaying;
    final sessionId = _playSessionId;
    if (track == null || sessionId == null) {
      return;
    }
    if (_reportedStartSessionId == sessionId) {
      return;
    }
    _reportedStartSessionId = sessionId;
    unawaited(
      _client.reportPlaybackStart(
        track: track,
        position: _position,
        isPaused: false,
        playSessionId: sessionId,
        duration: _duration,
      ),
    );
  }

  void _reportPlaybackProgress({
    required bool isPaused,
    required bool force,
  }) {
    if (_offlineMode) {
      return;
    }
    final track = _nowPlaying;
    final sessionId = _playSessionId;
    if (track == null || sessionId == null) {
      return;
    }
    if (!_telemetryProgress && !force) {
      return;
    }
    if (!_telemetryPlayback && force) {
      return;
    }
    unawaited(
      _client.reportPlaybackProgress(
        track: track,
        position: _position,
        isPaused: isPaused,
        playSessionId: sessionId,
        duration: _duration,
      ),
    );
  }

  void _reportPlaybackStopped(
    MediaItem track, {
    required String sessionId,
    required bool completed,
  }) {
    if (_offlineMode) {
      return;
    }
    unawaited(
      _client.reportPlaybackStopped(
        track: track,
        position: _position,
        isPaused: !_isPlaying,
        completed: completed,
        playSessionId: sessionId,
        duration: _duration,
      ),
    );
  }

  T? _randomFromList<T>(List<T> items) {
    if (items.isEmpty) {
      return null;
    }
    return items[_random.nextInt(items.length)];
  }

  List<MediaItem> _filterPinnedTracks(List<MediaItem> tracks) {
    if (_pinnedAudio.isEmpty) {
      return [];
    }
    return tracks.where(_isTrackPinnedInMemory).toList();
  }

  Future<List<MediaItem>> _offlineTracksForAlbum(Album album) async {
    if (_pinnedAudio.isEmpty) {
      return [];
    }
    final normalized = album.name.trim().toLowerCase();
    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    final matches = cachedEntries
        .where(
          (entry) =>
              _pinnedAudio.contains(entry.streamUrl) &&
              entry.album.trim().toLowerCase() == normalized,
        )
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return matches.map(_mediaItemFromCachedEntry).toList();
  }

  Future<List<MediaItem>> _offlineTracksForArtist(Artist artist) async {
    if (_pinnedAudio.isEmpty) {
      return [];
    }
    final normalized = artist.name.trim().toLowerCase();
    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    final matches = cachedEntries.where((entry) {
      if (!_pinnedAudio.contains(entry.streamUrl)) {
        return false;
      }
      return entry.artists.any(
        (name) => name.trim().toLowerCase() == normalized,
      );
    }).toList()
      ..sort((a, b) {
        final albumCompare = a.album.compareTo(b.album);
        if (albumCompare != 0) {
          return albumCompare;
        }
        return a.title.compareTo(b.title);
      });
    return matches.map(_mediaItemFromCachedEntry).toList();
  }

  Future<void> _playFromList(
    List<MediaItem> tracks,
    MediaItem track,
  ) async {
    final logService = await LogService.instance;
    final requestId = ++_playRequestId;
    final formatInfo = track.container != null || track.codec != null
        ? ' [container=${track.container ?? "unknown"}, codec=${track.codec ?? "unknown"}'
            '${track.bitrate != null ? ", bitrate=${track.bitrate}" : ""}'
            '${track.sampleRate != null ? ", sampleRate=${track.sampleRate}Hz" : ""}]'
        : '';
    await logService.info(
        '_playFromList[$requestId]: Starting with ${tracks.length} tracks, playing "${track.title}"$formatInfo');

    final index = tracks.indexWhere((item) => item.id == track.id);
    if (index < 0) {
      await logService
          .warning('_playFromList[$requestId]: Track not found in list');
      return;
    }

    await logService.info(
        '_playFromList[$requestId]: Track index $index, normalizing tracks');
    final normalized = _normalizeTracksForPlayback(tracks);
    final playbackTrack = normalized[index];

    await logService
        .info('_playFromList[$requestId]: Refreshing cache status for track');
    await _refreshNowPlayingCacheStatus(playbackTrack);
    if (_isPlayRequestStale(requestId)) {
      await logService.info(
          '_playFromList[$requestId]: Stale request after cache refresh; aborting');
      return;
    }

    final previousQueue = List<MediaItem>.from(_queue);
    _queue = normalized;
    _isApplyingQueueUpdate = true;
    _lastHandledCurrentIndex = null;
    _lastHandledCurrentTrackId = null;

    await logService.info(
        '_playFromList[$requestId]: Setting queue with ${_queue.length} tracks at index $index');
    final didSetQueue = await _performPlaybackAction(
      () => _playback.setQueue(
        _queue,
        startIndex: index,
        cacheStore: _cacheStore,
        headers: _playbackHeaders(),
      ),
      'set queue',
    );
    _isApplyingQueueUpdate = false;
    await logService.info(
        '_playFromList[$requestId]: Queue setup ${didSetQueue ? "successful" : "failed"}');
    if (_isPlayRequestStale(requestId)) {
      await logService.info(
          '_playFromList[$requestId]: Stale request after set queue; aborting');
      return;
    }
    if (!didSetQueue) {
      await logService.warning(
          '_playFromList[$requestId]: Failed to set queue, restoring previous queue');
      _queue = previousQueue;
      if (_isPreparingPlayback) {
        _isPreparingPlayback = false;
      }
      notifyListeners();
      return;
    }

    await logService
        .info('_playFromList[$requestId]: Priming now playing track state');
    _setNowPlaying(
      playbackTrack,
      forceRestart: true,
    );
    _rememberCurrentIndexEvent(index, playbackTrack);

    await logService.info('_playFromList[$requestId]: Initiating play command');
    final didPlay = await _performPlaybackAction(
      () => _playback.play(),
      'play',
    );
    await logService.info(
        '_playFromList[$requestId]: Play command ${didPlay ? "successful" : "failed"}');
  }

  Map<String, String>? _playbackHeaders() {
    final headers = _client.authorizationHeaders;
    if (headers == null) {
      return null;
    }
    return {
      ...headers,
      'User-Agent': JellyfinClient.clientName,
    };
  }

  List<MediaItem> _normalizeTracksForPlayback(List<MediaItem> tracks) {
    return tracks.map(_normalizeTrackForPlayback).toList();
  }

  MediaItem _normalizeTrackForPlayback(MediaItem track) {
    final session = _session;
    if (session == null) {
      return track;
    }
    final streamUrl = _client.buildStreamUrl(
      itemId: track.id,
      userId: session.userId,
    );
    if (streamUrl.isEmpty || streamUrl == track.streamUrl) {
      return track;
    }
    return MediaItem(
      id: track.id,
      title: track.title,
      album: track.album,
      artists: track.artists,
      duration: track.duration,
      imageUrl: track.imageUrl,
      streamUrl: streamUrl,
      albumId: track.albumId,
      artistIds: track.artistIds,
      playlistItemId: track.playlistItemId,
      addedAt: track.addedAt,
      playCount: track.playCount,
      lastPlayedAt: track.lastPlayedAt,
      genres: track.genres,
      container: track.container,
      codec: track.codec,
      bitrate: track.bitrate,
      sampleRate: track.sampleRate,
      bpm: track.bpm,
    );
  }

  Future<bool> _performPlaybackAction(
    Future<void> Function() action,
    String label,
  ) async {
    final logService = await LogService.instance;
    await logService.info('Playback action: $label - starting');
    try {
      await action();
      await logService.info('Playback action: $label - completed successfully');
      return true;
    } catch (error, stackTrace) {
      await logService.error(
          'Playback action: $label - failed', error, stackTrace);
      debugPrint('Playback $label failed: $error');
      return false;
    }
  }

  Future<void> _refreshNowPlayingCacheStatus(MediaItem? track) async {
    if (track == null) {
      final shouldNotify = _isNowPlayingCached || _isPreparingPlayback;
      _isNowPlayingCached = false;
      _isPreparingPlayback = false;
      if (shouldNotify) {
        notifyListeners();
      }
      return;
    }
    final isCached = await _cacheStore.isAudioCached(track);
    if (isCached) {
      _cachedAudio.addAll(_offlineKeysForTrack(track));
    }
    // Don't reassert "preparing" if the player has already reached ready —
    // the player-state listener may have just cleared it, and there's no
    // future state event guaranteed to clear it again.
    final processingState = _playback.processingState;
    final playerIsReady = processingState == ProcessingState.ready ||
        processingState == ProcessingState.completed;
    final nextPreparing = !isCached && !playerIsReady;
    final shouldNotify = _isNowPlayingCached != isCached ||
        _isPreparingPlayback != nextPreparing;
    _isNowPlayingCached = isCached;
    _isPreparingPlayback = nextPreparing;
    if (shouldNotify) {
      notifyListeners();
    }
  }
}
