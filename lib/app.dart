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
    final state = context.read<AppState>();
    final themeMode = context.select((AppState s) => s.themeMode);
    final fontFamily = context.select((AppState s) => s.fontFamily);
    final fontScale = context.select((AppState s) => s.fontScale);
    final accentColor = context.select((AppState s) => s.accentColor);
    final useNowPlayingPalette =
        context.select((AppState s) => s.useNowPlayingPalette);
    final nowPlayingPalette =
        context.select((AppState s) => s.nowPlayingPalette);
    final hasSession = context.select((AppState s) => s.session != null);
    final isPlaying = context.select((AppState s) => s.isPlaying);
    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      themeAnimationDuration: const Duration(milliseconds: 600),
      themeAnimationCurve: Curves.easeOutCubic,
      theme: CoppeliaTheme.lightTheme(
        fontFamily: fontFamily,
        fontScale: fontScale,
        accentColor: accentColor,
        nowPlayingPalette:
            useNowPlayingPalette ? nowPlayingPalette : null,
      ),
      darkTheme: CoppeliaTheme.darkTheme(
        fontFamily: fontFamily,
        fontScale: fontScale,
        accentColor: accentColor,
        nowPlayingPalette:
            useNowPlayingPalette ? nowPlayingPalette : null,
      ),
      themeMode: themeMode,
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
              label: isPlaying ? 'Pause' : 'Play',
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
    final isBootstrapping =
        context.select((AppState state) => state.isBootstrapping);
    final hasSession =
        context.select((AppState state) => state.session != null);
    if (isBootstrapping) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!hasSession) {
      return const LoginScreen();
    }

    return const HomeScreen();
  }
}
