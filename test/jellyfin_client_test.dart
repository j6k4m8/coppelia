import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:coppelia/models/auth_session.dart';
import 'package:coppelia/services/jellyfin_client.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(
      http.Request('POST', Uri.parse('https://example.com')),
    );
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

    final captured = verify(
      () => client.post(
        captureAny(),
        headers: captureAny(named: 'headers'),
        body: captureAny(named: 'body'),
      ),
    ).captured;
    final headers = captured[1] as Map<String, String>;
    expect(headers['Authorization'], startsWith('MediaBrowser '));
    expect(headers['Authorization'], contains('Client="Coppelia"'));
    expect(headers, isNot(contains('X-Emby-Authorization')));
    expect(headers, isNot(contains('X-Emby-Token')));
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

    when(
      () => client.get(
        any(),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer(
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

    final captured = verify(
      () => client.get(
        captureAny(),
        headers: captureAny(named: 'headers'),
      ),
    ).captured;
    final uri = captured[0] as Uri;
    final headers = captured[1] as Map<String, String>;
    expect(uri.queryParameters, isNot(contains('api_key')));
    expect(headers['Authorization'], contains('Token="token"'));
    expect(headers, isNot(contains('X-Emby-Authorization')));
    expect(headers, isNot(contains('X-Emby-Token')));
  });

  test('fetchAlbums retrieves every page', () async {
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
    final firstPage = List.generate(
      200,
      (index) => <String, dynamic>{
        'Id': 'album-$index',
        'Name': 'Album $index',
        'ChildCount': 1,
      },
    );
    when(
      () => client.get(
        any(),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer((invocation) async {
      final uri = invocation.positionalArguments.first as Uri;
      if (uri.queryParameters['StartIndex'] == '0') {
        return http.Response(
          jsonEncode({'Items': firstPage, 'TotalRecordCount': 201}),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'Items': [
            {'Id': 'album-200', 'Name': 'Album 200', 'ChildCount': 1},
          ],
          'TotalRecordCount': 201,
        }),
        200,
      );
    });

    final albums = await jellyfin.fetchAlbums();

    expect(albums, hasLength(201));
    final requests = verify(
      () => client.get(
        captureAny(),
        headers: any(named: 'headers'),
      ),
    ).captured.cast<Uri>();
    expect(requests, hasLength(2));
    expect(requests[0].path, '/Users/user-1/Items');
    expect(requests[0].queryParameters['Fields'], 'ChildCount');
    expect(requests[0].queryParameters['StartIndex'], '0');
    expect(requests[0].queryParameters['Limit'], '200');
    expect(requests[1].queryParameters['StartIndex'], '200');
  });

  test('fetchGenres uses the music genres endpoint', () async {
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
    when(
      () => client.get(
        any(),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'Items': [
            {'Id': 'genre-1', 'Name': 'Jazz', 'ItemCount': 7},
          ],
          'TotalRecordCount': 1,
        }),
        200,
      ),
    );

    final genres = await jellyfin.fetchGenres();

    expect(genres.single.name, 'Jazz');
    expect(genres.single.trackCount, 7);
    final uri = verify(
      () => client.get(
        captureAny(),
        headers: any(named: 'headers'),
      ),
    ).captured.single as Uri;
    expect(uri.path, '/MusicGenres');
    expect(uri.queryParameters['Fields'], 'ItemCounts');
    expect(uri.queryParameters, isNot(contains('IncludeItemTypes')));
  });

  test('fetchAlbums rejects a malformed response', () async {
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
    when(
      () => client.get(
        any(),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer((_) async => http.Response(jsonEncode({'Items': {}}), 200));

    await expectLater(
      jellyfin.fetchAlbums(),
      throwsA(isA<FormatException>()),
    );
  });

  test('fetchRecentlyAddedAlbums requests newest album records', () async {
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
    when(
      () => client.get(
        any(),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'Items': [
            {
              'Id': 'album-1',
              'Name': 'New Record',
              'AlbumArtist': 'Studio Band',
              'ChildCount': 10,
              'ImageTags': {'Primary': 'cover'},
            },
          ],
        }),
        200,
      ),
    );

    final albums = await jellyfin.fetchRecentlyAddedAlbums();

    expect(albums, hasLength(1));
    expect(albums.single.name, 'New Record');
    expect(albums.single.artistName, 'Studio Band');
    final uri = verify(
      () => client.get(
        captureAny(),
        headers: any(named: 'headers'),
      ),
    ).captured.single as Uri;
    expect(uri.queryParameters['IncludeItemTypes'], 'MusicAlbum');
    expect(uri.queryParameters['SortBy'], 'DateCreated');
    expect(uri.queryParameters['SortOrder'], 'Descending');
    expect(uri.queryParameters['Limit'], '12');
    expect(uri.queryParameters['Recursive'], 'true');
  });

  test('addToPlaylist uses the current Jellyfin query API', () async {
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
    when(
      () => client.send(any()),
    ).thenAnswer((_) async => http.StreamedResponse(Stream.value([]), 204));

    await jellyfin.addToPlaylist(
      playlistId: 'playlist-1',
      itemIds: ['track-1', 'track-2'],
    );

    final captured = verify(
      () => client.send(captureAny()),
    ).captured;
    final request = captured.single as http.BaseRequest;
    final uri = request.url;
    final headers = request.headers;
    expect(uri.path, '/Playlists/playlist-1/Items');
    expect(uri.queryParameters['ids'], 'track-1,track-2');
    expect(uri.queryParameters['userId'], 'user-1');
    expect(headers['Authorization'], contains('Token="token"'));
    expect(headers, isNot(contains('Content-Type')));
  });

  test('addToPlaylist aborts a stalled request', () async {
    final client = _MockHttpClient();
    final jellyfin = JellyfinClient(
      httpClient: client,
      playlistRequestTimeout: Duration.zero,
    );
    jellyfin.updateSession(
      const AuthSession(
        accessToken: 'token',
        serverUrl: 'https://demo.jellyfin.org',
        userId: 'user-1',
        userName: 'Jordan',
      ),
    );
    when(() => client.send(any())).thenAnswer((invocation) {
      final request =
          invocation.positionalArguments.single as http.AbortableRequest;
      return request.abortTrigger!.then<http.StreamedResponse>((_) {
        throw http.RequestAbortedException(request.url);
      });
    });

    await expectLater(
      jellyfin.addToPlaylist(
        playlistId: 'playlist-1',
        itemIds: ['track-1'],
      ),
      throwsA(
        isA<JellyfinRequestException>().having(
          (error) => error.message,
          'message',
          contains('timed out'),
        ),
      ),
    );
  });

  test('fetchAlbumTracks filters by album id and keeps a parent fallback',
      () async {
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

    when(
      () => client.get(
        any(),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'Items': [
            {
              'Id': 'track-1',
              'Name': 'Track 1',
              'Album': 'Morning Focus',
              'Artists': ['Jordan'],
              'RunTimeTicks': 1800000000,
              'Container': 'mp3',
            }
          ]
        }),
        200,
      ),
    );

    final tracks = await jellyfin.fetchAlbumTracks('album-1');

    expect(tracks, hasLength(1));
    expect(tracks.single.title, 'Track 1');
    expect(tracks.single.container, 'mp3');

    final firstUri = verify(
      () => client.get(
        captureAny(),
        headers: any(named: 'headers'),
      ),
    ).captured.single as Uri;
    expect(firstUri.queryParameters['AlbumIds'], 'album-1');
    expect(firstUri.queryParameters['ParentId'], isNull);
    expect(firstUri.queryParameters['Fields'], isNot(contains('Container')));
  });

  test('fetchAlbumTracks falls back to parent filtering when needed', () async {
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

    var requestCount = 0;
    when(
      () => client.get(
        any(),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer((invocation) async {
      requestCount += 1;
      final uri = invocation.positionalArguments.first as Uri;
      if (uri.queryParameters['AlbumIds'] != null) {
        return http.Response(jsonEncode({'Items': []}), 200);
      }
      return http.Response(
        jsonEncode({
          'Items': [
            {
              'Id': 'track-1',
              'Name': 'Track 1',
              'Album': 'Morning Focus',
              'Artists': ['Jordan'],
              'RunTimeTicks': 1800000000,
            }
          ]
        }),
        200,
      );
    });

    final tracks = await jellyfin.fetchAlbumTracks('album-1');

    expect(requestCount, 2);
    expect(tracks, hasLength(1));
    expect(tracks.single.id, 'track-1');
  });
}
