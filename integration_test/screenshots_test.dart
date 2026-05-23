import 'dart:io';

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coppelia/app.dart';
import 'package:coppelia/services/cache_store.dart';
import 'package:coppelia/services/jellyfin_client.dart';
import 'package:coppelia/services/playback_controller.dart';
import 'package:coppelia/services/settings_store.dart';
import 'package:coppelia/services/session_store.dart';
import 'package:coppelia/state/app_state.dart';
import 'package:coppelia/state/library_view.dart';

import 'screenshot_helper.dart';

const _targetPollStep = Duration(milliseconds: 200);
const _targetTimeout = Duration(seconds: 15);
const _finalSettleDelay = Duration(seconds: 5);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const target =
      String.fromEnvironment('SCREENSHOT_TARGET', defaultValue: 'login');
  const screenshotServer =
      String.fromEnvironment('SCREENSHOT_SERVER', defaultValue: '');
  const screenshotUsername =
      String.fromEnvironment('SCREENSHOT_USERNAME', defaultValue: '');
  const screenshotPassword =
      String.fromEnvironment('SCREENSHOT_PASSWORD', defaultValue: '');
  const disableScrollbars = bool.fromEnvironment(
      'SCREENSHOT_DISABLE_SCROLLBARS',
      defaultValue: false);

  testWidgets('capture screenshot - $target', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final appState = AppState(
      cacheStore: CacheStore(),
      client: JellyfinClient(),
      playback: PlaybackController(),
      sessionStore: SessionStore(),
      settingsStore: SettingsStore(),
    );
    await appState.bootstrap();

    if (target != 'login' &&
        (screenshotServer.isEmpty ||
            screenshotUsername.isEmpty ||
            screenshotPassword.isEmpty)) {
      throw StateError(
        'Screenshot target "$target" requires '
        'SCREENSHOT_SERVER, SCREENSHOT_USERNAME, and SCREENSHOT_PASSWORD.',
      );
    }

    if (target != 'login' && screenshotServer.isNotEmpty) {
      final success = await appState.signIn(
        serverUrl: screenshotServer,
        username: screenshotUsername,
        password: screenshotPassword,
      );
      if (!success) {
        throw StateError('Screenshot sign-in failed for $screenshotServer');
      }
    }
    final scrollController = ScrollController();
    final screenshotKey = GlobalKey();
    await tester.pumpWidget(
      ScrollConfiguration(
        behavior: disableScrollbars
            ? const _NoScrollbarBehavior()
            : const ScrollBehavior(),
        child: PrimaryScrollController(
          controller: scrollController,
          child: RepaintBoundary(
            key: screenshotKey,
            child: CoppeliaApp(appState: appState),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _prepareScreenshotTarget(
      tester: tester,
      appState: appState,
      target: target,
    );

    await Future<void>.delayed(_finalSettleDelay);
    await tester.pump();
    final screenshotData = await captureScreenshot(
      screenshotKey,
      pixelRatio:
          tester.binding.platformDispatcher.views.first.devicePixelRatio,
    );

    binding.reportData = <String, String>{
      'screenshot': base64Encode(screenshotData),
      'target': target,
      'platform': Platform.operatingSystem,
    };
  });
}

Future<void> _prepareScreenshotTarget({
  required WidgetTester tester,
  required AppState appState,
  required String target,
}) async {
  switch (target) {
    case 'login':
      return;
    case 'home':
      await _pumpForAsyncWork(tester);
      return;
    case 'settings':
      appState.selectLibraryView(LibraryView.settings);
      await _pumpForAsyncWork(tester);
      return;
    case 'albums':
      appState.selectLibraryView(LibraryView.albums);
      await _waitForCondition(
        tester,
        () => appState.albums.isNotEmpty,
      );
      return;
    case 'artists':
      appState.selectLibraryView(LibraryView.artists);
      await _waitForCondition(
        tester,
        () => appState.artists.isNotEmpty,
      );
      return;
    case 'tracks':
      appState.selectLibraryView(LibraryView.tracks);
      await _waitForCondition(
        tester,
        () => appState.libraryTracks.isNotEmpty || !appState.isLoadingTracks,
      );
      return;
    case 'playlists':
      appState.selectLibraryView(LibraryView.homePlaylists);
      await _pumpForAsyncWork(tester);
      return;
    case 'album-detail':
      await _prepareAlbumDetail(tester, appState);
      return;
    case 'artist-detail':
      await _prepareArtistDetail(tester, appState);
      return;
    case 'playlist-detail':
      await _preparePlaylistDetail(tester, appState);
      return;
    case 'queue':
      await _prepareQueue(tester, appState);
      return;
    default:
      throw UnsupportedError('Unknown screenshot target "$target".');
  }
}

Future<void> _prepareAlbumDetail(
  WidgetTester tester,
  AppState appState,
) async {
  final album =
      await appState.getRandomAlbum() ?? _firstOrNull(appState.albums);
  if (album == null) {
    throw StateError('Album detail screenshot requires at least one album.');
  }
  await appState.selectAlbum(album);
  await _waitForCondition(
    tester,
    () => appState.selectedAlbum?.id == album.id,
  );
}

Future<void> _prepareArtistDetail(
  WidgetTester tester,
  AppState appState,
) async {
  final artist =
      await appState.getRandomArtist() ?? _firstOrNull(appState.artists);
  if (artist == null) {
    throw StateError('Artist detail screenshot requires at least one artist.');
  }
  await appState.selectArtist(artist);
  await _waitForCondition(
    tester,
    () => appState.selectedArtist?.id == artist.id,
  );
}

Future<void> _preparePlaylistDetail(
  WidgetTester tester,
  AppState appState,
) async {
  final playlist = _firstOrNull(appState.playlists);
  if (playlist == null) {
    throw StateError(
      'Playlist detail screenshot requires at least one playlist.',
    );
  }
  await appState.selectPlaylist(playlist);
  await _waitForCondition(
    tester,
    () => appState.selectedPlaylist?.id == playlist.id,
  );
}

Future<void> _prepareQueue(
  WidgetTester tester,
  AppState appState,
) async {
  if (appState.queue.isEmpty) {
    final album =
        await appState.getRandomAlbum() ?? _firstOrNull(appState.albums);
    if (album != null) {
      await appState.playAlbum(album);
    } else {
      final track = await appState.getRandomTrack() ??
          _firstOrNull(appState.featuredTracks);
      if (track == null) {
        throw StateError(
            'Queue screenshot requires at least one playable item.');
      }
      await appState.enqueueTrack(track);
    }
    await _waitForCondition(
      tester,
      () => appState.queue.isNotEmpty,
    );
    if (appState.isPlaying) {
      await appState.togglePlayback();
      await _pumpForAsyncWork(tester);
    }
  }

  appState.selectLibraryView(LibraryView.queue);
  await _waitForCondition(
    tester,
    () => appState.selectedView == LibraryView.queue,
  );
}

T? _firstOrNull<T>(List<T> items) => items.isEmpty ? null : items.first;

Future<void> _waitForCondition(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = _targetTimeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) {
      break;
    }
    await tester.pump(_targetPollStep);
  }
  await _pumpForAsyncWork(tester);
}

Future<void> _pumpForAsyncWork(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 300));
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();
  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
