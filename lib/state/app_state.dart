import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/auth_session.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';
import '../services/cache_store.dart';
import '../services/jellyfin_client.dart';
import '../services/playback_controller.dart';
import '../services/session_store.dart';

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

  List<Playlist> _playlists = [];
  List<MediaItem> _playlistTracks = [];
  List<MediaItem> _featuredTracks = [];
  List<MediaItem> _queue = [];

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

  /// Playback queue of tracks.
  List<MediaItem> get queue => List.unmodifiable(_queue);

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
    _playlistTracks = [];
    _featuredTracks = [];
    _playlists = [];
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
    } catch (_) {
      // Keep cached content if refresh fails.
    }
    _isLoadingLibrary = false;
    notifyListeners();
  }

  /// Selects a playlist and loads its tracks.
  Future<void> selectPlaylist(Playlist playlist) async {
    _selectedPlaylist = playlist;
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
    notifyListeners();
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
