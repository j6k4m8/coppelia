/// Aggregated library counts for quick display.
class LibraryStats {
  /// Creates library stats.
  const LibraryStats({
    required this.trackCount,
    required this.albumCount,
    required this.artistCount,
    required this.playlistCount,
  });

  /// Total tracks in the library.
  final int trackCount;

  /// Total albums in the library.
  final int albumCount;

  /// Total artists in the library.
  final int artistCount;

  /// Total playlists in the library.
  final int playlistCount;

  /// Serializes this instance for caching.
  Map<String, dynamic> toJson() => {
        'trackCount': trackCount,
        'albumCount': albumCount,
        'artistCount': artistCount,
        'playlistCount': playlistCount,
      };

  /// Restores stats from cached JSON.
  factory LibraryStats.fromJson(Map<String, dynamic> json) => LibraryStats(
        trackCount: json['trackCount'] as int? ?? 0,
        albumCount: json['albumCount'] as int? ?? 0,
        artistCount: json['artistCount'] as int? ?? 0,
        playlistCount: json['playlistCount'] as int? ?? 0,
      );
}
