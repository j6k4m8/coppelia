import 'dart:convert';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/genre.dart';
import '../models/library_stats.dart';
import '../models/media_item.dart';
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
    await _audioCache.downloadFile(item.streamUrl);
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
  }

  /// Clears cached audio files.
  Future<void> clearAudioCache() async {
    await _audioCache.emptyCache();
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
}
