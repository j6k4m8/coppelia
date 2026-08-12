import 'dart:convert';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/cached_audio_entry.dart';
import '../models/genre.dart';
import '../models/library_stats.dart';
import '../models/media_item.dart';
import '../models/playback_resume_state.dart';
import '../models/playlist.dart';
import 'log_service.dart';

/// Manages cached metadata and audio assets.
class CacheStore {
  /// Creates a cache manager instance.
  CacheStore();

  /// Default cache size limit (500 MB).
  static const int defaultCacheMaxBytes = 500 * 1024 * 1024;

  static const _audioCacheKey = 'coppelia_audio_cache';
  static const _playlistsKey = 'cached_playlists';
  static const _tracksKey = 'cached_playlist_tracks';
  static const _featuredKey = 'cached_featured_tracks';
  static const _albumsKey = 'cached_albums';
  static const _recentlyAddedAlbumsKey = 'cached_recently_added_albums';
  static const _artistsKey = 'cached_artists';
  static const _genresKey = 'cached_genres';
  static const _albumTracksKey = 'cached_album_tracks';
  static const _artistTracksKey = 'cached_artist_tracks';
  static const _genreTracksKey = 'cached_genre_tracks';
  static const _favoriteAlbumsKey = 'cached_favorite_albums';
  static const _favoriteArtistsKey = 'cached_favorite_artists';
  static const _favoriteTracksKey = 'cached_favorite_tracks';
  static const _libraryTracksKey = 'cached_library_tracks';
  static const _recentTracksKey = 'cached_recent_tracks';
  static const _playHistoryKey = 'cached_play_history';
  static const _libraryStatsKey = 'cached_library_stats';
  static const _cachedAudioKey = 'cached_audio_entries';
  static const _cachedAudioLimitKey = 'cached_audio_limit_bytes';
  static const _pinnedAudioKey = 'cached_audio_pins';
  static const _pinnedAudioItemsKey = 'cached_audio_pin_items';
  static const _wholeLibraryPinnedAudioKey = 'cached_audio_whole_library_pins';
  static const _playbackResumeKey = 'cached_playback_resume';

  static const _legacyCacheKeyField = 'legacyCacheKey';

  static const _profileKeys = <String>[
    _playlistsKey,
    _tracksKey,
    _featuredKey,
    _albumsKey,
    _recentlyAddedAlbumsKey,
    _artistsKey,
    _genresKey,
    _albumTracksKey,
    _artistTracksKey,
    _genreTracksKey,
    _favoriteAlbumsKey,
    _favoriteArtistsKey,
    _favoriteTracksKey,
    _libraryTracksKey,
    _recentTracksKey,
    _playHistoryKey,
    _libraryStatsKey,
    _cachedAudioKey,
    _pinnedAudioKey,
    _pinnedAudioItemsKey,
    _wholeLibraryPinnedAudioKey,
    _playbackResumeKey,
  ];

  String? _scope;

  final CacheManager _audioCache = CacheManager(
    Config(
      _audioCacheKey,
      stalePeriod: const Duration(days: 3650),
      maxNrOfCacheObjects: 20000,
    ),
  );

  /// Activates the profile scope used for library and offline data.
  void activateScope(String? serverId) {
    _scope = serverId;
  }

  /// Moves legacy single-session cache data into a server-specific scope.
  Future<void> migrateLegacyData(String serverId) async {
    final preferences = await SharedPreferences.getInstance();
    final legacyAudioEntries = _readJsonMap(
      preferences.getString(_cachedAudioKey),
    );
    final migratedAudioEntries = <String, dynamic>{};
    for (final entry in legacyAudioEntries.entries) {
      final payload = entry.value;
      if (payload is! Map) {
        continue;
      }
      final payloadMap = Map<String, dynamic>.from(payload);
      final mediaItem = payloadMap['mediaItem'];
      final itemId = mediaItem is Map<String, dynamic>
          ? mediaItem['id']?.toString()
          : _streamItemId(entry.key);
      if (itemId == null || itemId.isEmpty) {
        continue;
      }
      migratedAudioEntries['$serverId:audio:$itemId'] = {
        ...payloadMap,
        _legacyCacheKeyField: entry.key,
      };
    }

    for (final key in _profileKeys) {
      if (key == _cachedAudioKey) {
        continue;
      }
      final value = preferences.get(key);
      if (value != null) {
        await _copyPreferenceValue(
            preferences, _scopedKey(key, serverId), value);
      }
    }
    if (migratedAudioEntries.isNotEmpty) {
      await preferences.setString(
        _scopedKey(_cachedAudioKey, serverId),
        jsonEncode(migratedAudioEntries),
      );
    }
    final legacyPinned = _readJsonList(preferences.getString(_pinnedAudioKey));
    if (legacyPinned.isNotEmpty) {
      await preferences.setString(
        _scopedKey(_pinnedAudioKey, serverId),
        jsonEncode(
          legacyPinned
              .map((entry) => _audioKeyForStreamUrl(entry.toString(), serverId))
              .toSet()
              .toList(),
        ),
      );
    }
    final legacyPinnedItems = _readJsonMap(
      preferences.getString(_pinnedAudioItemsKey),
    );
    if (legacyPinnedItems.isNotEmpty) {
      final migratedPinnedItems = <String, dynamic>{};
      for (final entry in legacyPinnedItems.entries) {
        final item = entry.value;
        final itemId = item is Map<String, dynamic>
            ? item['id']?.toString()
            : _streamItemId(entry.key);
        if (itemId != null && itemId.isNotEmpty) {
          migratedPinnedItems['$serverId:audio:$itemId'] = item;
        }
      }
      await preferences.setString(
        _scopedKey(_pinnedAudioItemsKey, serverId),
        jsonEncode(migratedPinnedItems),
      );
    }
    final legacyWholeLibraryPins = _readJsonList(
      preferences.getString(_wholeLibraryPinnedAudioKey),
    );
    if (legacyWholeLibraryPins.isNotEmpty) {
      await preferences.setString(
        _scopedKey(_wholeLibraryPinnedAudioKey, serverId),
        jsonEncode(
          legacyWholeLibraryPins
              .map((entry) => _audioKeyForStreamUrl(entry.toString(), serverId))
              .toSet()
              .toList(),
        ),
      );
    }
    for (final key in _profileKeys) {
      await preferences.remove(key);
    }
  }

