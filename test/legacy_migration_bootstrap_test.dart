import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:coppelia/models/media_item.dart';
import 'package:coppelia/models/playlist.dart';
import 'package:coppelia/models/track_status_icon_state.dart';
import 'package:coppelia/services/cache_store.dart';
import 'package:coppelia/services/jellyfin_client.dart';
import 'package:coppelia/services/playback_controller.dart';
import 'package:coppelia/services/server_store.dart';
import 'package:coppelia/services/settings_store.dart';
import 'package:coppelia/state/app_state.dart';

class _MockJellyfinClient extends Mock implements JellyfinClient {}

class _MockPlaybackController extends Mock implements PlaybackController {}

/// Points the cache manager at a directory private to this test file, so
/// concurrently running suites do not share its database or files.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getTemporaryPath() async => root.path;

  @override
  Future<String?> getApplicationSupportPath() async => root.path;
}

/// Lets the seeded legacy download reach the loopback server; the test
/// binding otherwise answers every HTTP request with a 400.
class _LoopbackHttpOverrides extends HttpOverrides {}

/// Boots the app over the real stores from a pre-server-profile install and
/// checks that the single session, its cached library, and its offline pin
/// carry over without re-downloading anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Directory.systemTemp.createTempSync('coppelia_migration_test_');
  PathProviderPlatform.instance = _FakePathProvider(root);
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  tearDownAll(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Best effort; the OS reclaims the temp directory either way.
    }
  });

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('coppelia/now_playing'),
      (_) async => null,
    );
  });

  test('legacy single-session install migrates and keeps its offline pin',
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
    final serverUrl = 'http://127.0.0.1:${server.port}';
    final trackId = 'legacy-${DateTime.now().microsecondsSinceEpoch}';
    final legacyTrack = MediaItem(
      id: trackId,
      title: 'Legacy',
      album: 'Album',
      artists: const ['Artist'],
      duration: const Duration(seconds: 1),
      imageUrl: null,
      streamUrl: '$serverUrl/Audio/$trackId/universal',
    );

    // Seed the pre-profile layout: one downloaded and pinned track plus a
    // cached playlist, all under the unscoped keys, and the single session.
    await HttpOverrides.runWithHttpOverrides(
      () async {
        final legacyStore = CacheStore();
        await legacyStore
            .downloadAudioWithProgress(legacyTrack)
            .firstWhere((response) => response is FileInfo);
        // On desktop the cache manager keeps its index in memory and flushes
        // it to disk on a timer, and a new instance reads that file only once
        // when it opens. Poll with fresh instances until the flush has landed
        // so the restarted store below can find the download.
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        while (!await CacheStore().isAudioCached(legacyTrack) &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        expect(await CacheStore().isAudioCached(legacyTrack), isTrue);
        await legacyStore.savePinnedAudio({legacyTrack.streamUrl});
        await legacyStore.savePinnedAudioItems([legacyTrack]);
        await legacyStore.savePlaylists(const [
          Playlist(
            id: 'legacy-playlist',
            name: 'Legacy playlist',
            trackCount: 1,
            imageUrl: null,
          ),
        ]);
      },
      _LoopbackHttpOverrides(),
    );
    final preferences = await SharedPreferences.getInstance();
    // Builds before the mediaItem field stored only title/album/artists.
    // Strip it so the entry exercises the metadata fallback after migration.
    final legacyEntries = Map<String, dynamic>.from(
      jsonDecode(preferences.getString('cached_audio_entries')!) as Map,
    );
    for (final entry in legacyEntries.values) {
      (entry as Map).remove('mediaItem');
    }
    await preferences.setString(
      'cached_audio_entries',
      jsonEncode(legacyEntries),
    );
    await preferences.setString(
      'auth_session',
      jsonEncode({
        'accessToken': 'legacy-token',
        'serverUrl': serverUrl,
        'userId': 'legacy-user',
        'userName': 'Legacy User',
      }),
    );
    expect(requests, 1);

    // Start the new build over the same preferences and cache directory.
    final client = _MockJellyfinClient();
    final playback = _MockPlaybackController();
    when(() => playback.durationStream)
        .thenAnswer((_) => const Stream<Duration?>.empty());
    when(() => playback.playerStateStream)
        .thenAnswer((_) => const Stream<PlayerState>.empty());
    when(() => playback.currentIndexStream)
        .thenAnswer((_) => const Stream<int?>.empty());
    when(() => playback.position).thenReturn(Duration.zero);
    when(() => playback.currentIndex).thenReturn(null);
    when(() => playback.dispose()).thenAnswer((_) async {});
    when(() => playback.setGaplessPlayback(any())).thenAnswer((_) async {});
    when(() => client.fetchPlaylists()).thenThrow(StateError('no network'));
    // The new build derives a different URL form for the same item.
    when(
      () => client.buildStreamUrl(
        itemId: any(named: 'itemId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer(
      (invocation) =>
          '$serverUrl/Audio/${invocation.namedArguments[#itemId]}/universal'
          '?UserId=legacy-user',
    );
    final cacheStore = CacheStore();
    final state = AppState(
      cacheStore: cacheStore,
      client: client,
      playback: playback,
      serverStore: ServerStore(),
      settingsStore: SettingsStore(),
    );
    addTearDown(state.dispose);

    await state.bootstrap();
    // Pinned-download resume runs unawaited. It marks the track downloaded
    // once it finds the migrated file, or queues it if it wrongly does not.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (state.trackStatusForTrack(legacyTrack) !=
            TrackStatusIconState.downloaded &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }

    expect(state.session?.accessToken, 'legacy-token');
    expect(state.savedServers, hasLength(1));
    expect(preferences.getString('auth_session'), isNull);
    expect(
      preferences.getString('pending_jellyfin_legacy_data_migration'),
      isNull,
    );
    expect(preferences.getString('cached_audio_pins'), isNull);
    expect(preferences.getString('cached_playlists'), isNull);
    expect(state.playlists.single.name, 'Legacy playlist');
    expect(state.isTrackPinnedInMemory(legacyTrack), isTrue);
    expect(
      state.trackStatusForTrack(legacyTrack),
      TrackStatusIconState.downloaded,
    );
    expect(state.downloadQueue, isEmpty);
    final viaNewUrl = MediaItem(
      id: trackId,
      title: legacyTrack.title,
      album: legacyTrack.album,
      artists: legacyTrack.artists,
      duration: legacyTrack.duration,
      imageUrl: null,
      streamUrl: '$serverUrl/Audio/$trackId/universal?UserId=legacy-user',
    );
    expect(await cacheStore.getCachedAudio(viaNewUrl), isNotNull);
    // The entry has no stored metadata, so this goes through the fallback
    // that rebuilds a track from the legacy URL.
    final offlineTrack = (await state.loadOfflineTracks()).single;
    expect(offlineTrack.id, trackId);
    expect(offlineTrack.title, 'Legacy');
    expect(offlineTrack.streamUrl, viaNewUrl.streamUrl);
    expect(offlineTrack.imageUrl, contains('/Items/$trackId/Images/Primary'));
    expect(state.isTrackPinnedInMemory(offlineTrack), isTrue);
  });
}
