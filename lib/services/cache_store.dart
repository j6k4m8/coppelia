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

/// Manages cached metadata and audio assets.
class CacheStore {
  /// Creates a cache manager instance.
  CacheStore();

  static const _playlistsKey = 'cached_playlists';
  static const _tracksKey = 'cached_playlist_tracks';
  static const _featuredKey = 'cached_featured_tracks';
  static const _albumsKey = 'cached_albums';
  static const _artistsKey = 'cached_artists';
  static const _genresKey = 'cached_genres';
  static const _albumTracksKey = 'cached_album_tracks';
  static const _artistTracksKey = 'cached_artist_tracks';
  static const _genreTracksKey = 'cached_genre_tracks';
  static const _favoriteAlbumsKey = 'cached_favorite_albums';
  static const _favoriteArtistsKey = 'cached_favorite_artists';
  static const _favoriteTracksKey = 'cached_favorite_tracks';
  static const _recentTracksKey = 'cached_recent_tracks';
  static const _playHistoryKey = 'cached_play_history';
  static const _libraryStatsKey = 'cached_library_stats';
  static const _cachedAudioKey = 'cached_audio_entries';
  static const _playbackResumeKey = 'cached_playback_resume';

  final DefaultCacheManager _audioCache = DefaultCacheManager();

  /// Persists playlists for offline use.
  Future<void> savePlaylists(List<Playlist> playlists) async {
    final preferences = await SharedPreferences.getInstance();
    final payload = playlists.map((playlist) => playlist.toJson()).toList();
    await preferences.setString(_playlistsKey, jsonEncode(payload));
  }

