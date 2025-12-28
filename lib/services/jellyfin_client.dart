import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/album.dart';
import '../models/artist.dart';
import '../models/auth_session.dart';
import '../models/genre.dart';
import '../models/library_stats.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';
import '../models/search_results.dart';
/// Client wrapper for Jellyfin REST APIs.
class JellyfinClient {
  /// Default identifier used for Jellyfin device tracking.
  static const String defaultDeviceId = 'coppelia';

  /// Default displayed device name in Jellyfin.
  static const String defaultDeviceName = 'Coppelia';

  /// Client name for Jellyfin analytics.
  static const String clientName = 'Coppelia';

  /// Client version for Jellyfin analytics.
  static const String clientVersion = '0.1.0';

  /// Creates a client with an optional HTTP override.
  JellyfinClient({
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  AuthSession? _session;
  String _deviceId = defaultDeviceId;
  String _deviceName = defaultDeviceName;

  /// Currently authenticated session.
  AuthSession? get session => _session;

  /// Authorization header for Jellyfin requests.
  String get authorizationHeader => _authorizationHeader();

  /// Attaches a saved session for authenticated calls.
  void updateSession(AuthSession session) {
    _session = session;
  }

  /// Clears the current session.
  void clearSession() {
    _session = null;
  }

  /// Updates the device information used in requests.
  void updateDeviceInfo({
    required String deviceId,
    required String deviceName,
  }) {
    _deviceId = deviceId;
    _deviceName = deviceName;
  }

  /// Builds a stream URL for a track using current device info.
  String buildStreamUrl({
    required String itemId,
    required String userId,
    required String token,
  }) {
    final session = _session;
    final serverUrl = session?.serverUrl;
    if (serverUrl == null) {
      return '';
    }
    final streamUri = Uri.parse('$serverUrl/Audio/$itemId/universal').replace(
      queryParameters: {
        'UserId': userId,
        'DeviceId': _deviceId,
        'Container': 'mp3',
        'AudioCodec': 'mp3',
        'TranscodingContainer': 'mp3',
        'TranscodingProtocol': 'http',
        'api_key': token,
      },
    );
    return streamUri.toString();
  }

  /// Signs in to Jellyfin using username and password.
  Future<AuthSession> authenticate({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final sanitizedUrl = _sanitizeServerUrl(serverUrl);
    final uri = Uri.parse('$sanitizedUrl/Users/AuthenticateByName');
    final response = await _httpClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Emby-Authorization': _authorizationHeader(),
      },
      body: jsonEncode({
        'Username': username,
        'Pw': password,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Authentication failed (${response.statusCode}).');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final user = payload['User'] as Map<String, dynamic>;
    final session = AuthSession(
      accessToken: payload['AccessToken'] as String,
      serverUrl: sanitizedUrl,
      userId: user['Id'] as String,
      userName: user['Name'] as String? ?? username,
    );
    _session = session;
    return session;
  }

  /// Fetches user playlists from Jellyfin.
  Future<List<Playlist>> fetchPlaylists() async {
    final session = _requireSession();
    final uri = Uri.parse(
      '${session.serverUrl}/Users/${session.userId}/Items',
    ).replace(
      queryParameters: {
        'IncludeItemTypes': 'Playlist',
        'Recursive': 'true',
        'SortBy': 'SortName',
        'api_key': session.accessToken,
      },
    );

    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to load playlists (${response.statusCode}).');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['Items'] as List<dynamic>? ?? [];
    return items
        .map((item) => Playlist.fromJellyfin(
              item as Map<String, dynamic>,
              serverUrl: session.serverUrl,
            ))
        .toList();
  }

  /// Fetches albums from Jellyfin.
  Future<List<Album>> fetchAlbums() async {
    final session = _requireSession();
    final uri = Uri.parse(
      '${session.serverUrl}/Users/${session.userId}/Items',
    ).replace(
      queryParameters: {
        'IncludeItemTypes': 'MusicAlbum',
        'Recursive': 'true',
        'SortBy': 'SortName',
        'Fields': 'ImageTags,ChildCount,AlbumArtist,AlbumArtists',
        'api_key': session.accessToken,
      },
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to load albums (${response.statusCode}).');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['Items'] as List<dynamic>? ?? [];
    return items
        .map((item) => Album.fromJellyfin(
              item as Map<String, dynamic>,
              serverUrl: session.serverUrl,
            ))
        .toList();
  }

  /// Fetches artists from Jellyfin.
  Future<List<Artist>> fetchArtists() async {
    final session = _requireSession();
    final uri = Uri.parse('${session.serverUrl}/Artists').replace(
      queryParameters: {
        'UserId': session.userId,
        'SortBy': 'SortName',
        'Fields': 'ImageTags',
        'api_key': session.accessToken,
      },
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to load artists (${response.statusCode}).');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['Items'] as List<dynamic>? ?? [];
    return items
        .map((item) => Artist.fromJellyfin(
              item as Map<String, dynamic>,
              serverUrl: session.serverUrl,
            ))
        .toList();
  }

  /// Fetches genres from Jellyfin.
  Future<List<Genre>> fetchGenres() async {
    final session = _requireSession();
    final uri = Uri.parse('${session.serverUrl}/Genres').replace(
      queryParameters: {
        'UserId': session.userId,
        'SortBy': 'SortName',
        'IncludeItemTypes': 'Audio',
        'Fields': 'ImageTags',
        'api_key': session.accessToken,
      },
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to load genres (${response.statusCode}).');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['Items'] as List<dynamic>? ?? [];
    return items
        .map((item) => Genre.fromJellyfin(
              item as Map<String, dynamic>,
              serverUrl: session.serverUrl,
            ))
        .toList();
  }

  /// Fetches the tracks for a playlist.
  Future<List<MediaItem>> fetchPlaylistTracks(String playlistId) async {
    final session = _requireSession();
    final uri = Uri.parse(
      '${session.serverUrl}/Playlists/$playlistId/Items',
    ).replace(
      queryParameters: {
        'Fields':
            'RunTimeTicks,Artists,Album,ImageTags,AlbumId,ArtistItems',
        'api_key': session.accessToken,
      },
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to load playlist tracks.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['Items'] as List<dynamic>? ?? [];
    return items
        .map((item) => MediaItem.fromJellyfin(
              item as Map<String, dynamic>,
              serverUrl: session.serverUrl,
              token: session.accessToken,
              userId: session.userId,
              deviceId: _deviceId,
            ))
        .toList();
  }

  /// Fetches tracks for an album.
  Future<List<MediaItem>> fetchAlbumTracks(String albumId) async {
    final session = _requireSession();
    final uri = Uri.parse(
      '${session.serverUrl}/Users/${session.userId}/Items',
    ).replace(
      queryParameters: {
        'ParentId': albumId,
        'IncludeItemTypes': 'Audio',
        'Recursive': 'true',
        'Fields': 'RunTimeTicks,Artists,Album,ImageTags,AlbumId,ArtistItems',
        'api_key': session.accessToken,
      },
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to load album tracks.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['Items'] as List<dynamic>? ?? [];
    return items
        .map((item) => MediaItem.fromJellyfin(
              item as Map<String, dynamic>,
              serverUrl: session.serverUrl,
              token: session.accessToken,
              userId: session.userId,
              deviceId: _deviceId,
            ))
        .toList();
  }

  /// Fetches tracks for an artist.
  Future<List<MediaItem>> fetchArtistTracks(String artistId) async {
    final session = _requireSession();
    final uri = Uri.parse(
      '${session.serverUrl}/Users/${session.userId}/Items',
    ).replace(
      queryParameters: {
        'ArtistIds': artistId,
        'IncludeItemTypes': 'Audio',
        'Recursive': 'true',
        'SortBy': 'Album,SortName',
        'Fields': 'RunTimeTicks,Artists,Album,ImageTags,AlbumId,ArtistItems',
        'api_key': session.accessToken,
      },
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to load artist tracks.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['Items'] as List<dynamic>? ?? [];
    return items
        .map((item) => MediaItem.fromJellyfin(
              item as Map<String, dynamic>,
              serverUrl: session.serverUrl,
              token: session.accessToken,
              userId: session.userId,
              deviceId: _deviceId,
            ))
        .toList();
  }

  /// Fetches tracks for a genre.
  Future<List<MediaItem>> fetchGenreTracks(String genreId) async {
    final session = _requireSession();
    final uri = Uri.parse(
      '${session.serverUrl}/Users/${session.userId}/Items',
    ).replace(
      queryParameters: {
        'GenreIds': genreId,
        'IncludeItemTypes': 'Audio',
        'Recursive': 'true',
        'SortBy': 'Album,SortName',
        'Fields': 'RunTimeTicks,Artists,Album,ImageTags,AlbumId,ArtistItems',
        'api_key': session.accessToken,
      },
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to load genre tracks.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['Items'] as List<dynamic>? ?? [];
    return items
        .map((item) => MediaItem.fromJellyfin(
              item as Map<String, dynamic>,
              serverUrl: session.serverUrl,
              token: session.accessToken,
              userId: session.userId,
              deviceId: _deviceId,
            ))
        .toList();
  }

  /// Fetches favorited albums from Jellyfin.
  Future<List<Album>> fetchFavoriteAlbums() async {
    final session = _requireSession();
    final uri = Uri.parse(
      '${session.serverUrl}/Users/${session.userId}/Items',
    ).replace(
      queryParameters: {
        'IncludeItemTypes': 'MusicAlbum',
        'Recursive': 'true',
        'Filters': 'IsFavorite',
        'SortBy': 'SortName',
        'Fields': 'ImageTags,ChildCount,AlbumArtist,AlbumArtists',
        'api_key': session.accessToken,
      },
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to load favorite albums.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['Items'] as List<dynamic>? ?? [];
    return items
        .map((item) => Album.fromJellyfin(
              item as Map<String, dynamic>,
              serverUrl: session.serverUrl,
            ))
        .toList();
  }

  /// Fetches favorited artists from Jellyfin.
  Future<List<Artist>> fetchFavoriteArtists() async {
    final session = _requireSession();
    final uri = Uri.parse(
      '${session.serverUrl}/Users/${session.userId}/Items',
    ).replace(
      queryParameters: {
        'IncludeItemTypes': 'MusicArtist',
        'Recursive': 'true',
        'Filters': 'IsFavorite',
        'SortBy': 'SortName',
        'Fields': 'ImageTags',
        'api_key': session.accessToken,
      },
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to load favorite artists.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['Items'] as List<dynamic>? ?? [];
    return items
        .map((item) => Artist.fromJellyfin(
              item as Map<String, dynamic>,
              serverUrl: session.serverUrl,
            ))
        .toList();
  }

  /// Fetches favorited tracks from Jellyfin.
  Future<List<MediaItem>> fetchFavoriteTracks() async {
    final session = _requireSession();
    final uri = Uri.parse(
      '${session.serverUrl}/Users/${session.userId}/Items',
    ).replace(
      queryParameters: {
        'IncludeItemTypes': 'Audio',
        'Recursive': 'true',
        'Filters': 'IsFavorite',
        'SortBy': 'SortName',
        'Fields':
            'RunTimeTicks,Artists,Album,ImageTags,AlbumId,ArtistItems',
        'api_key': session.accessToken,
      },
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to load favorite tracks.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['Items'] as List<dynamic>? ?? [];
    return items
        .map((item) => MediaItem.fromJellyfin(
              item as Map<String, dynamic>,
              serverUrl: session.serverUrl,
              token: session.accessToken,
              userId: session.userId,
              deviceId: _deviceId,
            ))
        .toList();
  }

  /// Updates the favorite state for a Jellyfin item.
  Future<void> setFavorite({
    required String itemId,
    required bool isFavorite,
  }) async {
    final session = _requireSession();
    final uri = Uri.parse(
      '${session.serverUrl}/Users/${session.userId}/FavoriteItems/$itemId',
    ).replace(
      queryParameters: {
        'api_key': session.accessToken,
      },
    );
    final response = isFavorite
        ? await _httpClient.post(uri)
        : await _httpClient.delete(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to update favorite (${response.statusCode}).');
    }
  }

  /// Reports that playback has started for an item.
  Future<void> reportPlaybackStart({
    required MediaItem track,
    required Duration position,
    required bool isPaused,
    required String playSessionId,
    required Duration duration,
  }) async {
    await _reportPlaybackEvent(
      endpoint: 'Playing',
      track: track,
      position: position,
      duration: duration,
      isPaused: isPaused,
      playSessionId: playSessionId,
    );
  }

  /// Reports a playback progress update for an item.
  Future<void> reportPlaybackProgress({
    required MediaItem track,
    required Duration position,
    required bool isPaused,
    required String playSessionId,
    required Duration duration,
  }) async {
    await _reportPlaybackEvent(
      endpoint: 'Playing/Progress',
      track: track,
      position: position,
      duration: duration,
      isPaused: isPaused,
      playSessionId: playSessionId,
    );
  }

  /// Reports that playback has stopped for an item.
  Future<void> reportPlaybackStopped({
    required MediaItem track,
    required Duration position,
    required bool isPaused,
    required bool completed,
    required String playSessionId,
    required Duration duration,
  }) async {
    await _reportPlaybackEvent(
      endpoint: 'Playing/Stopped',
      track: track,
      position: position,
      duration: duration,
      isPaused: isPaused,
      playSessionId: playSessionId,
      completed: completed,
    );
  }

  /// Searches the library for matching items.
  Future<SearchResults> searchLibrary(String query) async {
    final session = _requireSession();
    final uri = Uri.parse(
      '${session.serverUrl}/Users/${session.userId}/Items',
    ).replace(
      queryParameters: {
        'SearchTerm': query,
        'IncludeItemTypes': 'Audio,MusicAlbum,MusicArtist,Genre',
        'Recursive': 'true',
        'Limit': '60',
        'Fields':
            'RunTimeTicks,Artists,Album,ImageTags,AlbumId,ArtistItems,'
                'ChildCount,AlbumArtist,AlbumArtists',
        'api_key': session.accessToken,
      },
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to search library.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['Items'] as List<dynamic>? ?? [];
    final tracks = <MediaItem>[];
    final albums = <Album>[];
    final artists = <Artist>[];
    final genres = <Genre>[];
    for (final entry in items) {
      final item = entry as Map<String, dynamic>;
      final type = item['Type']?.toString();
      if (type == 'Audio') {
        tracks.add(
          MediaItem.fromJellyfin(
            item,
            serverUrl: session.serverUrl,
            token: session.accessToken,
            userId: session.userId,
            deviceId: _deviceId,
          ),
        );
      } else if (type == 'MusicAlbum') {
        albums.add(
          Album.fromJellyfin(item, serverUrl: session.serverUrl),
        );
      } else if (type == 'MusicArtist') {
        artists.add(
          Artist.fromJellyfin(item, serverUrl: session.serverUrl),
        );
      } else if (type == 'Genre') {
        genres.add(
          Genre.fromJellyfin(item, serverUrl: session.serverUrl),
        );
      }
    }
    return SearchResults(
      tracks: tracks,
      albums: albums,
      artists: artists,
      genres: genres,
    );
  }

  /// Fetches recently added tracks for the home shelf.
  Future<List<MediaItem>> fetchRecentTracks() async {
    final session = _requireSession();
    final uri = Uri.parse(
      '${session.serverUrl}/Users/${session.userId}/Items',
    ).replace(
      queryParameters: {
        'IncludeItemTypes': 'Audio',
        'SortBy': 'DateCreated',
        'SortOrder': 'Descending',
        'Limit': '12',
        'Recursive': 'true',
        'Fields':
            'RunTimeTicks,Artists,Album,ImageTags,AlbumId,ArtistItems',
        'api_key': session.accessToken,
      },
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to load recent tracks.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['Items'] as List<dynamic>? ?? [];
    return items
        .map((item) => MediaItem.fromJellyfin(
              item as Map<String, dynamic>,
              serverUrl: session.serverUrl,
              token: session.accessToken,
              userId: session.userId,
              deviceId: _deviceId,
            ))
        .toList();
  }

  /// Fetches recently played tracks for the current user.
  Future<List<MediaItem>> fetchRecentlyPlayedTracks() async {
    final session = _requireSession();
    final uri = Uri.parse(
      '${session.serverUrl}/Users/${session.userId}/Items',
    ).replace(
      queryParameters: {
        'IncludeItemTypes': 'Audio',
        'SortBy': 'DatePlayed',
        'SortOrder': 'Descending',
        'Limit': '12',
        'Recursive': 'true',
        'Fields':
            'RunTimeTicks,Artists,Album,ImageTags,AlbumId,ArtistItems',
        'api_key': session.accessToken,
      },
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to load recently played tracks.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['Items'] as List<dynamic>? ?? [];
    return items
        .map((item) => MediaItem.fromJellyfin(
              item as Map<String, dynamic>,
              serverUrl: session.serverUrl,
              token: session.accessToken,
              userId: session.userId,
              deviceId: _deviceId,
            ))
        .toList();
  }

  /// Fetches library-wide counts for home stats.
  Future<LibraryStats> fetchLibraryStats() async {
    final session = _requireSession();
    final counts = await Future.wait([
      _fetchItemCount(
        session: session,
        includeItemTypes: 'Audio',
      ),
      _fetchItemCount(
        session: session,
        includeItemTypes: 'MusicAlbum',
      ),
      _fetchArtistCount(session),
      _fetchItemCount(
        session: session,
        includeItemTypes: 'Playlist',
      ),
    ]);
    return LibraryStats(
      trackCount: counts[0],
      albumCount: counts[1],
      artistCount: counts[2],
      playlistCount: counts[3],
    );
  }

  /// Returns the server URL without a trailing slash.
  String _sanitizeServerUrl(String raw) {
    return raw.trim().replaceAll(RegExp(r'/+$'), '');
  }

  AuthSession _requireSession() {
    final session = _session;
    if (session == null) {
      throw StateError('Missing session. Authenticate first.');
    }
    return session;
  }

  String _authorizationHeader() {
    return 'MediaBrowser Client="$clientName", Device="$_deviceName", '
        'DeviceId="$_deviceId", Version="$clientVersion"';
  }

  Future<int> _fetchItemCount({
    required AuthSession session,
    required String includeItemTypes,
  }) async {
    final uri = Uri.parse(
      '${session.serverUrl}/Users/${session.userId}/Items',
    ).replace(
      queryParameters: {
        'IncludeItemTypes': includeItemTypes,
        'Recursive': 'true',
        'Limit': '0',
        'api_key': session.accessToken,
      },
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to load item count for $includeItemTypes.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return payload['TotalRecordCount'] as int? ?? 0;
  }

  Future<int> _fetchArtistCount(AuthSession session) async {
    final uri = Uri.parse('${session.serverUrl}/Artists').replace(
      queryParameters: {
        'UserId': session.userId,
        'Limit': '0',
        'api_key': session.accessToken,
      },
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to load artist count.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final total = payload['TotalRecordCount'] as int?;
    if (total != null) {
      return total;
    }
    final items = payload['Items'] as List<dynamic>? ?? [];
    return items.length;
  }

  Future<void> _reportPlaybackEvent({
    required String endpoint,
    required MediaItem track,
    required Duration position,
    required Duration duration,
    required bool isPaused,
    required String playSessionId,
    bool completed = false,
  }) async {
    final session = _requireSession();
    final uri = Uri.parse('${session.serverUrl}/Sessions/$endpoint').replace(
      queryParameters: {
        'api_key': session.accessToken,
      },
    );
    final payload = <String, dynamic>{
      'ItemId': track.id,
      'MediaSourceId': track.id,
      'PositionTicks': position.inMilliseconds * 10000,
      'DurationTicks': duration.inMilliseconds * 10000,
      'IsPaused': isPaused,
      'PlayMethod': 'DirectStream',
      'CanSeek': true,
      'PlaySessionId': playSessionId,
      'UserId': session.userId,
    };
    if (endpoint == 'Playing/Stopped') {
      payload['Failed'] = false;
      payload['PlayedToCompletion'] = completed;
    }
    final response = await _httpClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Emby-Authorization': _authorizationHeader(),
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Telemetry failures should not interrupt playback.
      return;
    }
  }
}
