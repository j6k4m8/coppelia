/// Represents a Jellyfin album.
class Album {
  /// Creates an album summary.
  const Album({
    required this.id,
    required this.name,
    required this.artistName,
    required this.trackCount,
    required this.imageUrl,
  });

  /// Jellyfin album identifier.
  final String id;

  /// Album name.
  final String name;

  /// Album artist.
  final String artistName;

  /// Number of tracks.
  final int trackCount;

  /// Album art URL.
  final String? imageUrl;

  /// Builds an album from Jellyfin JSON.
  factory Album.fromJellyfin(
    Map<String, dynamic> json, {
    required String serverUrl,
  }) {
    final id = json['Id'] as String;
    final imageUrl = json['ImageTags']?['Primary'] != null
        ? '$serverUrl/Items/$id/Images/Primary?fillWidth=500&quality=90'
        : null;
    final albumArtist = json['AlbumArtist'] as String?;
    final artists = json['AlbumArtists'] as List<dynamic>?;
    final artistName = albumArtist ??
        (artists != null && artists.isNotEmpty
            ? artists.first['Name']?.toString() ?? 'Unknown Artist'
            : 'Unknown Artist');
    return Album(
      id: id,
      name: json['Name'] as String? ?? 'Untitled Album',
      artistName: artistName,
      trackCount: json['ChildCount'] as int? ?? 0,
      imageUrl: imageUrl,
    );
  }

  /// Serializes this album for local caching.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'artistName': artistName,
        'trackCount': trackCount,
        'imageUrl': imageUrl,
      };

  /// Restores an album from cached JSON.
  factory Album.fromJson(Map<String, dynamic> json) => Album(
        id: json['id'] as String,
        name: json['name'] as String,
        artistName: json['artistName'] as String? ?? 'Unknown Artist',
        trackCount: json['trackCount'] as int? ?? 0,
        imageUrl: json['imageUrl'] as String?,
      );
}
