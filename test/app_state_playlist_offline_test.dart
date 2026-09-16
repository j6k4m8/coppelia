import 'dart:async';

import 'package:coppelia/models/playback_resume_state.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

import 'package:coppelia/models/auth_session.dart';
import 'package:coppelia/models/album.dart';
import 'package:coppelia/models/artist.dart';
import 'package:coppelia/models/genre.dart';
import 'package:coppelia/models/library_stats.dart';
import 'package:coppelia/models/media_item.dart';
import 'package:coppelia/models/playlist.dart';
import 'package:coppelia/models/smart_list.dart';
import 'package:coppelia/models/cached_audio_entry.dart';
import 'package:coppelia/models/download_task.dart';
import 'package:coppelia/models/saved_server.dart';
import 'package:coppelia/models/track_status_icon_state.dart';
import 'package:coppelia/services/cache_store.dart';
import 'package:coppelia/services/jellyfin_client.dart';
import 'package:coppelia/services/playback_controller.dart';
import 'package:coppelia/services/server_store.dart';
import 'package:coppelia/services/settings_store.dart';
import 'package:coppelia/state/app_state.dart';
import 'package:coppelia/state/library_view.dart';

class _MockCacheStore extends Mock implements CacheStore {}

class _MockJellyfinClient extends Mock implements JellyfinClient {}

class _MockPlaybackController extends Mock implements PlaybackController {}

class _MockServerStore extends Mock implements ServerStore {}

class _MockSettingsStore extends Mock implements SettingsStore {}

const _savedServer = SavedServer(
  id: 'server-1',
  name: 'Example',
  userId: 'user',
  userName: 'User',
  addresses: [
    ServerAddress(
      id: 'address-1',
      name: 'Example',
      url: 'https://example.com',
    ),
  ],
  activeAddressId: 'address-1',
);

const _remoteSavedServer = SavedServer(
  id: 'server-2',
  name: 'Remote',
  userId: 'remote-user',
  userName: 'Remote User',
  addresses: [
    ServerAddress(
      id: 'address-2',
      name: 'Remote',
      url: 'https://remote.example.com',
    ),
  ],
  activeAddressId: 'address-2',
);

MediaItem _track(
  String id, {
  String? title,
  String album = 'Album',
  String? albumId,
  List<String> artists = const ['Artist'],
  List<String> artistIds = const [],
}) {
  return MediaItem(
    id: id,
    title: title ?? 'Track $id',
    album: album,
    artists: artists,
    duration: const Duration(minutes: 3),
    imageUrl: null,
    streamUrl: 'https://example.com/audio/$id.mp3',
    albumId: albumId,
    artistIds: artistIds,
  );
}

Album _album(String id) {
  return Album(
    id: id,
    name: 'Album $id',
    artistName: 'Artist',
    trackCount: 1,
    imageUrl: null,
  );
}

Artist _artist(String id) {
  return Artist(
    id: id,
    name: 'Artist $id',
    albumCount: 1,
    trackCount: 1,
    imageUrl: null,
  );
}

Genre _genre(String id) {
  return Genre(
    id: id,
    name: 'Genre $id',
    trackCount: 1,
    imageUrl: null,
  );
}

