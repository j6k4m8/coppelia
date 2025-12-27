import 'dart:convert';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';
import '../models/playlist.dart';

/// Manages cached metadata and audio assets.
class CacheStore {
  /// Creates a cache manager instance.
  CacheStore();

  static const _playlistsKey = 'cached_playlists';
  static const _tracksKey = 'cached_playlist_tracks';
  static const _featuredKey = 'cached_featured_tracks';

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

  /// Returns a cached audio file if present.
  Future<File?> getCachedAudio(MediaItem item) async {
    final cached = await _audioCache.getFileFromCache(item.streamUrl);
    return cached?.file;
  }

  /// Downloads audio for offline-ready playback.
  Future<void> prefetchAudio(MediaItem item) async {
    await _audioCache.downloadFile(item.streamUrl);
  }
}