  /// Loads cached playlists, if any exist.
  Future<List<Playlist>> loadPlaylists() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_playlistsKey);
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
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_tracksKey);
    final Map<String, dynamic> decoded = raw == null || raw.isEmpty
        ? {}
        : jsonDecode(raw) as Map<String, dynamic>;
    decoded[playlistId] = tracks.map((track) => track.toJson()).toList();
    await preferences.setString(_tracksKey, jsonEncode(decoded));
  }

  /// Returns cached tracks for a playlist.
  Future<List<MediaItem>> loadPlaylistTracks(String playlistId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_tracksKey);
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
    final preferences = await SharedPreferences.getInstance();
    final payload = tracks.map((track) => track.toJson()).toList();
    await preferences.setString(_featuredKey, jsonEncode(payload));
  }

  /// Loads cached featured tracks.
  Future<List<MediaItem>> loadFeaturedTracks() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_featuredKey);
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
    final preferences = await SharedPreferences.getInstance();
    final payload = albums.map((album) => album.toJson()).toList();
    await preferences.setString(_albumsKey, jsonEncode(payload));
  }

  /// Loads cached albums.
  Future<List<Album>> loadAlbums() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_albumsKey);
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
    final preferences = await SharedPreferences.getInstance();
    final payload = artists.map((artist) => artist.toJson()).toList();
    await preferences.setString(_artistsKey, jsonEncode(payload));
  }

  /// Loads cached artists.
  Future<List<Artist>> loadArtists() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_artistsKey);
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
    final preferences = await SharedPreferences.getInstance();
    final payload = genres.map((genre) => genre.toJson()).toList();
    await preferences.setString(_genresKey, jsonEncode(payload));
  }

  /// Loads cached genres.
  Future<List<Genre>> loadGenres() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_genresKey);
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
    final preferences = await SharedPreferences.getInstance();
    final payload = albums.map((album) => album.toJson()).toList();
    await preferences.setString(_favoriteAlbumsKey, jsonEncode(payload));
  }

  /// Loads cached favorite albums.
  Future<List<Album>> loadFavoriteAlbums() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_favoriteAlbumsKey);
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
    final preferences = await SharedPreferences.getInstance();
    final payload = artists.map((artist) => artist.toJson()).toList();
    await preferences.setString(_favoriteArtistsKey, jsonEncode(payload));
  }

  /// Loads cached favorite artists.
  Future<List<Artist>> loadFavoriteArtists() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_favoriteArtistsKey);
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
    final preferences = await SharedPreferences.getInstance();
    final payload = tracks.map((track) => track.toJson()).toList();
    await preferences.setString(_favoriteTracksKey, jsonEncode(payload));
  }

  /// Loads cached favorite tracks.
  Future<List<MediaItem>> loadFavoriteTracks() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_favoriteTracksKey);
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
    final preferences = await SharedPreferences.getInstance();
    final payload = tracks.map((track) => track.toJson()).toList();
    await preferences.setString(_recentTracksKey, jsonEncode(payload));
  }

  /// Loads cached recent tracks.
  Future<List<MediaItem>> loadRecentTracks() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_recentTracksKey);
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
    final preferences = await SharedPreferences.getInstance();
    final payload = tracks.map((track) => track.toJson()).toList();
    await preferences.setString(_playHistoryKey, jsonEncode(payload));
  }

  /// Persists the last known playback state for resume.
  Future<void> savePlaybackResumeState(PlaybackResumeState? state) async {
    final preferences = await SharedPreferences.getInstance();
    if (state == null) {
      await preferences.remove(_playbackResumeKey);
      return;
    }
    await preferences.setString(
      _playbackResumeKey,
      jsonEncode(state.toJson()),
    );
  }

  /// Loads the last known playback state for resume.
  Future<PlaybackResumeState?> loadPlaybackResumeState() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_playbackResumeKey);
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
    final raw = preferences.getString(_playHistoryKey);
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
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_libraryStatsKey, jsonEncode(stats.toJson()));
  }

  /// Loads cached library stats.
  Future<LibraryStats?> loadLibraryStats() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_libraryStatsKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return LibraryStats.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  /// Returns a cached audio file if present.
  Future<File?> getCachedAudio(MediaItem item) async {
    final cached = await _audioCache.getFileFromCache(item.streamUrl);
    return cached?.file;
  }

  /// Downloads audio for offline-ready playback.
  Future<void> prefetchAudio(MediaItem item) async {
    try {
      await _audioCache.downloadFile(item.streamUrl);
      await _rememberCachedAudio(item);
    } catch (_) {
      // Ignore failed prefetch attempts.
    }
  }

  /// Clears cached metadata for library lists and tracks.
  Future<void> clearMetadata() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_playlistsKey);
    await preferences.remove(_tracksKey);
    await preferences.remove(_featuredKey);
    await preferences.remove(_albumsKey);
    await preferences.remove(_artistsKey);
    await preferences.remove(_genresKey);
    await preferences.remove(_albumTracksKey);
    await preferences.remove(_artistTracksKey);
    await preferences.remove(_genreTracksKey);
    await preferences.remove(_favoriteAlbumsKey);
    await preferences.remove(_favoriteArtistsKey);
    await preferences.remove(_favoriteTracksKey);
    await preferences.remove(_recentTracksKey);
    await preferences.remove(_playHistoryKey);
    await preferences.remove(_libraryStatsKey);
    await preferences.remove(_playbackResumeKey);
  }

  /// Clears cached audio files.
  Future<void> clearAudioCache() async {
    await _audioCache.emptyCache();
    await _saveCachedAudioEntries(const {});
  }

  /// Returns the approximate size of cached media on disk.
  Future<int> getMediaCacheBytes() async {
    return _audioCache.store.getCacheSize();
  }

  /// Returns a list of cached audio entries with metadata.
  Future<List<CachedAudioEntry>> loadCachedAudioEntries() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_cachedAudioKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final entries = <CachedAudioEntry>[];
    final toRemove = <String>[];

    for (final entry in decoded.entries) {
      final value = entry.value as Map<String, dynamic>?;
      if (value == null) {
        toRemove.add(entry.key);
        continue;
      }
      final cacheInfo = await _audioCache.getFileFromCache(entry.key);
      if (cacheInfo == null) {
        toRemove.add(entry.key);
        continue;
      }
      final bytes = await cacheInfo.file.length();
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
        ),
      );
    }

    if (toRemove.isNotEmpty) {
      for (final key in toRemove) {
        decoded.remove(key);
      }
      await _saveCachedAudioEntries(decoded);
    }

    entries.sort((a, b) => b.cachedAt.compareTo(a.cachedAt));
    return entries;
  }

  /// Removes a cached audio entry and evicts the file.
  Future<void> evictCachedAudio(String streamUrl) async {
    await _audioCache.removeFile(streamUrl);
    await _forgetCachedAudio(streamUrl);
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
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);
    final Map<String, dynamic> decoded = raw == null || raw.isEmpty
        ? {}
        : jsonDecode(raw) as Map<String, dynamic>;
    decoded[id] = tracks.map((track) => track.toJson()).toList();
    await preferences.setString(key, jsonEncode(decoded));
  }

  Future<List<MediaItem>> _loadTrackMap(String key, String id) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);
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

  Future<void> _rememberCachedAudio(MediaItem item) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_cachedAudioKey);
    final Map<String, dynamic> decoded = raw == null || raw.isEmpty
        ? {}
        : jsonDecode(raw) as Map<String, dynamic>;
    decoded[item.streamUrl] = {
      'title': item.title,
      'album': item.album,
      'artists': item.artists,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await _saveCachedAudioEntries(decoded);
  }

  Future<void> _forgetCachedAudio(String streamUrl) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_cachedAudioKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    decoded.remove(streamUrl);
    await _saveCachedAudioEntries(decoded);
  }

  Future<void> _saveCachedAudioEntries(Map<String, dynamic> entries) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_cachedAudioKey, jsonEncode(entries));
  }
}
