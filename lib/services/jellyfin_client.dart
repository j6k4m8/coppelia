import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';
/// Client wrapper for Jellyfin REST APIs.
class JellyfinClient {
  /// Creates a client with an optional HTTP override.
  JellyfinClient({
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  AuthSession? _session;

  /// Currently authenticated session.
  AuthSession? get session => _session;

  /// Attaches a saved session for authenticated calls.
  void updateSession(AuthSession session) {
    _session = session;
  }

  /// Clears the current session.
  void clearSession() {
    _session = null;
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

  /// Fetches the tracks for a playlist.
  Future<List<MediaItem>> fetchPlaylistTracks(String playlistId) async {
    final session = _requireSession();
    final uri = Uri.parse(
      '${session.serverUrl}/Playlists/$playlistId/Items',
    ).replace(
      queryParameters: {
        'Fields': 'RunTimeTicks,Artists,Album,ImageTags',
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
            ))
        .toList();
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
        'Fields': 'RunTimeTicks,Artists,Album,ImageTags',
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
            ))
        .toList();
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
    return 'MediaBrowser Client="Copellia", Device="macOS", '
        'DeviceId="copellia-desktop", Version="0.1.0"';
  }
}
