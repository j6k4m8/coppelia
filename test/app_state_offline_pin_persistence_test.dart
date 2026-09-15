import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:coppelia/models/auth_session.dart';
import 'package:coppelia/models/media_item.dart';
import 'package:coppelia/models/saved_server.dart';
import 'package:coppelia/services/cache_store.dart';
import 'package:coppelia/services/jellyfin_client.dart';
import 'package:coppelia/services/playback_controller.dart';
import 'package:coppelia/services/server_store.dart';
import 'package:coppelia/services/settings_store.dart';
import 'package:coppelia/state/app_state.dart';

class _MockJellyfinClient extends Mock implements JellyfinClient {}

class _MockPlaybackController extends Mock implements PlaybackController {}

class _MockServerStore extends Mock implements ServerStore {}

class _MockSettingsStore extends Mock implements SettingsStore {}

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

const _homeServer = SavedServer(
  id: 'server-home',
  name: 'Home',
  userId: 'home-user',
  userName: 'Home User',
  addresses: [
    ServerAddress(id: 'home-1', name: 'Home', url: 'https://home.example.com'),
  ],
  activeAddressId: 'home-1',
);
const _remoteServer = SavedServer(
  id: 'server-remote',
  name: 'Remote',
  userId: 'remote-user',
  userName: 'Remote User',
  addresses: [
    ServerAddress(
      id: 'remote-1',
      name: 'Remote',
      url: 'https://remote.example.com',
    ),
  ],
  activeAddressId: 'remote-1',
);
const _homeSession = AuthSession(
  accessToken: 'home-token',
  serverUrl: 'https://home.example.com',
  userId: 'home-user',
  userName: 'Home User',
);
const _remoteSession = AuthSession(
  accessToken: 'remote-token',
  serverUrl: 'https://remote.example.com',
  userId: 'remote-user',
  userName: 'Remote User',
);

MediaItem _track(String host, String id) => MediaItem(
      id: id,
      title: id,
      album: 'Album',
      artists: const ['Artist'],
      duration: const Duration(minutes: 1),
      imageUrl: null,
      streamUrl: 'https://$host/Audio/$id/universal',
    );

