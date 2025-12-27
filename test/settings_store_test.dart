import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:copellia/services/settings_store.dart';

void main() {
  test('settings store defaults to dark theme', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore();

    final mode = await store.loadThemeMode();

    expect(mode, ThemeMode.dark);
  });

  test('settings store saves system theme mode', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore();

    await store.saveThemeMode(ThemeMode.system);
    final mode = await store.loadThemeMode();

    expect(mode, ThemeMode.system);
  });
}
