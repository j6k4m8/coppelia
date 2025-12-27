import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:copellia/models/auth_session.dart';
import 'package:copellia/services/jellyfin_client.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  test('authenticate builds an auth session', () async {
    final client = _MockHttpClient();
    when(
      () => client.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'AccessToken': 'token-123',
          'User': {'Id': 'user-1', 'Name': 'Jordan'},
        }),
        200,
      ),
    );

    final jellyfin = JellyfinClient(httpClient: client);
    final session = await jellyfin.authenticate(
      serverUrl: 'https://demo.jellyfin.org',
      username: 'jordan',
      password: 'password',
    );

    expect(session.accessToken, 'token-123');
    expect(session.userId, 'user-1');
    expect(session.userName, 'Jordan');
    expect(session.serverUrl, 'https://demo.jellyfin.org');
  });

  test('fetchPlaylists maps Jellyfin responses', () async {
    final client = _MockHttpClient();
    final jellyfin = JellyfinClient(httpClient: client);
    jellyfin.updateSession(
      const AuthSession(
        accessToken: 'token',
        serverUrl: 'https://demo.jellyfin.org',
        userId: 'user-1',
        userName: 'Jordan',
      ),
    );

    when(() => client.get(any())).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'Items': [
            {
              'Id': 'playlist-1',
              'Name': 'Morning Focus',
              'ChildCount': 12,
              'ImageTags': {'Primary': 'abc123'},
            }
          ]
        }),
        200,
      ),
    );

    final playlists = await jellyfin.fetchPlaylists();
    expect(playlists, hasLength(1));
    expect(playlists.first.name, 'Morning Focus');
    expect(playlists.first.trackCount, 12);
  });
}
