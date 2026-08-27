import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:coppelia/services/cache_store.dart';
import 'package:coppelia/services/jellyfin_client.dart';
import 'package:coppelia/services/playback_controller.dart';
import 'package:coppelia/services/server_store.dart';
import 'package:coppelia/services/settings_store.dart';
import 'package:coppelia/state/app_state.dart';
import 'package:coppelia/ui/widgets/settings_view.dart';

class _MockCacheStore extends Mock implements CacheStore {}

class _MockJellyfinClient extends Mock implements JellyfinClient {}

class _MockPlaybackController extends Mock implements PlaybackController {}

class _MockServerStore extends Mock implements ServerStore {}

class _MockSettingsStore extends Mock implements SettingsStore {}

void main() {
  testWidgets('add-server dialog submits an empty password safely',
      (tester) async {
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
    when(
      () => client.authenticate(
        serverUrl: any(named: 'serverUrl'),
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    ).thenThrow(StateError('stop after capturing credentials'));

    final state = AppState(
      cacheStore: _MockCacheStore(),
      client: client,
      playback: playback,
      serverStore: _MockServerStore(),
      settingsStore: _MockSettingsStore(),
    );
    var stateDisposed = false;
    void disposeState() {
      if (!stateDisposed) {
        state.dispose();
        stateDisposed = true;
      }
    }

    addTearDown(disposeState);
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SettingsView())),
      ),
    );
    await tester.tap(find.text('Servers'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add server'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Server URL'),
      'music.example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'demo',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Add server'),
      ),
    );
    await tester.pumpAndSettle();

    verify(
      () => client.authenticate(
        serverUrl: 'music.example.com',
        username: 'demo',
        password: '',
      ),
    ).called(1);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    disposeState();
  });
}