  /// Deletes all local data belonging to one saved server.
  Future<void> clearScope(String serverId) async {
    await _clearMetadataForScope(serverId);
    await _clearOfflineAudioStateForScope(serverId);
    final preferences = await SharedPreferences.getInstance();
    for (final key in _profileKeys) {
      await preferences.remove(_scopedKey(key, serverId));
    }
  }

  /// Returns a stable cache identity for a stream in the active profile.
  String audioKeyForStreamUrl(String streamUrl) =>
      _audioKeyForStreamUrl(streamUrl, _scope);

  String _audioKeyForStreamUrl(String streamUrl, String? scope) {
    final itemId = _streamItemId(streamUrl);
    if (scope == null || itemId == null || itemId.isEmpty) {
      return streamUrl;
    }
    return '$scope:audio:$itemId';
  }

  String? _streamItemId(String streamUrl) {
    final uri = Uri.tryParse(streamUrl);
    if (uri == null) {
      return null;
    }
    final segments = uri.pathSegments;
    final index = segments.indexOf('Audio');
    if (index == -1 || index + 1 >= segments.length) {
      return null;
    }
    return segments[index + 1];
  }

  String _key(String key, [String? scope]) => _scopedKey(key, scope ?? _scope);

  String _scopedKey(String key, String? scope) =>
      scope == null ? key : '$key.$scope';

