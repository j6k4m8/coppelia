import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'services/cache_store.dart';
import 'services/jellyfin_client.dart';
import 'services/playback_controller.dart';
import 'services/session_store.dart';
import 'state/app_state.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';

/// Root widget for the Copellia application.
class CopelliaApp extends StatelessWidget {
  /// Creates the app shell.
  const CopelliaApp({super.key, this.appState});

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
          final appState = AppState(
            cacheStore: cacheStore,
            client: client,
            playback: playback,
            sessionStore: sessionStore,
          );
          appState.bootstrap();
          return appState;
        },
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: CopelliaTheme.darkTheme,
          home: const _RootRouter(),
        ),
      );
    }

    return ChangeNotifierProvider<AppState>.value(
      value: appState!,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: CopelliaTheme.darkTheme,
        home: const _RootRouter(),
      ),
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
