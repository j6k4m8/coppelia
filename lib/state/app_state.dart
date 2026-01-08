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
import '../models/smart_list.dart';
import '../services/cache_store.dart';
import '../services/jellyfin_client.dart';
import '../services/now_playing_service.dart';
import '../services/playback_controller.dart';
import '../services/settings_store.dart';
import '../services/session_store.dart';
import 'browse_layout.dart';
import 'accent_color_source.dart';
import 'home_section.dart';
import 'keyboard_shortcut.dart';
import 'layout_density.dart';
import 'library_view.dart';
import 'now_playing_layout.dart';
import 'sidebar_item.dart';
import 'theme_palette_source.dart';

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
    required SessionStore sessionStore,
    required SettingsStore settingsStore,
  })  : _cacheStore = cacheStore,
        _client = client,
        _playback = playback,
        _sessionStore = sessionStore,
        _settingsStore = settingsStore {
    _bindPlayback();
    _bindNowPlaying();
  }

  final CacheStore _cacheStore;
  final JellyfinClient _client;
  final PlaybackController _playback;
  final NowPlayingService _nowPlayingService = NowPlayingService();
  final SessionStore _sessionStore;
  final SettingsStore _settingsStore;

  AuthSession? _session;
  bool _isBootstrapping = true;
  bool _isLoadingLibrary = false;
  String? _authError;
  Playlist? _selectedPlaylist;
  LibraryView _selectedView = LibraryView.home;
  Album? _selectedAlbum;
  Artist? _selectedArtist;
  Genre? _selectedGenre;
  String _searchQuery = '';
  bool _isSearching = false;
  SearchResults? _searchResults;
  int _searchFocusRequest = 0;
  LoopMode _repeatMode = LoopMode.off;

  void _notifyListenersLater() {
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  List<Playlist> _playlists = [];
  List<MediaItem> _playlistTracks = [];
  List<MediaItem> _featuredTracks = [];
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
  final List<DownloadTask> _downloadQueue = [];
  final Map<String, DateTime> _downloadProgressTimestamps = {};
  bool _isProcessingDownloads = false;
  List<MediaItem> _recentTracks = [];
  List<MediaItem> _playHistory = [];

  LibraryStats? _libraryStats;

  MediaItem? _nowPlaying;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isNowPlayingCached = false;
  bool _isPreparingPlayback = false;
  final ValueNotifier<Duration> _positionNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isBufferingNotifier = ValueNotifier(false);
  final ValueNotifier<int> _mediaCacheBytesNotifier = ValueNotifier(0);
  final ValueNotifier<int> _pinnedCacheBytesNotifier = ValueNotifier(0);
  final Random _random = Random();
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
  LayoutDensity _layoutDensity = LayoutDensity.comfortable;
  NowPlayingLayout _nowPlayingLayout = NowPlayingLayout.bottom;
  Map<HomeSection, bool> _homeSectionVisibility = {
    for (final section in HomeSection.values) section: true,
  };
  List<HomeSection> _homeSectionOrder = List<HomeSection>.from(
    HomeSection.values,
  );
  Map<SidebarItem, bool> _sidebarVisibility = {
    for (final item in SidebarItem.values) item: true,
  };
  double _sidebarWidth = 240;
  bool _sidebarCollapsed = false;
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

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<int?>? _currentIndexSubscription;
  Timer? _playbackPollTimer;

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

  /// True while the app restores cached state.
  bool get isBootstrapping => _isBootstrapping;

  /// True while Jellyfin data is loading.
  bool get isLoadingLibrary => _isLoadingLibrary;

  /// Error message from the last authentication attempt.
  String? get authError => _authError;

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

  /// Preferred layout density.
  LayoutDensity get layoutDensity => _layoutDensity;

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

  /// True when there is a previous view in history.
  bool get canGoBack => _viewHistory.isNotEmpty;

  /// Preferred browse layout for a library view.
  BrowseLayout browseLayoutFor(LibraryView view) =>
      _browseLayouts[view] ?? BrowseLayout.grid;

  /// Returns whether a home section should be shown.
  bool isHomeSectionVisible(HomeSection section) =>
      _homeSectionVisibility[section] ?? true;

  /// Returns whether a sidebar item should be shown.
  bool isSidebarItemVisible(SidebarItem item) =>
      _sidebarVisibility[item] ?? true;

  /// Updates the browse layout for a library view.
  void setBrowseLayout(LibraryView view, BrowseLayout layout) {
    _browseLayouts[view] = layout;
    notifyListeners();
  }

  /// Updates the visibility of a home section.
  Future<void> setHomeSectionVisible(
    HomeSection section,
    bool visible,
  ) async {
    _homeSectionVisibility[section] = visible;
    await _settingsStore.saveHomeSectionVisibility(_homeSectionVisibility);
    notifyListeners();
    if (section == HomeSection.jumpIn && visible) {
      unawaited(loadJumpIn(force: true));
    }
  }

  /// Updates the ordering of home sections.
  Future<void> reorderHomeSections(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) {
      return;
    }
    final list = List<HomeSection>.from(_homeSectionOrder);
    if (oldIndex < 0 || oldIndex >= list.length) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = list.removeAt(oldIndex);
    final target = newIndex.clamp(0, list.length);
    list.insert(target, moved);
    _homeSectionOrder = list;
    await _settingsStore.saveHomeSectionOrder(_homeSectionOrder);
    notifyListeners();
  }

  /// Updates the visibility of a sidebar item.
  Future<void> setSidebarItemVisible(
    SidebarItem item,
    bool visible,
  ) async {
    _sidebarVisibility[item] = visible;
    await _settingsStore.saveSidebarVisibility(_sidebarVisibility);
    notifyListeners();
  }

  /// Returns a saved scroll offset for a key.
  double loadScrollOffset(String key) => _scrollOffsets[key] ?? 0;

  /// Saves a scroll offset for a key.
  void saveScrollOffset(String key, double offset) {
    _scrollOffsets[key] = offset;
  }

  /// Initializes cached state and refreshes library.
  Future<void> bootstrap() async {
    await AppInfo.load();
    final deviceId = await _settingsStore.loadDeviceId();
    _client.updateDeviceInfo(
      deviceId: deviceId,
      deviceName: _platformDeviceName(),
    );
    _session = await _sessionStore.loadSession();
    if (_session != null) {
      _client.updateSession(_session!);
    }
    _themeMode = await _settingsStore.loadThemeMode();
    _fontFamily = await _settingsStore.loadFontFamily();
    _fontScale = await _settingsStore.loadFontScale();
    _accentColorValue = await _settingsStore.loadAccentColorValue();
    _accentColorSource = await _settingsStore.loadAccentColorSource();
    _themePaletteSource = await _settingsStore.loadThemePaletteSource();
    _telemetryPlayback = await _settingsStore.loadPlaybackTelemetry();
    _telemetryProgress = await _settingsStore.loadProgressTelemetry();
    _telemetryHistory = await _settingsStore.loadHistoryTelemetry();
    _gaplessPlayback = await _settingsStore.loadGaplessPlayback();
    _downloadsWifiOnly = await _settingsStore.loadDownloadsWifiOnly();
    _downloadsPaused = await _settingsStore.loadDownloadsPaused();
    _autoDownloadFavoritesEnabled =
        await _settingsStore.loadAutoDownloadFavoritesEnabled();
    _autoDownloadFavoriteAlbums =
        await _settingsStore.loadAutoDownloadFavoriteAlbums();
    _autoDownloadFavoriteArtists =
        await _settingsStore.loadAutoDownloadFavoriteArtists();
    _autoDownloadFavoriteTracks =
        await _settingsStore.loadAutoDownloadFavoriteTracks();
    _autoDownloadFavoritesWifiOnly =
        await _settingsStore.loadAutoDownloadFavoritesWifiOnly();
    _settingsShortcutEnabled =
        await _settingsStore.loadSettingsShortcutEnabled();
    _settingsShortcut = await _settingsStore.loadSettingsShortcut();
    _searchShortcutEnabled = await _settingsStore.loadSearchShortcutEnabled();
    _searchShortcut = await _settingsStore.loadSearchShortcut();
    _layoutDensity = await _settingsStore.loadLayoutDensity();
    _nowPlayingLayout = await _settingsStore.loadNowPlayingLayout();
    _offlineMode = await _settingsStore.loadOfflineMode();
    _cacheMaxBytes = await _cacheStore.loadCacheMaxBytes();
    _homeSectionVisibility = await _settingsStore.loadHomeSectionVisibility();
    _homeSectionOrder = await _settingsStore.loadHomeSectionOrder();
    _sidebarVisibility = await _settingsStore.loadSidebarVisibility();
    _sidebarWidth = await _settingsStore.loadSidebarWidth();
    _sidebarCollapsed = await _settingsStore.loadSidebarCollapsed();
    _smartLists = await _settingsStore.loadSmartLists();
    _pinnedAudio = await _cacheStore.loadPinnedAudio();
    unawaited(refreshMediaCacheBytes());
    await _loadCachedLibrary();
    await _applyPlaybackSettings();
    if (_offlineMode) {
      await _applyOfflineModeData();
    }
    await _restorePlaybackResumeState();
    unawaited(_maybeUpdateNowPlayingPalette(_nowPlaying));
    _isBootstrapping = false;
    notifyListeners();

    if (_session != null && !_offlineMode) {
      await refreshLibrary();
    }
  }

  Future<void> _applyPlaybackSettings() async {
    await _playback.setGaplessPlayback(_gaplessPlayback);
  }

  /// Attempts Jellyfin sign-in.
  Future<bool> signIn({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    _authError = null;
    notifyListeners();
    try {
      final session = await _client.authenticate(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      _session = session;
      await _sessionStore.saveSession(session);
      await refreshLibrary();
      notifyListeners();
      return true;
    } catch (error) {
      _authError = error.toString();
      notifyListeners();
      return false;
    }
  }

  /// Signs out and clears cached state.
  Future<void> signOut() async {
    await _cacheStore.savePlaybackResumeState(null);
    _session = null;
    _client.clearSession();
    _selectedPlaylist = null;
    _selectedSmartList = null;
    _selectedView = LibraryView.home;
    _viewHistory.clear();
    _selectedAlbum = null;
    _selectedArtist = null;
    _selectedGenre = null;
    _searchQuery = '';
    _searchResults = null;
    _isSearching = false;
    _playlistTracks = [];
    _smartListTracks = [];
    _featuredTracks = [];
    _playlists = [];
    _albums = [];
    _artists = [];
    _genres = [];
    _libraryTracks = [];
    _trackBrowseLetter = null;
    _tracksLoadCompleter = null;
    _isLoadingTracks = false;
    _hasMoreTracks = true;
    _tracksOffset = 0;
    _albumTracks = [];
    _artistTracks = [];
    _genreTracks = [];
    _favoriteAlbums = [];
    _favoriteArtists = [];
    _favoriteTracks = [];
    _recentTracks = [];
    _playHistory = [];
    _libraryStats = null;
    _jumpInTrack = null;
    _jumpInAlbum = null;
    _jumpInArtist = null;
    _isLoadingJumpIn = false;
    _lastJumpInRefreshAt = null;
    _queue = [];
    _downloadQueue.clear();
    _isProcessingDownloads = false;
    _nowPlaying = null;
    unawaited(_maybeUpdateNowPlayingPalette(null));
    _playSessionId = null;
    _reportedStartSessionId = null;
    _reportedStopSessionId = null;
    _lastProgressReportAt = null;
    _lastPlaybackPersistAt = null;
    _lastNowPlayingUpdateAt = null;
    _activeSessionHasPlayed = false;
    _isBuffering = false;
    _isNowPlayingCached = false;
    _isPreparingPlayback = false;
    unawaited(_nowPlayingService.clear());
    await _sessionStore.saveSession(null);
    notifyListeners();
  }

  /// Refreshes playlists and featured tracks.
  Future<void> refreshLibrary() async {
    if (_session == null) {
      return;
    }
    if (_offlineMode) {
      await _applyOfflineModeData();
      return;
    }
    _isLoadingLibrary = true;
    notifyListeners();
    try {
      final playlists = await _client.fetchPlaylists();
      _playlists = playlists;
      await _cacheStore.savePlaylists(playlists);
      final stats = await _client.fetchLibraryStats();
      _libraryStats = stats;
      await _cacheStore.saveLibraryStats(stats);
      List<MediaItem> recent;
      try {
        recent = await _client.fetchRecentlyPlayedTracks();
      } catch (_) {
        recent = await _client.fetchRecentTracks();
      }
      _recentTracks = recent;
      await _cacheStore.saveRecentTracks(recent);
      final featured = await _client.fetchRecentTracks();
      _featuredTracks = featured;
      await _cacheStore.saveFeaturedTracks(featured);
      if (_albums.isNotEmpty) {
        await _loadAlbums();
      }
      if (_artists.isNotEmpty) {
        await _loadArtists();
      }
      if (_genres.isNotEmpty) {
        await _loadGenres();
      }
      await _loadFavoriteAlbums();
      await _loadFavoriteArtists();
      await _loadFavoriteTracks();
      if (_selectedSmartList != null) {
        unawaited(_loadSmartListTracks(_selectedSmartList!));
      }
      if (isHomeSectionVisible(HomeSection.jumpIn)) {
        unawaited(loadJumpIn(force: true));
      }
    } catch (_) {
      // Keep cached content if refresh fails.
    }
    _isLoadingLibrary = false;
    notifyListeners();
  }

  /// Selects a playlist and loads its tracks.
  Future<void> selectPlaylist(
    Playlist playlist, {
    bool offlineOnly = false,
  }) async {
    if (_selectedView != LibraryView.home) {
      _recordViewHistory(_selectedView);
    }
    _selectedPlaylist = playlist;
    _selectedSmartList = null;
    _selectedView = LibraryView.home;
    _offlineOnlyFilter = offlineOnly;
    clearBrowseSelection(notify: false);
    clearSearch(notify: false);
    notifyListeners();
    final cached = await _cacheStore.loadPlaylistTracks(playlist.id);
    if (cached.isNotEmpty) {
      _playlistTracks = cached;
      notifyListeners();
    }
    if (_offlineMode) {
      return;
    }
    try {
      final tracks = await _client.fetchPlaylistTracks(playlist.id);
      _playlistTracks = tracks;
      await _cacheStore.savePlaylistTracks(playlist.id, tracks);
      notifyListeners();
    } catch (_) {
      // Keep cached tracks if refresh fails.
    }
  }

  /// Loads a playlist and starts playback without navigating.
  Future<void> playPlaylist(Playlist playlist) async {
    List<MediaItem> tracks = const [];
    if (_offlineMode) {
      tracks = await _cacheStore.loadPlaylistTracks(playlist.id);
      final filtered = _filterPinnedTracks(tracks);
      if (filtered.isEmpty) {
        return;
      }
      await _playFromList(filtered, filtered.first);
      return;
    }
    try {
      tracks = await _client.fetchPlaylistTracks(playlist.id);
      await _cacheStore.savePlaylistTracks(playlist.id, tracks);
    } catch (_) {
      tracks = await _cacheStore.loadPlaylistTracks(playlist.id);
    }
    if (tracks.isEmpty) {
      return;
    }
    await _playFromList(tracks, tracks.first);
  }

  /// Builds and plays a Smart List without navigating.
  Future<void> playSmartList(SmartList list) async {
    await _ensureSmartListSourceLoaded();
    final tracks = _buildSmartListTracks(list);
    if (tracks.isEmpty) {
      return;
    }
    await _playFromList(tracks, tracks.first);
  }

  /// Clears the current playlist selection.
  void clearPlaylistSelection() {
    _selectedPlaylist = null;
    _playlistTracks = [];
    _selectedView = LibraryView.home;
    clearBrowseSelection(notify: false);
    notifyListeners();
  }

  /// Selects a Smart List and loads its tracks.
  Future<void> selectSmartList(SmartList list) async {
    if (_selectedView != LibraryView.home) {
      _recordViewHistory(_selectedView);
    }
    _selectedSmartList = list;
    _selectedView = LibraryView.home;
    _offlineOnlyFilter = false;
    _selectedPlaylist = null;
    _playlistTracks = [];
    clearBrowseSelection(notify: false);
    clearSearch(notify: false);
    notifyListeners();
    await _loadSmartListTracks(list);
  }

  /// Clears the current Smart List selection.
  void clearSmartListSelection() {
    _selectedSmartList = null;
    _smartListTracks = [];
    _selectedView = LibraryView.home;
    clearBrowseSelection(notify: false);
    notifyListeners();
  }

  /// Creates and stores a Smart List.
  Future<SmartList> createSmartList(SmartList list) async {
    _smartLists = [..._smartLists, list]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await _settingsStore.saveSmartLists(_smartLists);
    notifyListeners();
    return list;
  }

  /// Updates a Smart List definition.
  Future<void> updateSmartList(SmartList list) async {
    final index = _smartLists.indexWhere((entry) => entry.id == list.id);
    if (index == -1) {
      return;
    }
    _smartLists = List<SmartList>.from(_smartLists);
    _smartLists[index] = list;
    _smartLists.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    await _settingsStore.saveSmartLists(_smartLists);
    if (_selectedSmartList?.id == list.id) {
      _selectedSmartList = list;
      await _loadSmartListTracks(list);
    }
    notifyListeners();
  }

  /// Deletes a Smart List.
  Future<void> deleteSmartList(SmartList list) async {
    _smartLists = _smartLists.where((entry) => entry.id != list.id).toList();
    await _settingsStore.saveSmartLists(_smartLists);
    if (_selectedSmartList?.id == list.id) {
      clearSmartListSelection();
    } else {
      notifyListeners();
    }
  }

  /// Creates a new playlist.
  Future<Playlist?> createPlaylist({
    required String name,
    List<MediaItem> initialTracks = const [],
  }) async {
    if (_session == null || _offlineMode) {
      return null;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final playlist = await _client.createPlaylist(
        name: trimmed,
        itemIds: initialTracks.map((track) => track.id).toList(),
      );
      final created = playlist.id.isEmpty
          ? Playlist(
              id: playlist.id,
              name: trimmed,
              trackCount: initialTracks.length,
              imageUrl: playlist.imageUrl,
            )
          : playlist;
      _playlists = [..._playlists, created]..sort(_comparePlaylists);
      await _cacheStore.savePlaylists(_playlists);
      _updatePlaylistStats(1);
      _notifyListenersLater();
      if (created.id.isNotEmpty && initialTracks.isNotEmpty) {
        final tracks = await _client.fetchPlaylistTracks(created.id);
        await _cacheStore.savePlaylistTracks(created.id, tracks);
        if (_selectedPlaylist?.id == created.id) {
          _playlistTracks = tracks;
          notifyListeners();
        }
      }
      return created;
    } catch (_) {
      return null;
    }
  }

  /// Renames an existing playlist.
  Future<String?> renamePlaylist(Playlist playlist, String name) async {
    if (_session == null || _offlineMode) {
      return 'Playlists are unavailable offline.';
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == playlist.name) {
      return null;
    }
    final updated = Playlist(
      id: playlist.id,
      name: trimmed,
      trackCount: playlist.trackCount,
      imageUrl: playlist.imageUrl,
    );
    final previous = _playlists;
    _playlists = _playlists
        .map((item) => item.id == playlist.id ? updated : item)
        .toList()
      ..sort(_comparePlaylists);
    await _cacheStore.savePlaylists(_playlists);
    notifyListeners();
    try {
      await _client.renamePlaylist(playlistId: playlist.id, name: trimmed);
      if (_selectedPlaylist?.id == playlist.id) {
        _selectedPlaylist = updated;
        notifyListeners();
      }
      return null;
    } catch (error) {
      _playlists = previous;
      await _cacheStore.savePlaylists(_playlists);
      notifyListeners();
      return _requestErrorMessage(
        error,
        fallback: 'Unable to rename playlist.',
      );
    }
  }

  /// Deletes a playlist.
  Future<String?> deletePlaylist(Playlist playlist) async {
    if (_session == null || _offlineMode) {
      return 'Playlists are unavailable offline.';
    }
    final previous = _playlists;
    _playlists = _playlists.where((item) => item.id != playlist.id).toList();
    await _cacheStore.savePlaylists(_playlists);
    _updatePlaylistStats(-1);
    if (_selectedPlaylist?.id == playlist.id) {
      clearPlaylistSelection();
    } else {
      notifyListeners();
    }
    try {
      await _client.deletePlaylist(playlist.id);
      return null;
    } catch (error) {
      _playlists = previous;
      await _cacheStore.savePlaylists(_playlists);
      _updatePlaylistStats(1);
      notifyListeners();
      return _requestErrorMessage(
        error,
        fallback: 'Unable to delete playlist.',
      );
    }
  }

  /// Adds a track to the selected playlist.
  Future<String?> addTrackToPlaylist(
    MediaItem track,
    Playlist playlist,
  ) async {
    return addTracksToPlaylist(playlist, [track]);
  }

  /// Adds tracks to a playlist.
  Future<String?> addTracksToPlaylist(
    Playlist playlist,
    List<MediaItem> tracks,
  ) async {
    if (_session == null || _offlineMode || tracks.isEmpty) {
      return 'Playlists are unavailable offline.';
    }
    try {
      await _client.addToPlaylist(
        playlistId: playlist.id,
        itemIds: tracks.map((track) => track.id).toList(),
      );
      if (_selectedPlaylist?.id == playlist.id) {
        final refreshed = await _client.fetchPlaylistTracks(playlist.id);
        _playlistTracks = refreshed;
        await _cacheStore.savePlaylistTracks(playlist.id, refreshed);
        notifyListeners();
      }
      _updatePlaylistTrackCount(playlist, tracks.length);
      return null;
    } catch (error) {
      return _requestErrorMessage(
        error,
        fallback: 'Unable to add to playlist.',
      );
    }
  }

  /// Removes a track from a playlist.
  Future<String?> removeTrackFromPlaylist(
    MediaItem track,
    Playlist playlist,
  ) async {
    if (_session == null || _offlineMode) {
      return 'Playlists are unavailable offline.';
    }
    try {
      await _client.removeFromPlaylist(
        playlistId: playlist.id,
        entryIds:
            track.playlistItemId == null ? const [] : [track.playlistItemId!],
        itemIds: track.playlistItemId == null ? [track.id] : const [],
      );
      if (_selectedPlaylist?.id == playlist.id) {
        final updated = List<MediaItem>.from(_playlistTracks);
        if (track.playlistItemId != null) {
          updated.removeWhere(
            (item) => item.playlistItemId == track.playlistItemId,
          );
        } else {
          final index = updated.indexWhere((item) => item.id == track.id);
          if (index != -1) {
            updated.removeAt(index);
          }
        }
        _playlistTracks = updated;
        await _cacheStore.savePlaylistTracks(playlist.id, updated);
        notifyListeners();
      }
      _updatePlaylistTrackCount(playlist, -1);
      return null;
    } catch (error) {
      return _requestErrorMessage(
        error,
        fallback: 'Unable to remove from playlist.',
      );
    }
  }

  /// Reorders tracks within a playlist.
  Future<String?> reorderPlaylistTracks(
    Playlist playlist,
    List<MediaItem> orderedTracks,
  ) async {
    if (_session == null || _offlineMode) {
      return 'Playlists are unavailable offline.';
    }
    final entryIds =
        orderedTracks.map((track) => track.playlistItemId).toList();
    if (entryIds.any((id) => id == null)) {
      return 'Unable to reorder this playlist.';
    }
    final previous = _playlistTracks;
    _playlistTracks = orderedTracks;
    await _cacheStore.savePlaylistTracks(playlist.id, orderedTracks);
    notifyListeners();
    try {
      await _client.reorderPlaylist(
        playlistId: playlist.id,
        entryIds: entryIds.whereType<String>().toList(),
      );
      return null;
    } catch (error) {
      final fallback = await _attemptPlaylistRebuildReorder(
        playlist,
        orderedTracks,
        error,
      );
      if (fallback == null) {
        return null;
      }
      _playlistTracks = previous;
      await _cacheStore.savePlaylistTracks(playlist.id, previous);
      notifyListeners();
      return fallback;
    }
  }

  /// Navigates to a library view.
  void selectLibraryView(LibraryView view, {bool recordHistory = true}) {
    if (recordHistory && view != _selectedView) {
      _recordViewHistory(_selectedView);
    }
    _selectedView = view;
    _selectedPlaylist = null;
    _playlistTracks = [];
    _selectedSmartList = null;
    _smartListTracks = [];
    if (!_isOfflineLibraryView(view) && !_offlineMode) {
      _offlineOnlyFilter = false;
    }
    clearBrowseSelection(notify: false);
    if (view != LibraryView.home) {
      clearSearch(notify: false);
    }
    notifyListeners();
    if (view == LibraryView.albums) {
      unawaited(loadAlbums());
    }
    if (view == LibraryView.artists) {
      unawaited(loadArtists());
    }
    if (view == LibraryView.genres) {
      unawaited(loadGenres());
    }
    if (view == LibraryView.tracks) {
      unawaited(loadLibraryTracks());
    }
    if (view == LibraryView.favoritesAlbums) {
      unawaited(loadFavoriteAlbums());
    }
    if (view == LibraryView.favoritesArtists) {
      unawaited(loadFavoriteArtists());
    }
    if (view == LibraryView.favoritesSongs) {
      unawaited(loadFavoriteTracks());
    }
  }

  /// Navigates back to the previous library view.
  void goBack() {
    if (_viewHistory.isEmpty) {
      return;
    }
    final previous = _viewHistory.removeLast();
    selectLibraryView(previous, recordHistory: false);
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

  /// Navigates to an album by identifier.
  Future<void> selectAlbumById(String albumId) async {
    if (_albums.isEmpty) {
      await loadAlbums();
    }
    Album? match;
    for (final album in _albums) {
      if (album.id == albumId) {
        match = album;
        break;
      }
    }
    if (match != null) {
      await selectAlbum(match, offlineOnly: offlineOnlyFilter);
    }
  }

  /// Navigates to an artist by identifier.
  Future<void> selectArtistById(String artistId) async {
    if (_artists.isEmpty) {
      await loadArtists();
    }
    Artist? match;
    for (final artist in _artists) {
      if (artist.id == artistId) {
        match = artist;
        break;
      }
    }
    if (match != null) {
      await selectArtist(match, offlineOnly: offlineOnlyFilter);
    }
  }

  /// Navigates to an artist by name.
  Future<void> selectArtistByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (_artists.isEmpty) {
      await loadArtists();
    }
    final target = trimmed.toLowerCase();
    Artist? match;
    for (final artist in _artists) {
      if (artist.name.trim().toLowerCase() == target) {
        match = artist;
        break;
      }
    }
    if (match == null) {
      return;
    }
    await selectArtist(match, offlineOnly: offlineOnlyFilter);
  }

  /// Performs a search across the library.
  Future<void> searchLibrary(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      clearSearch();
      return;
    }
    _searchQuery = query;
    if (_offlineMode) {
      _isSearching = true;
      notifyListeners();
      final needle = trimmed.toLowerCase();
      bool matches(String value) => value.toLowerCase().contains(needle);
      final tracks = _libraryTracks
          .where(
            (track) =>
                matches(track.title) ||
                matches(track.album) ||
                track.artists.any(matches),
          )
          .toList();
      final albums = _albums
          .where(
            (album) => matches(album.name) || matches(album.artistName),
          )
          .toList();
      final artists = _artists.where((artist) => matches(artist.name)).toList();
      final genres = _genres.where((genre) => matches(genre.name)).toList();
      final playlists =
          _playlists.where((playlist) => matches(playlist.name)).toList();
      _searchResults = SearchResults(
        tracks: tracks,
        albums: albums,
        artists: artists,
        genres: genres,
        playlists: playlists,
      );
      _isSearching = false;
      notifyListeners();
      return;
    }
    _isSearching = true;
    notifyListeners();
    try {
      _searchResults = await _client.searchLibrary(trimmed);
    } catch (_) {
      _searchResults = const SearchResults();
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Updates the search query without triggering a network request.
  void setSearchQuery(String query, {bool notify = true}) {
    _searchQuery = query;
    if (notify) {
      notifyListeners();
    }
  }

  /// Clears the current search results.
  void clearSearch({bool notify = true}) {
    _searchQuery = '';
    _searchResults = null;
    _isSearching = false;
    if (notify) {
      notifyListeners();
    }
  }

  /// Cycles between repeat off, repeat all, and repeat one.
  Future<void> toggleRepeatMode() async {
    switch (_repeatMode) {
      case LoopMode.off:
        _repeatMode = LoopMode.all;
        break;
      case LoopMode.all:
        _repeatMode = LoopMode.one;
        break;
      case LoopMode.one:
        _repeatMode = LoopMode.off;
        break;
    }
    await _playback.setLoopMode(_repeatMode);
    notifyListeners();
  }

  /// Updates the track browse letter highlight.
  void setTrackBrowseLetter(String? letter) {
    if (_trackBrowseLetter == letter) {
      return;
    }
    _trackBrowseLetter = letter;
    notifyListeners();
  }

  /// Requests focus for the search field.
  void requestSearchFocus() {
    if (_searchQuery.isEmpty && !_isSearching) {
      // Enter the search view without needing a query.
      _isSearching = true;
    }
    _searchFocusRequest += 1;
    notifyListeners();
  }

  /// Loads albums, using cached results when possible.
  Future<void> loadAlbums() async {
    final cached = await _cacheStore.loadAlbums();
    if (cached.isNotEmpty) {
      _albums = cached;
      notifyListeners();
    }
    if (_offlineMode) {
      _albums = await loadOfflineAlbums();
      notifyListeners();
      return;
    }
    await _loadAlbums();
  }

  /// Loads artists, using cached results when possible.
  Future<void> loadArtists() async {
    final cached = await _cacheStore.loadArtists();
    if (cached.isNotEmpty) {
      _artists = cached;
      notifyListeners();
    }
    if (_offlineMode) {
      _artists = await loadOfflineArtists();
      notifyListeners();
      return;
    }
    await _loadArtists();
  }

  /// Loads genres, using cached results when possible.
  Future<void> loadGenres() async {
    final cached = await _cacheStore.loadGenres();
    if (cached.isNotEmpty) {
      _genres = cached;
      notifyListeners();
    }
    if (_offlineMode) {
      return;
    }
    await _loadGenres();
  }

  /// Loads paginated tracks for the library browse view.
  Future<void> loadLibraryTracks({bool reset = false}) async {
    if (_session == null) {
      return;
    }
    if (_offlineMode) {
      final offlineTracks = await loadOfflineTracks();
      _libraryTracks = offlineTracks;
      _tracksOffset = offlineTracks.length;
      _hasMoreTracks = false;
      _isLoadingTracks = false;
      notifyListeners();
      return;
    }
    if (_isLoadingTracks) {
      await _tracksLoadCompleter?.future;
      return;
    }
    if (!reset && !_hasMoreTracks) {
      return;
    }
    if (reset) {
      _libraryTracks = [];
      _tracksOffset = 0;
      _hasMoreTracks = true;
      notifyListeners();
    }
    _isLoadingTracks = true;
    _tracksLoadCompleter = Completer<void>();
    notifyListeners();
    try {
      final tracks = await _client.fetchLibraryTracks(
        startIndex: _tracksOffset,
        limit: _tracksPageSize,
      );
      if (reset) {
        _libraryTracks = tracks;
      } else {
        _libraryTracks = [..._libraryTracks, ...tracks];
      }
      _tracksOffset += tracks.length;
      if (tracks.length < _tracksPageSize) {
        _hasMoreTracks = false;
      }
    } catch (_) {
      // Ignore load failures; keep whatever tracks we already have.
    } finally {
      _isLoadingTracks = false;
      _tracksLoadCompleter?.complete();
      _tracksLoadCompleter = null;
      notifyListeners();
    }
  }

  /// Returns a random track from the library when available.
  Future<MediaItem?> getRandomTrack() async {
    if (_offlineMode) {
      return _randomFromList(_libraryTracks);
    }
    if (_session == null) {
      return null;
    }
    try {
      final track = await _client.fetchRandomTrack();
      if (track != null) {
        return track;
      }
    } catch (_) {}
    return _randomFromList(
          _featuredTracks.isNotEmpty ? _featuredTracks : _recentTracks,
        ) ??
        _randomFromList(_libraryTracks);
  }

  /// Returns a random album from the library when available.
  Future<Album?> getRandomAlbum() async {
    if (_offlineMode) {
      return _randomFromList(_albums);
    }
    if (_session == null) {
      return null;
    }
    try {
      final album = await _client.fetchRandomAlbum();
      if (album != null) {
        return album;
      }
    } catch (_) {}
    return _randomFromList(_albums.isNotEmpty ? _albums : _favoriteAlbums);
  }

  /// Returns a random artist from the library when available.
  Future<Artist?> getRandomArtist() async {
    if (_offlineMode) {
      return _randomFromList(_artists);
    }
    if (_session == null) {
      return null;
    }
    try {
      final artist = await _client.fetchRandomArtist();
      if (artist != null) {
        return artist;
      }
    } catch (_) {}
    return _randomFromList(_artists.isNotEmpty ? _artists : _favoriteArtists);
  }

  /// Loads the Jump in shelf picks.
  Future<void> loadJumpIn({bool force = false}) async {
    if (_offlineMode) {
      if (_isLoadingJumpIn) {
        return;
      }
      _isLoadingJumpIn = true;
      notifyListeners();
      _jumpInTrack = _randomFromList(_libraryTracks) ?? _jumpInTrack;
      _jumpInAlbum = _randomFromList(_albums) ?? _jumpInAlbum;
      _jumpInArtist = _randomFromList(_artists) ?? _jumpInArtist;
      _lastJumpInRefreshAt = DateTime.now();
      _isLoadingJumpIn = false;
      notifyListeners();
      return;
    }
    if (_session == null) {
      return;
    }
    if (_isLoadingJumpIn) {
      return;
    }
    if (!force &&
        _jumpInTrack != null &&
        _jumpInAlbum != null &&
        _jumpInArtist != null) {
      return;
    }
    _isLoadingJumpIn = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        getRandomTrack(),
        getRandomAlbum(),
        getRandomArtist(),
      ]);
      _jumpInTrack = results[0] as MediaItem? ?? _jumpInTrack;
      _jumpInAlbum = results[1] as Album? ?? _jumpInAlbum;
      _jumpInArtist = results[2] as Artist? ?? _jumpInArtist;
      _lastJumpInRefreshAt = DateTime.now();
    } finally {
      _isLoadingJumpIn = false;
      notifyListeners();
    }
  }

  /// Plays a shuffled copy of the provided tracks.
  Future<void> playShuffledList(List<MediaItem> tracks) async {
    final selection =
        _offlineMode ? _filterPinnedTracks(tracks) : List.of(tracks);
    if (selection.isEmpty) {
      return;
    }
    selection.shuffle(_random);
    await _playFromList(selection, selection.first);
  }

  /// Loads favorite albums.
  Future<void> loadFavoriteAlbums() async {
    final cached = await _cacheStore.loadFavoriteAlbums();
    if (cached.isNotEmpty) {
      _favoriteAlbums = cached;
      notifyListeners();
    }
    if (_offlineMode) {
      final offlineAlbums = await loadOfflineAlbums();
      final offlineIds = offlineAlbums.map((album) => album.id).toSet();
      _favoriteAlbums =
          cached.where((album) => offlineIds.contains(album.id)).toList();
      notifyListeners();
      return;
    }
    await _loadFavoriteAlbums();
  }

  /// Loads favorite artists.
  Future<void> loadFavoriteArtists() async {
    final cached = await _cacheStore.loadFavoriteArtists();
    if (cached.isNotEmpty) {
      _favoriteArtists = cached;
      notifyListeners();
    }
    if (_offlineMode) {
      final offlineArtists = await loadOfflineArtists();
      final offlineIds = offlineArtists.map((artist) => artist.id).toSet();
      _favoriteArtists =
          cached.where((artist) => offlineIds.contains(artist.id)).toList();
      notifyListeners();
      return;
    }
    await _loadFavoriteArtists();
  }

  /// Loads favorite tracks.
  Future<void> loadFavoriteTracks() async {
    final cached = await _cacheStore.loadFavoriteTracks();
    if (cached.isNotEmpty) {
      _favoriteTracks = cached;
      notifyListeners();
    }
    if (_offlineMode) {
      _favoriteTracks = _filterPinnedTracks(cached);
      notifyListeners();
      return;
    }
    await _loadFavoriteTracks();
  }

  Future<void> _loadSmartListTracks(SmartList list) async {
    _isLoadingSmartList = true;
    notifyListeners();
    await _ensureSmartListSourceLoaded();
    final results = _buildSmartListTracks(list);
    _smartListTracks = results;
    _isLoadingSmartList = false;
    notifyListeners();
  }

  Future<void> _ensureSmartListSourceLoaded() async {
    if (_offlineMode) {
      if (_libraryTracks.isEmpty) {
        await loadLibraryTracks();
      }
      return;
    }
    while (_hasMoreTracks) {
      await loadLibraryTracks();
    }
  }

  List<MediaItem> _buildSmartListTracks(SmartList list) {
    if (list.scope != SmartListScope.tracks) {
      return [];
    }
    final source = _libraryTracks;
    final filtered = source
        .where((track) => _matchesSmartListGroup(list.group, track))
        .toList();
    if (list.sorts.isNotEmpty) {
      filtered.sort((a, b) => _compareSmartListSorts(list.sorts, a, b));
    }
    final limit = list.limit;
    if (limit != null && limit > 0 && filtered.length > limit) {
      return filtered.take(limit).toList();
    }
    return filtered;
  }

  int _compareSmartListSorts(
    List<SmartListSort> sorts,
    MediaItem a,
    MediaItem b,
  ) {
    for (final sort in sorts) {
      final comparison = _compareSmartListField(sort.field, a, b);
      if (comparison != 0) {
        return sort.direction == SmartListSortDirection.desc
            ? -comparison
            : comparison;
      }
    }
    return 0;
  }

  int _compareSmartListField(
    SmartListField field,
    MediaItem a,
    MediaItem b,
  ) {
    switch (field) {
      case SmartListField.title:
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case SmartListField.album:
        return a.album.toLowerCase().compareTo(b.album.toLowerCase());
      case SmartListField.artist:
        return a.subtitle.toLowerCase().compareTo(b.subtitle.toLowerCase());
      case SmartListField.genre:
        return _joinGenres(a).compareTo(_joinGenres(b));
      case SmartListField.addedAt:
        return _compareDate(a.addedAt, b.addedAt);
      case SmartListField.playCount:
        return (a.playCount ?? 0).compareTo(b.playCount ?? 0);
      case SmartListField.lastPlayedAt:
        return _compareDate(a.lastPlayedAt, b.lastPlayedAt);
      case SmartListField.duration:
        return a.duration.compareTo(b.duration);
      case SmartListField.isFavorite:
        return _compareBool(isFavoriteTrack(a.id), isFavoriteTrack(b.id));
      case SmartListField.isDownloaded:
        return _compareBool(
          _pinnedAudio.contains(a.streamUrl),
          _pinnedAudio.contains(b.streamUrl),
        );
      case SmartListField.albumIsFavorite:
        return _compareBool(
          a.albumId != null && isFavoriteAlbum(a.albumId!),
          b.albumId != null && isFavoriteAlbum(b.albumId!),
        );
      case SmartListField.artistIsFavorite:
        return _compareBool(
          a.artistIds.any(isFavoriteArtist),
          b.artistIds.any(isFavoriteArtist),
        );
    }
  }

  int _compareBool(bool a, bool b) {
    if (a == b) {
      return 0;
    }
    return a ? 1 : -1;
  }

  int _compareDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return -1;
    }
    if (b == null) {
      return 1;
    }
    return a.compareTo(b);
  }

  bool _matchesSmartListGroup(SmartListGroup group, MediaItem track) {
    if (group.children.isEmpty) {
      switch (group.mode) {
        case SmartListGroupMode.all:
          return true;
        case SmartListGroupMode.any:
          return false;
        case SmartListGroupMode.not:
          return true;
      }
    }
    final matches = group.children.map((child) {
      if (child is SmartListRuleNode) {
        return _matchesSmartListRule(child.rule, track);
      }
      if (child is SmartListGroupNode) {
        return _matchesSmartListGroup(child.group, track);
      }
      return false;
    }).toList();
    switch (group.mode) {
      case SmartListGroupMode.all:
        return matches.every((match) => match);
      case SmartListGroupMode.any:
        return matches.any((match) => match);
      case SmartListGroupMode.not:
        return !matches.any((match) => match);
    }
  }

  bool _matchesSmartListRule(SmartListRule rule, MediaItem track) {
    switch (rule.field.valueType) {
      case SmartListValueType.text:
        final haystack = _valueForTextField(rule.field, track);
        return _evaluateTextRule(rule, haystack);
      case SmartListValueType.number:
        final value = rule.field == SmartListField.playCount
            ? (track.playCount ?? 0).toDouble()
            : 0.0;
        return _evaluateNumberRule(rule, value);
      case SmartListValueType.duration:
        final seconds = track.duration.inSeconds.toDouble();
        return _evaluateNumberRule(rule, seconds, isDuration: true);
      case SmartListValueType.date:
        final date = rule.field == SmartListField.addedAt
            ? track.addedAt
            : track.lastPlayedAt;
        return _evaluateDateRule(rule, date);
      case SmartListValueType.boolean:
        final value = _valueForBoolField(rule.field, track);
        return _evaluateBoolRule(rule, value);
    }
  }

  String _valueForTextField(SmartListField field, MediaItem track) {
    switch (field) {
      case SmartListField.title:
        return track.title;
      case SmartListField.album:
        return track.album;
      case SmartListField.artist:
        return track.subtitle;
      case SmartListField.genre:
        return _joinGenres(track);
      default:
        return '';
    }
  }

  bool _valueForBoolField(SmartListField field, MediaItem track) {
    switch (field) {
      case SmartListField.isFavorite:
        return isFavoriteTrack(track.id);
      case SmartListField.isDownloaded:
        return _pinnedAudio.contains(track.streamUrl);
      case SmartListField.albumIsFavorite:
        return track.albumId != null && isFavoriteAlbum(track.albumId!);
      case SmartListField.artistIsFavorite:
        return track.artistIds.any(isFavoriteArtist);
      default:
        return false;
    }
  }

  String _joinGenres(MediaItem track) {
    return track.genres.map((genre) => genre.toLowerCase()).join(', ');
  }

  bool _evaluateTextRule(SmartListRule rule, String rawValue) {
    final value = rawValue.toLowerCase();
    final needle = rule.value.toLowerCase().trim();
    switch (rule.operatorType) {
      case SmartListOperator.contains:
        return needle.isNotEmpty && value.contains(needle);
      case SmartListOperator.doesNotContain:
        return needle.isNotEmpty ? !value.contains(needle) : true;
      case SmartListOperator.equals:
        return needle.isNotEmpty && value == needle;
      case SmartListOperator.notEquals:
        return needle.isNotEmpty ? value != needle : true;
      case SmartListOperator.startsWith:
        return needle.isNotEmpty && value.startsWith(needle);
      case SmartListOperator.endsWith:
        return needle.isNotEmpty && value.endsWith(needle);
      default:
        return false;
    }
  }

  bool _evaluateNumberRule(
    SmartListRule rule,
    double actualValue, {
    bool isDuration = false,
  }) {
    final value = _parseNumber(rule.value, isDuration: isDuration);
    final value2 = _parseNumber(rule.value2, isDuration: isDuration);
    if (value == null) {
      return false;
    }
    switch (rule.operatorType) {
      case SmartListOperator.equals:
        return actualValue == value;
      case SmartListOperator.notEquals:
        return actualValue != value;
      case SmartListOperator.greaterThan:
        return actualValue > value;
      case SmartListOperator.greaterThanOrEqual:
        return actualValue >= value;
      case SmartListOperator.lessThan:
        return actualValue < value;
      case SmartListOperator.lessThanOrEqual:
        return actualValue <= value;
      case SmartListOperator.between:
        if (value2 == null) {
          return false;
        }
        final min = value < value2 ? value : value2;
        final max = value > value2 ? value : value2;
        return actualValue >= min && actualValue <= max;
      default:
        return false;
    }
  }

  bool _evaluateDateRule(SmartListRule rule, DateTime? actual) {
    if (actual == null) {
      if (rule.operatorType == SmartListOperator.notInLast) {
        return true;
      }
      return false;
    }
    switch (rule.operatorType) {
      case SmartListOperator.isBefore:
        final target = _parseDate(rule.value);
        return target != null && actual.isBefore(target);
      case SmartListOperator.isAfter:
        final target = _parseDate(rule.value);
        return target != null && actual.isAfter(target);
      case SmartListOperator.isOn:
        final target = _parseDate(rule.value);
        if (target == null) {
          return false;
        }
        return _isSameDate(actual, target);
      case SmartListOperator.inLast:
        final delta = _parseRelativeDuration(rule.value);
        if (delta == null) {
          return false;
        }
        return actual.isAfter(DateTime.now().subtract(delta));
      case SmartListOperator.notInLast:
        final delta = _parseRelativeDuration(rule.value);
        if (delta == null) {
          return false;
        }
        return actual.isBefore(DateTime.now().subtract(delta));
      default:
        return false;
    }
  }

  bool _evaluateBoolRule(SmartListRule rule, bool actual) {
    switch (rule.operatorType) {
      case SmartListOperator.isTrue:
        return actual;
      case SmartListOperator.isFalse:
        return !actual;
      default:
        return false;
    }
  }

  double? _parseNumber(String? input, {bool isDuration = false}) {
    if (input == null) {
      return null;
    }
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (isDuration) {
      final duration = _parseDuration(trimmed);
      if (duration != null) {
        return duration.inSeconds.toDouble();
      }
    }
    return double.tryParse(trimmed);
  }

  Duration? _parseDuration(String input) {
    if (input.contains(':')) {
      final parts = input.split(':').map((part) => part.trim()).toList();
      if (parts.any((part) => part.isEmpty)) {
        return null;
      }
      final numbers = parts.map(int.tryParse).toList();
      if (numbers.any((value) => value == null)) {
        return null;
      }
      if (numbers.length == 2) {
        return Duration(
          minutes: numbers[0]!,
          seconds: numbers[1]!,
        );
      }
      if (numbers.length == 3) {
        return Duration(
          hours: numbers[0]!,
          minutes: numbers[1]!,
          seconds: numbers[2]!,
        );
      }
    }
    final seconds = int.tryParse(input);
    if (seconds == null) {
      return null;
    }
    return Duration(seconds: seconds);
  }

  DateTime? _parseDate(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return DateTime.tryParse(trimmed);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Duration? _parseRelativeDuration(String input) {
    final trimmed = input.trim().toLowerCase();
    final match = RegExp(r'^(\d+)([dwmy])$').firstMatch(trimmed);
    if (match == null) {
      return null;
    }
    final amount = int.tryParse(match.group(1) ?? '');
    final unit = match.group(2);
    if (amount == null || amount <= 0 || unit == null) {
      return null;
    }
    switch (unit) {
      case 'd':
        return Duration(days: amount);
      case 'w':
        return Duration(days: amount * 7);
      case 'm':
        return Duration(days: amount * 30);
      case 'y':
        return Duration(days: amount * 365);
      default:
        return null;
    }
  }

  /// Selects an album and loads its tracks.
  Future<void> selectAlbum(Album album, {bool offlineOnly = false}) async {
    _selectedAlbum = album;
    _selectedSmartList = null;
    _selectedArtist = null;
    _selectedGenre = null;
    _offlineOnlyFilter = offlineOnly;
    clearSearch(notify: false);
    notifyListeners();
    final cached = await _cacheStore.loadAlbumTracks(album.id);
    if (cached.isNotEmpty) {
      _albumTracks = cached;
      notifyListeners();
    }
    if (_offlineMode) {
      final filtered = _filterPinnedTracks(_albumTracks);
      _albumTracks =
          filtered.isNotEmpty ? filtered : await _offlineTracksForAlbum(album);
      notifyListeners();
      return;
    }
    try {
      final tracks = await _client.fetchAlbumTracks(album.id);
      _albumTracks = tracks;
      await _cacheStore.saveAlbumTracks(album.id, tracks);
      notifyListeners();
    } catch (_) {
      // Keep cached tracks if refresh fails.
    }
  }

  /// Loads an album and starts playback.
  Future<void> playAlbum(Album album) async {
    await selectAlbum(album);
    final tracks =
        _offlineMode ? _filterPinnedTracks(_albumTracks) : _albumTracks;
    if (tracks.isNotEmpty) {
      await _playFromList(tracks, tracks.first);
    }
  }

  /// Selects an artist and loads their tracks.
  Future<void> selectArtist(Artist artist, {bool offlineOnly = false}) async {
    _selectedArtist = artist;
    _selectedSmartList = null;
    _selectedAlbum = null;
    _selectedGenre = null;
    _offlineOnlyFilter = offlineOnly;
    clearSearch(notify: false);
    notifyListeners();
    final cached = await _cacheStore.loadArtistTracks(artist.id);
    if (cached.isNotEmpty) {
      _artistTracks = cached;
      notifyListeners();
    }
    if (_offlineMode) {
      final filtered = _filterPinnedTracks(_artistTracks);
      _artistTracks = filtered.isNotEmpty
          ? filtered
          : await _offlineTracksForArtist(artist);
      notifyListeners();
      return;
    }
    try {
      final tracks = await _client.fetchArtistTracks(artist.id);
      _artistTracks = tracks;
      await _cacheStore.saveArtistTracks(artist.id, tracks);
      notifyListeners();
    } catch (_) {
      // Keep cached tracks if refresh fails.
    }
  }

  /// Loads an artist and starts playback.
  Future<void> playArtist(Artist artist) async {
    await selectArtist(artist);
    final tracks =
        _offlineMode ? _filterPinnedTracks(_artistTracks) : _artistTracks;
    if (tracks.isNotEmpty) {
      await _playFromList(tracks, tracks.first);
    }
  }

  /// Selects a genre and loads its tracks.
  Future<void> selectGenre(Genre genre) async {
    _selectedGenre = genre;
    _selectedSmartList = null;
    _selectedAlbum = null;
    _selectedArtist = null;
    clearSearch(notify: false);
    notifyListeners();
    final cached = await _cacheStore.loadGenreTracks(genre.id);
    if (cached.isNotEmpty) {
      _genreTracks = cached;
      notifyListeners();
    }
    if (_offlineMode) {
      return;
    }
    try {
      final tracks = await _client.fetchGenreTracks(genre.id);
      _genreTracks = tracks;
      await _cacheStore.saveGenreTracks(genre.id, tracks);
      notifyListeners();
    } catch (_) {
      // Keep cached tracks if refresh fails.
    }
  }

  /// Loads a genre and starts playback.
  Future<void> playGenre(Genre genre) async {
    await selectGenre(genre);
    final tracks =
        _offlineMode ? _filterPinnedTracks(_genreTracks) : _genreTracks;
    if (tracks.isNotEmpty) {
      await _playFromList(tracks, tracks.first);
    }
  }

  /// Starts playback from a selected track.
  Future<void> playFromPlaylist(MediaItem track) async {
    await playFromList(_playlistTracks, track);
  }

  /// Plays tracks from the selected album.
  Future<void> playFromAlbum(MediaItem track) async {
    await playFromList(_albumTracks, track);
  }

  /// Plays tracks from the selected artist.
  Future<void> playFromArtist(MediaItem track) async {
    await playFromList(_artistTracks, track);
  }

  /// Plays tracks from the selected genre.
  Future<void> playFromGenre(MediaItem track) async {
    await playFromList(_genreTracks, track);
  }

  /// Plays tracks from favorites.
  Future<void> playFromFavorites(MediaItem track) async {
    await playFromList(_favoriteTracks, track);
  }

  /// Plays tracks from search results.
  Future<void> playFromSearch(MediaItem track) async {
    final tracks = _searchResults?.tracks ?? const <MediaItem>[];
    await playFromList(tracks, track);
  }

  /// Plays tracks from a provided list.
  Future<void> playFromList(List<MediaItem> tracks, MediaItem track) async {
    if (_offlineMode) {
      final filtered = _filterPinnedTracks(tracks);
      if (filtered.isEmpty) {
        return;
      }
      final match = filtered.firstWhere(
        (item) => item.id == track.id,
        orElse: () => filtered.first,
      );
      await _playFromList(filtered, match);
      return;
    }
    await _playFromList(tracks, track);
  }

  /// Plays featured tracks from the home shelf.
  Future<void> playFeatured(MediaItem track) async {
    await playFromList(_featuredTracks, track);
  }

  /// Toggles between play and pause states.
  Future<void> togglePlayback() async {
    if (_playback.isPlaying) {
      await _performPlaybackAction(
        () => _playback.pause(),
        'pause',
      );
    } else {
      _startPlaybackPolling();
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
      await _performPlaybackAction(
        () => _playback.seek(Duration.zero),
        'restart',
      );
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

  /// Adds a track to the end of the queue.
  Future<void> enqueueTrack(MediaItem track) async {
    if (_offlineMode && !_pinnedAudio.contains(track.streamUrl)) {
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
    if (_offlineMode && !_pinnedAudio.contains(track.streamUrl)) {
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
      _nowPlaying = null;
      unawaited(_maybeUpdateNowPlayingPalette(null));
      _position = Duration.zero;
      _duration = Duration.zero;
      _positionNotifier.value = _position;
      _durationNotifier.value = _duration;
      _isPlaying = false;
      _isBuffering = false;
      _isNowPlayingCached = false;
      _isPreparingPlayback = false;
      _isPlayingNotifier.value = _isPlaying;
      _isBufferingNotifier.value = _isBuffering;
      _lastNowPlayingUpdateAt = null;
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
    await _performPlaybackAction(
      () => _playback.seek(position),
      'seek',
    );
  }

  /// Updates the theme preference.
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _settingsStore.saveThemeMode(mode);
    notifyListeners();
  }

  /// Updates playback telemetry preference.
  Future<void> setTelemetryPlayback(bool enabled) async {
    _telemetryPlayback = enabled;
    await _settingsStore.savePlaybackTelemetry(enabled);
    notifyListeners();
  }

  /// Updates playback progress telemetry preference.
  Future<void> setTelemetryProgress(bool enabled) async {
    _telemetryProgress = enabled;
    await _settingsStore.saveProgressTelemetry(enabled);
    notifyListeners();
  }

  /// Updates playback history telemetry preference.
  Future<void> setTelemetryHistory(bool enabled) async {
    _telemetryHistory = enabled;
    await _settingsStore.saveHistoryTelemetry(enabled);
    notifyListeners();
  }

  /// Updates the gapless playback preference.
  Future<void> setGaplessPlayback(bool enabled) async {
    if (_gaplessPlayback == enabled) {
      return;
    }
    _gaplessPlayback = enabled;
    await _settingsStore.saveGaplessPlayback(enabled);
    await _applyPlaybackSettings();
    notifyListeners();
  }

  /// Updates whether downloads are limited to Wi-Fi.
  Future<void> setDownloadsWifiOnly(bool enabled) async {
    _downloadsWifiOnly = enabled;
    await _settingsStore.saveDownloadsWifiOnly(enabled);
    notifyListeners();
    unawaited(_processDownloadQueue());
  }

  /// Updates whether downloads are paused.
  Future<void> setDownloadsPaused(bool paused) async {
    _downloadsPaused = paused;
    await _settingsStore.saveDownloadsPaused(paused);
    notifyListeners();
    if (!paused) {
      unawaited(_processDownloadQueue());
    }
  }

  /// Updates auto-download preference for favorites.
  Future<void> setAutoDownloadFavoritesEnabled(bool enabled) async {
    _autoDownloadFavoritesEnabled = enabled;
    await _settingsStore.saveAutoDownloadFavoritesEnabled(enabled);
    notifyListeners();
    if (enabled) {
      unawaited(_prefetchFavoriteDownloads());
    }
  }

  /// Updates auto-download preference for favorited albums.
  Future<void> setAutoDownloadFavoriteAlbums(bool enabled) async {
    _autoDownloadFavoriteAlbums = enabled;
    await _settingsStore.saveAutoDownloadFavoriteAlbums(enabled);
    notifyListeners();
    if (enabled && _autoDownloadFavoritesEnabled) {
      unawaited(_prefetchFavoriteDownloads(albumsOnly: true));
    }
  }

  /// Updates auto-download preference for favorited artists.
  Future<void> setAutoDownloadFavoriteArtists(bool enabled) async {
    _autoDownloadFavoriteArtists = enabled;
    await _settingsStore.saveAutoDownloadFavoriteArtists(enabled);
    notifyListeners();
    if (enabled && _autoDownloadFavoritesEnabled) {
      unawaited(_prefetchFavoriteDownloads(artistsOnly: true));
    }
  }

  /// Updates auto-download preference for favorited tracks.
  Future<void> setAutoDownloadFavoriteTracks(bool enabled) async {
    _autoDownloadFavoriteTracks = enabled;
    await _settingsStore.saveAutoDownloadFavoriteTracks(enabled);
    notifyListeners();
    if (enabled && _autoDownloadFavoritesEnabled) {
      unawaited(_prefetchFavoriteDownloads(tracksOnly: true));
    }
  }

  /// Updates Wi-Fi only auto-download preference.
  Future<void> setAutoDownloadFavoritesWifiOnly(bool enabled) async {
    _autoDownloadFavoritesWifiOnly = enabled;
    await _settingsStore.saveAutoDownloadFavoritesWifiOnly(enabled);
    notifyListeners();
    if (enabled && _autoDownloadFavoritesEnabled) {
      unawaited(_prefetchFavoriteDownloads());
    }
  }

  /// Updates the ordering of pending downloads.
  void reorderDownloadQueue(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) {
      return;
    }
    if (oldIndex < 0 || oldIndex >= _downloadQueue.length) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final task = _downloadQueue.removeAt(oldIndex);
    final target = newIndex.clamp(0, _downloadQueue.length);
    _downloadQueue.insert(target, task);
    notifyListeners();
  }

  /// Retries a failed download.
  void retryDownload(DownloadTask task) {
    final index = _indexOfDownload(task.track.streamUrl);
    if (index == null) {
      return;
    }
    _downloadQueue[index] = _downloadQueue[index].copyWith(
      status: DownloadStatus.queued,
      progress: null,
      totalBytes: null,
      downloadedBytes: null,
      errorMessage: null,
    );
    notifyListeners();
    unawaited(_processDownloadQueue());
  }

  /// Updates the offline mode preference.
  Future<void> setOfflineMode(bool enabled) async {
    if (_offlineMode == enabled) {
      return;
    }
    _offlineMode = enabled;
    await _settingsStore.saveOfflineMode(enabled);
    if (enabled) {
      await _applyOfflineModeData();
      return;
    }
    _offlineOnlyFilter = false;
    notifyListeners();
    if (_session != null) {
      unawaited(refreshLibrary());
    }
    unawaited(_processDownloadQueue());
  }

  /// Updates the offline-only filter for detail views.
  void setOfflineOnlyFilter(bool enabled) {
    final next = _offlineMode ? true : enabled;
    if (_offlineOnlyFilter == next) {
      return;
    }
    _offlineOnlyFilter = next;
    notifyListeners();
  }

  /// Updates the font family preference.
  Future<void> setFontFamily(String? family) async {
    _fontFamily = family;
    await _settingsStore.saveFontFamily(family);
    notifyListeners();
  }

  /// Updates the font scale preference.
  Future<void> setFontScale(double scale) async {
    _fontScale = scale;
    await _settingsStore.saveFontScale(scale);
    notifyListeners();
  }

  /// Updates the accent color preference.
  Future<void> setAccentColor(Color color) async {
    _accentColorValue = color.toARGB32();
    await _settingsStore.saveAccentColorValue(color.toARGB32());
    notifyListeners();
  }

  /// Updates the accent color source preference.
  Future<void> setAccentColorSource(AccentColorSource source) async {
    _accentColorSource = source;
    await _settingsStore.saveAccentColorSource(source);
    notifyListeners();
    if (source == AccentColorSource.nowPlaying) {
      unawaited(_maybeUpdateNowPlayingPalette(_nowPlaying));
    }
  }

  /// Updates the theme palette source preference.
  Future<void> setThemePaletteSource(ThemePaletteSource source) async {
    _themePaletteSource = source;
    await _settingsStore.saveThemePaletteSource(source);
    notifyListeners();
    if (source == ThemePaletteSource.nowPlaying) {
      unawaited(_maybeUpdateNowPlayingPalette(_nowPlaying));
    }
  }

  /// Updates the settings shortcut enabled preference.
  Future<void> setSettingsShortcutEnabled(bool enabled) async {
    _settingsShortcutEnabled = enabled;
    await _settingsStore.saveSettingsShortcutEnabled(enabled);
    notifyListeners();
  }

  /// Updates the settings shortcut preference.
  Future<void> setSettingsShortcut(KeyboardShortcut shortcut) async {
    _settingsShortcut = shortcut;
    await _settingsStore.saveSettingsShortcut(shortcut);
    notifyListeners();
  }

  /// Updates the search shortcut enabled preference.
  Future<void> setSearchShortcutEnabled(bool enabled) async {
    _searchShortcutEnabled = enabled;
    await _settingsStore.saveSearchShortcutEnabled(enabled);
    notifyListeners();
  }

  /// Updates the search shortcut preference.
  Future<void> setSearchShortcut(KeyboardShortcut shortcut) async {
    _searchShortcut = shortcut;
    await _settingsStore.saveSearchShortcut(shortcut);
    notifyListeners();
  }

  /// Updates the layout density preference.
  Future<void> setLayoutDensity(LayoutDensity density) async {
    _layoutDensity = density;
    await _settingsStore.saveLayoutDensity(density);
    notifyListeners();
  }

  /// Updates the now playing layout preference.
  Future<void> setNowPlayingLayout(NowPlayingLayout layout) async {
    _nowPlayingLayout = layout;
    await _settingsStore.saveNowPlayingLayout(layout);
    notifyListeners();
  }

  /// Updates the sidebar width preference.
  Future<void> setSidebarWidth(
    double width, {
    bool persist = true,
  }) async {
    _sidebarWidth = width;
    if (persist) {
      await _settingsStore.saveSidebarWidth(width);
    }
    notifyListeners();
  }

  /// Updates the sidebar collapsed preference.
  Future<void> setSidebarCollapsed(
    bool collapsed, {
    bool persist = true,
  }) async {
    _sidebarCollapsed = collapsed;
    if (persist) {
      await _settingsStore.saveSidebarCollapsed(collapsed);
    }
    notifyListeners();
  }

  /// Clears cached metadata entries.
  Future<void> clearMetadataCache() async {
    await _cacheStore.clearMetadata();
    await refreshLibrary();
  }

  /// Clears cached audio files.
  Future<void> clearAudioCache() async {
    await _cacheStore.clearAudioCache();
    await refreshMediaCacheBytes();
  }

  /// Returns the estimated cached media size in bytes.
  Future<int> getMediaCacheBytes() async {
    return _cacheStore.getMediaCacheBytes();
  }

  /// Refreshes cached media size counters.
  Future<void> refreshMediaCacheBytes() async {
    final totalBytes = await _cacheStore.getMediaCacheBytes();
    _mediaCacheBytesNotifier.value = totalBytes;
    final pinnedBytes = await _cacheStore.getPinnedMediaBytes(_pinnedAudio);
    _pinnedCacheBytesNotifier.value = pinnedBytes;
  }

  /// Returns the estimated size of pinned downloads.
  Future<int> getPinnedCacheBytes() async {
    return _cacheStore.getPinnedMediaBytes(_pinnedAudio);
  }

  /// Updates the cache size limit.
  Future<void> setCacheMaxBytes(int bytes) async {
    _cacheMaxBytes = bytes;
    await _cacheStore.saveCacheMaxBytes(bytes);
    await refreshMediaCacheBytes();
    notifyListeners();
  }

  /// Returns cached audio entries for display.
  Future<List<CachedAudioEntry>> getCachedAudioEntries() async {
    return _cacheStore.loadCachedAudioEntries();
  }

  /// Opens the cached media location in the OS file manager.
  Future<void> showMediaCacheLocation() async {
    await _cacheStore.openMediaCacheLocation();
  }

  /// Removes a cached audio entry and its file.
  Future<void> evictCachedAudio(String streamUrl) async {
    await _cacheStore.evictCachedAudio(streamUrl);
    await refreshMediaCacheBytes();
  }

  Future<bool> _canDownloadOverNetwork({bool requireWifi = false}) async {
    if (_offlineMode) {
      return false;
    }
    final needsWifi = _downloadsWifiOnly || requireWifi;
    if (!needsWifi) {
      return true;
    }
    if (kIsWeb) {
      return true;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        try {
          final statuses = await Connectivity().checkConnectivity();
          return statuses.any(_networkConnectivityWhitelist.contains);
        } catch (_) {
          return false;
        }
      case TargetPlatform.fuchsia:
        return true;
    }
  }

  Future<void> _prefetchFavoriteDownloads({
    bool albumsOnly = false,
    bool artistsOnly = false,
    bool tracksOnly = false,
  }) async {
    if (!_autoDownloadFavoritesEnabled) {
      return;
    }
    final shouldAlbums =
        _autoDownloadFavoriteAlbums && !artistsOnly && !tracksOnly;
    final shouldArtists =
        _autoDownloadFavoriteArtists && !albumsOnly && !tracksOnly;
    final shouldTracks =
        _autoDownloadFavoriteTracks && !albumsOnly && !artistsOnly;
    if (shouldAlbums) {
      for (final album in _favoriteAlbums) {
        await makeAlbumAvailableOffline(
          album,
          requiresWifi: _autoDownloadFavoritesWifiOnly,
        );
      }
    }
    if (shouldArtists) {
      for (final artist in _favoriteArtists) {
        await makeArtistAvailableOffline(
          artist,
          requiresWifi: _autoDownloadFavoritesWifiOnly,
        );
      }
    }
    if (shouldTracks) {
      for (final track in _favoriteTracks) {
        await makeTrackAvailableOffline(
          track,
          requiresWifi: _autoDownloadFavoritesWifiOnly,
        );
      }
    }
  }

  int? _indexOfDownload(String streamUrl) {
    final index = _downloadQueue.indexWhere(
      (task) => task.track.streamUrl == streamUrl,
    );
    return index == -1 ? null : index;
  }

  Future<void> _queueDownload(
    MediaItem track, {
    bool requiresWifi = false,
  }) async {
    final normalized = _normalizeTrackForPlayback(track);
    if (_downloadQueue.any(
      (task) => task.track.streamUrl == normalized.streamUrl,
    )) {
      return;
    }
    final cached = await _cacheStore.isAudioCached(normalized);
    if (cached) {
      await _cacheStore.touchCachedAudio(normalized);
      return;
    }
    _downloadQueue.add(
      DownloadTask(
        track: normalized,
        status: DownloadStatus.queued,
        queuedAt: DateTime.now(),
        requiresWifi: requiresWifi,
      ),
    );
    notifyListeners();
    unawaited(_processDownloadQueue());
  }

  void _resetWaitingDownloads() {
    var updated = false;
    for (var i = 0; i < _downloadQueue.length; i += 1) {
      final task = _downloadQueue[i];
      if (task.status == DownloadStatus.waitingForWifi) {
        _downloadQueue[i] = task.copyWith(status: DownloadStatus.queued);
        updated = true;
      }
    }
    if (updated) {
      notifyListeners();
    }
  }

  void _updateDownloadTask(
    String streamUrl, {
    DownloadStatus? status,
    double? progress,
    int? totalBytes,
    int? downloadedBytes,
    String? errorMessage,
  }) {
    final index = _indexOfDownload(streamUrl);
    if (index == null) {
      return;
    }
    final existing = _downloadQueue[index];
    if (progress != null &&
        _shouldThrottleProgress(
          streamUrl,
          progress,
          existing.progress,
        )) {
      return;
    }
    _downloadQueue[index] = existing.copyWith(
      status: status,
      progress: progress,
      totalBytes: totalBytes,
      downloadedBytes: downloadedBytes,
      errorMessage: errorMessage,
    );
    notifyListeners();
  }

  bool _shouldThrottleProgress(
    String streamUrl,
    double newProgress,
    double? currentProgress,
  ) {
    final now = DateTime.now();
    final last = _downloadProgressTimestamps[streamUrl];
    final pivot = currentProgress ?? 0.0;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 250) &&
        (newProgress - pivot).abs() < 0.01) {
      return true;
    }
    _downloadProgressTimestamps[streamUrl] = now;
    return false;
  }

  void _removeDownload(String streamUrl) {
    final index = _indexOfDownload(streamUrl);
    if (index == null) {
      return;
    }
    _downloadQueue.removeAt(index);
    _downloadProgressTimestamps.remove(streamUrl);
    notifyListeners();
  }

  Future<void> _processDownloadQueue() async {
    if (_isProcessingDownloads) {
      return;
    }
    if (_downloadsPaused) {
      return;
    }
    _isProcessingDownloads = true;
    try {
      _resetWaitingDownloads();
      while (true) {
        if (_downloadsPaused) {
          break;
        }
        DownloadTask? next;
        for (final task in _downloadQueue) {
          if (task.status == DownloadStatus.queued) {
            final canDownload = await _canDownloadOverNetwork(
              requireWifi: task.requiresWifi,
            );
            if (canDownload) {
              next = task;
              break;
            }
            _updateDownloadTask(
              task.track.streamUrl,
              status: DownloadStatus.waitingForWifi,
            );
          }
        }
        if (next == null) {
          break;
        }
        await _downloadTrack(next);
      }
    } finally {
      _isProcessingDownloads = false;
    }
  }

  Future<void> _downloadTrack(DownloadTask task) async {
    final streamUrl = task.track.streamUrl;
    _updateDownloadTask(streamUrl, status: DownloadStatus.downloading);
    try {
      await for (final response in _cacheStore.downloadAudioWithProgress(
        task.track,
        headers: _playbackHeaders(),
      )) {
        if (response is DownloadProgress) {
          _updateDownloadTask(
            streamUrl,
            progress: response.progress,
            totalBytes: response.totalSize,
            downloadedBytes: response.downloaded,
          );
        } else if (response is FileInfo) {
          _removeDownload(streamUrl);
          unawaited(refreshMediaCacheBytes());
        }
      }
    } catch (error) {
      _updateDownloadTask(
        streamUrl,
        status: DownloadStatus.failed,
        errorMessage: error.toString(),
      );
    }
  }

  /// Pins a track for offline playback.
  Future<void> makeTrackAvailableOffline(
    MediaItem track, {
    bool requiresWifi = false,
  }) async {
    await _cacheStore.setPinnedAudio(track.streamUrl, true);
    _pinnedAudio.add(track.streamUrl);
    await _queueDownload(track, requiresWifi: requiresWifi);
    if (_selectedSmartList != null) {
      unawaited(_loadSmartListTracks(_selectedSmartList!));
    }
    unawaited(refreshMediaCacheBytes());
    notifyListeners();
  }

  /// Removes a track from offline pinning.
  Future<void> unpinTrackOffline(MediaItem track) async {
    await _cacheStore.setPinnedAudio(track.streamUrl, false);
    _pinnedAudio.remove(track.streamUrl);
    _removeDownload(track.streamUrl);
    if (_selectedSmartList != null) {
      unawaited(_loadSmartListTracks(_selectedSmartList!));
    }
    unawaited(refreshMediaCacheBytes());
    notifyListeners();
  }

  Future<List<MediaItem>> _loadAlbumTracksForOffline(Album album) async {
    final cached = await _cacheStore.loadAlbumTracks(album.id);
    if (cached.isNotEmpty) {
      return cached;
    }
    if (_offlineMode) {
      return [];
    }
    try {
      final tracks = await _client.fetchAlbumTracks(album.id);
      await _cacheStore.saveAlbumTracks(album.id, tracks);
      return tracks;
    } catch (_) {
      return [];
    }
  }

  Future<List<MediaItem>> _loadArtistTracksForOffline(Artist artist) async {
    final cached = await _cacheStore.loadArtistTracks(artist.id);
    if (cached.isNotEmpty) {
      return cached;
    }
    if (_offlineMode) {
      return [];
    }
    try {
      final tracks = await _client.fetchArtistTracks(artist.id);
      await _cacheStore.saveArtistTracks(artist.id, tracks);
      return tracks;
    } catch (_) {
      return [];
    }
  }

  /// Pins all tracks in an album for offline playback.
  Future<void> makeAlbumAvailableOffline(
    Album album, {
    bool requiresWifi = false,
  }) async {
    final tracks = await _loadAlbumTracksForOffline(album);
    for (final track in tracks) {
      await _cacheStore.setPinnedAudio(track.streamUrl, true);
      _pinnedAudio.add(track.streamUrl);
      await _queueDownload(track, requiresWifi: requiresWifi);
    }
    if (_selectedSmartList != null) {
      unawaited(_loadSmartListTracks(_selectedSmartList!));
    }
    unawaited(refreshMediaCacheBytes());
    notifyListeners();
  }

  /// Removes an album from offline pinning.
  Future<void> unpinAlbumOffline(Album album) async {
    final tracks = await _loadAlbumTracksForOffline(album);
    for (final track in tracks) {
      await _cacheStore.setPinnedAudio(track.streamUrl, false);
      _pinnedAudio.remove(track.streamUrl);
      _removeDownload(track.streamUrl);
    }
    if (_selectedSmartList != null) {
      unawaited(_loadSmartListTracks(_selectedSmartList!));
    }
    unawaited(refreshMediaCacheBytes());
    notifyListeners();
  }

  /// Pins all tracks for an artist for offline playback.
  Future<void> makeArtistAvailableOffline(
    Artist artist, {
    bool requiresWifi = false,
  }) async {
    final tracks = await _loadArtistTracksForOffline(artist);
    for (final track in tracks) {
      await _cacheStore.setPinnedAudio(track.streamUrl, true);
      _pinnedAudio.add(track.streamUrl);
      await _queueDownload(track, requiresWifi: requiresWifi);
    }
    if (_selectedSmartList != null) {
      unawaited(_loadSmartListTracks(_selectedSmartList!));
    }
    unawaited(refreshMediaCacheBytes());
    notifyListeners();
  }

  /// Removes an artist from offline pinning.
  Future<void> unpinArtistOffline(Artist artist) async {
    final tracks = await _loadArtistTracksForOffline(artist);
    for (final track in tracks) {
      await _cacheStore.setPinnedAudio(track.streamUrl, false);
      _pinnedAudio.remove(track.streamUrl);
      _removeDownload(track.streamUrl);
    }
    if (_selectedSmartList != null) {
      unawaited(_loadSmartListTracks(_selectedSmartList!));
    }
    unawaited(refreshMediaCacheBytes());
    notifyListeners();
  }

  /// Returns whether a track is pinned for offline playback.
  Future<bool> isTrackPinned(MediaItem track) async {
    if (_pinnedAudio.isNotEmpty) {
      return _pinnedAudio.contains(track.streamUrl);
    }
    return _cacheStore.isPinnedAudio(track.streamUrl);
  }

  /// Returns whether any tracks in an album are pinned for offline playback.
  Future<bool> isAlbumPinned(Album album) async {
    if (_pinnedAudio.isEmpty) {
      return false;
    }
    final tracks = await _cacheStore.loadAlbumTracks(album.id);
    if (tracks.isNotEmpty) {
      return tracks.any((track) => _pinnedAudio.contains(track.streamUrl));
    }
    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    final albumName = album.name.trim().toLowerCase();
    return cachedEntries.any(
      (entry) =>
          _pinnedAudio.contains(entry.streamUrl) &&
          entry.album.trim().toLowerCase() == albumName,
    );
  }

  /// Returns whether any tracks for an artist are pinned for offline playback.
  Future<bool> isArtistPinned(Artist artist) async {
    if (_pinnedAudio.isEmpty) {
      return false;
    }
    final tracks = await _cacheStore.loadArtistTracks(artist.id);
    if (tracks.isNotEmpty) {
      return tracks.any((track) => _pinnedAudio.contains(track.streamUrl));
    }
    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    final artistName = artist.name.trim().toLowerCase();
    return cachedEntries.any(
      (entry) =>
          _pinnedAudio.contains(entry.streamUrl) &&
          entry.artists.any(
            (name) => name.trim().toLowerCase() == artistName,
          ),
    );
  }

  /// Returns offline-ready albums based on pinned tracks.
  Future<List<Album>> loadOfflineAlbums() async {
    if (_pinnedAudio.isEmpty) {
      return [];
    }
    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    final pinnedAlbums = cachedEntries
        .where((entry) => _pinnedAudio.contains(entry.streamUrl))
        .map((entry) => entry.album.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    if (pinnedAlbums.isEmpty) {
      return [];
    }
    final albums = await _cacheStore.loadAlbums();
    final offline = albums
        .where(
          (album) => pinnedAlbums.contains(album.name.trim().toLowerCase()),
        )
        .toList();
    offline.sort((a, b) => a.name.compareTo(b.name));
    return offline;
  }

  /// Returns offline-ready artists based on pinned tracks.
  Future<List<Artist>> loadOfflineArtists() async {
    if (_pinnedAudio.isEmpty) {
      return [];
    }
    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    final pinnedArtists = <String>{};
    for (final entry in cachedEntries) {
      if (!_pinnedAudio.contains(entry.streamUrl)) {
        continue;
      }
      for (final artist in entry.artists) {
        final normalized = artist.trim().toLowerCase();
        if (normalized.isNotEmpty) {
          pinnedArtists.add(normalized);
        }
      }
    }
    if (pinnedArtists.isEmpty) {
      return [];
    }
    final artists = await _cacheStore.loadArtists();
    final offline = artists
        .where((artist) =>
            pinnedArtists.contains(artist.name.trim().toLowerCase()))
        .toList();
    offline.sort((a, b) => a.name.compareTo(b.name));
    return offline;
  }

  /// Returns offline-ready playlists based on pinned tracks.
  Future<List<Playlist>> loadOfflinePlaylists() async {
    if (_pinnedAudio.isEmpty) {
      return [];
    }
    final playlists = await _cacheStore.loadPlaylists();
    final offline = <Playlist>[];
    for (final playlist in playlists) {
      final tracks = await _cacheStore.loadPlaylistTracks(playlist.id);
      if (tracks.any((track) => _pinnedAudio.contains(track.streamUrl))) {
        offline.add(playlist);
      }
    }
    offline.sort((a, b) => a.name.compareTo(b.name));
    return offline;
  }

  /// Returns offline-ready tracks based on pinned audio.
  Future<List<MediaItem>> loadOfflineTracks() async {
    if (_pinnedAudio.isEmpty) {
      return [];
    }
    final cached = await _cacheStore.loadCachedAudioEntries();
    final offline = cached
        .where((entry) => _pinnedAudio.contains(entry.streamUrl))
        .map(_mediaItemFromCachedEntry)
        .toList();
    return offline;
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

  MediaItem _mediaItemFromCachedEntry(CachedAudioEntry entry) {
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
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _currentIndexSubscription?.cancel();
    _playbackPollTimer?.cancel();
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    _isPlayingNotifier.dispose();
    _isBufferingNotifier.dispose();
    _mediaCacheBytesNotifier.dispose();
    _pinnedCacheBytesNotifier.dispose();
    unawaited(_playback.dispose());
    super.dispose();
  }

  Future<void> _loadCachedLibrary() async {
    _playlists = await _cacheStore.loadPlaylists();
    _featuredTracks = await _cacheStore.loadFeaturedTracks();
    _albums = await _cacheStore.loadAlbums();
    _artists = await _cacheStore.loadArtists();
    _genres = await _cacheStore.loadGenres();
    _favoriteAlbums = await _cacheStore.loadFavoriteAlbums();
    _favoriteArtists = await _cacheStore.loadFavoriteArtists();
    _favoriteTracks = await _cacheStore.loadFavoriteTracks();
    _recentTracks = await _cacheStore.loadRecentTracks();
    _playHistory = await _cacheStore.loadPlayHistory();
    _libraryStats = await _cacheStore.loadLibraryStats();
    notifyListeners();
  }

  Future<void> _applyOfflineModeData() async {
    _isLoadingLibrary = true;
    clearSearch(notify: false);
    notifyListeners();
    _pinnedAudio = await _cacheStore.loadPinnedAudio();
    final offlineTracks = await loadOfflineTracks();
    final offlineAlbums = await loadOfflineAlbums();
    final offlineArtists = await loadOfflineArtists();
    final offlinePlaylists = await loadOfflinePlaylists();
    _genres = await _cacheStore.loadGenres();
    _libraryStats = await _cacheStore.loadLibraryStats();
    final offlineAlbumIds = offlineAlbums.map((album) => album.id).toSet();
    final offlineArtistIds = offlineArtists.map((artist) => artist.id).toSet();
    _libraryTracks = offlineTracks;
    _tracksOffset = offlineTracks.length;
    _hasMoreTracks = false;
    _isLoadingTracks = false;
    _featuredTracks = offlineTracks;
    _recentTracks = offlineTracks;
    _albums = offlineAlbums;
    _artists = offlineArtists;
    _playlists = offlinePlaylists;
    final cachedFavorites = await _cacheStore.loadFavoriteTracks();
    _favoriteTracks = _filterPinnedTracks(cachedFavorites);
    final cachedFavoriteAlbums = await _cacheStore.loadFavoriteAlbums();
    _favoriteAlbums = cachedFavoriteAlbums
        .where((album) => offlineAlbumIds.contains(album.id))
        .toList();
    final cachedFavoriteArtists = await _cacheStore.loadFavoriteArtists();
    _favoriteArtists = cachedFavoriteArtists
        .where((artist) => offlineArtistIds.contains(artist.id))
        .toList();
    await _refreshSelectedDetailsForOfflineMode();
    _jumpInTrack = _randomFromList(offlineTracks);
    _jumpInAlbum = _randomFromList(offlineAlbums);
    _jumpInArtist = _randomFromList(offlineArtists);
    _lastJumpInRefreshAt = DateTime.now();
    if (_selectedSmartList != null) {
      _smartListTracks = _buildSmartListTracks(_selectedSmartList!);
    }
    _isLoadingLibrary = false;
    notifyListeners();
  }

  Future<void> _refreshSelectedDetailsForOfflineMode() async {
    if (_selectedPlaylist != null) {
      _playlistTracks =
          await _cacheStore.loadPlaylistTracks(_selectedPlaylist!.id);
    }
    if (_selectedAlbum != null) {
      final cached = await _cacheStore.loadAlbumTracks(_selectedAlbum!.id);
      final filtered = _filterPinnedTracks(cached);
      _albumTracks = filtered.isNotEmpty
          ? filtered
          : await _offlineTracksForAlbum(_selectedAlbum!);
    }
    if (_selectedArtist != null) {
      final cached = await _cacheStore.loadArtistTracks(_selectedArtist!.id);
      final filtered = _filterPinnedTracks(cached);
      _artistTracks = filtered.isNotEmpty
          ? filtered
          : await _offlineTracksForArtist(_selectedArtist!);
    }
    if (_selectedGenre != null) {
      final cached = await _cacheStore.loadGenreTracks(_selectedGenre!.id);
      _genreTracks = _filterPinnedTracks(cached);
    }
  }

  void _bindPlayback() {
    _positionSubscription = _playback.positionStream.listen((position) {
      _position = position;
      _positionNotifier.value = position;
      if (_duration == Duration.zero) {
        final liveDuration = _playback.duration;
        if (liveDuration != null && liveDuration > Duration.zero) {
          _duration = liveDuration;
          _durationNotifier.value = liveDuration;
        }
      }
      _maybeReportProgress();
      _persistPlaybackResumeState();
      _updateNowPlayingInfo();
    });
    _durationSubscription = _playback.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      _durationNotifier.value = _duration;
      _updateNowPlayingInfo(force: true);
    });
    _playerStateSubscription = _playback.playerStateStream.listen((state) {
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
        _maybeReportPlaybackState(isPaused: !_isPlaying);
      }
      if (state.processingState == ProcessingState.ready ||
          state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading) {
        _startPlaybackPolling();
      } else {
        _stopPlaybackPolling();
      }
      if (state.processingState == ProcessingState.completed) {
        _maybeReportStopped(completed: true);
      }
    });
    _currentIndexSubscription = _playback.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _queue.length) {
        final next = _queue[index];
        _setNowPlaying(next, notify: false);
        unawaited(_cacheStore.handlePlaybackAdvance(_queue, index));
      }
      notifyListeners();
    });
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

  void _startPlaybackPolling() {
    if (_playbackPollTimer != null) {
      return;
    }
    _playbackPollTimer =
        Timer.periodic(const Duration(milliseconds: 500), (_) {
      final position = _playback.position;
      if (position != _position) {
        _position = position;
        _positionNotifier.value = position;
      }
      final liveDuration = _playback.duration;
      if (liveDuration != null &&
          liveDuration > Duration.zero &&
          liveDuration != _duration) {
        _duration = liveDuration;
        _durationNotifier.value = liveDuration;
      }
    });
  }

  void _stopPlaybackPolling() {
    _playbackPollTimer?.cancel();
    _playbackPollTimer = null;
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
    _position = resume.position;
    _duration = Duration.zero;
    _positionNotifier.value = _position;
    _durationNotifier.value = _duration;
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
        cacheStore: _cacheStore,
        headers: _playbackHeaders(),
      );
      await _playback.seek(_position);
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
  }) {
    if (_nowPlaying?.id == track.id) {
      if (_duration == Duration.zero && track.duration > Duration.zero) {
        _duration = track.duration;
        _durationNotifier.value = _duration;
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
    _position = Duration.zero;
    _positionNotifier.value = _position;
    if (track.duration > Duration.zero) {
      _duration = track.duration;
      _durationNotifier.value = _duration;
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

  void _maybeReportPlaybackState({required bool isPaused}) {
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
    _reportPlaybackProgress(isPaused: isPaused, force: true);
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

  Future<void> _loadAlbums() async {
    if (_session == null) {
      return;
    }
    if (_offlineMode) {
      return;
    }
    try {
      _isLoadingLibrary = true;
      notifyListeners();
      final albums = await _client.fetchAlbums();
      _albums = albums;
      await _cacheStore.saveAlbums(albums);
    } catch (_) {
      // Use cached results when available.
    } finally {
      _isLoadingLibrary = false;
      notifyListeners();
    }
  }

  Future<void> _loadArtists() async {
    if (_session == null) {
      return;
    }
    if (_offlineMode) {
      return;
    }
    try {
      _isLoadingLibrary = true;
      notifyListeners();
      final artists = await _client.fetchArtists();
      _artists = artists;
      await _cacheStore.saveArtists(artists);
    } catch (_) {
      // Use cached results when available.
    } finally {
      _isLoadingLibrary = false;
      notifyListeners();
    }
  }

  Future<void> _loadGenres() async {
    if (_session == null) {
      return;
    }
    if (_offlineMode) {
      return;
    }
    try {
      _isLoadingLibrary = true;
      notifyListeners();
      final genres = await _client.fetchGenres();
      _genres = genres;
      await _cacheStore.saveGenres(genres);
    } catch (_) {
      // Use cached results when available.
    } finally {
      _isLoadingLibrary = false;
      notifyListeners();
    }
  }

  Future<void> _loadFavoriteAlbums() async {
    if (_session == null) {
      return;
    }
    if (_offlineMode) {
      return;
    }
    try {
      _isLoadingLibrary = true;
      notifyListeners();
      final albums = await _client.fetchFavoriteAlbums();
      _favoriteAlbums = albums;
      await _cacheStore.saveFavoriteAlbums(albums);
    } catch (_) {
      // Use cached results when available.
    } finally {
      _isLoadingLibrary = false;
      notifyListeners();
      if (_autoDownloadFavoritesEnabled && _autoDownloadFavoriteAlbums) {
        unawaited(_prefetchFavoriteDownloads(albumsOnly: true));
      }
    }
  }

  Future<void> _loadFavoriteArtists() async {
    if (_session == null) {
      return;
    }
    if (_offlineMode) {
      return;
    }
    try {
      _isLoadingLibrary = true;
      notifyListeners();
      final artists = await _client.fetchFavoriteArtists();
      if (artists.isNotEmpty || _favoriteArtists.isEmpty) {
        _favoriteArtists = artists;
        await _cacheStore.saveFavoriteArtists(artists);
      }
    } catch (_) {
      // Use cached results when available.
    } finally {
      _isLoadingLibrary = false;
      notifyListeners();
      if (_autoDownloadFavoritesEnabled && _autoDownloadFavoriteArtists) {
        unawaited(_prefetchFavoriteDownloads(artistsOnly: true));
      }
    }
  }

  Future<void> _loadFavoriteTracks() async {
    if (_session == null) {
      return;
    }
    if (_offlineMode) {
      return;
    }
    try {
      _isLoadingLibrary = true;
      notifyListeners();
      final tracks = await _client.fetchFavoriteTracks();
      _favoriteTracks = tracks;
      await _cacheStore.saveFavoriteTracks(tracks);
    } catch (_) {
      // Use cached results when available.
    } finally {
      _isLoadingLibrary = false;
      notifyListeners();
      if (_autoDownloadFavoritesEnabled && _autoDownloadFavoriteTracks) {
        unawaited(_prefetchFavoriteDownloads(tracksOnly: true));
      }
    }
  }

  void _applyAlbumFavoriteLocal(Album album, bool isFavorite) {
    if (isFavorite) {
      if (!_favoriteAlbums.any((item) => item.id == album.id)) {
        _favoriteAlbums = [..._favoriteAlbums, album];
      }
    } else {
      _favoriteAlbums =
          _favoriteAlbums.where((item) => item.id != album.id).toList();
    }
    _favoriteAlbums.sort((a, b) => a.name.compareTo(b.name));
  }

  void _applyArtistFavoriteLocal(Artist artist, bool isFavorite) {
    if (isFavorite) {
      if (!_favoriteArtists.any((item) => item.id == artist.id)) {
        _favoriteArtists = [..._favoriteArtists, artist];
      }
    } else {
      _favoriteArtists =
          _favoriteArtists.where((item) => item.id != artist.id).toList();
    }
    _favoriteArtists.sort((a, b) => a.name.compareTo(b.name));
  }

  void _applyTrackFavoriteLocal(MediaItem track, bool isFavorite) {
    if (isFavorite) {
      if (!_favoriteTracks.any((item) => item.id == track.id)) {
        _favoriteTracks = [..._favoriteTracks, track];
      }
    } else {
      _favoriteTracks =
          _favoriteTracks.where((item) => item.id != track.id).toList();
    }
    _favoriteTracks.sort((a, b) => a.title.compareTo(b.title));
  }

  Future<void> _syncAlbumFavoriteOffline(
    Album album,
    bool isFavorite,
  ) async {
    if (!_autoDownloadFavoritesEnabled || !_autoDownloadFavoriteAlbums) {
      return;
    }
    if (isFavorite) {
      await makeAlbumAvailableOffline(
        album,
        requiresWifi: _autoDownloadFavoritesWifiOnly,
      );
      return;
    }
    await unpinAlbumOffline(album);
  }

  Future<void> _syncArtistFavoriteOffline(
    Artist artist,
    bool isFavorite,
  ) async {
    if (!_autoDownloadFavoritesEnabled || !_autoDownloadFavoriteArtists) {
      return;
    }
    if (isFavorite) {
      await makeArtistAvailableOffline(
        artist,
        requiresWifi: _autoDownloadFavoritesWifiOnly,
      );
      return;
    }
    await unpinArtistOffline(artist);
  }

  Future<void> _syncTrackFavoriteOffline(
    MediaItem track,
    bool isFavorite,
  ) async {
    if (!_autoDownloadFavoritesEnabled || !_autoDownloadFavoriteTracks) {
      return;
    }
    if (isFavorite) {
      await makeTrackAvailableOffline(
        track,
        requiresWifi: _autoDownloadFavoritesWifiOnly,
      );
      return;
    }
    await unpinTrackOffline(track);
  }

  /// Updates the favorite status for an album.
  Future<String?> setAlbumFavorite(Album album, bool isFavorite) async {
    if (_favoriteAlbumUpdatesInFlight.contains(album.id)) {
      return null;
    }
    final wasFavorite = isFavoriteAlbum(album.id);
    if (wasFavorite == isFavorite) {
      return null;
    }
    _favoriteAlbumUpdatesInFlight.add(album.id);
    _applyAlbumFavoriteLocal(album, isFavorite);
    notifyListeners();
    if (_offlineMode) {
      await _cacheStore.saveFavoriteAlbums(_favoriteAlbums);
      if (_selectedSmartList != null) {
        unawaited(_loadSmartListTracks(_selectedSmartList!));
      }
      _favoriteAlbumUpdatesInFlight.remove(album.id);
      notifyListeners();
      return null;
    }
    try {
      await _client.setFavorite(itemId: album.id, isFavorite: isFavorite);
      await _cacheStore.saveFavoriteAlbums(_favoriteAlbums);
      if (_selectedSmartList != null) {
        unawaited(_loadSmartListTracks(_selectedSmartList!));
      }
      unawaited(_syncAlbumFavoriteOffline(album, isFavorite));
      return null;
    } catch (error) {
      _applyAlbumFavoriteLocal(album, wasFavorite);
      await _cacheStore.saveFavoriteAlbums(_favoriteAlbums);
      return _requestErrorMessage(
        error,
        fallback: 'Unable to update album favorite.',
      );
    } finally {
      _favoriteAlbumUpdatesInFlight.remove(album.id);
      notifyListeners();
    }
  }

  /// Updates the favorite status for an artist.
  Future<String?> setArtistFavorite(Artist artist, bool isFavorite) async {
    if (_favoriteArtistUpdatesInFlight.contains(artist.id)) {
      return null;
    }
    final wasFavorite = isFavoriteArtist(artist.id);
    if (wasFavorite == isFavorite) {
      return null;
    }
    _favoriteArtistUpdatesInFlight.add(artist.id);
    _applyArtistFavoriteLocal(artist, isFavorite);
    notifyListeners();
    if (_offlineMode) {
      await _cacheStore.saveFavoriteArtists(_favoriteArtists);
      if (_selectedSmartList != null) {
        unawaited(_loadSmartListTracks(_selectedSmartList!));
      }
      _favoriteArtistUpdatesInFlight.remove(artist.id);
      notifyListeners();
      return null;
    }
    try {
      await _client.setFavorite(itemId: artist.id, isFavorite: isFavorite);
      await _cacheStore.saveFavoriteArtists(_favoriteArtists);
      if (_selectedSmartList != null) {
        unawaited(_loadSmartListTracks(_selectedSmartList!));
      }
      unawaited(_syncArtistFavoriteOffline(artist, isFavorite));
      final confirmed = await _client.fetchFavoriteState(artist.id);
      if (confirmed != null && confirmed != isFavorite) {
        _applyArtistFavoriteLocal(artist, wasFavorite);
        await _cacheStore.saveFavoriteArtists(_favoriteArtists);
        notifyListeners();
        return 'Server did not update artist favorite.';
      }
      return null;
    } catch (error) {
      _applyArtistFavoriteLocal(artist, wasFavorite);
      await _cacheStore.saveFavoriteArtists(_favoriteArtists);
      return _requestErrorMessage(
        error,
        fallback: 'Unable to update artist favorite.',
      );
    } finally {
      _favoriteArtistUpdatesInFlight.remove(artist.id);
      notifyListeners();
    }
  }

  /// Updates the favorite status for a track.
  Future<String?> setTrackFavorite(MediaItem track, bool isFavorite) async {
    if (_favoriteTrackUpdatesInFlight.contains(track.id)) {
      return null;
    }
    final wasFavorite = isFavoriteTrack(track.id);
    if (wasFavorite == isFavorite) {
      return null;
    }
    _favoriteTrackUpdatesInFlight.add(track.id);
    _applyTrackFavoriteLocal(track, isFavorite);
    notifyListeners();
    if (_offlineMode) {
      await _cacheStore.saveFavoriteTracks(_favoriteTracks);
      if (_selectedSmartList != null) {
        unawaited(_loadSmartListTracks(_selectedSmartList!));
      }
      _favoriteTrackUpdatesInFlight.remove(track.id);
      notifyListeners();
      return null;
    }
    try {
      await _client.setFavorite(itemId: track.id, isFavorite: isFavorite);
      await _cacheStore.saveFavoriteTracks(_favoriteTracks);
      unawaited(_syncTrackFavoriteOffline(track, isFavorite));
      return null;
    } catch (error) {
      _applyTrackFavoriteLocal(track, wasFavorite);
      await _cacheStore.saveFavoriteTracks(_favoriteTracks);
      return _requestErrorMessage(
        error,
        fallback: 'Unable to update track favorite.',
      );
    } finally {
      _favoriteTrackUpdatesInFlight.remove(track.id);
      notifyListeners();
    }
  }

  /// Clears album, artist, and genre selections.
  void clearBrowseSelection({bool notify = true}) {
    _selectedAlbum = null;
    _selectedArtist = null;
    _selectedGenre = null;
    _albumTracks = [];
    _artistTracks = [];
    _genreTracks = [];
    if (notify) {
      notifyListeners();
    }
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
    return tracks
        .where((track) => _pinnedAudio.contains(track.streamUrl))
        .toList();
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
    final index = tracks.indexWhere((item) => item.id == track.id);
    if (index < 0) {
      return;
    }
    final normalized = _normalizeTracksForPlayback(tracks);
    final playbackTrack = normalized[index];
    await _refreshNowPlayingCacheStatus(playbackTrack);
    final previousQueue = List<MediaItem>.from(_queue);
    _queue = normalized;
    final didSetQueue = await _performPlaybackAction(
      () => _playback.setQueue(
        _queue,
        startIndex: index,
        cacheStore: _cacheStore,
        headers: _playbackHeaders(),
      ),
      'set queue',
    );
    if (!didSetQueue) {
      _queue = previousQueue;
      if (_isPreparingPlayback) {
        _isPreparingPlayback = false;
      }
      notifyListeners();
      return;
    }
    if (_nowPlaying?.id != playbackTrack.id) {
      _setNowPlaying(playbackTrack);
    } else if (playbackTrack.duration > Duration.zero &&
        _duration == Duration.zero) {
      _duration = playbackTrack.duration;
      _durationNotifier.value = _duration;
    }
    _startPlaybackPolling();
    await _performPlaybackAction(
      () => _playback.play(),
      'play',
    );
  }

  Map<String, String>? _playbackHeaders() {
    final session = _session;
    if (session == null) {
      return null;
    }
    return {
      'X-Emby-Token': session.accessToken,
      'X-Emby-Authorization': _client.authorizationHeader,
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
      token: session.accessToken,
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
    );
  }

  Future<bool> _performPlaybackAction(
    Future<void> Function() action,
    String label,
  ) async {
    try {
      await action();
      return true;
    } catch (error) {
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
    final nextPreparing = !isCached;
    final shouldNotify = _isNowPlayingCached != isCached ||
        _isPreparingPlayback != nextPreparing;
    _isNowPlayingCached = isCached;
    _isPreparingPlayback = nextPreparing;
    if (shouldNotify) {
      notifyListeners();
    }
  }
}
