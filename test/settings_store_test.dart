import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coppelia/services/settings_store.dart';
import 'package:coppelia/state/accent_color_source.dart';
import 'package:coppelia/state/home_section.dart';
import 'package:coppelia/state/sidebar_item.dart';
import 'package:coppelia/state/theme_palette_source.dart';

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

  test('settings store defaults to SF Pro Display font family', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore();

    final family = await store.loadFontFamily();

    expect(family, 'SF Pro Display');
  });

  test('settings store supports system font family', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore();

    await store.saveFontFamily(null);
    final family = await store.loadFontFamily();

    expect(family, isNull);
  });

  test('settings store saves font scale', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore();

    await store.saveFontScale(1.1);
    final scale = await store.loadFontScale();

    expect(scale, closeTo(1.1, 0.001));
  });

  test('settings store defaults accent color and sources', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore();

    final colorValue = await store.loadAccentColorValue();
    final source = await store.loadAccentColorSource();
    final paletteSource = await store.loadThemePaletteSource();

    expect(colorValue, 0xFF6F7BFF);
    expect(source, AccentColorSource.preset);
    expect(paletteSource, ThemePaletteSource.defaultPalette);
  });

  test('settings store saves accent color and sources', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore();

    await store.saveAccentColorValue(0xFF123456);
    await store.saveAccentColorSource(AccentColorSource.custom);
    await store.saveThemePaletteSource(ThemePaletteSource.nowPlaying);

    expect(await store.loadAccentColorValue(), 0xFF123456);
    expect(
      await store.loadAccentColorSource(),
      AccentColorSource.custom,
    );
    expect(
      await store.loadThemePaletteSource(),
      ThemePaletteSource.nowPlaying,
    );
  });

  test('settings store defaults telemetry toggles to true', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore();

    final playback = await store.loadPlaybackTelemetry();
    final progress = await store.loadProgressTelemetry();
    final history = await store.loadHistoryTelemetry();

    expect(playback, isTrue);
    expect(progress, isTrue);
    expect(history, isTrue);
  });

  test('settings store saves telemetry toggles', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore();

    await store.savePlaybackTelemetry(false);
    await store.saveProgressTelemetry(false);
    await store.saveHistoryTelemetry(false);

    expect(await store.loadPlaybackTelemetry(), isFalse);
    expect(await store.loadProgressTelemetry(), isFalse);
    expect(await store.loadHistoryTelemetry(), isFalse);
  });

  test('settings store saves offline mode', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore();

    expect(await store.loadOfflineMode(), isFalse);
    await store.saveOfflineMode(true);

    expect(await store.loadOfflineMode(), isTrue);
  });
}
