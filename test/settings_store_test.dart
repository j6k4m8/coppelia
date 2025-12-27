import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:copellia/services/settings_store.dart';
import 'package:copellia/state/home_section.dart';
import 'package:copellia/state/sidebar_item.dart';

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

  test('settings store saves home section visibility', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore();

    await store.saveHomeSectionVisibility({
      HomeSection.featured: true,
      HomeSection.recent: false,
      HomeSection.playlists: true,
    });
    final visibility = await store.loadHomeSectionVisibility();

    expect(visibility[HomeSection.featured], isTrue);
    expect(visibility[HomeSection.recent], isFalse);
    expect(visibility[HomeSection.playlists], isTrue);
  });

  test('settings store saves sidebar visibility', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore();

    await store.saveSidebarVisibility({
      SidebarItem.home: true,
      SidebarItem.settings: false,
      SidebarItem.queue: true,
    });
    final visibility = await store.loadSidebarVisibility();

    expect(visibility[SidebarItem.home], isTrue);
    expect(visibility[SidebarItem.settings], isFalse);
    expect(visibility[SidebarItem.queue], isTrue);
  });
}
