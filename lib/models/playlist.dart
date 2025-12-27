/// Represents a user playlist in Jellyfin.
class Playlist {
  /// Creates a playlist summary.
  const Playlist({
    required this.id,
    required this.name,
    required this.trackCount,
    required this.imageUrl,
  });

  /// Jellyfin playlist identifier.
  final String id;

  /// Playlist display name.
  final String name;

  /// Number of tracks in the playlist.
  final int trackCount;

  /// Optional artwork URL.
  final String? imageUrl;

  /// Builds a Playlist from Jellyfin JSON.
  factory Playlist.fromJellyfin(
    Map<String, dynamic> json, {
    required String serverUrl,
  }) {
    final id = json['Id'] as String;
    final imageUrl = json['ImageTags']?['Primary'] != null
        ? '$serverUrl/Items/$id/Images/Primary?fillWidth=500&quality=90'
        : null;
    return Playlist(
      id: id,
      name: json['Name'] as String? ?? 'Playlist',
      trackCount: json['ChildCount'] as int? ?? 0,
      imageUrl: imageUrl,
    );
  }

  /// Serializes this playlist for local caching.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'trackCount': trackCount,
        'imageUrl': imageUrl,
      };

  /// Restores a playlist from cached JSON.
  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        trackCount: json['trackCount'] as int? ?? 0,
        imageUrl: json['imageUrl'] as String?,
      );
}