  Map<String, dynamic> _readJsonMap(String? raw) {
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  List<dynamic> _readJsonList(String? raw) {
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  Future<void> _copyPreferenceValue(
    SharedPreferences preferences,
    String key,
    Object value,
  ) async {
    if (value is String) {
      await preferences.setString(key, value);
    } else if (value is int) {
      await preferences.setInt(key, value);
    } else if (value is bool) {
      await preferences.setBool(key, value);
    } else if (value is double) {
      await preferences.setDouble(key, value);
    } else if (value is List<String>) {
      await preferences.setStringList(key, value);
    }
  }

  /// Persists playlists for offline use.
  Future<void> savePlaylists(List<Playlist> playlists) async {
    final scope = _scope;
    final preferences = await SharedPreferences.getInstance();
    final payload = playlists.map((playlist) => playlist.toJson()).toList();
    await preferences.setString(
        _key(_playlistsKey, scope), jsonEncode(payload));
  }

  /// Loads cached playlists, if any exist.
  Future<List<Playlist>> loadPlaylists() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_playlistsKey));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => Playlist.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  /// Persists playlist tracks to the cache.
  Future<void> savePlaylistTracks(
    String playlistId,
    List<MediaItem> tracks,
  ) async {
    final scope = _scope;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_tracksKey, scope));
    final Map<String, dynamic> decoded = raw == null || raw.isEmpty
        ? {}
        : jsonDecode(raw) as Map<String, dynamic>;
    decoded[playlistId] = tracks.map((track) => track.toJson()).toList();
    await preferences.setString(_key(_tracksKey, scope), jsonEncode(decoded));
  }

  /// Returns cached tracks for a playlist.
  Future<List<MediaItem>> loadPlaylistTracks(String playlistId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_tracksKey));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final items = decoded[playlistId] as List<dynamic>?;
    if (items == null) {
      return [];
    }
    return items
        .map((entry) => MediaItem.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  /// Persists featured tracks for the home screen.
  Future<void> saveFeaturedTracks(List<MediaItem> tracks) async {
    final scope = _scope;
    final preferences = await SharedPreferences.getInstance();
    final payload = tracks.map((track) => track.toJson()).toList();
    await preferences.setString(_key(_featuredKey, scope), jsonEncode(payload));
  }

  /// Loads cached featured tracks.
  Future<List<MediaItem>> loadFeaturedTracks() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_featuredKey));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => MediaItem.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  /// Persists albums for offline use.
  Future<void> saveAlbums(List<Album> albums) async {
    final scope = _scope;
    final preferences = await SharedPreferences.getInstance();
    final payload = albums.map((album) => album.toJson()).toList();
    await preferences.setString(_key(_albumsKey, scope), jsonEncode(payload));
  }

  /// Loads cached albums.
  Future<List<Album>> loadAlbums() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_albumsKey));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => Album.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  /// Persists the newest albums shown on the Home screen.
  Future<void> saveRecentlyAddedAlbums(List<Album> albums) async {
    final scope = _scope;
    final preferences = await SharedPreferences.getInstance();
    final payload = albums.map((album) => album.toJson()).toList();
    await preferences.setString(
      _key(_recentlyAddedAlbumsKey, scope),
      jsonEncode(payload),
    );
  }

  /// Loads the cached newest albums shown on the Home screen.
  Future<List<Album>> loadRecentlyAddedAlbums() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_recentlyAddedAlbumsKey));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => Album.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  /// Persists artists for offline use.
  Future<void> saveArtists(List<Artist> artists) async {
    final scope = _scope;
    final preferences = await SharedPreferences.getInstance();
    final payload = artists.map((artist) => artist.toJson()).toList();
    await preferences.setString(_key(_artistsKey, scope), jsonEncode(payload));
  }

  /// Loads cached artists.
  Future<List<Artist>> loadArtists() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_artistsKey));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => Artist.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  /// Persists genres for offline use.
  Future<void> saveGenres(List<Genre> genres) async {
    final scope = _scope;
    final preferences = await SharedPreferences.getInstance();
    final payload = genres.map((genre) => genre.toJson()).toList();
    await preferences.setString(_key(_genresKey, scope), jsonEncode(payload));
  }

  /// Loads cached genres.
  Future<List<Genre>> loadGenres() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_genresKey));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => Genre.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  /// Persists album tracks to the cache.
  Future<void> saveAlbumTracks(
    String albumId,
    List<MediaItem> tracks,
  ) async {
    await _saveTrackMap(_albumTracksKey, albumId, tracks);
  }

  /// Loads cached album tracks.
  Future<List<MediaItem>> loadAlbumTracks(String albumId) async {
    return _loadTrackMap(_albumTracksKey, albumId);
  }

  /// Persists artist tracks to the cache.
  Future<void> saveArtistTracks(
    String artistId,
    List<MediaItem> tracks,
  ) async {
    await _saveTrackMap(_artistTracksKey, artistId, tracks);
  }

  /// Loads cached artist tracks.
  Future<List<MediaItem>> loadArtistTracks(String artistId) async {
    return _loadTrackMap(_artistTracksKey, artistId);
  }

  /// Persists genre tracks to the cache.
  Future<void> saveGenreTracks(
    String genreId,
    List<MediaItem> tracks,
  ) async {
    await _saveTrackMap(_genreTracksKey, genreId, tracks);
  }

  /// Loads cached genre tracks.
  Future<List<MediaItem>> loadGenreTracks(String genreId) async {
    return _loadTrackMap(_genreTracksKey, genreId);
  }

  /// Persists favorite albums for quick access.
  Future<void> saveFavoriteAlbums(List<Album> albums) async {
    final scope = _scope;
    final preferences = await SharedPreferences.getInstance();
    final payload = albums.map((album) => album.toJson()).toList();
    await preferences.setString(
      _key(_favoriteAlbumsKey, scope),
      jsonEncode(payload),
    );
  }

  /// Loads cached favorite albums.
  Future<List<Album>> loadFavoriteAlbums() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_favoriteAlbumsKey));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => Album.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  /// Persists favorite artists.
  Future<void> saveFavoriteArtists(List<Artist> artists) async {
    final scope = _scope;
    final preferences = await SharedPreferences.getInstance();
    final payload = artists.map((artist) => artist.toJson()).toList();
    await preferences.setString(
      _key(_favoriteArtistsKey, scope),
      jsonEncode(payload),
    );
  }

  /// Loads cached favorite artists.
  Future<List<Artist>> loadFavoriteArtists() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_favoriteArtistsKey));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => Artist.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  /// Persists favorite tracks.
  Future<void> saveFavoriteTracks(List<MediaItem> tracks) async {
    final scope = _scope;
    final preferences = await SharedPreferences.getInstance();
    final payload = tracks.map((track) => track.toJson()).toList();
    await preferences.setString(
      _key(_favoriteTracksKey, scope),
      jsonEncode(payload),
    );
  }

  /// Loads cached favorite tracks.
  Future<List<MediaItem>> loadFavoriteTracks() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_favoriteTracksKey));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => MediaItem.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  /// Persists a complete library track snapshot for Smart List evaluation.
  Future<void> saveLibraryTracks(List<MediaItem> tracks) async {
    final scope = _scope;
    final preferences = await SharedPreferences.getInstance();
    final payload = tracks.map((track) => track.toJson()).toList();
    await preferences.setString(
      _key(_libraryTracksKey, scope),
      jsonEncode(payload),
    );
  }

  /// Loads the cached complete library track snapshot.
  Future<List<MediaItem>> loadLibraryTracks() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_libraryTracksKey));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => MediaItem.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  /// Persists recent tracks for the home shelf.
  Future<void> saveRecentTracks(List<MediaItem> tracks) async {
    final scope = _scope;
    final preferences = await SharedPreferences.getInstance();
    final payload = tracks.map((track) => track.toJson()).toList();
    await preferences.setString(
        _key(_recentTracksKey, scope), jsonEncode(payload));
  }

  /// Loads cached recent tracks.
  Future<List<MediaItem>> loadRecentTracks() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_recentTracksKey));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => MediaItem.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  /// Persists playback history.
  Future<void> savePlayHistory(List<MediaItem> tracks) async {
    final scope = _scope;
    final preferences = await SharedPreferences.getInstance();
    final payload = tracks.map((track) => track.toJson()).toList();
    await preferences.setString(
      _key(_playHistoryKey, scope),
      jsonEncode(payload),
    );
  }

  /// Persists the last known playback state for resume.
  Future<void> savePlaybackResumeState(PlaybackResumeState? state) async {
    final scope = _scope;
    final preferences = await SharedPreferences.getInstance();
    if (state == null) {
      await preferences.remove(_key(_playbackResumeKey, scope));
      return;
    }
    await preferences.setString(
      _key(_playbackResumeKey, scope),
      jsonEncode(state.toJson()),
    );
  }

  /// Loads the last known playback state for resume.
  Future<PlaybackResumeState?> loadPlaybackResumeState() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_playbackResumeKey));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return PlaybackResumeState.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  /// Loads cached playback history.
  Future<List<MediaItem>> loadPlayHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_playHistoryKey));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => MediaItem.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  /// Persists library statistics for the home screen.
  Future<void> saveLibraryStats(LibraryStats stats) async {
    final scope = _scope;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(_libraryStatsKey, scope),
      jsonEncode(stats.toJson()),
    );
  }

  /// Loads cached library stats.
  Future<LibraryStats?> loadLibraryStats() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_libraryStatsKey));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return LibraryStats.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  /// Returns a cached audio file if present.
  Future<File?> getCachedAudio(MediaItem item, {bool touch = false}) async {
    final scope = _scope;
    final cached = await _getAudioCacheInfoForItem(item, scope: scope);
    if (touch && cached != null) {
      await _rememberCachedAudio(item, scope: scope);
    }
    return cached?.file;
  }

  /// Returns true when the audio is cached on disk.
  Future<bool> isAudioCached(MediaItem item) async {
    final scope = _scope;
    final cached = await _getAudioCacheInfoForItem(item, scope: scope);
    return cached != null;
  }

  /// Downloads audio for offline-ready playback.
  Future<void> prefetchAudio(
    MediaItem item, {
    Map<String, String>? headers,
  }) async {
    final scope = _scope;
    final cacheKey = _audioKeyForStreamUrl(item.streamUrl, scope);
    try {
      await _audioCache.downloadFile(
        item.streamUrl,
        key: cacheKey,
        authHeaders: headers,
      );
      await _rememberCachedAudio(item, scope: scope);
      await enforceCacheLimit(scope: scope);
    } catch (e) {
      final log = await LogService.instance;
      await log.warning('prefetchAudio failed for "${item.title}": $e');
    }
  }

  /// Streams a download with progress updates and caches the result.
  Stream<FileResponse> downloadAudioWithProgress(
    MediaItem item, {
    Map<String, String>? headers,
  }) async* {
    final scope = _scope;
    final stream = _audioCache.getFileStream(
      item.streamUrl,
      key: _audioKeyForStreamUrl(item.streamUrl, scope),
      headers: headers,
      withProgress: true,
    );
    await for (final response in stream) {
      if (response is FileInfo) {
        await _rememberCachedAudio(item, scope: scope);
        await enforceCacheLimit(scope: scope);
      }
      yield response;
    }
  }

  /// Updates the LRU timestamp for a cached track.
  Future<void> touchCachedAudio(MediaItem item) async {
    final scope = _scope;
    final cached = await _getAudioCacheInfoForItem(item, scope: scope);
    if (cached == null) {
      return;
    }
    await _rememberCachedAudio(item, scope: scope);
  }

  /// Prefetches the next track in the queue, when available.
  Future<void> prefetchNextFromQueue(
    List<MediaItem> queue,
    int currentIndex, {
    Map<String, String>? headers,
  }) async {
    final nextIndex = currentIndex + 1;
    if (nextIndex < 0 || nextIndex >= queue.length) {
      return;
    }
    final next = queue[nextIndex];
    if (await isAudioCached(next)) {
      return;
    }
    await prefetchAudio(next, headers: headers);
  }

  /// Handles cache updates when playback advances.
  Future<void> handlePlaybackAdvance(
    List<MediaItem> queue,
    int currentIndex, {
    Map<String, String>? headers,
  }) async {
    if (currentIndex < 0 || currentIndex >= queue.length) {
      return;
    }
    final current = queue[currentIndex];
    await touchCachedAudio(current);
    await prefetchNextFromQueue(queue, currentIndex, headers: headers);
  }

  /// Clears cached metadata for library lists and tracks.
  Future<void> clearMetadata() async {
    final scope = _scope;
    await _clearMetadataForScope(scope);
  }

  Future<void> _clearMetadataForScope(String? scope) async {
    final preferences = await SharedPreferences.getInstance();
    for (final key in [
      _playlistsKey,
      _tracksKey,
      _featuredKey,
      _albumsKey,
      _recentlyAddedAlbumsKey,
      _artistsKey,
      _genresKey,
      _albumTracksKey,
      _artistTracksKey,
      _genreTracksKey,
      _favoriteAlbumsKey,
      _favoriteArtistsKey,
      _favoriteTracksKey,
      _libraryTracksKey,
      _recentTracksKey,
      _playHistoryKey,
      _libraryStatsKey,
      _playbackResumeKey,
    ]) {
      await preferences.remove(_key(key, scope));
    }
  }

  /// Clears cached audio files.
  Future<void> clearAudioCache() async {
    final scope = _scope;
    await _clearAudioCacheForScope(scope);
  }

  Future<void> _clearAudioCacheForScope(String? scope) async {
    final entries = await _loadCachedAudioEntriesForScope(scope);
    for (final entry in entries) {
      await _deleteAudioFile(
        entry.streamUrl,
        legacyCacheKey: entry.legacyCacheKey,
      );
    }
    await _saveCachedAudioEntries(const {}, scope: scope);
  }

  /// Clears cached audio plus offline pin metadata for account sign-out.
  Future<void> clearOfflineAudioState() async {
    final scope = _scope;
    await _clearOfflineAudioStateForScope(scope);
  }

  Future<void> _clearOfflineAudioStateForScope(String? scope) async {
    await _clearAudioCacheForScope(scope);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(_pinnedAudioKey, scope));
    await preferences.remove(_key(_pinnedAudioItemsKey, scope));
    await preferences.remove(_key(_wholeLibraryPinnedAudioKey, scope));
  }

  /// Returns the approximate size of cached media on disk.
  Future<int> getMediaCacheBytes() async {
    final scope = _scope;
    final entries = await _loadCachedAudioEntriesForScope(scope);
    return entries.fold<int>(0, (sum, entry) => sum + entry.bytes);
  }

  /// Returns the total bytes used by pinned tracks.
  Future<int> getPinnedMediaBytes(Set<String> pinnedAudio) async {
    if (pinnedAudio.isEmpty) {
      return 0;
    }
    final scope = _scope;
    final entries = await _loadCachedAudioEntriesForScope(scope);
    return entries
        .where((entry) => pinnedAudio.contains(entry.streamUrl))
        .fold<int>(0, (sum, entry) => sum + entry.bytes);
  }

  /// Loads the configured cache size limit.
  Future<int> loadCacheMaxBytes() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getInt(_cachedAudioLimitKey);
    if (stored != null && stored >= 0) {
      return stored;
    }
    await preferences.setInt(_cachedAudioLimitKey, defaultCacheMaxBytes);
    return defaultCacheMaxBytes;
  }

  /// Saves the configured cache size limit.
  Future<void> saveCacheMaxBytes(int bytes) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_cachedAudioLimitKey, bytes);
    await enforceCacheLimit(maxBytes: bytes);
  }

  /// Returns a list of cached audio entries with metadata.
  Future<List<CachedAudioEntry>> loadCachedAudioEntries() async {
    final scope = _scope;
    return _loadCachedAudioEntriesForScope(scope);
  }

  Future<List<CachedAudioEntry>> _loadCachedAudioEntriesForScope(
    String? scope,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_cachedAudioKey, scope));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final entries = <CachedAudioEntry>[];
    final toRemove = <String>[];

    for (final entry in decoded.entries) {
      final value = entry.value is Map
          ? Map<String, dynamic>.from(entry.value as Map)
          : null;
      if (value == null) {
        toRemove.add(entry.key);
        continue;
      }
      final legacyCacheKey = value[_legacyCacheKeyField] as String?;
      final cacheInfo = await _getAudioCacheInfo(entry.key) ??
          (legacyCacheKey == null
              ? null
              : await _getAudioCacheInfo(legacyCacheKey));
      if (cacheInfo == null) {
        toRemove.add(entry.key);
        continue;
      }
      final bytes = await cacheInfo.file.length();
      final mediaItem = _mediaItemFromCachedPayload(value);
      final artists = (value['artists'] as List<dynamic>? ?? const [])
          .map((artist) => artist.toString())
          .toList();
      final cachedAt = DateTime.tryParse(
            value['cachedAt']?.toString() ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      entries.add(
        CachedAudioEntry(
          streamUrl: entry.key,
          title: value['title'] as String? ?? 'Unknown Track',
          album: value['album'] as String? ?? 'Unknown Album',
          artists: artists,
          cachedAt: cachedAt,
          bytes: bytes,
          mediaItem: mediaItem,
          legacyCacheKey: legacyCacheKey,
        ),
      );
    }

    if (toRemove.isNotEmpty) {
      for (final key in toRemove) {
        decoded.remove(key);
      }
      await _saveCachedAudioEntries(decoded, scope: scope);
    }

    entries.sort((a, b) => b.cachedAt.compareTo(a.cachedAt));
    return entries;
  }

  /// Removes a cached audio entry and evicts the file.
  Future<void> evictCachedAudio(String streamUrl) async {
    final scope = _scope;
    CachedAudioEntry? entry;
    for (final candidate in await _loadCachedAudioEntriesForScope(scope)) {
      if (candidate.streamUrl == streamUrl) {
        entry = candidate;
        break;
      }
    }
    await _deleteAudioFile(streamUrl, legacyCacheKey: entry?.legacyCacheKey);
    await _forgetCachedAudio(streamUrl, scope: scope);
  }

  /// Enforces the cache size limit using LRU eviction.
  Future<void> enforceCacheLimit({int? maxBytes, String? scope}) async {
    final cacheScope = scope ?? _scope;
    final limit = maxBytes ?? await loadCacheMaxBytes();
    if (limit <= 0) {
      return;
    }
    final entries = await _loadCachedAudioEntriesForScope(cacheScope);
    final pinned = await _loadPinnedAudio(scope: cacheScope);
    if (entries.isEmpty) {
      return;
    }
    var total = entries.fold<int>(0, (sum, entry) => sum + entry.bytes);
    if (total <= limit) {
      return;
    }
    entries.sort((a, b) => a.cachedAt.compareTo(b.cachedAt));
    final toRemove = <CachedAudioEntry>[];
    for (final entry in entries) {
      if (pinned.contains(entry.streamUrl)) {
        continue;
      }
      toRemove.add(entry);
      total -= entry.bytes;
      if (total <= limit) {
        break;
      }
    }
    if (toRemove.isEmpty) {
      return;
    }
    for (final entry in toRemove) {
      await _deleteAudioFile(
        entry.streamUrl,
        legacyCacheKey: entry.legacyCacheKey,
      );
    }
    await _forgetCachedAudioEntries(
      toRemove.map((entry) => entry.streamUrl).toSet(),
      scope: cacheScope,
    );
  }

  Future<void> _deleteAudioFile(
    String streamUrl, {
    String? legacyCacheKey,
  }) async {
    for (final key in {streamUrl, if (legacyCacheKey != null) legacyCacheKey}) {
      File? cachedFile;
      try {
        cachedFile = (await _getAudioCacheInfo(key))?.file;
      } catch (_) {}
      try {
        await _audioCache.removeFile(key);
      } catch (_) {}
      if (cachedFile != null) {
        try {
          if (await cachedFile.exists()) {
            await cachedFile.delete();
          }
        } catch (_) {
          // Ignore failures clearing the on-disk cache directory.
        }
      }
    }
  }

  /// Returns the directory used by the media cache.
  Future<Directory> getMediaCacheDirectory() async {
    final baseDir = await getTemporaryDirectory();
    final cacheKey = _audioCache.config.cacheKey;
    return Directory('${baseDir.path}${Platform.pathSeparator}$cacheKey');
  }

  /// Opens the cached media directory in the OS file manager.
  Future<void> openMediaCacheLocation() async {
    try {
      final directory = await getMediaCacheDirectory();
      await directory.create(recursive: true);
      if (Platform.isMacOS) {
        await Process.run('open', [directory.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [directory.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [directory.path]);
      }
    } catch (_) {
      // Ignore failures to open system file manager.
    }
  }

  Future<void> _saveTrackMap(
    String key,
    String id,
    List<MediaItem> tracks,
  ) async {
    final scope = _scope;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(key, scope));
    final Map<String, dynamic> decoded = raw == null || raw.isEmpty
        ? {}
        : jsonDecode(raw) as Map<String, dynamic>;
    decoded[id] = tracks.map((track) => track.toJson()).toList();
    await preferences.setString(_key(key, scope), jsonEncode(decoded));
  }

  Future<List<MediaItem>> _loadTrackMap(String key, String id) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(key));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final items = decoded[id] as List<dynamic>?;
    if (items == null) {
      return [];
    }
    return items
        .map((entry) => MediaItem.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<void> _rememberCachedAudio(
    MediaItem item, {
    String? scope,
  }) async {
    final cacheScope = scope ?? _scope;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_cachedAudioKey, cacheScope));
    final Map<String, dynamic> decoded = raw == null || raw.isEmpty
        ? {}
        : jsonDecode(raw) as Map<String, dynamic>;
    final cacheKey = _audioKeyForStreamUrl(item.streamUrl, cacheScope);
    final existing = decoded[cacheKey];
    decoded[cacheKey] = {
      if (existing is Map && existing[_legacyCacheKeyField] is String)
        _legacyCacheKeyField: existing[_legacyCacheKeyField],
      'title': item.title,
      'album': item.album,
      'artists': item.artists,
      'mediaItem': item.toJson(),
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await _saveCachedAudioEntries(decoded, scope: cacheScope);
  }

  Future<FileInfo?> _getAudioCacheInfo(String streamUrl) async {
    return _audioCache.getFileFromCache(streamUrl);
  }

  Future<FileInfo?> _getAudioCacheInfoForItem(
    MediaItem item, {
    String? scope,
  }) async {
    final cacheScope = scope ?? _scope;
    final cacheKey = _audioKeyForStreamUrl(item.streamUrl, cacheScope);
    final cached = await _getAudioCacheInfo(cacheKey);
    if (cached != null) {
      return cached;
    }
    final entries = _readJsonMap(
      (await SharedPreferences.getInstance())
          .getString(_key(_cachedAudioKey, cacheScope)),
    );
    final entry = entries[cacheKey];
    if (entry is! Map) {
      return null;
    }
    final legacyCacheKey = entry[_legacyCacheKeyField] as String?;
    return legacyCacheKey == null ? null : _getAudioCacheInfo(legacyCacheKey);
  }

  MediaItem? _mediaItemFromCachedPayload(Map<String, dynamic> payload) {
    final raw = payload['mediaItem'];
    if (raw is! Map) {
      return null;
    }
    try {
      return MediaItem.fromJson(raw.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> _forgetCachedAudio(
    String streamUrl, {
    String? scope,
  }) async {
    final cacheScope = scope ?? _scope;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_cachedAudioKey, cacheScope));
    if (raw == null || raw.isEmpty) {
      return;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    decoded.remove(streamUrl);
    await _saveCachedAudioEntries(decoded, scope: cacheScope);
  }

  Future<Set<String>> _loadPinnedAudio({String? scope}) async {
    final cacheScope = scope ?? _scope;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_pinnedAudioKey, cacheScope));
    if (raw == null || raw.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((entry) => entry.toString()).toSet();
  }

  Future<void> _savePinnedAudio(Set<String> urls, {String? scope}) async {
    final cacheScope = scope ?? _scope;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(_pinnedAudioKey, cacheScope),
      jsonEncode(
        urls
            .map((url) => _audioKeyForStreamUrl(url, cacheScope))
            .toSet()
            .toList(),
      ),
    );
  }

  /// Pins or unpins a cached track for offline use.
  Future<void> setPinnedAudio(String streamUrl, bool pinned) async {
    final scope = _scope;
    await _setPinnedAudio(streamUrl, pinned, scope: scope);
  }

  Future<void> _setPinnedAudio(
    String streamUrl,
    bool pinned, {
    required String? scope,
  }) async {
    final cacheKey = _audioKeyForStreamUrl(streamUrl, scope);
    final current = await _loadPinnedAudio(scope: scope);
    if (pinned) {
      current.add(cacheKey);
    } else {
      current.remove(cacheKey);
      await _forgetPinnedAudioItem(cacheKey, scope: scope);
    }
    await _savePinnedAudio(current, scope: scope);
  }

  /// Pins or unpins a track and persists enough metadata to resume downloads.
  Future<void> setPinnedAudioItem(MediaItem item, bool pinned) async {
    final scope = _scope;
    await _setPinnedAudio(item.streamUrl, pinned, scope: scope);
    if (!pinned) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_pinnedAudioItemsKey, scope));
    final Map<String, dynamic> decoded = raw == null || raw.isEmpty
        ? {}
        : jsonDecode(raw) as Map<String, dynamic>;
    decoded[_audioKeyForStreamUrl(item.streamUrl, scope)] = item.toJson();
    await preferences.setString(
      _key(_pinnedAudioItemsKey, scope),
      jsonEncode(decoded),
    );
  }

  /// Returns whether a track is pinned for offline playback.
  Future<bool> isPinnedAudio(String streamUrl) async {
    final scope = _scope;
    final pinned = await _loadPinnedAudio(scope: scope);
    return pinned.contains(_audioKeyForStreamUrl(streamUrl, scope));
  }

  /// Loads pinned track URLs for offline playback.
  Future<Set<String>> loadPinnedAudio() async {
    final scope = _scope;
    return _loadPinnedAudio(scope: scope);
  }

  /// Loads metadata for tracks that are pinned for offline playback.
  Future<List<MediaItem>> loadPinnedAudioItems() async {
    final scope = _scope;
    final pinned = await _loadPinnedAudio(scope: scope);
    if (pinned.isEmpty) {
      return [];
    }
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_pinnedAudioItemsKey, scope));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final items = <MediaItem>[];
    final toRemove = <String>[];
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map) {
        toRemove.add(entry.key);
        continue;
      }
      try {
        items.add(MediaItem.fromJson(value.cast<String, dynamic>()));
      } catch (_) {
        toRemove.add(entry.key);
      }
    }
    if (toRemove.isNotEmpty) {
      for (final key in toRemove) {
        decoded.remove(key);
      }
      await preferences.setString(
        _key(_pinnedAudioItemsKey, scope),
        jsonEncode(decoded),
      );
    }
    return items;
  }

  /// Saves metadata for pinned tracks in one pass.
  Future<void> savePinnedAudioItems(Iterable<MediaItem> items) async {
    final scope = _scope;
    final normalized = items.toList(growable: false);
    if (normalized.isEmpty) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_pinnedAudioItemsKey, scope));
    final Map<String, dynamic> decoded = raw == null || raw.isEmpty
        ? {}
        : jsonDecode(raw) as Map<String, dynamic>;
    for (final item in normalized) {
      decoded[_audioKeyForStreamUrl(item.streamUrl, scope)] = item.toJson();
    }
    await preferences.setString(
      _key(_pinnedAudioItemsKey, scope),
      jsonEncode(decoded),
    );
  }

  /// Replaces pinned track URLs after canonicalization or migration.
  Future<void> savePinnedAudio(Set<String> urls) async {
    final scope = _scope;
    await _savePinnedAudio(urls, scope: scope);
  }

  /// Removes pinned track metadata in one pass.
  Future<void> forgetPinnedAudioItems(Iterable<String> streamUrls) async {
    final scope = _scope;
    final urls = streamUrls
        .map((streamUrl) => _audioKeyForStreamUrl(streamUrl, scope))
        .toSet();
    if (urls.isEmpty) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_pinnedAudioItemsKey, scope));
    if (raw == null || raw.isEmpty) {
      return;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    for (final streamUrl in urls) {
      decoded.remove(streamUrl);
    }
    await preferences.setString(
      _key(_pinnedAudioItemsKey, scope),
      jsonEncode(decoded),
    );
  }

  Future<Set<String>> _loadWholeLibraryPinnedAudio({String? scope}) async {
    final cacheScope = scope ?? _scope;
    final preferences = await SharedPreferences.getInstance();
    final raw =
        preferences.getString(_key(_wholeLibraryPinnedAudioKey, cacheScope));
    if (raw == null || raw.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((entry) => entry.toString()).toSet();
  }

  Future<void> _saveWholeLibraryPinnedAudio(
    Set<String> urls, {
    String? scope,
  }) async {
    final cacheScope = scope ?? _scope;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(_wholeLibraryPinnedAudioKey, cacheScope),
      jsonEncode(
        urls
            .map((streamUrl) => _audioKeyForStreamUrl(streamUrl, cacheScope))
            .toSet()
            .toList(),
      ),
    );
  }

  /// Tracks pins created by the whole-library offline action.
  Future<void> setWholeLibraryPinnedAudio(String streamUrl, bool pinned) async {
    final scope = _scope;
    final cacheKey = _audioKeyForStreamUrl(streamUrl, scope);
    final current = await _loadWholeLibraryPinnedAudio(scope: scope);
    if (pinned) {
      current.add(cacheKey);
    } else {
      current.remove(cacheKey);
    }
    await _saveWholeLibraryPinnedAudio(current, scope: scope);
  }

  /// Loads pins created by the whole-library offline action.
  Future<Set<String>> loadWholeLibraryPinnedAudio() async {
    final scope = _scope;
    return _loadWholeLibraryPinnedAudio(scope: scope);
  }

  /// Replaces the set of pins created by the whole-library offline action.
  Future<void> saveWholeLibraryPinnedAudio(Set<String> urls) async {
    final scope = _scope;
    await _saveWholeLibraryPinnedAudio(urls, scope: scope);
  }

  Future<void> _forgetPinnedAudioItem(
    String streamUrl, {
    String? scope,
  }) async {
    final cacheScope = scope ?? _scope;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_pinnedAudioItemsKey, cacheScope));
    if (raw == null || raw.isEmpty) {
      return;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    decoded.remove(_audioKeyForStreamUrl(streamUrl, cacheScope));
    await preferences.setString(
      _key(_pinnedAudioItemsKey, cacheScope),
      jsonEncode(decoded),
    );
  }

  Future<void> _forgetCachedAudioEntries(
    Set<String> streamUrls, {
    String? scope,
  }) async {
    if (streamUrls.isEmpty) {
      return;
    }
    final cacheScope = scope ?? _scope;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(_cachedAudioKey, cacheScope));
    if (raw == null || raw.isEmpty) {
      return;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    for (final url in streamUrls) {
      decoded.remove(url);
    }
    await _saveCachedAudioEntries(decoded, scope: cacheScope);
  }

  Future<void> _saveCachedAudioEntries(
    Map<String, dynamic> entries, {
    String? scope,
  }) async {
    final cacheScope = scope ?? _scope;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(_cachedAudioKey, cacheScope),
      jsonEncode(entries),
    );
  }
}
