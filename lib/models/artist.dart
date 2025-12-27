/// Represents a Jellyfin artist.
class Artist {
  /// Creates an artist summary.
  const Artist({
    required this.id,
    required this.name,
    required this.albumCount,
    required this.trackCount,
    required this.imageUrl,
  });

  /// Jellyfin artist identifier.
  final String id;

  /// Artist name.
  final String name;

  /// Number of albums for the artist.
  final int albumCount;

  /// Number of tracks for the artist.
  final int trackCount;

  /// Artist image URL.
  final String? imageUrl;

  /// Builds an artist from Jellyfin JSON.
  factory Artist.fromJellyfin(
    Map<String, dynamic> json, {
    required String serverUrl,
  }) {
    final id = json['Id'] as String;
    final imageUrl = json['ImageTags']?['Primary'] != null
        ? '$serverUrl/Items/$id/Images/Primary?fillWidth=500&quality=90'
        : null;
    return Artist(
      id: id,
      name: json['Name'] as String? ?? 'Unknown Artist',
      albumCount: json['AlbumCount'] as int? ?? 0,
      trackCount: json['SongCount'] as int? ?? 0,
      imageUrl: imageUrl,
    );
  }

  /// Serializes this artist for local caching.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'albumCount': albumCount,
        'trackCount': trackCount,
        'imageUrl': imageUrl,
      };

  /// Restores an artist from cached JSON.
  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
        id: json['id'] as String,
        name: json['name'] as String,
        albumCount: json['albumCount'] as int? ?? 0,
        trackCount: json['trackCount'] as int? ?? 0,
        imageUrl: json['imageUrl'] as String?,
      );
}
