import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:coppelia/models/album.dart';
import 'package:coppelia/models/media_item.dart';
import 'package:coppelia/models/playback_resume_state.dart';
import 'package:coppelia/models/playlist.dart';
import 'package:coppelia/services/cache_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProvider();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('cache store saves and restores playlists', () async {
    SharedPreferences.setMockInitialValues({});
    final cacheStore = CacheStore();
    final playlists = [
      const Playlist(
        id: 'playlist-1',
        name: 'Late Night',
        trackCount: 8,
        imageUrl: null,
      ),
    ];

    await cacheStore.savePlaylists(playlists);
    final restored = await cacheStore.loadPlaylists();

    expect(restored, hasLength(1));
    expect(restored.first.name, 'Late Night');
  });

  test('cache store saves playlist tracks', () async {
    SharedPreferences.setMockInitialValues({});
    final cacheStore = CacheStore();
    final tracks = [
      const MediaItem(
        id: 'track-1',
        title: 'Evergreen',
        album: 'Solstice',
        artists: ['Studio Band'],
        duration: Duration(minutes: 3, seconds: 12),
        imageUrl: null,
        streamUrl: 'https://demo.jellyfin.org/Audio/track-1/stream',
      ),
    ];

    await cacheStore.savePlaylistTracks('playlist-1', tracks);
    final restored = await cacheStore.loadPlaylistTracks('playlist-1');

    expect(restored, hasLength(1));
    expect(restored.first.title, 'Evergreen');
  });

  test('cache store saves and restores recently added albums', () async {
    SharedPreferences.setMockInitialValues({});
    final cacheStore = CacheStore();
    const albums = [
      Album(
        id: 'album-1',
        name: 'New Record',
        artistName: 'Studio Band',
        trackCount: 10,
        imageUrl: 'https://demo.jellyfin.org/Items/album-1/Images/Primary',
      ),
    ];

    await cacheStore.saveRecentlyAddedAlbums(albums);
    final restored = await cacheStore.loadRecentlyAddedAlbums();

    expect(restored, hasLength(1));
    expect(restored.single.id, 'album-1');
    expect(restored.single.name, 'New Record');
  });

  test('media item cache migration strips legacy api key from stream URL', () {
    final item = MediaItem.fromJson({
      'id': 'track-legacy',
      'title': 'Legacy',
      'album': 'Old Cache',
      'artists': ['Studio Band'],
      'durationMs': 120000,
      'imageUrl': null,
      'streamUrl':
          'https://demo.jellyfin.org/Audio/track-legacy/universal?UserId=user&api_key=secret&DeviceId=device',
    });

    final uri = Uri.parse(item.streamUrl);
    expect(uri.queryParameters, isNot(contains('api_key')));
    expect(uri.queryParameters['UserId'], 'user');
    expect(uri.queryParameters['DeviceId'], 'device');
  });

  test('cache store normalizes legacy playback resume stream URL', () async {
    SharedPreferences.setMockInitialValues({});
    final cacheStore = CacheStore();
    const track = MediaItem(
      id: 'track-resume',
      title: 'Resume',
      album: 'Old Cache',
      artists: ['Studio Band'],
      duration: Duration(minutes: 2),
      imageUrl: null,
      streamUrl:
          'https://demo.jellyfin.org/Audio/track-resume/universal?UserId=user&api_key=secret',
    );

    await cacheStore.savePlaybackResumeState(
      const PlaybackResumeState(
        track: track,
        position: Duration(seconds: 30),
      ),
    );
    final restored = await cacheStore.loadPlaybackResumeState();

    expect(restored, isNotNull);
    expect(
      Uri.parse(restored!.track.streamUrl).queryParameters,
      isNot(contains('api_key')),
    );
  });

  test('cache store saves whole-library offline pins', () async {
    SharedPreferences.setMockInitialValues({});
    final cacheStore = CacheStore();

    await cacheStore.saveWholeLibraryPinnedAudio({
      'https://demo.jellyfin.org/Audio/track-1/stream',
      'https://demo.jellyfin.org/Audio/track-2/stream',
    });

    final restored = await cacheStore.loadWholeLibraryPinnedAudio();

    expect(
      restored,
      containsAll([
        'https://demo.jellyfin.org/Audio/track-1/stream',
        'https://demo.jellyfin.org/Audio/track-2/stream',
      ]),
    );
  });

  test('cache store saves and forgets pinned audio metadata in bulk', () async {
    SharedPreferences.setMockInitialValues({});
    final cacheStore = CacheStore();
    const track = MediaItem(
      id: 'track-9',
      title: 'Northbound',
      album: 'Transit',
      artists: ['Demo Artist'],
      duration: Duration(minutes: 4),
      imageUrl: null,
      streamUrl: 'https://demo.jellyfin.org/Audio/track-9/stream',
    );

    await cacheStore.savePinnedAudioItems([track]);
    await cacheStore.savePinnedAudio({track.streamUrl});
    var restored = await cacheStore.loadPinnedAudioItems();
    expect(restored.map((item) => item.streamUrl), contains(track.streamUrl));

    await cacheStore.forgetPinnedAudioItems([track.streamUrl]);
    restored = await cacheStore.loadPinnedAudioItems();
    expect(restored, isEmpty);
  });

  test('clearOfflineAudioState clears offline pin metadata', () async {
    SharedPreferences.setMockInitialValues({});
    final cacheStore = CacheStore();
    const track = MediaItem(
      id: 'track-clear',
      title: 'Clear Me',
      album: 'Offline',
      artists: ['Studio Band'],
      duration: Duration(minutes: 4),
      imageUrl: null,
      streamUrl: 'https://demo.jellyfin.org/Audio/track-clear/stream',
    );

    await cacheStore.savePinnedAudio({track.streamUrl});
    await cacheStore.savePinnedAudioItems([track]);
    await cacheStore.saveWholeLibraryPinnedAudio({track.streamUrl});

    await cacheStore.clearOfflineAudioState();

    expect(await cacheStore.loadPinnedAudio(), isEmpty);
    expect(await cacheStore.loadPinnedAudioItems(), isEmpty);
    expect(await cacheStore.loadWholeLibraryPinnedAudio(), isEmpty);
  });

  test('server scopes isolate cached library metadata', () async {
    SharedPreferences.setMockInitialValues({});
    final cacheStore = CacheStore();
    const first = Playlist(
      id: 'playlist-1',
      name: 'First server',
      trackCount: 1,
      imageUrl: null,
    );
    const second = Playlist(
      id: 'playlist-2',
      name: 'Second server',
      trackCount: 1,
      imageUrl: null,
    );

    cacheStore.activateScope('server-one');
    await cacheStore.savePlaylists([first]);
    cacheStore.activateScope('server-two');
    expect(await cacheStore.loadPlaylists(), isEmpty);
    await cacheStore.savePlaylists([second]);

    cacheStore.activateScope('server-one');
    expect((await cacheStore.loadPlaylists()).single.name, first.name);
    cacheStore.activateScope('server-two');
    expect((await cacheStore.loadPlaylists()).single.name, second.name);
  });

  test('in-flight offline pin writes retain their originating server scope',
      () async {
    SharedPreferences.setMockInitialValues({});
    final cacheStore = CacheStore();
    const track = MediaItem(
      id: 'scope-race-track',
      title: 'Scope race',
      album: 'Test',
      artists: ['Test'],
      duration: Duration(minutes: 3),
      imageUrl: null,
      streamUrl: 'https://demo.jellyfin.org/Audio/scope-race-track/universal',
    );

    cacheStore.activateScope('server-one');
    final pin = cacheStore.setPinnedAudioItem(track, true);
    cacheStore.activateScope('server-two');
    await pin;

    expect(await cacheStore.loadPinnedAudio(), isEmpty);
    expect(await cacheStore.loadPinnedAudioItems(), isEmpty);

    cacheStore.activateScope('server-one');
    expect(
      await cacheStore.loadPinnedAudio(),
      contains(cacheStore.audioKeyForStreamUrl(track.streamUrl)),
    );
    expect((await cacheStore.loadPinnedAudioItems()).single.id, track.id);
  });

  test('migration retains legacy metadata, pins, and resume state in its scope',
      () async {
    SharedPreferences.setMockInitialValues({});
    final cacheStore = CacheStore();
    const track = MediaItem(
      id: 'track-migration',
      title: 'Migrated',
      album: 'Old Cache',
      artists: ['Studio Band'],
      duration: Duration(minutes: 2),
      imageUrl: null,
      streamUrl: 'https://demo.jellyfin.org/Audio/track-migration/universal',
    );
    const playlist = Playlist(
      id: 'playlist-migration',
      name: 'Migrated playlist',
      trackCount: 1,
      imageUrl: null,
    );

    await cacheStore.savePlaylists([playlist]);
    await cacheStore.savePinnedAudio({track.streamUrl});
    await cacheStore.savePlaybackResumeState(
      const PlaybackResumeState(track: track, position: Duration(seconds: 21)),
    );

    await cacheStore.migrateLegacyData('server-one');
    cacheStore.activateScope('server-one');

    expect((await cacheStore.loadPlaylists()).single.id, playlist.id);
    expect(
      await cacheStore.loadPinnedAudio(),
      contains(cacheStore.audioKeyForStreamUrl(track.streamUrl)),
    );
    expect((await cacheStore.loadPlaybackResumeState())?.track.id, track.id);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('cached_playlists'), isNull);
    expect(preferences.getString('cached_audio_pins'), isNull);
  });

  test('aliases reuse downloaded audio while saved servers stay isolated',
      () async {
    SharedPreferences.setMockInitialValues({});
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    unawaited(server.forEach((request) async {
      requests += 1;
      request.response
        ..contentLength = 6
        ..add('audio!'.codeUnits);
      await request.response.close();
    }));
    addTearDown(server.close);

    late CacheStore cacheStore;
    final trackId = 'alias-cache-${DateTime.now().microsecondsSinceEpoch}';
    final homeTrack = MediaItem(
      id: trackId,
      title: 'Alias cache',
      album: 'Test',
      artists: const ['Test'],
      duration: const Duration(seconds: 1),
      imageUrl: null,
      streamUrl: 'http://127.0.0.1:${server.port}/Audio/$trackId/universal',
    );
    final remoteTrack = MediaItem(
      id: trackId,
      title: homeTrack.title,
      album: homeTrack.album,
      artists: homeTrack.artists,
      duration: homeTrack.duration,
      imageUrl: null,
      // This route need not be reachable: a cache hit must not request it.
      streamUrl: 'http://127.0.0.2:${server.port}/Audio/$trackId/universal',
    );

    await HttpOverrides.runWithHttpOverrides(
      () async {
        cacheStore = CacheStore();
        cacheStore.activateScope('server-one');
        await cacheStore
            .downloadAudioWithProgress(homeTrack)
            .firstWhere((response) => response is FileInfo);
      },
      _LoopbackHttpOverrides(),
    );
    final cachedFromHome = await cacheStore.getCachedAudio(homeTrack);
    final cachedFromAlias = await cacheStore.getCachedAudio(remoteTrack);

    expect(cachedFromHome, isNotNull);
    expect(cachedFromAlias, isNotNull);
    expect(await cachedFromAlias!.readAsBytes(), 'audio!'.codeUnits);
    expect(requests, 1);

    cacheStore.activateScope('server-two');
    expect(await cacheStore.getCachedAudio(remoteTrack), isNull);
  });

  test('clearing one server scope does not erase another server cache',
      () async {
    SharedPreferences.setMockInitialValues({});
    final cacheStore = CacheStore();
    const first = Playlist(
      id: 'playlist-1',
      name: 'First server',
      trackCount: 1,
      imageUrl: null,
    );
    const second = Playlist(
      id: 'playlist-2',
      name: 'Second server',
      trackCount: 1,
      imageUrl: null,
    );

    cacheStore.activateScope('server-one');
    await cacheStore.savePlaylists([first]);
    cacheStore.activateScope('server-two');
    await cacheStore.savePlaylists([second]);

    await cacheStore.clearScope('server-one');

    cacheStore.activateScope('server-one');
    expect(await cacheStore.loadPlaylists(), isEmpty);
    cacheStore.activateScope('server-two');
    expect((await cacheStore.loadPlaylists()).single.name, second.name);
  });
}

class _FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getApplicationSupportPath() async =>
      Directory.systemTemp.path;
}

class _LoopbackHttpOverrides extends HttpOverrides {
  @override
  // ignore: unnecessary_overrides
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}
