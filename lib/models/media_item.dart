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
    this.albumId,
    this.artistIds = const [],
    this.playlistItemId,
    this.addedAt,
    this.playCount,
    this.lastPlayedAt,
    this.genres = const [],
    this.container,
    this.codec,
    this.bitrate,
    this.sampleRate,
    this.bpm,
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

  /// Album identifier when available.
  final String? albumId;

  /// Artist identifiers when available.
  final List<String> artistIds;

  /// Playlist entry identifier when loaded from a playlist.
  final String? playlistItemId;

  /// Library add date.
  final DateTime? addedAt;

  /// Times this track has been played.
  final int? playCount;

  /// Last played timestamp.
  final DateTime? lastPlayedAt;

  /// Genre labels for the track.
  final List<String> genres;

  /// Original file container format from Jellyfin (e.g., 'flac', 'mp3', 'aac').
  final String? container;

  /// Audio codec from Jellyfin (e.g., 'flac', 'mp3', 'aac', 'opus').
  final String? codec;

  /// Bitrate in bits per second.
  final int? bitrate;

  /// Sample rate in Hz.
  final int? sampleRate;

  /// Beats per minute (tempo).
  final int? bpm;

  /// User-friendly subtitle.
  String get subtitle => artists.isEmpty ? album : artists.join(', ');

  /// Extracts codec/container info from stream URL for logging.
  String get codecInfo {
    final uri = Uri.tryParse(streamUrl);
    if (uri == null) return 'unknown';
    final container = uri.queryParameters['Container'] ?? 'unknown';
    final codec = uri.queryParameters['AudioCodec'] ?? 'unknown';
    return 'container=$container, codec=$codec';
  }

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
    final albumId = json['AlbumId'] as String?;
    String? imageUrl;
    if (json['ImageTags']?['Primary'] != null) {
      imageUrl = '$serverUrl/Items/$id/Images/Primary?fillWidth=500&quality=90';
    } else if (albumId != null) {
      imageUrl =
          '$serverUrl/Items/$albumId/Images/Primary?fillWidth=500&quality=90';
    }
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
    final artistItems = json['ArtistItems'] as List<dynamic>?;
    final artistIds = artistItems
            ?.map((entry) => entry['Id']?.toString())
            .whereType<String>()
            .toList() ??
        const <String>[];
    final playlistItemId = json['PlaylistItemId']?.toString();
    final addedAtRaw = json['DateCreated']?.toString();
    final addedAt = addedAtRaw == null ? null : DateTime.tryParse(addedAtRaw);
    final userData = json['UserData'] as Map<String, dynamic>?;
    final playCount = (userData?['PlayCount'] as num?)?.toInt();
    final lastPlayedRaw = userData?['LastPlayedDate']?.toString();
    final lastPlayedAt =
        lastPlayedRaw == null ? null : DateTime.tryParse(lastPlayedRaw);
    final genres = (json['Genres'] as List<dynamic>? ?? const [])
        .map((entry) => entry.toString())
        .where((entry) => entry.isNotEmpty)
        .toList();

    // Extract format info from MediaStreams
    String? container;
    String? codec;
    int? bitrate;
    int? sampleRate;
    final mediaStreams = json['MediaStreams'] as List<dynamic>?;
    if (mediaStreams != null) {
      for (final stream in mediaStreams) {
        if (stream is Map<String, dynamic> && stream['Type'] == 'Audio') {
          codec = stream['Codec']?.toString();
          bitrate = (stream['BitRate'] as num?)?.toInt();
          sampleRate = (stream['SampleRate'] as num?)?.toInt();
          break;
        }
      }
    }
    container = json['Container']?.toString();
    final bpm = (json['BPM'] as num?)?.toInt();

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
      albumId: albumId,
      artistIds: artistIds,
      playlistItemId: playlistItemId,
      addedAt: addedAt,
      playCount: playCount,
      lastPlayedAt: lastPlayedAt,
      genres: genres,
      container: container,
      codec: codec,
      bitrate: bitrate,
      sampleRate: sampleRate,
      bpm: bpm,
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
        'albumId': albumId,
        'artistIds': artistIds,
        'playlistItemId': playlistItemId,
        'addedAt': addedAt?.toIso8601String(),
        'playCount': playCount,
        'lastPlayedAt': lastPlayedAt?.toIso8601String(),
        'genres': genres,
        'container': container,
        'codec': codec,
        'bitrate': bitrate,
        'sampleRate': sampleRate,
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
        albumId: json['albumId'] as String?,
        artistIds: (json['artistIds'] as List<dynamic>?)
                ?.map((entry) => entry.toString())
                .toList() ??
            const [],
        playlistItemId: json['playlistItemId'] as String?,
        addedAt: json['addedAt'] == null
            ? null
            : DateTime.tryParse(json['addedAt'] as String),
        playCount: json['playCount'] as int?,
        lastPlayedAt: json['lastPlayedAt'] == null
            ? null
            : DateTime.tryParse(json['lastPlayedAt'] as String),
        genres: (json['genres'] as List<dynamic>?)
                ?.map((entry) => entry.toString())
                .toList() ??
            const [],
        container: json['container'] as String?,
        codec: json['codec'] as String?,
        bitrate: json['bitrate'] as int?,
        sampleRate: json['sampleRate'] as int?,
      );
}
