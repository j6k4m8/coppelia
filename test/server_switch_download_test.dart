import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:coppelia/models/auth_session.dart';
import 'package:coppelia/models/media_item.dart';
import 'package:coppelia/services/cache_store.dart';
import 'package:coppelia/services/jellyfin_client.dart';
import 'package:coppelia/services/playback_controller.dart';
import 'package:coppelia/services/server_store.dart';
import 'package:coppelia/services/settings_store.dart';
import 'package:coppelia/state/app_state.dart';

class _Playback extends Mock implements PlaybackController {}

class _Settings extends Mock implements SettingsStore {}

class _Loopback extends HttpOverrides {}

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final Directory root;
  @override
  Future<String?> getTemporaryPath() async => root.path;
  @override
  Future<String?> getApplicationSupportPath() async => root.path;
}

// Only scheduling is controlled; lookup, storage, HTTP, and downloads are real.
class _DelayedCache extends CacheStore {
  final lookupStarted = Completer<void>();
  final releaseLookup = Completer<void>();
  @override
  Future<bool> isAudioCached(MediaItem item) async {
    final found = await super.isAudioCached(item);
    if (!lookupStarted.isCompleted) {
      lookupStarted.complete();
      await releaseLookup.future;
    }
    return found;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Directory.systemTemp.createTempSync('coppelia_review_http_');
  PathProviderPlatform.instance = _Paths(root);
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('coppelia/now_playing'), (_) async => null);

  tearDownAll(() async {
    // Linux and Windows cache-manager indexes flush on a three-second timer.
    if (Platform.isLinux || Platform.isWindows) {
      await Future<void>.delayed(const Duration(seconds: 4));
    }
    await root.delete(recursive: true);
  });

  test('real HTTP must never disclose B credentials to A', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      SharedPreferences.setMockInitialValues({});
      final endpointA = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => endpointA.close(force: true));
      final requests = <({String path, String? authorization})>[];
      final received = Completer<void>();
      final responseClosed = Completer<void>();
      endpointA.listen((request) async {
        requests.add((
          path: request.uri.path,
          authorization: request.headers.value('authorization')
        ));
        if (request.uri.path.startsWith('/b/') && !received.isCompleted) {
          received.complete();
        }
        request.response
          ..contentLength = 6
          ..add('audio!'.codeUnits);
        await request.response.close();
        if (!responseClosed.isCompleted) responseClosed.complete();
      });
      final originA = 'http://127.0.0.1:${endpointA.port}';
      final client = JellyfinClient(httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/Users/AuthenticateByName')) {
          return http.Response(
              jsonEncode({
                'AccessToken': 'a-test-token',
                'User': {'Id': 'a-user', 'Name': 'A'}
              }),
              200);
        }
        return http.Response('{}', 503);
      }));
      final servers = ServerStore();
      final b = await servers.addAuthenticatedServer(AuthSession(
          accessToken: 'b-test-token',
          serverUrl: '$originA/b',
          userId: 'b-user',
          userName: 'B'));
      final playback = _Playback();
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
      final settings = _Settings();
      when(() => settings.loadSmartLists()).thenAnswer((_) async => []);
      when(() => settings.saveDownloadsPaused(any())).thenAnswer((_) async {});
      final cache = _DelayedCache();
      final state = AppState(
          cacheStore: cache,
          client: client,
          playback: playback,
          serverStore: servers,
          settingsStore: settings);
      addTearDown(state.dispose);
      await state.setDownloadsPaused(true);
      expect(
          await state.signIn(serverUrl: originA, username: 'A', password: ''),
          isTrue);
      final item = MediaItem(
          id: 'a-track',
          title: 'A track',
          album: 'A',
          artists: const [],
          duration: const Duration(seconds: 1),
          imageUrl: null,
          streamUrl:
              client.buildStreamUrl(itemId: 'a-track', userId: 'a-user'));
      final pending = state.makeTrackAvailableOffline(item);
      await cache.lookupStarted.future;
      expect(await state.switchServer(b.server.id), isTrue);
      cache.releaseLookup.complete();
      await pending;
      expect(state.downloadQueue, isEmpty);
      final bItem = MediaItem(
          id: 'b-track',
          title: 'B track',
          album: 'B',
          artists: const [],
          duration: const Duration(seconds: 1),
          imageUrl: null,
          streamUrl:
              client.buildStreamUrl(itemId: 'b-track', userId: 'b-user'));
      await state.makeTrackAvailableOffline(bItem);
      await state.setDownloadsPaused(false);
      await received.future.timeout(const Duration(seconds: 5));
      await responseClosed.future;
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (
          state.downloadQueue.isNotEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(state.downloadQueue, isEmpty);
      expect(requests, hasLength(1));
      expect(requests.single.path, startsWith('/b/Audio/b-track/'));
      expect(requests.single.authorization, contains('b-test-token'));
      expect((await cache.loadCachedAudioEntries()).map((e) => e.cacheKey),
          [cache.audioKeyForStreamUrl(bItem.streamUrl)]);
    }, _Loopback());
  });
}
