import 'dart:async';

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
import 'package:coppelia/state/sidebar_item.dart';

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
      () => cacheStore.clearOfflineAudioState(),
    ).thenAnswer((_) async {});
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
      expect(state.isSidebarItemVisible(SidebarItem.servers), isTrue);
      await state.setSidebarItemVisible(SidebarItem.servers, false);
      expect(state.isSidebarItemVisible(SidebarItem.servers), isFalse);
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
            streamUrl: manualTrack.streamUrl,
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
            streamUrl: manualTrack.streamUrl,
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
}
