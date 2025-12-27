import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/auth_session.dart';
import '../models/genre.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';
import '../models/search_results.dart';
import '../services/cache_store.dart';
import '../services/jellyfin_client.dart';
import '../services/playback_controller.dart';
import '../services/session_store.dart';
import 'library_view.dart';

/// Central application state and Jellyfin coordination.
class AppState extends ChangeNotifier {
  /// Creates the shared application state.
  AppState({
    required CacheStore cacheStore,
    required JellyfinClient client,
    required PlaybackController playback,
    required SessionStore sessionStore,
  })  : _cacheStore = cacheStore,
        _client = client,
        _playback = playback,
        _sessionStore = sessionStore {
    _bindPlayback();
  }

  final CacheStore _cacheStore;
  final JellyfinClient _client;
  final PlaybackController _playback;
  final SessionStore _sessionStore;

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

  MediaItem? _nowPlaying;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

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

  /// Duration of the current track.
  Duration get duration => _duration;

  /// True when audio is playing.
  bool get isPlaying => _isPlaying;

  /// Initializes cached state and refreshes library.
  Future<void> bootstrap() async {
    _session = await _sessionStore.loadSession();
    if (_session != null) {
      _client.updateSession(_session!);
    }
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
    _queue = [];
    _nowPlaying = null;
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

  /// Selects an album and loads its tracks.
  Future<void> selectAlbum(Album album) async {
    _selectedAlbum = album;
    _selectedArtist = null;
    _selectedGenre = null;
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

  /// Plays tracks from search results.
  Future<void> playFromSearch(MediaItem track) async {
    final tracks = _searchResults?.tracks ?? const <MediaItem>[];
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
    await _playback.skipPrevious();
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

  /// Seeks to a specific playback position.
  Future<void> seek(Duration position) async {
    await _playback.seek(position);
  }

  /// Releases audio resources.
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _currentIndexSubscription?.cancel();
    unawaited(_playback.dispose());
    super.dispose();
  }

  Future<void> _loadCachedLibrary() async {
    _playlists = await _cacheStore.loadPlaylists();
    _featuredTracks = await _cacheStore.loadFeaturedTracks();
    _albums = await _cacheStore.loadAlbums();
    _artists = await _cacheStore.loadArtists();
    _genres = await _cacheStore.loadGenres();
    notifyListeners();
  }

  void _bindPlayback() {
    _positionSubscription = _playback.positionStream.listen((position) {
      _position = position;
      notifyListeners();
    });
    _durationSubscription = _playback.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    });
    _playerStateSubscription = _playback.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });
    _currentIndexSubscription =
        _playback.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _queue.length) {
        _nowPlaying = _queue[index];
      }
      notifyListeners();
    });
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
