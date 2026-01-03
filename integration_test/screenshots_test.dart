import 'dart:io';

import 'dart:convert';
import 'dart:async';

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
    if (target == 'settings') {
      appState.selectLibraryView(LibraryView.settings);
      await tester.pumpAndSettle();
    }

    await Future<void>.delayed(const Duration(seconds: 5));
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

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();
  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
