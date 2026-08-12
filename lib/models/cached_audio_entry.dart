import 'media_item.dart';

/// Represents a cached audio file with metadata.
class CachedAudioEntry {
  /// Creates a cached audio entry.
  const CachedAudioEntry({
    required this.streamUrl,
    required this.title,
    required this.album,
    required this.artists,
    required this.cachedAt,
    required this.bytes,
    this.mediaItem,
    this.legacyCacheKey,
  });

  /// Stream URL used as cache key.
  final String streamUrl;

  /// Track title.
  final String title;

  /// Album name.
  final String album;

  /// Artist names.
  final List<String> artists;

  /// Timestamp for when the entry was cached.
  final DateTime cachedAt;

  /// File size in bytes.
  final int bytes;

  /// Full track metadata captured when the audio was cached.
  final MediaItem? mediaItem;

  /// Original cache-manager key retained while migrating legacy downloads.
  final String? legacyCacheKey;

  /// Returns a user-friendly artist label.
  String get artistLabel =>
      artists.isEmpty ? 'Unknown Artist' : artists.join(', ');
}
