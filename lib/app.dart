import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'services/cache_store.dart';
import 'services/jellyfin_client.dart';
import 'services/menu_service.dart';
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
          MenuService.initialize(
            onShowPreferences: () {
              appState.selectLibraryView(LibraryView.settings);
            },
            onTogglePlayback: () => appState.togglePlayback(),
            onNextTrack: () => appState.nextTrack(),
            onPreviousTrack: () => appState.previousTrack(),
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
    final themeMode = context.select((AppState s) => s.themeMode);
    final fontFamily = context.select((AppState s) => s.fontFamily);
    final fontScale = context.select((AppState s) => s.fontScale);
    final accentColor = context.select((AppState s) => s.accentColor);
    final cornerRadiusScale =
        context.select((AppState s) => s.cornerRadiusScale);
    final useNowPlayingPalette =
        context.select((AppState s) => s.useNowPlayingPalette);
    final nowPlayingPalette =
        context.select((AppState s) => s.nowPlayingPalette);
    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      themeAnimationDuration: const Duration(milliseconds: 600),
      themeAnimationCurve: Curves.easeOutCubic,
      theme: CoppeliaTheme.lightTheme(
        fontFamily: fontFamily,
        fontScale: fontScale,
        cornerRadiusScale: cornerRadiusScale,
        accentColor: accentColor,
        nowPlayingPalette: useNowPlayingPalette ? nowPlayingPalette : null,
      ),
      darkTheme: CoppeliaTheme.darkTheme(
        fontFamily: fontFamily,
        fontScale: fontScale,
        cornerRadiusScale: cornerRadiusScale,
        accentColor: accentColor,
        nowPlayingPalette: useNowPlayingPalette ? nowPlayingPalette : null,
      ),
      themeMode: themeMode,
      home: const _RootRouter(),
      builder: (context, child) {
        return PlaybackShortcuts(child: child ?? const SizedBox.shrink());
      },
    );

    return app;
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
