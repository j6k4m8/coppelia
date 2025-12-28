import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:just_audio/just_audio.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/auth_session.dart';
import '../models/cached_audio_entry.dart';
import '../models/genre.dart';
import '../models/library_stats.dart';
import '../models/media_item.dart';
import '../models/playback_resume_state.dart';
import '../models/playlist.dart';
import '../models/search_results.dart';
import '../services/cache_store.dart';
import '../services/jellyfin_client.dart';
import '../services/now_playing_service.dart';
import '../services/playback_controller.dart';
import '../services/settings_store.dart';
import '../services/session_store.dart';
import 'browse_layout.dart';
import 'home_section.dart';
import 'keyboard_shortcut.dart';
import 'layout_density.dart';
import 'library_view.dart';
import 'now_playing_layout.dart';
import 'sidebar_item.dart';

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
  final Set<String> _favoriteAlbumUpdatesInFlight = {};
  final Set<String> _favoriteArtistUpdatesInFlight = {};
  final Set<String> _favoriteTrackUpdatesInFlight = {};
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
  final Random _random = Random();
  ThemeMode _themeMode = ThemeMode.dark;
  String? _fontFamily = 'SF Pro Display';
  double _fontScale = 1.0;
  bool _telemetryPlayback = true;
  bool _telemetryProgress = true;
  bool _telemetryHistory = true;
  bool _settingsShortcutEnabled = true;
  KeyboardShortcut _settingsShortcut = KeyboardShortcut.defaultForPlatform();
  bool _searchShortcutEnabled = true;
  KeyboardShortcut _searchShortcut = KeyboardShortcut.searchForPlatform();
  LayoutDensity _layoutDensity = LayoutDensity.comfortable;
  NowPlayingLayout _nowPlayingLayout = NowPlayingLayout.bottom;
  Map<HomeSection, bool> _homeSectionVisibility = {
    for (final section in HomeSection.values) section: true,
  };
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

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<int?>? _currentIndexSubscription;

  static const int _tracksPageSize = 100;

  String? _playSessionId;
  String? _reportedStartSessionId;
  String? _reportedStopSessionId;
  DateTime? _lastProgressReportAt;
  DateTime? _lastPlaybackPersistAt;
  bool _activeSessionHasPlayed = false;
  DateTime? _lastNowPlayingUpdateAt;

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

  /// Preferred layout for now playing.
  NowPlayingLayout get nowPlayingLayout => _nowPlayingLayout;

  /// Home section visibility settings.
  Map<HomeSection, bool> get homeSectionVisibility =>
      Map.unmodifiable(_homeSectionVisibility);

  /// Random track for the Jump in shelf.
  MediaItem? get jumpInTrack => _jumpInTrack;

  /// Random album for the Jump in shelf.
  Album? get jumpInAlbum => _jumpInAlbum;

  /// Random artist for the Jump in shelf.
  Artist? get jumpInArtist => _jumpInArtist;

  /// True while Jump in picks are loading.
  bool get isLoadingJumpIn => _isLoadingJumpIn;

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
    _telemetryPlayback = await _settingsStore.loadPlaybackTelemetry();
    _telemetryProgress = await _settingsStore.loadProgressTelemetry();
    _telemetryHistory = await _settingsStore.loadHistoryTelemetry();
    _settingsShortcutEnabled =
        await _settingsStore.loadSettingsShortcutEnabled();
    _settingsShortcut = await _settingsStore.loadSettingsShortcut();
    _searchShortcutEnabled = await _settingsStore.loadSearchShortcutEnabled();
    _searchShortcut = await _settingsStore.loadSearchShortcut();
    _layoutDensity = await _settingsStore.loadLayoutDensity();
    _nowPlayingLayout = await _settingsStore.loadNowPlayingLayout();
    _homeSectionVisibility = await _settingsStore.loadHomeSectionVisibility();
    _sidebarVisibility = await _settingsStore.loadSidebarVisibility();
    _sidebarWidth = await _settingsStore.loadSidebarWidth();
    _sidebarCollapsed = await _settingsStore.loadSidebarCollapsed();
    await _loadCachedLibrary();
    await _restorePlaybackResumeState();
    _isBootstrapping = false;
    notifyListeners();

    if (_session != null) {
      await refreshLibrary();
    }
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
    _selectedView = LibraryView.home;
    _viewHistory.clear();
    _selectedAlbum = null;
    _selectedArtist = null;
    _selectedGenre = null;
    _searchQuery = '';
    _searchResults = null;
    _isSearching = false;
    _playlistTracks = [];
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
    _nowPlaying = null;
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
  Future<void> selectPlaylist(Playlist playlist) async {
    if (_selectedView != LibraryView.home) {
      _recordViewHistory(_selectedView);
    }
    _selectedPlaylist = playlist;
    _selectedView = LibraryView.home;
    clearBrowseSelection(notify: false);
    clearSearch(notify: false);
    notifyListeners();
    final cached = await _cacheStore.loadPlaylistTracks(playlist.id);
    if (cached.isNotEmpty) {
      _playlistTracks = cached;
      notifyListeners();
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

  /// Clears the current playlist selection.
  void clearPlaylistSelection() {
    _selectedPlaylist = null;
    _playlistTracks = [];
    _selectedView = LibraryView.home;
    clearBrowseSelection(notify: false);
    notifyListeners();
  }

  /// Navigates to a library view.
  void selectLibraryView(LibraryView view, {bool recordHistory = true}) {
    if (recordHistory && view != _selectedView) {
      _recordViewHistory(_selectedView);
    }
    _selectedView = view;
    _selectedPlaylist = null;
    _playlistTracks = [];
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
      await selectAlbum(match);
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
      await selectArtist(match);
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
    await selectArtist(match);
  }

  /// Performs a search across the library.
  Future<void> searchLibrary(String query) async {
    final trimmed = query.trim();
    _searchQuery = trimmed;
    if (trimmed.isEmpty) {
      clearSearch();
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

  /// Clears the current search results.
  void clearSearch({bool notify = true}) {
    _searchQuery = '';
    _searchResults = null;
    _isSearching = false;
    if (notify) {
      notifyListeners();
    }
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
    await _loadAlbums();
  }

  /// Loads artists, using cached results when possible.
  Future<void> loadArtists() async {
    final cached = await _cacheStore.loadArtists();
    if (cached.isNotEmpty) {
      _artists = cached;
      notifyListeners();
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
    await _loadGenres();
  }

  /// Loads paginated tracks for the library browse view.
  Future<void> loadLibraryTracks({bool reset = false}) async {
    if (_session == null) {
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
    if (tracks.isEmpty) {
      return;
    }
    final shuffled = [...tracks]..shuffle(_random);
    await _playFromList(shuffled, shuffled.first);
  }

  /// Loads favorite albums.
  Future<void> loadFavoriteAlbums() async {
    final cached = await _cacheStore.loadFavoriteAlbums();
    if (cached.isNotEmpty) {
      _favoriteAlbums = cached;
      notifyListeners();
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
    await _loadFavoriteArtists();
  }

  /// Loads favorite tracks.
  Future<void> loadFavoriteTracks() async {
    final cached = await _cacheStore.loadFavoriteTracks();
    if (cached.isNotEmpty) {
      _favoriteTracks = cached;
      notifyListeners();
    }
    await _loadFavoriteTracks();
  }

  /// Selects an album and loads its tracks.
  Future<void> selectAlbum(Album album) async {
    _selectedAlbum = album;
    _selectedArtist = null;
    _selectedGenre = null;
    clearSearch(notify: false);
    notifyListeners();
    final cached = await _cacheStore.loadAlbumTracks(album.id);
    if (cached.isNotEmpty) {
      _albumTracks = cached;
      notifyListeners();
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
    if (_albumTracks.isNotEmpty) {
      await playFromAlbum(_albumTracks.first);
    }
  }

  /// Selects an artist and loads their tracks.
  Future<void> selectArtist(Artist artist) async {
    _selectedArtist = artist;
    _selectedAlbum = null;
    _selectedGenre = null;
    clearSearch(notify: false);
    notifyListeners();
    final cached = await _cacheStore.loadArtistTracks(artist.id);
    if (cached.isNotEmpty) {
      _artistTracks = cached;
      notifyListeners();
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
    if (_artistTracks.isNotEmpty) {
      await playFromArtist(_artistTracks.first);
    }
  }

  /// Selects a genre and loads its tracks.
  Future<void> selectGenre(Genre genre) async {
    _selectedGenre = genre;
    _selectedAlbum = null;
    _selectedArtist = null;
    clearSearch(notify: false);
    notifyListeners();
    final cached = await _cacheStore.loadGenreTracks(genre.id);
    if (cached.isNotEmpty) {
      _genreTracks = cached;
      notifyListeners();
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
    if (_genreTracks.isNotEmpty) {
      await playFromGenre(_genreTracks.first);
    }
  }

  /// Starts playback from a selected track.
  Future<void> playFromPlaylist(MediaItem track) async {
    await _playFromList(_playlistTracks, track);
  }

  /// Plays tracks from the selected album.
  Future<void> playFromAlbum(MediaItem track) async {
    await _playFromList(_albumTracks, track);
  }

  /// Plays tracks from the selected artist.
  Future<void> playFromArtist(MediaItem track) async {
    await _playFromList(_artistTracks, track);
  }

  /// Plays tracks from the selected genre.
  Future<void> playFromGenre(MediaItem track) async {
    await _playFromList(_genreTracks, track);
  }

  /// Plays tracks from favorites.
  Future<void> playFromFavorites(MediaItem track) async {
    await _playFromList(_favoriteTracks, track);
  }

  /// Plays tracks from search results.
  Future<void> playFromSearch(MediaItem track) async {
    final tracks = _searchResults?.tracks ?? const <MediaItem>[];
    await _playFromList(tracks, track);
  }

  /// Plays tracks from a provided list.
  Future<void> playFromList(List<MediaItem> tracks, MediaItem track) async {
    await _playFromList(tracks, track);
  }

  /// Plays featured tracks from the home shelf.
  Future<void> playFeatured(MediaItem track) async {
    await _playFromList(_featuredTracks, track);
  }

  /// Toggles between play and pause states.
  Future<void> togglePlayback() async {
    if (_playback.isPlaying) {
      await _performPlaybackAction(
        () => _playback.pause(),
        'pause',
      );
    } else {
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
  }

  /// Returns the estimated cached media size in bytes.
  Future<int> getMediaCacheBytes() async {
    return _cacheStore.getMediaCacheBytes();
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
  }

  /// Releases audio resources.
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _currentIndexSubscription?.cancel();
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    _isPlayingNotifier.dispose();
    _isBufferingNotifier.dispose();
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

  void _bindPlayback() {
    _positionSubscription = _playback.positionStream.listen((position) {
      _position = position;
      _positionNotifier.value = position;
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
      final nextBuffering =
          state.processingState == ProcessingState.loading ||
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
      if (state.processingState == ProcessingState.completed) {
        _maybeReportStopped(completed: true);
      }
    });
    _currentIndexSubscription =
        _playback.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _queue.length) {
        final next = _queue[index];
        _setNowPlaying(next, notify: false);
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
    unawaited(_refreshNowPlayingCacheStatus(track));
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
    final duration =
        _duration == Duration.zero ? track.duration : _duration;
    final position =
        duration.inMilliseconds > 0 && _position > duration
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
    }
  }

  Future<void> _loadFavoriteArtists() async {
    if (_session == null) {
      return;
    }
    try {
      _isLoadingLibrary = true;
      notifyListeners();
      final artists = await _client.fetchFavoriteArtists();
      _favoriteArtists = artists;
      await _cacheStore.saveFavoriteArtists(artists);
    } catch (_) {
      // Use cached results when available.
    } finally {
      _isLoadingLibrary = false;
      notifyListeners();
    }
  }

  Future<void> _loadFavoriteTracks() async {
    if (_session == null) {
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

  /// Updates the favorite status for an album.
  Future<void> setAlbumFavorite(Album album, bool isFavorite) async {
    if (_favoriteAlbumUpdatesInFlight.contains(album.id)) {
      return;
    }
    final wasFavorite = isFavoriteAlbum(album.id);
    if (wasFavorite == isFavorite) {
      return;
    }
    _favoriteAlbumUpdatesInFlight.add(album.id);
    _applyAlbumFavoriteLocal(album, isFavorite);
    notifyListeners();
    try {
      await _client.setFavorite(itemId: album.id, isFavorite: isFavorite);
      await _cacheStore.saveFavoriteAlbums(_favoriteAlbums);
    } catch (_) {
      _applyAlbumFavoriteLocal(album, wasFavorite);
      await _cacheStore.saveFavoriteAlbums(_favoriteAlbums);
    } finally {
      _favoriteAlbumUpdatesInFlight.remove(album.id);
      notifyListeners();
    }
  }

  /// Updates the favorite status for an artist.
  Future<void> setArtistFavorite(Artist artist, bool isFavorite) async {
    if (_favoriteArtistUpdatesInFlight.contains(artist.id)) {
      return;
    }
    final wasFavorite = isFavoriteArtist(artist.id);
    if (wasFavorite == isFavorite) {
      return;
    }
    _favoriteArtistUpdatesInFlight.add(artist.id);
    _applyArtistFavoriteLocal(artist, isFavorite);
    notifyListeners();
    try {
      await _client.setFavorite(itemId: artist.id, isFavorite: isFavorite);
      await _cacheStore.saveFavoriteArtists(_favoriteArtists);
    } catch (_) {
      _applyArtistFavoriteLocal(artist, wasFavorite);
      await _cacheStore.saveFavoriteArtists(_favoriteArtists);
    } finally {
      _favoriteArtistUpdatesInFlight.remove(artist.id);
      notifyListeners();
    }
  }

  /// Updates the favorite status for a track.
  Future<void> setTrackFavorite(MediaItem track, bool isFavorite) async {
    if (_favoriteTrackUpdatesInFlight.contains(track.id)) {
      return;
    }
    final wasFavorite = isFavoriteTrack(track.id);
    if (wasFavorite == isFavorite) {
      return;
    }
    _favoriteTrackUpdatesInFlight.add(track.id);
    _applyTrackFavoriteLocal(track, isFavorite);
    notifyListeners();
    try {
      await _client.setFavorite(itemId: track.id, isFavorite: isFavorite);
      await _cacheStore.saveFavoriteTracks(_favoriteTracks);
    } catch (_) {
      _applyTrackFavoriteLocal(track, wasFavorite);
      await _cacheStore.saveFavoriteTracks(_favoriteTracks);
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
    }
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
    final cached = await _cacheStore.getCachedAudio(track);
    final isCached = cached != null;
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
