import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:just_audio/just_audio.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/auth_session.dart';
import '../models/genre.dart';
import '../models/library_stats.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';
import '../models/search_results.dart';
import '../services/cache_store.dart';
import '../services/jellyfin_client.dart';
import '../services/playback_controller.dart';
import '../services/settings_store.dart';
import '../services/session_store.dart';
import 'browse_layout.dart';
import 'home_section.dart';
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
  }

  final CacheStore _cacheStore;
  final JellyfinClient _client;
  final PlaybackController _playback;
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

  List<Playlist> _playlists = [];
  List<MediaItem> _playlistTracks = [];
  List<MediaItem> _featuredTracks = [];
  List<MediaItem> _queue = [];
  List<Album> _albums = [];
  List<Artist> _artists = [];
  List<Genre> _genres = [];
  List<MediaItem> _albumTracks = [];
  List<MediaItem> _artistTracks = [];
  List<MediaItem> _genreTracks = [];
  List<Album> _favoriteAlbums = [];
  List<Artist> _favoriteArtists = [];
  List<MediaItem> _favoriteTracks = [];
  List<MediaItem> _recentTracks = [];
  List<MediaItem> _playHistory = [];

  LibraryStats? _libraryStats;

  MediaItem? _nowPlaying;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;
  final ValueNotifier<Duration> _positionNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isBufferingNotifier = ValueNotifier(false);
  ThemeMode _themeMode = ThemeMode.dark;
  String? _fontFamily = 'SF Pro Display';
  double _fontScale = 1.0;
  NowPlayingLayout _nowPlayingLayout = NowPlayingLayout.side;
  Map<HomeSection, bool> _homeSectionVisibility = {
    for (final section in HomeSection.values) section: true,
  };
  Map<SidebarItem, bool> _sidebarVisibility = {
    for (final item in SidebarItem.values) item: true,
  };
  double _sidebarWidth = 240;
  bool _sidebarCollapsed = false;
  final Map<LibraryView, BrowseLayout> _browseLayouts = {};
  final Map<String, double> _scrollOffsets = {};

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<int?>? _currentIndexSubscription;

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

  /// Recently played tracks.
  List<MediaItem> get recentTracks => List.unmodifiable(_recentTracks);

  /// Playback history (most recent first).
  List<MediaItem> get playHistory => List.unmodifiable(_playHistory);

  /// Aggregated library stats.
  LibraryStats? get libraryStats => _libraryStats;

  /// Current search query.
  String get searchQuery => _searchQuery;

  /// True while search results are loading.
  bool get isSearching => _isSearching;

  /// Search results, when available.
  SearchResults? get searchResults => _searchResults;

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

  /// Active theme mode.
  ThemeMode get themeMode => _themeMode;

  /// Preferred font family.
  String? get fontFamily => _fontFamily;

  /// Preferred font scale.
  double get fontScale => _fontScale;

  /// Preferred layout for now playing.
  NowPlayingLayout get nowPlayingLayout => _nowPlayingLayout;

  /// Home section visibility settings.
  Map<HomeSection, bool> get homeSectionVisibility =>
      Map.unmodifiable(_homeSectionVisibility);

  /// Sidebar item visibility settings.
  Map<SidebarItem, bool> get sidebarVisibility =>
      Map.unmodifiable(_sidebarVisibility);

  /// Current sidebar width.
  double get sidebarWidth => _sidebarWidth;

  /// True when the sidebar is collapsed.
  bool get isSidebarCollapsed => _sidebarCollapsed;

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
    _session = await _sessionStore.loadSession();
    if (_session != null) {
      _client.updateSession(_session!);
    }
    _themeMode = await _settingsStore.loadThemeMode();
    _fontFamily = await _settingsStore.loadFontFamily();
    _fontScale = await _settingsStore.loadFontScale();
    _nowPlayingLayout = await _settingsStore.loadNowPlayingLayout();
    _homeSectionVisibility = await _settingsStore.loadHomeSectionVisibility();
    _sidebarVisibility = await _settingsStore.loadSidebarVisibility();
    _sidebarWidth = await _settingsStore.loadSidebarWidth();
    _sidebarCollapsed = await _settingsStore.loadSidebarCollapsed();
    await _loadCachedLibrary();
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
    _session = null;
    _client.clearSession();
    _selectedPlaylist = null;
    _selectedView = LibraryView.home;
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
    _albumTracks = [];
    _artistTracks = [];
    _genreTracks = [];
    _favoriteAlbums = [];
    _favoriteArtists = [];
    _favoriteTracks = [];
    _recentTracks = [];
    _playHistory = [];
    _libraryStats = null;
    _queue = [];
    _nowPlaying = null;
    _isBuffering = false;
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
      if (_favoriteAlbums.isNotEmpty) {
        await _loadFavoriteAlbums();
      }
      if (_favoriteArtists.isNotEmpty) {
        await _loadFavoriteArtists();
      }
      if (_favoriteTracks.isNotEmpty) {
        await _loadFavoriteTracks();
      }
    } catch (_) {
      // Keep cached content if refresh fails.
    }
    _isLoadingLibrary = false;
    notifyListeners();
  }

  /// Selects a playlist and loads its tracks.
  Future<void> selectPlaylist(Playlist playlist) async {
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
  void selectLibraryView(LibraryView view) {
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
    final index = _playlistTracks.indexWhere((item) => item.id == track.id);
    if (index < 0) {
      return;
    }
    _queue = _playlistTracks;
    await _playback.setQueue(
      _queue,
      startIndex: index,
      cacheStore: _cacheStore,
      headers: _playbackHeaders(),
    );
    if (_nowPlaying?.id != track.id) {
      _nowPlaying = track;
      notifyListeners();
    }
    await _playback.play();
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
    final index = _featuredTracks.indexWhere((item) => item.id == track.id);
    if (index < 0) {
      return;
    }
    _queue = _featuredTracks;
    await _playback.setQueue(
      _queue,
      startIndex: index,
      cacheStore: _cacheStore,
      headers: _playbackHeaders(),
    );
    if (_nowPlaying?.id != track.id) {
      _nowPlaying = track;
      notifyListeners();
    }
    await _playback.play();
  }

  /// Toggles between play and pause states.
  Future<void> togglePlayback() async {
    if (_playback.isPlaying) {
      await _playback.pause();
    } else {
      await _playback.play();
    }
  }

  /// Skips to the next track.
  Future<void> nextTrack() async {
    await _playback.skipNext();
  }

  /// Skips to the previous track.
  Future<void> previousTrack() async {
    const restartThreshold = Duration(seconds: 5);
    if (_position > restartThreshold) {
      await _playback.seek(Duration.zero);
      return;
    }
    await _playback.skipPrevious();
  }

  /// Jumps to a specific position in the queue.
  Future<void> playQueueIndex(int index) async {
    if (index < 0 || index >= _queue.length) {
      return;
    }
    await _playback.seekToIndex(index);
    await _playback.play();
  }

  /// Adds a track to the end of the queue.
  Future<void> enqueueTrack(MediaItem track) async {
    if (_queue.isEmpty) {
      _queue = [track];
      await _playback.setQueue(
        _queue,
        startIndex: 0,
        cacheStore: _cacheStore,
        headers: _playbackHeaders(),
      );
      await _playback.play();
      notifyListeners();
      return;
    }
    _queue.add(track);
    await _playback.appendToQueue(
      track,
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
    _queue.insert(insertIndex, track);
    await _playback.insertNext(
      track,
      cacheStore: _cacheStore,
      headers: _playbackHeaders(),
    );
    notifyListeners();
  }

  /// Clears the current playback queue.
  Future<void> clearQueue() async {
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
      _isPlayingNotifier.value = _isPlaying;
      _isBufferingNotifier.value = _isBuffering;
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
    await _playback.seek(position);
  }

  /// Updates the theme preference.
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _settingsStore.saveThemeMode(mode);
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
    });
    _durationSubscription = _playback.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      _durationNotifier.value = _duration;
    });
    _playerStateSubscription = _playback.playerStateStream.listen((state) {
      final nextPlaying = state.playing;
      final nextBuffering =
          state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      final playingChanged = _isPlaying != nextPlaying;
      final bufferingChanged = _isBuffering != nextBuffering;
      _isPlaying = nextPlaying;
      _isBuffering = nextBuffering;
      _isPlayingNotifier.value = _isPlaying;
      _isBufferingNotifier.value = _isBuffering;
      if (playingChanged || bufferingChanged) {
        notifyListeners();
      }
    });
    _currentIndexSubscription =
        _playback.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _queue.length) {
        final next = _queue[index];
        if (_nowPlaying?.id != next.id) {
          _nowPlaying = next;
          _recordPlayHistory(next);
        }
      }
      notifyListeners();
    });
  }

  void _recordPlayHistory(MediaItem track) {
    _playHistory.removeWhere((item) => item.id == track.id);
    _playHistory.insert(0, track);
    if (_playHistory.length > 50) {
      _playHistory = _playHistory.sublist(0, 50);
    }
    unawaited(_cacheStore.savePlayHistory(_playHistory));
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

  Future<void> _playFromList(
    List<MediaItem> tracks,
    MediaItem track,
  ) async {
    final index = tracks.indexWhere((item) => item.id == track.id);
    if (index < 0) {
      return;
    }
    _queue = tracks;
    await _playback.setQueue(
      _queue,
      startIndex: index,
      cacheStore: _cacheStore,
      headers: _playbackHeaders(),
    );
    if (_nowPlaying?.id != track.id) {
      _nowPlaying = track;
      notifyListeners();
    }
    await _playback.play();
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
}
