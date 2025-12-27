import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/now_playing_layout.dart';

/// Persists user preferences for the app.
class SettingsStore {
  /// Creates a settings store.
  SettingsStore();

  static const _themeKey = 'settings_theme_mode';
  static const _layoutKey = 'settings_now_playing_layout';
  static const _sidebarWidthKey = 'settings_sidebar_width';

  /// Loads the preferred theme mode.
  Future<ThemeMode> loadThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_themeKey);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.dark;
    }
  }

  /// Saves the preferred theme mode.
  Future<void> saveThemeMode(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    final value = mode == ThemeMode.light ? 'light' : 'dark';
    await preferences.setString(_themeKey, value);
  }

  /// Loads the preferred now playing layout.
  Future<NowPlayingLayout> loadNowPlayingLayout() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_layoutKey);
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
}
