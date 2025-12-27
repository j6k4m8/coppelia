/// Represents an audio track ready for playback.
class MediaItem {
  /// Creates a track record.
  const MediaItem({
    required this.id,
    required this.title,
    required this.album,
    required this.artists,
    required this.duration,
    required this.imageUrl,
    required this.streamUrl,
  });

  /// Jellyfin item identifier.
  final String id;

  /// Track title.
  final String title;

  /// Album title.
  final String album;

  /// Contributing artists.
  final List<String> artists;

  /// Runtime length.
  final Duration duration;

  /// Image URL for album art.
  final String? imageUrl;

  /// Streamable URL for playback.
  final String streamUrl;

  /// User-friendly subtitle.
  String get subtitle => artists.isEmpty ? album : artists.join(', ');

  /// Builds a MediaItem from Jellyfin JSON.
  factory MediaItem.fromJellyfin(
    Map<String, dynamic> json, {
    required String serverUrl,
    required String token,
    required String userId,
    required String deviceId,
  }) {
    final id = json['Id'] as String;
    final runtimeTicks = (json['RunTimeTicks'] as num?)?.toInt() ?? 0;
    final runtime = Duration(milliseconds: runtimeTicks ~/ 10000);
    final imageUrl = json['ImageTags']?['Primary'] != null
        ? '$serverUrl/Items/$id/Images/Primary?fillWidth=500&quality=90'
        : null;
    final streamUri = Uri.parse('$serverUrl/Audio/$id/universal').replace(
      queryParameters: {
        'UserId': userId,
        'DeviceId': deviceId,
        'Container': 'mp3',
        'AudioCodec': 'mp3',
        'TranscodingContainer': 'mp3',
        'TranscodingProtocol': 'http',
        'api_key': token,
      },
    );
    final streamUrl = streamUri.toString();

    return MediaItem(
      id: id,
      title: json['Name'] as String? ?? 'Untitled',
      album: json['Album'] as String? ?? 'Unknown Album',
      artists: (json['Artists'] as List<dynamic>? ?? const [])
          .map((artist) => artist.toString())
          .toList(),
      duration: runtime,
      imageUrl: imageUrl,
      streamUrl: streamUrl,
    );
  }

  /// Serializes this track for local caching.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'album': album,
        'artists': artists,
        'durationMs': duration.inMilliseconds,
        'imageUrl': imageUrl,
        'streamUrl': streamUrl,
      };

  /// Restores a track from cached JSON.
  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id'] as String,
        title: json['title'] as String,
        album: json['album'] as String,
        artists: (json['artists'] as List<dynamic>?)
                ?.map((artist) => artist.toString())
                .toList() ??
            const [],
        duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
        imageUrl: json['imageUrl'] as String?,
        streamUrl: json['streamUrl'] as String,
      );
}
