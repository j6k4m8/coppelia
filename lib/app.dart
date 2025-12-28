import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'services/cache_store.dart';
import 'services/jellyfin_client.dart';
import 'services/playback_controller.dart';
import 'services/settings_store.dart';
import 'services/session_store.dart';
import 'state/app_state.dart';
import 'state/library_view.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/widgets/playback_shortcuts.dart';

/// Root widget for the Coppelia application.
class CoppeliaApp extends StatelessWidget {
  /// Creates the app shell.
  const CoppeliaApp({super.key, this.appState});

  /// Optional app state override for tests.
  final AppState? appState;

  @override
  Widget build(BuildContext context) {
    if (appState == null) {
      return ChangeNotifierProvider<AppState>(
        create: (_) {
          final cacheStore = CacheStore();
          final sessionStore = SessionStore();
          final playback = PlaybackController();
          final client = JellyfinClient();
          final settingsStore = SettingsStore();
          final appState = AppState(
            cacheStore: cacheStore,
            client: client,
            playback: playback,
            sessionStore: sessionStore,
            settingsStore: settingsStore,
          );
          appState.bootstrap();
          return appState;
        },
        child: const _AppShell(),
      );
    }

    return ChangeNotifierProvider<AppState>.value(
      value: appState!,
      child: const _AppShell(),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hasSession = state.session != null;
    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CoppeliaTheme.lightTheme(
        fontFamily: state.fontFamily,
        fontScale: state.fontScale,
      ),
      darkTheme: CoppeliaTheme.darkTheme(
        fontFamily: state.fontFamily,
        fontScale: state.fontScale,
      ),
      themeMode: state.themeMode,
      home: const _RootRouter(),
      builder: (context, child) {
        return PlaybackShortcuts(child: child ?? const SizedBox.shrink());
      },
    );

    if (!Platform.isMacOS) {
      return app;
    }

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Library',
          menus: [
            PlatformMenuItem(
              label: 'Home',
              onSelected: () => state.selectLibraryView(LibraryView.home),
            ),
            PlatformMenuItem(
              label: 'Settings',
              onSelected: () => state.selectLibraryView(LibraryView.settings),
            ),
            PlatformMenuItem(
              label: 'Refresh Library',
              onSelected: state.refreshLibrary,
            ),
          ],
        ),
        PlatformMenu(
          label: 'Playback',
          menus: [
            PlatformMenuItem(
              label: state.isPlaying ? 'Pause' : 'Play',
              onSelected: hasSession ? state.togglePlayback : null,
            ),
            PlatformMenuItem(
              label: 'Next Track',
              onSelected: hasSession ? state.nextTrack : null,
            ),
            PlatformMenuItem(
              label: 'Previous Track',
              onSelected: hasSession ? state.previousTrack : null,
            ),
          ],
        ),
      ],
      child: app,
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.isBootstrapping) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (state.session == null) {
      return const LoginScreen();
    }

    return const HomeScreen();
  }
}
