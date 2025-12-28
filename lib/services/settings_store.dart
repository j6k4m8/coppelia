import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/now_playing_layout.dart';
import '../state/home_section.dart';
import '../state/sidebar_item.dart';

/// Persists user preferences for the app.
class SettingsStore {
  /// Creates a settings store.
  SettingsStore();

  static const _themeKey = 'settings_theme_mode';
  static const _layoutKey = 'settings_now_playing_layout';
  static const _sidebarWidthKey = 'settings_sidebar_width';
  static const _sidebarCollapsedKey = 'settings_sidebar_collapsed';
  static const _homeSectionKey = 'settings_home_sections';
  static const _sidebarVisibilityKey = 'settings_sidebar_visibility';
  static const _fontFamilyKey = 'settings_font_family';
  static const _fontScaleKey = 'settings_font_scale';
  static const _telemetryPlaybackKey = 'settings_telemetry_playback';
  static const _telemetryProgressKey = 'settings_telemetry_progress';
  static const _telemetryHistoryKey = 'settings_telemetry_history';

  /// Loads the preferred theme mode.
  Future<ThemeMode> loadThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_themeKey);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  /// Saves the preferred theme mode.
  Future<void> saveThemeMode(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
    await preferences.setString(_themeKey, value);
  }

  /// Loads the preferred now playing layout.
  Future<NowPlayingLayout> loadNowPlayingLayout() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_layoutKey);
    if (raw == null && defaultTargetPlatform == TargetPlatform.iOS) {
      return NowPlayingLayout.bottom;
    }
    return raw == 'bottom'
        ? NowPlayingLayout.bottom
        : NowPlayingLayout.side;
  }

  /// Saves the preferred now playing layout.
  Future<void> saveNowPlayingLayout(NowPlayingLayout layout) async {
    final preferences = await SharedPreferences.getInstance();
    final value = layout == NowPlayingLayout.bottom ? 'bottom' : 'side';
    await preferences.setString(_layoutKey, value);
  }

  /// Loads the preferred sidebar width.
  Future<double> loadSidebarWidth() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getDouble(_sidebarWidthKey) ?? 240;
  }

  /// Saves the preferred sidebar width.
  Future<void> saveSidebarWidth(double width) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_sidebarWidthKey, width);
  }

  /// Loads the preferred sidebar collapsed state.
  Future<bool> loadSidebarCollapsed() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_sidebarCollapsedKey) ?? false;
  }

  /// Saves the preferred sidebar collapsed state.
  Future<void> saveSidebarCollapsed(bool collapsed) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_sidebarCollapsedKey, collapsed);
  }

  /// Loads the preferred home section visibility map.
  Future<Map<HomeSection, bool>> loadHomeSectionVisibility() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_homeSectionKey);
    final visibility = {
      for (final section in HomeSection.values) section: true,
    };
    if (raw == null) {
      return visibility;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    for (final section in HomeSection.values) {
      final value = decoded[section.storageKey];
      if (value is bool) {
        visibility[section] = value;
      }
    }
    return visibility;
  }

  /// Saves the preferred home section visibility map.
  Future<void> saveHomeSectionVisibility(
    Map<HomeSection, bool> visibility,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final payload = <String, bool>{
      for (final section in HomeSection.values)
        section.storageKey: visibility[section] ?? true,
    };
    await preferences.setString(_homeSectionKey, jsonEncode(payload));
  }

  /// Loads the preferred sidebar visibility map.
  Future<Map<SidebarItem, bool>> loadSidebarVisibility() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_sidebarVisibilityKey);
    final visibility = {
      for (final item in SidebarItem.values) item: true,
    };
    if (raw == null) {
      return visibility;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    for (final item in SidebarItem.values) {
      final value = decoded[item.storageKey];
      if (value is bool) {
        visibility[item] = value;
      }
    }
    return visibility;
  }

  /// Saves the preferred sidebar visibility map.
  Future<void> saveSidebarVisibility(
    Map<SidebarItem, bool> visibility,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final payload = <String, bool>{
      for (final item in SidebarItem.values)
        item.storageKey: visibility[item] ?? true,
    };
    await preferences.setString(_sidebarVisibilityKey, jsonEncode(payload));
  }

  /// Loads the preferred font family.
  Future<String?> loadFontFamily() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_fontFamilyKey);
    if (raw == null) {
      return 'SF Pro Display';
    }
    if (raw == 'system') {
      return null;
    }
    return raw;
  }

  /// Saves the preferred font family.
  Future<void> saveFontFamily(String? family) async {
    final preferences = await SharedPreferences.getInstance();
    final value = (family == null || family.trim().isEmpty)
        ? 'system'
        : family.trim();
    await preferences.setString(_fontFamilyKey, value);
  }

  /// Loads the preferred font scale.
  Future<double> loadFontScale() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getDouble(_fontScaleKey);
    return raw ?? 1.0;
  }

  /// Saves the preferred font scale.
  Future<void> saveFontScale(double scale) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_fontScaleKey, scale);
  }

  /// Loads the playback telemetry preference.
  Future<bool> loadPlaybackTelemetry() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_telemetryPlaybackKey) ?? true;
  }

  /// Saves the playback telemetry preference.
  Future<void> savePlaybackTelemetry(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_telemetryPlaybackKey, enabled);
  }

  /// Loads the playback progress telemetry preference.
  Future<bool> loadProgressTelemetry() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_telemetryProgressKey) ?? true;
  }

  /// Saves the playback progress telemetry preference.
  Future<void> saveProgressTelemetry(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_telemetryProgressKey, enabled);
  }

  /// Loads the playback history telemetry preference.
  Future<bool> loadHistoryTelemetry() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_telemetryHistoryKey) ?? true;
  }

  /// Saves the playback history telemetry preference.
  Future<void> saveHistoryTelemetry(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_telemetryHistoryKey, enabled);
  }
}