/// Builds an AppState over a real [CacheStore] with network and playback
/// mocked out. Downloads start paused so queue contents can be inspected.
Future<({AppState state, CacheStore cacheStore})> _buildState() async {
  SharedPreferences.setMockInitialValues({});
  final cacheStore = CacheStore();
  final client = _MockJellyfinClient();
  final playback = _MockPlaybackController();
  final serverStore = _MockServerStore();
  final settingsStore = _MockSettingsStore();

  when(() => playback.durationStream)
      .thenAnswer((_) => const Stream<Duration?>.empty());
  when(() => playback.playerStateStream)
      .thenAnswer((_) => const Stream<PlayerState>.empty());
  when(() => playback.currentIndexStream)
      .thenAnswer((_) => const Stream<int?>.empty());
  when(() => playback.position).thenReturn(Duration.zero);
  when(() => playback.currentIndex).thenReturn(null);
  when(() => playback.dispose()).thenAnswer((_) async {});
  when(() => playback.clearQueue(keepCurrent: any(named: 'keepCurrent')))
      .thenAnswer((_) async {});
  when(() => settingsStore.saveDownloadsPaused(any())).thenAnswer((_) async {});
  when(() => settingsStore.loadSmartLists()).thenAnswer((_) async => const []);
  when(
    () => client.authenticate(
      serverUrl: any(named: 'serverUrl'),
      username: any(named: 'username'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) async => _homeSession);
  // Short-circuit the library refresh; this suite is about offline state.
  when(() => client.fetchPlaylists()).thenThrow(StateError('no network'));
  when(
    () => client.buildStreamUrl(
      itemId: any(named: 'itemId'),
      userId: any(named: 'userId'),
    ),
  ).thenAnswer((invocation) {
    final itemId = invocation.namedArguments[#itemId] as String;
    final userId = invocation.namedArguments[#userId] as String;
    final host = userId == 'home-user' ? 'home' : 'remote';
    return 'https://$host.example.com/Audio/$itemId/universal';
  });
  when(
    () => serverStore.addAuthenticatedServer(any(), name: any(named: 'name')),
  ).thenAnswer(
    (_) async => const StoredServerSession(
      server: _homeServer,
      session: _homeSession,
    ),
  );
  when(() => serverStore.loadServers())
      .thenAnswer((_) async => const [_homeServer, _remoteServer]);
  when(() => serverStore.activate(_remoteServer.id, addressId: 'remote-1'))
      .thenAnswer(
    (_) async => const StoredServerSession(
      server: _remoteServer,
      session: _remoteSession,
    ),
  );

  final state = AppState(
    cacheStore: cacheStore,
    client: client,
    playback: playback,
    serverStore: serverStore,
    settingsStore: settingsStore,
  );
  addTearDown(state.dispose);
  await state.setDownloadsPaused(true);
  return (state: state, cacheStore: cacheStore);
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Directory.systemTemp.createTempSync('coppelia_pin_test_');
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
    registerFallbackValue(_homeSession);
    registerFallbackValue(_homeServer);
  });

  test('pinning a track keeps the pin in the active server scope', () async {
    final harness = await _buildState();
    final state = harness.state;
    final cacheStore = harness.cacheStore;
    expect(
      await state.signIn(
        serverUrl: 'https://home.example.com',
        username: 'home-user',
        password: '',
      ),
      isTrue,
    );
    final track = _track('home.example.com', 'track-home');

    await state.makeTrackAvailableOffline(track);

    final key = cacheStore.audioKeyForStreamUrl(track.streamUrl);
    expect(state.isTrackPinnedInMemory(track), isTrue);
    expect(state.pinnedAudio, {key});
    expect(await cacheStore.loadPinnedAudio(), contains(key));
    expect(
      (await cacheStore.loadPinnedAudioItems()).map((item) => item.id),
      contains(track.id),
    );
    expect(state.downloadQueue.map((task) => task.track.id), [track.id]);
  });

  test('activating a server queues its pinned but undownloaded tracks',
      () async {
    final harness = await _buildState();
    final state = harness.state;
    final cacheStore = harness.cacheStore;
    final remoteTrack = _track('remote.example.com', 'track-remote');
    cacheStore.activateScope(_remoteServer.id);
    await cacheStore.setPinnedAudioItem(remoteTrack, true);
    expect(
      await state.signIn(
        serverUrl: 'https://home.example.com',
        username: 'home-user',
        password: '',
      ),
      isTrue,
    );

    expect(
      await state.switchServer(_remoteServer.id, addressId: 'remote-1'),
      isTrue,
    );
    await _waitUntil(() => state.downloadQueue.isNotEmpty);

    expect(state.isTrackPinnedInMemory(remoteTrack), isTrue);
    expect(
      state.downloadQueue.map((task) => task.track.id),
      [remoteTrack.id],
    );
  });

  test('whole-library offline keeps earlier pins and their metadata', () async {
    final harness = await _buildState();
    final state = harness.state;
    final cacheStore = harness.cacheStore;
    final earlier = _track('remote.example.com', 'track-earlier');
    final added = _track('remote.example.com', 'track-added');
    cacheStore.activateScope(_remoteServer.id);
    await cacheStore.setPinnedAudioItem(earlier, true);
    expect(
      await state.signIn(
        serverUrl: 'https://home.example.com',
        username: 'home-user',
        password: '',
      ),
      isTrue,
    );
    expect(
      await state.switchServer(_remoteServer.id, addressId: 'remote-1'),
      isTrue,
    );
    await _waitUntil(() => state.downloadQueue.isNotEmpty);

    final result = await state.makeWholeLibraryAvailableOffline([
      earlier,
      added,
    ]);

    expect(result.alreadyPinnedCount, 1);
    expect(result.newlyPinnedCount, 1);
    expect(result.wholeLibraryPinnedTrackCount, 1);
    final pins = await cacheStore.loadPinnedAudio();
    expect(pins, contains(cacheStore.audioKeyForStreamUrl(earlier.streamUrl)));
    expect(pins, contains(cacheStore.audioKeyForStreamUrl(added.streamUrl)));
    expect(
      (await cacheStore.loadPinnedAudioItems()).map((item) => item.id).toSet(),
      {earlier.id, added.id},
    );
    expect(
      state.downloadQueue.map((task) => task.track.id).toSet(),
      {earlier.id, added.id},
    );
  });
}