SmartList _titleContainsSmartList(String value) {
  return SmartList(
    id: 'smart-$value',
    name: 'Smart $value',
    scope: SmartListScope.tracks,
    group: SmartListGroup(
      mode: SmartListGroupMode.all,
      children: [
        SmartListRuleNode(
          rule: SmartListRule(
            field: SmartListField.title,
            operatorType: SmartListOperator.contains,
            value: value,
          ),
        ),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('coppelia/now_playing'),
      (_) async => null,
    );
    registerFallbackValue(_track('fallback'));
    registerFallbackValue(
      const AuthSession(
        accessToken: 'fallback-token',
        serverUrl: 'https://example.com',
        userId: 'fallback-user',
        userName: 'Fallback User',
      ),
    );
    registerFallbackValue(_savedServer);
    registerFallbackValue(<String>{});
    registerFallbackValue(<String>[]);
    registerFallbackValue(<String, String>{});
    registerFallbackValue(<MediaItem>[]);
    registerFallbackValue(<Album>[]);
    registerFallbackValue(<Artist>[]);
    registerFallbackValue(<Genre>[]);
    registerFallbackValue(<Playlist>[]);
    registerFallbackValue(
      const LibraryStats(
        trackCount: 0,
        albumCount: 0,
        artistCount: 0,
        playlistCount: 0,
      ),
    );
  });

  AppState buildState({
    required _MockCacheStore cacheStore,
    required _MockJellyfinClient client,
    required _MockPlaybackController playback,
    required _MockServerStore serverStore,
    required _MockSettingsStore settingsStore,
  }) {
    when(
      () => playback.positionStream,
    ).thenAnswer((_) => const Stream<Duration>.empty());
    when(
      () => playback.durationStream,
    ).thenAnswer((_) => const Stream<Duration?>.empty());
    when(
      () => playback.playerStateStream,
    ).thenAnswer((_) => const Stream<PlayerState>.empty());
    when(
      () => playback.currentIndexStream,
    ).thenAnswer((_) => const Stream<int?>.empty());
    when(() => playback.position).thenReturn(Duration.zero);
    when(() => playback.duration).thenReturn(Duration.zero);
    when(() => playback.currentIndex).thenReturn(null);
    when(() => playback.dispose()).thenAnswer((_) async {});

    when(() => cacheStore.getMediaCacheBytes()).thenAnswer((_) async => 0);
    when(
      () => cacheStore.getPinnedMediaBytes(any()),
    ).thenAnswer((_) async => 0);
    when(
      () => cacheStore.loadCachedAudioEntries(),
    ).thenAnswer((_) async => const <CachedAudioEntry>[]);
    when(() => cacheStore.audioKeyForStreamUrl(any())).thenAnswer(
      (invocation) => invocation.positionalArguments.single as String,
    );
    when(() => cacheStore.loadPlaylists())
        .thenAnswer((_) async => const <Playlist>[]);
    when(() => cacheStore.loadFeaturedTracks())
        .thenAnswer((_) async => const <MediaItem>[]);
    when(() => cacheStore.loadAlbums())
        .thenAnswer((_) async => const <Album>[]);
    when(() => cacheStore.loadRecentlyAddedAlbums())
        .thenAnswer((_) async => const <Album>[]);
    when(() => cacheStore.loadArtists())
        .thenAnswer((_) async => const <Artist>[]);
    when(() => cacheStore.loadGenres())
        .thenAnswer((_) async => const <Genre>[]);
    when(() => cacheStore.loadFavoriteAlbums())
        .thenAnswer((_) async => const <Album>[]);
    when(() => cacheStore.loadFavoriteArtists())
        .thenAnswer((_) async => const <Artist>[]);
    when(() => cacheStore.loadFavoriteTracks())
        .thenAnswer((_) async => const <MediaItem>[]);
    when(() => cacheStore.loadRecentTracks())
        .thenAnswer((_) async => const <MediaItem>[]);
    when(() => cacheStore.loadPlayHistory())
        .thenAnswer((_) async => const <MediaItem>[]);
    when(() => cacheStore.loadLibraryStats()).thenAnswer((_) async => null);
    when(() => cacheStore.loadPlaybackResumeState())
        .thenAnswer((_) async => null);
    when(() => cacheStore.loadPinnedAudio())
        .thenAnswer((_) async => <String>{});
    when(() => settingsStore.loadSmartLists())
        .thenAnswer((_) async => const <SmartList>[]);
    when(() => settingsStore.saveSidebarVisibility(any()))
        .thenAnswer((_) async {});
    when(
      () => cacheStore.savePlaybackResumeState(null),
    ).thenAnswer((_) async {});
    when(
      () => cacheStore.setPinnedAudio(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => cacheStore.setPinnedAudioItem(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => cacheStore.savePinnedAudio(any()),
    ).thenAnswer((_) async {});
    when(
      () => cacheStore.savePinnedAudioItems(any()),
    ).thenAnswer((_) async {});
    when(
      () => cacheStore.forgetPinnedAudioItems(any()),
    ).thenAnswer((_) async {});
    when(
      () => cacheStore.loadWholeLibraryPinnedAudio(),
    ).thenAnswer((_) async => <String>{});
    when(
      () => cacheStore.saveWholeLibraryPinnedAudio(any()),
    ).thenAnswer((_) async {});
    when(
      () => cacheStore.setWholeLibraryPinnedAudio(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => cacheStore.loadPinnedAudioItems(),
    ).thenAnswer((_) async => const <MediaItem>[]);
    when(
      () => cacheStore.isAudioCached(any()),
    ).thenAnswer((_) async => true);
    when(
      () => cacheStore.touchCachedAudio(any()),
    ).thenAnswer((_) async {});
    when(
      () => cacheStore.savePlaylistTracks(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => cacheStore.loadLibraryTracks(),
    ).thenAnswer((_) async => const <MediaItem>[]);
    when(
      () => cacheStore.saveLibraryTracks(any()),
    ).thenAnswer((_) async {});
    when(
      () => cacheStore.downloadAudioWithProgress(
        any(),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer((_) => const Stream<FileResponse>.empty());
    when(() => settingsStore.saveDownloadsPaused(any()))
        .thenAnswer((_) async {});
    when(() => cacheStore.clearScope(any())).thenAnswer((_) async {});
    when(() => settingsStore.clearSmartListsScope(any()))
        .thenAnswer((_) async {});
    when(
      () => playback.clearQueue(keepCurrent: any(named: 'keepCurrent')),
    ).thenAnswer((_) async {});
    when(() => serverStore.removeServer(any())).thenAnswer((_) async => null);
    when(() => serverStore.pendingServerRemovals())
        .thenAnswer((_) async => const <String>[]);
    when(() => serverStore.completeServerRemoval(any()))
        .thenAnswer((_) async {});

    return AppState(
      cacheStore: cacheStore,
      client: client,
      playback: playback,
      serverStore: serverStore,
      settingsStore: settingsStore,
    );
  }

  void stubSignedInRefresh({
    required _MockCacheStore cacheStore,
    required _MockJellyfinClient client,
    required _MockServerStore serverStore,
  }) {
    const session = AuthSession(
      accessToken: 'token',
      serverUrl: 'https://example.com',
      userId: 'user',
      userName: 'User',
    );
    when(
      () => client.authenticate(
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'password',
      ),
    ).thenAnswer((_) async => session);
    when(
      () => serverStore.addAuthenticatedServer(
        session,
        name: any(named: 'name'),
      ),
    ).thenAnswer(
      (_) async => const StoredServerSession(
        server: _savedServer,
        session: session,
      ),
    );
    when(() => serverStore.loadServers())
        .thenAnswer((_) async => const [_savedServer]);
    when(() => client.fetchPlaylists())
        .thenAnswer((_) async => const <Playlist>[]);
    when(() => cacheStore.savePlaylists(any())).thenAnswer((_) async {});
    when(() => client.fetchLibraryStats()).thenAnswer(
      (_) async => const LibraryStats(
        trackCount: 0,
        albumCount: 0,
        artistCount: 0,
        playlistCount: 0,
      ),
    );
    when(() => cacheStore.saveLibraryStats(any())).thenAnswer((_) async {});
    when(() => client.fetchRecentlyPlayedTracks())
        .thenAnswer((_) async => const <MediaItem>[]);
    when(() => client.fetchRecentTracks())
        .thenAnswer((_) async => const <MediaItem>[]);
    when(() => cacheStore.saveRecentTracks(any())).thenAnswer((_) async {});
    when(() => cacheStore.saveFeaturedTracks(any())).thenAnswer((_) async {});
    when(() => client.fetchRecentlyAddedAlbums())
        .thenAnswer((_) async => const <Album>[]);
    when(() => cacheStore.saveRecentlyAddedAlbums(any()))
        .thenAnswer((_) async {});
    when(() => client.fetchAlbums()).thenAnswer((_) async => const <Album>[]);
    when(() => cacheStore.saveAlbums(any())).thenAnswer((_) async {});
    when(() => client.fetchArtists()).thenAnswer((_) async => const <Artist>[]);
    when(() => cacheStore.saveArtists(any())).thenAnswer((_) async {});
    when(() => client.fetchGenres()).thenAnswer((_) async => const <Genre>[]);
    when(() => cacheStore.saveGenres(any())).thenAnswer((_) async {});
    when(() => client.fetchFavoriteAlbums())
        .thenAnswer((_) async => const <Album>[]);
    when(() => cacheStore.saveFavoriteAlbums(any())).thenAnswer((_) async {});
    when(() => client.fetchFavoriteArtists())
        .thenAnswer((_) async => const <Artist>[]);
    when(() => cacheStore.saveFavoriteArtists(any())).thenAnswer((_) async {});
    when(() => client.fetchFavoriteTracks())
        .thenAnswer((_) async => const <MediaItem>[]);
    when(() => cacheStore.saveFavoriteTracks(any())).thenAnswer((_) async {});
  }

  group('AppState session', () {
    test('signIn loads and caches recently added albums', () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);
      stubSignedInRefresh(
        cacheStore: cacheStore,
        client: client,
        serverStore: serverStore,
      );
      final albums = [_album('new')];
      when(() => client.fetchRecentlyAddedAlbums())
          .thenAnswer((_) async => albums);

      final signedIn = await state.signIn(
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'password',
      );

      expect(signedIn, isTrue);
      expect(state.recentlyAddedAlbums, albums);
      verify(() => cacheStore.saveRecentlyAddedAlbums(albums)).called(1);
    });

    test('signIn succeeds when the optional recent album shelf fails',
        () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);
      stubSignedInRefresh(
        cacheStore: cacheStore,
        client: client,
        serverStore: serverStore,
      );
      when(() => client.fetchRecentlyAddedAlbums())
          .thenThrow(StateError('unsupported sort'));

      final signedIn = await state.signIn(
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'password',
      );

      expect(signedIn, isTrue);
      expect(state.recentlyAddedAlbums, isEmpty);
    });

    test('removeServer clears offline audio state for the removed account',
        () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);
      stubSignedInRefresh(
        cacheStore: cacheStore,
        client: client,
        serverStore: serverStore,
      );

      final signedIn = await state.signIn(
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'password',
      );
      expect(signedIn, isTrue);

      clearInteractions(client);
      await state.removeServer(_savedServer.id);

      verify(() => cacheStore.clearScope(_savedServer.id)).called(1);
      verify(() => client.clearSession()).called(1);
      verify(() => serverStore.removeServer(_savedServer.id)).called(1);
      expect(state.session, isNull);
      expect(state.pinnedAudio, isEmpty);
    });

    test('switchServer stops playback and activates scoped server data',
        () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);
      stubSignedInRefresh(
        cacheStore: cacheStore,
        client: client,
        serverStore: serverStore,
      );
      when(() => serverStore.loadServers()).thenAnswer(
        (_) async => const [_savedServer, _remoteSavedServer],
      );
      const remoteSession = AuthSession(
        accessToken: 'remote-token',
        serverUrl: 'https://remote.example.com',
        userId: 'remote-user',
        userName: 'Remote User',
      );
      const remoteStored = StoredServerSession(
        server: _remoteSavedServer,
        session: remoteSession,
      );
      when(
        () => serverStore.activate('server-2', addressId: 'address-2'),
      ).thenAnswer((_) async => remoteStored);

      expect(
        await state.signIn(
          serverUrl: 'https://example.com',
          username: 'user',
          password: 'password',
        ),
        isTrue,
      );
      clearInteractions(cacheStore);
      clearInteractions(client);
      clearInteractions(playback);

      expect(
        await state.switchServer('server-2', addressId: 'address-2'),
        isTrue,
      );

      expect(state.activeServer?.id, _remoteSavedServer.id);
      expect(state.session?.accessToken, remoteSession.accessToken);
      expect(state.session?.serverUrl, remoteSession.serverUrl);
      verify(() => playback.clearQueue(keepCurrent: false)).called(1);
      verify(() => client.updateSession(remoteSession)).called(1);
      verify(() => cacheStore.activateScope(_remoteSavedServer.id)).called(1);
    });

    test('a stale refresh cannot overwrite the newly selected server',
        () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);
      stubSignedInRefresh(
        cacheStore: cacheStore,
        client: client,
        serverStore: serverStore,
      );
      when(() => serverStore.loadServers()).thenAnswer(
        (_) async => const [_savedServer, _remoteSavedServer],
      );
      const remoteSession = AuthSession(
        accessToken: 'remote-token',
        serverUrl: 'https://remote.example.com',
        userId: 'remote-user',
        userName: 'Remote User',
      );
      when(
        () => serverStore.activate('server-2', addressId: 'address-2'),
      ).thenAnswer(
        (_) async => const StoredServerSession(
          server: _remoteSavedServer,
          session: remoteSession,
        ),
      );

      expect(
        await state.signIn(
          serverUrl: 'https://example.com',
          username: 'user',
          password: 'password',
        ),
        isTrue,
      );

      final oldRefresh = Completer<List<Playlist>>();
      const remotePlaylists = [
        Playlist(
          id: 'remote-playlist',
          name: 'Remote playlist',
          trackCount: 1,
          imageUrl: null,
        ),
      ];
      var requests = 0;
      when(() => client.fetchPlaylists()).thenAnswer((_) {
        requests += 1;
        return requests == 1
            ? oldRefresh.future
            : Future.value(remotePlaylists);
      });

      final staleRefresh = state.refreshLibrary();
      expect(
        await state.switchServer('server-2', addressId: 'address-2'),
        isTrue,
      );
      oldRefresh.complete(const [
        Playlist(
          id: 'old-playlist',
          name: 'Old playlist',
          trackCount: 1,
          imageUrl: null,
        ),
      ]);
      await staleRefresh;

      expect(state.activeServer?.id, _remoteSavedServer.id);
      expect(state.playlists, remotePlaylists);
    });

    test('adding an alias to another server does not switch profiles',
        () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);
      stubSignedInRefresh(
        cacheStore: cacheStore,
        client: client,
        serverStore: serverStore,
      );
      when(() => serverStore.loadServers()).thenAnswer(
        (_) async => const [_savedServer, _remoteSavedServer],
      );
      const remoteSession = AuthSession(
        accessToken: 'remote-token',
        serverUrl: 'https://remote.example.com',
        userId: 'remote-user',
        userName: 'Remote User',
      );
      when(() => serverStore.sessionFor(_remoteSavedServer)).thenAnswer(
        (_) async => const StoredServerSession(
          server: _remoteSavedServer,
          session: remoteSession,
        ),
      );
      when(() => client.validateSession(any())).thenAnswer((_) async {});
      final remoteWithAlias = _remoteSavedServer.copyWith(
        addresses: const [
          ServerAddress(
            id: 'address-2',
            name: 'Remote',
            url: 'https://remote.example.com',
          ),
          ServerAddress(
            id: 'address-3',
            name: 'Office',
            url: 'https://office.example.com',
          ),
        ],
      );
      when(
        () => serverStore.addAddress(
          _remoteSavedServer.id,
          name: 'Office',
          url: 'https://office.example.com',
        ),
      ).thenAnswer((_) async => [_savedServer, remoteWithAlias]);

      expect(
        await state.signIn(
          serverUrl: 'https://example.com',
          username: 'user',
          password: 'password',
        ),
        isTrue,
      );
      clearInteractions(client);

      await state.addServerAddress(
        _remoteSavedServer.id,
        name: 'Office',
        url: 'https://office.example.com',
      );

      expect(state.activeServer?.id, _savedServer.id);
      expect(state.session?.serverUrl, 'https://example.com');
      verify(() => client.validateSession(any())).called(1);
      verifyNever(() => client.updateSession(any()));
    });
  });

  group('AppState playlist offline', () {
    test('makePlaylistAvailableOffline pins cached playlist tracks', () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);

      const playlist = Playlist(
        id: 'playlist-1',
        name: 'Playlist',
        trackCount: 2,
        imageUrl: null,
      );
      final tracks = [_track('1'), _track('2')];

      when(
        () => cacheStore.loadPlaylistTracks(playlist.id),
      ).thenAnswer((_) async => tracks);

      await state.makePlaylistAvailableOffline(playlist);

      expect(state.pinnedAudio, containsAll(tracks.map((t) => t.streamUrl)));
      expect(state.downloadQueue, isEmpty);
      verifyNever(() => client.fetchPlaylistTracks(any()));
      for (final track in tracks) {
        verify(() => cacheStore.setPinnedAudioItem(track, true)).called(1);
        verify(() => cacheStore.isAudioCached(track)).called(1);
        verify(() => cacheStore.touchCachedAudio(track)).called(1);
      }
    });

    test('makePlaylistAvailableOffline fetches and caches when tracks missing',
        () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);

      const playlist = Playlist(
        id: 'playlist-2',
        name: 'Playlist 2',
        trackCount: 1,
        imageUrl: null,
      );
      final tracks = [_track('3')];

      when(
        () => cacheStore.loadPlaylistTracks(playlist.id),
      ).thenAnswer((_) async => const []);
      when(
        () => client.fetchPlaylistTracks(playlist.id),
      ).thenAnswer((_) async => tracks);

      await state.makePlaylistAvailableOffline(playlist);

      verify(() => client.fetchPlaylistTracks(playlist.id)).called(1);
      verify(() => cacheStore.savePlaylistTracks(playlist.id, tracks))
          .called(1);
      verify(() => cacheStore.setPinnedAudioItem(tracks.first, true)).called(1);
      expect(state.pinnedAudio, contains(tracks.first.streamUrl));
    });

    test('unpinPlaylistOffline clears pinned playlist tracks', () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);

      const playlist = Playlist(
        id: 'playlist-3',
        name: 'Playlist 3',
        trackCount: 2,
        imageUrl: null,
      );
      final tracks = [_track('4'), _track('5')];

      when(
        () => cacheStore.loadPlaylistTracks(playlist.id),
      ).thenAnswer((_) async => tracks);

      await state.makePlaylistAvailableOffline(playlist);
      expect(state.pinnedAudio, containsAll(tracks.map((t) => t.streamUrl)));

      await state.unpinPlaylistOffline(playlist);

      expect(state.pinnedAudio, isEmpty);
      for (final track in tracks) {
        verify(() => cacheStore.setPinnedAudio(track.streamUrl, false))
            .called(1);
      }
    });
  });

  group('AppState artist offline identity', () {
    const artistA = Artist(
      id: 'artist-a',
      name: 'Shared Name',
      albumCount: 1,
      trackCount: 1,
      imageUrl: null,
    );
    const artistB = Artist(
      id: 'artist-b',
      name: 'Shared Name',
      albumCount: 1,
      trackCount: 1,
      imageUrl: null,
    );

    test('offline artist discovery distinguishes artists with the same name',
        () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);

      final trackB = _track(
        'artist-b-track',
        artists: const ['Shared Name'],
        artistIds: const ['artist-b'],
      );
      when(() => cacheStore.loadCachedAudioEntries()).thenAnswer(
        (_) async => [
          CachedAudioEntry(
            cacheKey: trackB.streamUrl,
            title: trackB.title,
            album: trackB.album,
            artists: trackB.artists,
            cachedAt: DateTime(2024),
            bytes: 1024,
            mediaItem: trackB,
          ),
        ],
      );
      when(() => cacheStore.loadArtistTracks(any()))
          .thenAnswer((_) async => const <MediaItem>[]);
      when(() => cacheStore.loadArtists())
          .thenAnswer((_) async => const [artistA, artistB]);

      await state.makeTrackAvailableOffline(trackB);

      expect(await state.isArtistPinned(artistA), isFalse);
      expect(await state.isArtistPinned(artistB), isTrue);
      expect(await state.loadOfflineArtists(), const [artistB]);
    });
  });

  group('AppState whole-library offline', () {
    test(
        'makeWholeLibraryAvailableOffline only tracks newly added pins in the undo set',
        () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);

      var wholeLibraryPins = <String>{};
      when(
        () => cacheStore.loadWholeLibraryPinnedAudio(),
      ).thenAnswer((_) async => wholeLibraryPins);
      when(
        () => cacheStore.saveWholeLibraryPinnedAudio(any()),
      ).thenAnswer((invocation) async {
        wholeLibraryPins = Set<String>.from(
          invocation.positionalArguments.single as Set<String>,
        );
      });

      final manualTrack = _track('manual');
      final wholeLibraryTrack = _track('whole-library');
      when(
        () => cacheStore.loadCachedAudioEntries(),
      ).thenAnswer(
        (_) async => [
          CachedAudioEntry(
            cacheKey: manualTrack.streamUrl,
            title: manualTrack.title,
            album: manualTrack.album,
            artists: manualTrack.artists,
            cachedAt: DateTime(2024),
            bytes: 1024,
            mediaItem: manualTrack,
          ),
        ],
      );

      await state.makeTrackAvailableOffline(manualTrack);

      final result = await state.makeWholeLibraryAvailableOffline([
        manualTrack,
        wholeLibraryTrack,
      ]);

      expect(result.newlyPinnedCount, 1);
      expect(result.newlyQueuedCount, 1);
      expect(result.alreadyPinnedCount, 1);
      expect(wholeLibraryPins, {wholeLibraryTrack.streamUrl});
      expect(state.pinnedAudio,
          containsAll([manualTrack.streamUrl, wholeLibraryTrack.streamUrl]));
    });

    test('removeWholeLibraryOfflineSelection preserves manual pins', () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);

      var wholeLibraryPins = <String>{};
      when(
        () => cacheStore.loadWholeLibraryPinnedAudio(),
      ).thenAnswer((_) async => wholeLibraryPins);
      when(
        () => cacheStore.saveWholeLibraryPinnedAudio(any()),
      ).thenAnswer((invocation) async {
        wholeLibraryPins = Set<String>.from(
          invocation.positionalArguments.single as Set<String>,
        );
      });

      final manualTrack = _track('manual');
      final wholeLibraryTrack = _track('whole-library');
      when(
        () => cacheStore.loadCachedAudioEntries(),
      ).thenAnswer(
        (_) async => [
          CachedAudioEntry(
            cacheKey: manualTrack.streamUrl,
            title: manualTrack.title,
            album: manualTrack.album,
            artists: manualTrack.artists,
            cachedAt: DateTime(2024),
            bytes: 1024,
            mediaItem: manualTrack,
          ),
        ],
      );

      await state.makeTrackAvailableOffline(manualTrack);
      await state.makeWholeLibraryAvailableOffline([
        manualTrack,
        wholeLibraryTrack,
      ]);

      final result = await state.removeWholeLibraryOfflineSelection();

      expect(result.removedTrackCount, 1);
      expect(wholeLibraryPins, isEmpty);
      expect(state.pinnedAudio, {manualTrack.streamUrl});
      expect(state.downloadQueue, isEmpty);
    });
  });

  group('AppState detail selection', () {
    void testHomeDetailBackNavigation(
      String detail,
      Future<void> Function(AppState state) select,
      bool Function(AppState state) isSelected,
    ) {
      test('$detail opened from Home returns to Home', () async {
        final cacheStore = _MockCacheStore();
        final client = _MockJellyfinClient();
        final playback = _MockPlaybackController();
        final serverStore = _MockServerStore();
        final settingsStore = _MockSettingsStore();
        final state = buildState(
          cacheStore: cacheStore,
          client: client,
          playback: playback,
          serverStore: serverStore,
          settingsStore: settingsStore,
        );
        addTearDown(state.dispose);

        when(() => cacheStore.loadPlaylistTracks(any()))
            .thenAnswer((_) async => const <MediaItem>[]);
        when(() => client.fetchPlaylistTracks(any()))
            .thenAnswer((_) async => const <MediaItem>[]);
        when(() => cacheStore.loadAlbumTracks(any()))
            .thenAnswer((_) async => const <MediaItem>[]);
        when(() => client.fetchAlbumTracks(any()))
            .thenAnswer((_) async => const <MediaItem>[]);
        when(() => cacheStore.loadArtistTracks(any()))
            .thenAnswer((_) async => const <MediaItem>[]);
        when(() => client.fetchArtistTracks(any()))
            .thenAnswer((_) async => const <MediaItem>[]);
        when(() => cacheStore.saveArtistTracks(any(), any()))
            .thenAnswer((_) async {});
        when(() => cacheStore.loadGenreTracks(any()))
            .thenAnswer((_) async => const <MediaItem>[]);
        when(() => client.fetchGenreTracks(any()))
            .thenAnswer((_) async => const <MediaItem>[]);
        when(() => cacheStore.saveGenreTracks(any(), any()))
            .thenAnswer((_) async {});

        await select(state);

        expect(isSelected(state), isTrue);
        expect(state.canGoBack, isTrue);
        state.goBack();
        expect(state.selectedView, LibraryView.home);
        expect(state.selectedPlaylist, isNull);
        expect(state.selectedSmartList, isNull);
        expect(state.selectedAlbum, isNull);
        expect(state.selectedArtist, isNull);
        expect(state.selectedGenre, isNull);
        expect(state.canGoBack, isFalse);
      });
    }

    testHomeDetailBackNavigation(
      'playlist',
      (state) => state.selectPlaylist(
        const Playlist(
          id: 'playlist-back',
          name: 'Playlist',
          trackCount: 1,
          imageUrl: null,
        ),
      ),
      (state) => state.selectedPlaylist != null,
    );
    testHomeDetailBackNavigation(
      'Smart List',
      (state) => state.selectSmartList(_titleContainsSmartList('Needle')),
      (state) => state.selectedSmartList != null,
    );
    testHomeDetailBackNavigation(
      'album',
      (state) => state.selectAlbum(_album('back')),
      (state) => state.selectedAlbum != null,
    );
    testHomeDetailBackNavigation(
      'artist',
      (state) => state.selectArtist(_artist('back')),
      (state) => state.selectedArtist != null,
    );
    testHomeDetailBackNavigation(
      'genre',
      (state) => state.selectGenre(_genre('back')),
      (state) => state.selectedGenre != null,
    );

    test('playlist opened from a list returns to that list', () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);
      const playlist = Playlist(
        id: 'playlist-list-back',
        name: 'Playlist',
        trackCount: 1,
        imageUrl: null,
      );
      when(() => cacheStore.loadPlaylistTracks(playlist.id))
          .thenAnswer((_) async => const <MediaItem>[]);
      when(() => client.fetchPlaylistTracks(playlist.id))
          .thenAnswer((_) async => const <MediaItem>[]);

      state.selectLibraryView(LibraryView.homePlaylists);
      await state.selectPlaylist(playlist);
      state.goBack();

      expect(state.selectedView, LibraryView.homePlaylists);
      expect(state.selectedPlaylist, isNull);
      expect(state.canGoBack, isTrue);
      state.goBack();
      expect(state.selectedView, LibraryView.home);
      expect(state.canGoBack, isFalse);
    });

    test('selectAlbum clears playlist detail state', () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);

      const playlist = Playlist(
        id: 'playlist-detail',
        name: 'Playlist',
        trackCount: 1,
        imageUrl: null,
      );
      final playlistTracks = [_track('playlist-track')];
      final album = _album('target');
      final albumTracks = [_track('album-track')];

      when(
        () => cacheStore.loadPlaylistTracks(playlist.id),
      ).thenAnswer((_) async => playlistTracks);
      when(
        () => client.fetchPlaylistTracks(playlist.id),
      ).thenAnswer((_) async => playlistTracks);
      when(
        () => cacheStore.loadAlbumTracks(album.id),
      ).thenAnswer((_) async => const <MediaItem>[]);
      when(
        () => client.fetchAlbumTracks(album.id),
      ).thenAnswer((_) async => albumTracks);
      when(
        () => cacheStore.saveAlbumTracks(album.id, albumTracks),
      ).thenAnswer((_) async {});

      await state.selectPlaylist(playlist);
      expect(state.selectedPlaylist, playlist);
      expect(state.playlistTracks, playlistTracks);

      await state.selectAlbum(album);

      expect(state.selectedPlaylist, isNull);
      expect(state.playlistTracks, isEmpty);
      expect(state.selectedAlbum, album);
      expect(state.albumTracks, albumTracks);
    });

    test('late album fetch cannot overwrite newer album selection', () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);

      final firstAlbum = _album('first');
      final secondAlbum = _album('second');
      final firstTracks = [_track('first-track')];
      final secondTracks = [_track('second-track')];
      final firstFetch = Completer<List<MediaItem>>();
      final secondFetch = Completer<List<MediaItem>>();

      when(
        () => cacheStore.loadAlbumTracks(firstAlbum.id),
      ).thenAnswer((_) async => const <MediaItem>[]);
      when(
        () => cacheStore.loadAlbumTracks(secondAlbum.id),
      ).thenAnswer((_) async => const <MediaItem>[]);
      when(
        () => client.fetchAlbumTracks(firstAlbum.id),
      ).thenAnswer((_) => firstFetch.future);
      when(
        () => client.fetchAlbumTracks(secondAlbum.id),
      ).thenAnswer((_) => secondFetch.future);
      when(
        () => cacheStore.saveAlbumTracks(secondAlbum.id, secondTracks),
      ).thenAnswer((_) async {});

      final firstSelection = state.selectAlbum(firstAlbum);
      await Future<void>.delayed(Duration.zero);

      final secondSelection = state.selectAlbum(secondAlbum);
      secondFetch.complete(secondTracks);
      await secondSelection;

      firstFetch.complete(firstTracks);
      await firstSelection;

      expect(state.selectedAlbum, secondAlbum);
      expect(state.albumTracks, secondTracks);
    });

    test('selectAlbum uses the cached library snapshot when refresh fails',
        () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);

      final album = _album('target');
      final cachedTrack = _track(
        'cached-track',
        album: album.name,
        albumId: album.id,
      );
      when(
        () => cacheStore.loadAlbumTracks(album.id),
      ).thenAnswer((_) async => const <MediaItem>[]);
      when(
        () => cacheStore.loadLibraryTracks(),
      ).thenAnswer((_) async => [cachedTrack]);
      when(
        () => client.fetchAlbumTracks(album.id),
      ).thenThrow(StateError('server unavailable'));

      await state.selectAlbum(album);

      expect(state.albumTracks, [cachedTrack]);
    });
  });

  test('whole-library preview counts cached audio using its scoped key',
      () async {
    final cacheStore = _MockCacheStore();
    final client = _MockJellyfinClient();
    final playback = _MockPlaybackController();
    final serverStore = _MockServerStore();
    final settingsStore = _MockSettingsStore();
    final state = buildState(
      cacheStore: cacheStore,
      client: client,
      playback: playback,
      serverStore: serverStore,
      settingsStore: settingsStore,
    );
    addTearDown(state.dispose);
    stubSignedInRefresh(
      cacheStore: cacheStore,
      client: client,
      serverStore: serverStore,
    );
    final track = _track('cached');
    const key = 'server-1:audio:cached';
    when(() => cacheStore.audioKeyForStreamUrl(track.streamUrl))
        .thenReturn(key);
    when(() => client.buildStreamUrl(
        itemId: track.id,
        userId: any(named: 'userId'))).thenReturn(track.streamUrl);
    when(() => client.fetchLibraryTracks(startIndex: 0, limit: 100))
        .thenAnswer((_) async => [track]);
    when(() => cacheStore.loadCachedAudioEntries()).thenAnswer((_) async => [
          CachedAudioEntry(
            cacheKey: key,
            title: track.title,
            album: track.album,
            artists: track.artists,
            cachedAt: DateTime(2026),
            bytes: 123456,
            mediaItem: track,
          ),
        ]);
    expect(
        await state.signIn(
          serverUrl: 'https://example.com',
          username: 'user',
          password: 'password',
        ),
        isTrue);

    final preview = await state.prepareWholeLibraryOfflinePreview();

    expect(preview, isNotNull);
    expect(preview!.cachedTrackCount, 1);
    expect(preview.estimatedTotalBytes, 123456);
    expect(preview.estimatedRemainingBytes, 0);
  });

  group('AppState smart lists', () {
    test('selectSmartList evaluates tracks beyond the first library page',
        () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);
      stubSignedInRefresh(
        cacheStore: cacheStore,
        client: client,
        serverStore: serverStore,
      );

      final firstPage = List.generate(
        100,
        (index) => _track('page-1-$index'),
      );
      final match = _track('target', title: 'Needle Track');
      final secondPage = [match];
      final smartList = _titleContainsSmartList('Needle');

      when(
        () => client.fetchLibraryTracks(startIndex: 0, limit: 100),
      ).thenAnswer((_) async => firstPage);
      when(
        () => client.fetchLibraryTracks(startIndex: 100, limit: 100),
      ).thenAnswer((_) async => secondPage);

      await state.signIn(
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'password',
      );

      await state.selectSmartList(smartList);

      expect(state.smartListTracks, [match]);
      final captured = verify(
        () => cacheStore.saveLibraryTracks(captureAny()),
      ).captured.single as List<MediaItem>;
      expect(captured, [...firstPage, ...secondPage]);
    });

    test('selectSmartList can build from cached library snapshot', () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);

      final match = _track('cached-target', title: 'Cached Needle');
      final smartList = _titleContainsSmartList('Needle');
      when(
        () => cacheStore.loadLibraryTracks(),
      ).thenAnswer((_) async => [match]);

      await state.selectSmartList(smartList);

      expect(state.smartListTracks, [match]);
      verifyNever(
        () => client.fetchLibraryTracks(
          startIndex: any(named: 'startIndex'),
          limit: any(named: 'limit'),
        ),
      );
    });
  });

  group('AppState track status icons', () {
    test('returns downloaded for pinned tracks with no queue entry', () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);

      final track = _track('status-downloaded');
      when(() => cacheStore.isAudioCached(track)).thenAnswer((_) async => true);

      await state.makeTrackAvailableOffline(track);

      expect(
        state.trackStatusForStreamUrl(track.streamUrl),
        TrackStatusIconState.downloaded,
      );
    });

    test('returns inQueue while download is queued', () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);

      final track = _track('status-queued');
      when(() => cacheStore.isAudioCached(track))
          .thenAnswer((_) async => false);
      await state.setDownloadsPaused(true);
      await state.makeTrackAvailableOffline(track);

      expect(
        state.trackStatusForStreamUrl(track.streamUrl),
        TrackStatusIconState.inQueue,
      );
      expect(state.downloadQueue, hasLength(1));
      expect(state.downloadQueue.single.status, DownloadStatus.queued);
    });

    test('returns none when latest queue status is failed', () async {
      final cacheStore = _MockCacheStore();
      final client = _MockJellyfinClient();
      final playback = _MockPlaybackController();
      final serverStore = _MockServerStore();
      final settingsStore = _MockSettingsStore();
      final state = buildState(
        cacheStore: cacheStore,
        client: client,
        playback: playback,
        serverStore: serverStore,
        settingsStore: settingsStore,
      );
      addTearDown(state.dispose);

      final track = _track('status-failed');
      when(() => cacheStore.isAudioCached(track))
          .thenAnswer((_) async => false);
      when(
        () => cacheStore.downloadAudioWithProgress(
          track,
          headers: any(named: 'headers'),
        ),
      ).thenAnswer(
          (_) => Stream<FileResponse>.error(Exception('download failed')));

      await state.makeTrackAvailableOffline(track);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(state.downloadQueue, hasLength(1));
      expect(state.downloadQueue.single.status, DownloadStatus.failed);
      expect(
        state.trackStatusForStreamUrl(track.streamUrl),
        TrackStatusIconState.none,
      );
    });
  });
  Future<
      ({
        AppState state,
        _MockCacheStore cache,
        _MockJellyfinClient client,
        _MockServerStore servers,
        JellyfinClient runtime,
        _MockPlaybackController playback
      })> buildServerRaceState() async {
    final cache = _MockCacheStore();
    final client = _MockJellyfinClient();
    final playback = _MockPlaybackController();
    final servers = _MockServerStore();
    final settings = _MockSettingsStore();
    final state = buildState(
        cacheStore: cache,
        client: client,
        playback: playback,
        serverStore: servers,
        settingsStore: settings);
    addTearDown(state.dispose);
    stubSignedInRefresh(
        cacheStore: cache, client: client, serverStore: servers);
    final runtime = JellyfinClient();
    when(() => client.updateSession(any())).thenAnswer((call) {
      runtime.updateSession(call.positionalArguments.single as AuthSession);
    });
    when(() => client.authorizationHeaders)
        .thenAnswer((_) => runtime.authorizationHeaders);
    when(() => client.buildStreamUrl(
            itemId: any(named: 'itemId'), userId: any(named: 'userId')))
        .thenAnswer((call) => runtime.buildStreamUrl(
            itemId: call.namedArguments[#itemId] as String,
            userId: call.namedArguments[#userId] as String));
    when(() => servers.loadServers())
        .thenAnswer((_) async => [_savedServer, _remoteSavedServer]);
    when(() => servers.activate('server-2', addressId: 'address-2')).thenAnswer(
        (_) async => const StoredServerSession(
            server: _remoteSavedServer,
            session: AuthSession(
                accessToken: 'remote-token',
                serverUrl: 'https://remote.example.com',
                userId: 'remote-user',
                userName: 'Remote User')));
    expect(
        await state.signIn(
            serverUrl: 'https://example.com',
            username: 'user',
            password: 'password'),
        isTrue);
    return (
      state: state,
      cache: cache,
      client: client,
      servers: servers,
      runtime: runtime,
      playback: playback
    );
  }

  test('old track browse must not populate the new profile', () async {
    final h = await buildServerRaceState();
    final response = Completer<List<MediaItem>>();
    when(() => h.client.fetchLibraryTracks(
        startIndex: any(named: 'startIndex'),
        limit: any(named: 'limit'))).thenAnswer((_) => response.future);
    String? scope;
    when(() => h.cache.activateScope(any())).thenAnswer(
        (call) => scope = call.positionalArguments.single as String?);
    final saved = <String>[];
    when(() => h.cache.saveLibraryTracks(any())).thenAnswer((call) async {
      saved.add(
          '$scope:${(call.positionalArguments.single as List<MediaItem>).map((t) => t.id).join(',')}');
    });
    final pending = h.state.loadLibraryTracks();
    expect(
        await h.state.switchServer('server-2', addressId: 'address-2'), isTrue);
    response.complete([_track('old-server-track')]);
    await pending;
    expect(h.state.libraryTracks, isEmpty,
        reason: 'Late A results must not appear in B.');
    expect(saved, isEmpty);
  });

  test('pending cache lookup must not send B token to A', () async {
    final h = await buildServerRaceState();
    final lookupStarted = Completer<void>();
    final cacheLookup = Completer<bool>();
    when(() => h.cache.isAudioCached(any())).thenAnswer((_) {
      if (!lookupStarted.isCompleted) lookupStarted.complete();
      return cacheLookup.future;
    });
    await h.state.setDownloadsPaused(true);
    final pin = h.state.makeTrackAvailableOffline(_track('old-server-track'));
    await lookupStarted.future;
    expect(
        await h.state.switchServer('server-2', addressId: 'address-2'), isTrue);
    cacheLookup.complete(false);
    await pin;
    final requests = <({String url, Map<String, String>? headers})>[];
    when(() => h.cache.downloadAudioWithProgress(any(),
        headers: any(named: 'headers'))).thenAnswer((call) {
      requests.add((
        url: (call.positionalArguments.single as MediaItem).streamUrl,
        headers: call.namedArguments[#headers] as Map<String, String>?
      ));
      return const Stream<FileResponse>.empty();
    });
    await h.state.setDownloadsPaused(false);
    expect(h.state.downloadQueue, isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(requests, isEmpty,
        reason: 'The A request must be cancelled when B is activated.');
  });

  test('removing A must not override a later switch to C', () async {
    final h = await buildServerRaceState();
    const third = SavedServer(
        id: 'server-3',
        name: 'Third',
        userId: 'third-user',
        userName: 'Third',
        addresses: [
          ServerAddress(
              id: 'address-3', name: 'Third', url: 'https://third.example.com')
        ],
        activeAddressId: 'address-3');
    const thirdSession = AuthSession(
        accessToken: 'third-token',
        serverUrl: 'https://third.example.com',
        userId: 'third-user',
        userName: 'Third');
    when(() => h.servers.activate('server-3', addressId: 'address-3'))
        .thenAnswer((_) async =>
            const StoredServerSession(server: third, session: thirdSession));
    when(() => h.servers.loadServers())
        .thenAnswer((_) async => [_savedServer, _remoteSavedServer, third]);
    final removalStarted = Completer<void>();
    final removed = Completer<StoredServerSession?>();
    when(() => h.servers.removeServer('server-1')).thenAnswer((_) {
      removalStarted.complete();
      return removed.future;
    });
    final pending = h.state.removeServer('server-1');
    await removalStarted.future;
    expect(
        await h.state.switchServer('server-3', addressId: 'address-3'), isTrue);
    removed.complete(const StoredServerSession(
        server: _remoteSavedServer,
        session: AuthSession(
            accessToken: 'remote-token',
            serverUrl: 'https://remote.example.com',
            userId: 'remote-user',
            userName: 'Remote User')));
    await pending;
    expect(h.state.activeServer!.id, 'server-3');
  });

  test('address switching must rebuild the restored playback URL', () async {
    final h = await buildServerRaceState();
    final alias = _savedServer.copyWith(addresses: [
      ..._savedServer.addresses,
      const ServerAddress(
          id: 'alias', name: 'Remote alias', url: 'https://alias.example.com'),
    ], activeAddressId: 'alias');
    const aliasSession = AuthSession(
        accessToken: 'token',
        serverUrl: 'https://alias.example.com',
        userId: 'user',
        userName: 'User');
    when(() => h.servers.activate('server-1', addressId: 'alias')).thenAnswer(
        (_) async => StoredServerSession(server: alias, session: aliasSession));
    final oldTrack = MediaItem(
        id: 'resume',
        title: 'Resume',
        album: 'Album',
        artists: const [],
        duration: const Duration(minutes: 3),
        imageUrl: null,
        streamUrl: h.runtime.buildStreamUrl(itemId: 'resume', userId: 'user'));
    when(() => h.cache.loadPlaybackResumeState()).thenAnswer((_) async =>
        PlaybackResumeState(
            track: oldTrack, position: const Duration(seconds: 15)));
    List<MediaItem>? restored;
    when(() => h.playback.setQueue(any(),
        startIndex: any(named: 'startIndex'),
        startPosition: any(named: 'startPosition'),
        cacheStore: any(named: 'cacheStore'),
        headers: any(named: 'headers'))).thenAnswer((call) async {
      restored = call.positionalArguments.single as List<MediaItem>;
    });
    expect(await h.state.switchServer('server-1', addressId: 'alias'), isTrue);
    expect(Uri.parse(restored!.single.streamUrl).host, 'alias.example.com');
  });
  test(
      'an old browse completes its own waiters without finishing the new browse',
      () async {
    final h = await buildServerRaceState();
    final oldResponse = Completer<List<MediaItem>>();
    final newResponse = Completer<List<MediaItem>>();
    var calls = 0;
    when(() => h.client.fetchLibraryTracks(
            startIndex: any(named: 'startIndex'), limit: any(named: 'limit')))
        .thenAnswer(
            (_) => calls++ == 0 ? oldResponse.future : newResponse.future);
    final oldLoad = h.state.loadLibraryTracks();
    final oldWaiter = h.state.loadLibraryTracks();
    await h.state.switchServer('server-2', addressId: 'address-2');
    final newLoad = h.state.loadLibraryTracks();
    var newWaiterFinished = false;
    final newWaiter =
        h.state.loadLibraryTracks().then((_) => newWaiterFinished = true);
    oldResponse.complete([_track('old')]);
    await Future.wait([oldLoad, oldWaiter]);
    expect(h.state.isLoadingTracks, isTrue);
    expect(newWaiterFinished, isFalse);
    expect(h.state.libraryTracks, isEmpty);
    newResponse.complete([_track('new')]);
    await Future.wait([newLoad, newWaiter]);
    expect(h.state.libraryTracks.map((t) => t.id), ['new']);
    expect(h.state.isLoadingTracks, isFalse);
  });

  test(
      'cache restoration finishing after another switch cannot replace its library',
      () async {
    final h = await buildServerRaceState();
    final oldSession = h.state.session!;
    final started = Completer<void>();
    final cached = Completer<List<Playlist>>();
    when(() => h.cache.loadPlaylists()).thenAnswer((_) {
      if (!started.isCompleted) {
        started.complete();
        return cached.future;
      }
      return Future.value([]);
    });
    when(() => h.servers.activate('server-1', addressId: 'address-1'))
        .thenAnswer((_) async =>
            StoredServerSession(server: _savedServer, session: oldSession));
    final pending = h.state.switchServer('server-2', addressId: 'address-2');
    await started.future;
    await h.state.switchServer('server-1', addressId: 'address-1');
    cached.complete([
      const Playlist(id: 'old', name: 'Old', trackCount: 1, imageUrl: null)
    ]);
    await pending;
    expect(h.state.activeServer!.id, 'server-1');
    expect(h.state.playlists, isEmpty);
  });

  test('identical playlist IDs on different servers do not accept stale tracks',
      () async {
    final h = await buildServerRaceState();
    const playlist =
        Playlist(id: 'shared', name: 'Shared', trackCount: 1, imageUrl: null);
    final started = Completer<void>();
    final oldResponse = Completer<List<MediaItem>>();
    when(() => h.cache.loadPlaylistTracks('shared'))
        .thenAnswer((_) async => []);
    when(() => h.client.fetchPlaylistTracks('shared')).thenAnswer((_) {
      if (!started.isCompleted) {
        started.complete();
        return oldResponse.future;
      }
      return Future.value([_track('new')]);
    });
    final pending = h.state.selectPlaylist(playlist);
    await started.future;
    await h.state.switchServer('server-2', addressId: 'address-2');
    await h.state.selectPlaylist(playlist);
    oldResponse.complete([_track('old')]);
    await pending;
    expect(h.state.playlistTracks.map((t) => t.id), ['new']);
    verifyNever(() => h.cache.savePlaylistTracks(
        'shared',
        any(
            that: predicate<List<MediaItem>>(
                (tracks) => tracks.any((t) => t.id == 'old')))));
  });

  test('offline album loading cannot pin or cache old tracks on the new server',
      () async {
    final h = await buildServerRaceState();
    final started = Completer<void>();
    final response = Completer<List<MediaItem>>();
    when(() => h.cache.loadAlbumTracks('album')).thenAnswer((_) async => []);
    when(() => h.client.fetchAlbumTracks('album')).thenAnswer((_) {
      started.complete();
      return response.future;
    });
    when(() => h.cache.saveAlbumTracks(any(), any())).thenAnswer((_) async {});
    final pending = h.state.makeAlbumAvailableOffline(_album('album'));
    await started.future;
    await h.state.switchServer('server-2', addressId: 'address-2');
    response.complete([_track('old')]);
    await pending;
    expect(h.state.downloadQueue, isEmpty);
    verifyNever(() => h.cache.setPinnedAudioItem(any(), true));
    verifyNever(() => h.cache.saveAlbumTracks(any(), any()));
  });

  test('playback cache preparation cannot set a queue after switching servers',
      () async {
    final h = await buildServerRaceState();
    final started = Completer<void>();
    final lookup = Completer<bool>();
    when(() => h.cache.isAudioCached(any())).thenAnswer((_) {
      started.complete();
      return lookup.future;
    });
    final track = _track('old');
    final pending = h.state.playFromList([track], track);
    await started.future;
    await h.state.switchServer('server-2', addressId: 'address-2');
    lookup.complete(false);
    await pending;
    expect(h.state.queue, isEmpty);
    expect(h.state.nowPlaying, isNull);
    verifyNever(() => h.playback.setQueue(any(),
        startIndex: any(named: 'startIndex'),
        cacheStore: any(named: 'cacheStore'),
        headers: any(named: 'headers')));
  });

  test('work started during a switch is invalidated when its session changes',
      () async {
    final h = await buildServerRaceState();
    final activated = Completer<StoredServerSession?>();
    when(() => h.servers.activate('server-2', addressId: 'address-2'))
        .thenAnswer((_) => activated.future);
    final switching = h.state.switchServer('server-2', addressId: 'address-2');
    final response = Completer<List<MediaItem>>();
    when(() => h.client.fetchLibraryTracks(
        startIndex: any(named: 'startIndex'),
        limit: any(named: 'limit'))).thenAnswer((_) => response.future);
    final loading = h.state.loadLibraryTracks();
    activated.complete(const StoredServerSession(
        server: _remoteSavedServer,
        session: AuthSession(
            accessToken: 'remote-token',
            serverUrl: 'https://remote.example.com',
            userId: 'remote-user',
            userName: 'Remote User')));
    await switching;
    response.complete([_track('old')]);
    await loading;
    expect(h.state.libraryTracks, isEmpty);
    verifyNever(() => h.cache.saveLibraryTracks(any()));
  });
  test(
      'resuming pins cannot enqueue a track after its cache lookup crosses a switch',
      () async {
    final h = await buildServerRaceState();
    final original = h.state.session!;
    final track = _track('resume-pin');
    final key =
        h.runtime.buildStreamUrl(itemId: track.id, userId: original.userId);
    when(() => h.servers.activate('server-1', addressId: 'address-1'))
        .thenAnswer((_) async =>
            StoredServerSession(server: _savedServer, session: original));
    when(() => h.cache.loadPinnedAudio()).thenAnswer((_) async => {key});
    when(() => h.cache.loadPinnedAudioItems()).thenAnswer((_) async => [track]);
    final started = Completer<void>();
    final lookup = Completer<bool>();
    when(() => h.cache.isAudioCached(any())).thenAnswer((_) {
      if (!started.isCompleted) started.complete();
      return lookup.future;
    });
    await h.state.setDownloadsPaused(true);
    await h.state.switchServer('server-1', addressId: 'address-1');
    await started.future;
    when(() => h.cache.loadPinnedAudio()).thenAnswer((_) async => {});
    when(() => h.cache.loadPinnedAudioItems()).thenAnswer((_) async => []);
    await h.state.switchServer('server-2', addressId: 'address-2');
    lookup.complete(false);
    await Future<void>.delayed(Duration.zero);
    expect(h.state.downloadQueue, isEmpty);
  });

  test('a late sign-in response restores the newer active client session',
      () async {
    final h = await buildServerRaceState();
    final response = Completer<AuthSession>();
    final oldSession = h.state.session!;
    when(() => h.client.authenticate(
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'password')).thenAnswer((_) async {
      final session = await response.future;
      h.runtime.updateSession(
          session); // Real authenticate updates the client eagerly.
      return session;
    });
    final pending = h.state.signIn(
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'password');
    await h.state.switchServer('server-2', addressId: 'address-2');
    response.complete(oldSession);
    expect(await pending, isFalse);
    expect(h.state.activeServer!.id, 'server-2');
    expect(h.runtime.authorizationHeaders!['Authorization'],
        contains('remote-token'));
    // Only the harness's original sign-in was stored.
    verify(() =>
            h.servers.addAuthenticatedServer(any(), name: any(named: 'name')))
        .called(1);
  });

  test('an old favorite failure cannot roll back the new profile', () async {
    final h = await buildServerRaceState();
    final response = Completer<void>();
    when(() => h.client.setFavorite(itemId: 'old', isFavorite: true))
        .thenAnswer((_) => response.future);
    final pending = h.state.setTrackFavorite(_track('old'), true);
    await h.state.switchServer('server-2', addressId: 'address-2');
    clearInteractions(h.cache);
    response.completeError(StateError('old server failed'));
    await pending;
    expect(h.state.favoriteTracks, isEmpty);
    verifyNever(() => h.cache.saveFavoriteTracks(any()));
  });

  test(
      'a playlist delete does not reach the new server after a cache-write delay',
      () async {
    final h = await buildServerRaceState();
    final saved = Completer<void>();
    when(() => h.cache.savePlaylists(any())).thenAnswer((_) => saved.future);
    const playlist =
        Playlist(id: 'shared', name: 'Shared', trackCount: 0, imageUrl: null);
    final pending = h.state.deletePlaylist(playlist);
    // The new server's refresh must not wait on the old cache write.
    when(() => h.cache.savePlaylists(any())).thenAnswer((_) async {});
    await h.state.switchServer('server-2', addressId: 'address-2');
    saved.complete();
    await pending;
    verifyNever(() => h.client.deletePlaylist(any()));
  });
}
