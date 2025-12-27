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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login screen is visible on launch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final appState = AppState(
      cacheStore: CacheStore(),
      client: JellyfinClient(),
      playback: PlaybackController(),
      sessionStore: SessionStore(),
      settingsStore: SettingsStore(),
    );
    await appState.bootstrap();

    await tester.pumpWidget(CoppeliaApp(appState: appState));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
