import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:copellia/app.dart';
import 'package:copellia/services/cache_store.dart';
import 'package:copellia/services/jellyfin_client.dart';
import 'package:copellia/services/playback_controller.dart';
import 'package:copellia/services/settings_store.dart';
import 'package:copellia/services/session_store.dart';
import 'package:copellia/state/app_state.dart';

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

    await tester.pumpWidget(CopelliaApp(appState: appState));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
