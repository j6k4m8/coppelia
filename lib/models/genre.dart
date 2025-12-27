/// Represents a Jellyfin genre.
class Genre {
  /// Creates a genre summary.
  const Genre({
    required this.id,
    required this.name,
    required this.trackCount,
    required this.imageUrl,
  });

  /// Jellyfin genre identifier.
  final String id;

  /// Genre name.
  final String name;

  /// Count of tracks tagged with the genre.
  final int trackCount;

  /// Genre image URL.
  final String? imageUrl;

  /// Builds a genre from Jellyfin JSON.
  factory Genre.fromJellyfin(
    Map<String, dynamic> json, {
    required String serverUrl,
  }) {
    final id = json['Id'] as String;
    final imageUrl = json['ImageTags']?['Primary'] != null
        ? '$serverUrl/Items/$id/Images/Primary?fillWidth=500&quality=90'
        : null;
    return Genre(
      id: id,
      name: json['Name'] as String? ?? 'Unknown Genre',
      trackCount: json['ItemCount'] as int? ?? 0,
      imageUrl: imageUrl,
    );
  }

  /// Serializes this genre for local caching.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'trackCount': trackCount,
        'imageUrl': imageUrl,
      };

  /// Restores a genre from cached JSON.
  factory Genre.fromJson(Map<String, dynamic> json) => Genre(
        id: json['id'] as String,
        name: json['name'] as String,
        trackCount: json['trackCount'] as int? ?? 0,
        imageUrl: json['imageUrl'] as String?,
      );
}
