import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/now_playing_layout.dart';
import '../state/home_section.dart';
import '../state/home_shelf_layout.dart';
import '../state/keyboard_shortcut.dart';
import '../state/layout_density.dart';
import '../state/corner_radius_style.dart';
import '../state/sidebar_item.dart';
import '../state/accent_color_source.dart';
import '../state/theme_palette_source.dart';
import '../models/smart_list.dart';

/// Persists user preferences for the app.
class SettingsStore {
  /// Creates a settings store.
  SettingsStore();

  static const _themeKey = 'settings_theme_mode';
  static const _layoutKey = 'settings_now_playing_layout';
  static const _sidebarWidthKey = 'settings_sidebar_width';
  static const _sidebarCollapsedKey = 'settings_sidebar_collapsed';
  static const _homeSectionKey = 'settings_home_sections';
  static const _homeSectionOrderKey = 'settings_home_section_order';
  static const _homeShelfLayoutKey = 'settings_home_shelf_layout';
  static const _homeShelfGridRowsKey = 'settings_home_shelf_grid_rows';
  static const _sidebarVisibilityKey = 'settings_sidebar_visibility';
  static const _fontFamilyKey = 'settings_font_family';
  static const _fontScaleKey = 'settings_font_scale';
  static const _accentColorKey = 'settings_accent_color';
  static const _accentSourceKey = 'settings_accent_source';
  static const _themePaletteSourceKey = 'settings_theme_palette_source';
  static const _telemetryPlaybackKey = 'settings_telemetry_playback';
  static const _telemetryProgressKey = 'settings_telemetry_progress';
  static const _telemetryHistoryKey = 'settings_telemetry_history';
  static const _gaplessPlaybackKey = 'settings_gapless_playback';
  static const _downloadsWifiOnlyKey = 'settings_downloads_wifi_only';
  static const _downloadsPausedKey = 'settings_downloads_paused';
  static const _autoDownloadFavoritesKey =
      'settings_auto_download_favorites';
  static const _autoDownloadFavoriteAlbumsKey =
      'settings_auto_download_favorites_albums';
  static const _autoDownloadFavoriteArtistsKey =
      'settings_auto_download_favorites_artists';
  static const _autoDownloadFavoriteTracksKey =
      'settings_auto_download_favorites_tracks';
  static const _autoDownloadFavoritesWifiOnlyKey =
      'settings_auto_download_favorites_wifi_only';
  static const _settingsShortcutEnabledKey =
      'settings_shortcut_settings_enabled';
  static const _settingsShortcutKey = 'settings_shortcut_settings';
  static const _searchShortcutEnabledKey =
      'settings_shortcut_search_enabled';
  static const _searchShortcutKey = 'settings_shortcut_search';
  static const _layoutDensityKey = 'settings_layout_density';
  static const _cornerRadiusStyleKey = 'settings_corner_radius_style';
  static const _deviceIdKey = 'settings_device_id';
  static const _offlineModeKey = 'settings_offline_mode';
  static const _smartListsKey = 'settings_smart_lists';
  static const _skysetOnTrackChangeKey = 'settings_skyset_on_track_change';
  static const _skysetPeriodicKey = 'settings_skyset_periodic';
  static const _skysetIntervalMinutesKey =
      'settings_skyset_interval_minutes';
  static const _skysetOutputPathKey = 'settings_skyset_output_path';
  static const int _defaultAccentValue = 0xFF6F7BFF;

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

  /// Loads whether the settings shortcut is enabled.
  Future<bool> loadSettingsShortcutEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_settingsShortcutEnabledKey) ?? true;
  }

  /// Saves whether the settings shortcut is enabled.
  Future<void> saveSettingsShortcutEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_settingsShortcutEnabledKey, enabled);
  }

  /// Loads the settings shortcut.
  Future<KeyboardShortcut> loadSettingsShortcut() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_settingsShortcutKey);
    return KeyboardShortcut.tryParse(raw) ??
        KeyboardShortcut.defaultForPlatform();
  }

  /// Saves the settings shortcut.
  Future<void> saveSettingsShortcut(KeyboardShortcut shortcut) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_settingsShortcutKey, shortcut.serialize());
  }

  /// Loads whether the search shortcut is enabled.
  Future<bool> loadSearchShortcutEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_searchShortcutEnabledKey) ?? true;
  }

  /// Saves whether the search shortcut is enabled.
  Future<void> saveSearchShortcutEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_searchShortcutEnabledKey, enabled);
  }

  /// Loads the search shortcut.
  Future<KeyboardShortcut> loadSearchShortcut() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_searchShortcutKey);
    return KeyboardShortcut.tryParse(raw) ??
        KeyboardShortcut.searchForPlatform();
  }

  /// Saves the search shortcut.
  Future<void> saveSearchShortcut(KeyboardShortcut shortcut) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_searchShortcutKey, shortcut.serialize());
  }

  /// Loads whether gapless playback is enabled.
  Future<bool> loadGaplessPlayback() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_gaplessPlaybackKey) ?? true;
  }

  /// Saves whether gapless playback is enabled.
  Future<void> saveGaplessPlayback(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_gaplessPlaybackKey, enabled);
  }

  /// Loads whether downloads should be restricted to Wi-Fi.
  Future<bool> loadDownloadsWifiOnly() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_downloadsWifiOnlyKey) ?? false;
  }

  /// Saves whether downloads should be restricted to Wi-Fi.
  Future<void> saveDownloadsWifiOnly(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_downloadsWifiOnlyKey, enabled);
  }

  /// Loads whether downloads are paused.
  Future<bool> loadDownloadsPaused() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_downloadsPausedKey) ?? false;
  }

  /// Saves whether downloads are paused.
  Future<void> saveDownloadsPaused(bool paused) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_downloadsPausedKey, paused);
  }


  /// Loads whether offline mode is enabled.
  Future<bool> loadOfflineMode() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_offlineModeKey) ?? false;
  }

  /// Saves whether offline mode is enabled.
  Future<void> saveOfflineMode(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_offlineModeKey, enabled);
  }

  /// Loads stored Smart Lists.
  Future<List<SmartList>> loadSmartLists() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_smartListsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final payload = jsonDecode(raw) as List<dynamic>;
      return payload
          .whereType<Map<String, dynamic>>()
          .map(SmartList.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves Smart Lists locally.
  Future<void> saveSmartLists(List<SmartList> lists) async {
    final preferences = await SharedPreferences.getInstance();
    final payload = lists.map((list) => list.toJson()).toList();
    await preferences.setString(_smartListsKey, jsonEncode(payload));
  }

  /// Loads or generates a unique device identifier.
  Future<String> loadDeviceId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(1 << 32).toRadixString(16);
    final platform = _platformLabel();
    final deviceId = 'coppelia-$platform-$now-$random';
    await preferences.setString(_deviceIdKey, deviceId);
    return deviceId;
  }

  String _platformLabel() {
    if (kIsWeb) {
      return 'web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  /// Loads the preferred now playing layout.
  Future<NowPlayingLayout> loadNowPlayingLayout() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_layoutKey);
    if (raw == null) {
      return NowPlayingLayout.bottom;
    }
    return raw == 'side' ? NowPlayingLayout.side : NowPlayingLayout.bottom;
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

  /// Loads the preferred home section order.
  Future<List<HomeSection>> loadHomeSectionOrder() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_homeSectionOrderKey);
    final defaultOrder = List<HomeSection>.from(HomeSection.values);
    if (raw == null || raw.isEmpty) {
      return defaultOrder;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final ordered = decoded
          .map((entry) => entry?.toString())
          .whereType<String>()
          .map(
            (key) => HomeSection.values.firstWhere(
              (section) => section.storageKey == key,
              orElse: () => HomeSection.featured,
            ),
          )
          .toList();
      final seen = <HomeSection>{};
      final filtered = <HomeSection>[];
      for (final section in ordered) {
        if (seen.add(section)) {
          filtered.add(section);
        }
      }
      for (final section in HomeSection.values) {
        if (!seen.contains(section)) {
          filtered.add(section);
        }
      }
      return filtered;
    } catch (_) {
      return defaultOrder;
    }
  }

  /// Loads the preferred home shelf layout.
  Future<HomeShelfLayout> loadHomeShelfLayout() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_homeShelfLayoutKey);
    if (raw == null) {
      return HomeShelfLayout.whooshy;
    }
    return HomeShelfLayout.values.firstWhere(
      (layout) => layout.name == raw,
      orElse: () => HomeShelfLayout.whooshy,
    );
  }

  /// Loads the preferred home shelf grid row count.
  Future<int> loadHomeShelfGridRows() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getInt(_homeShelfGridRowsKey);
    if (raw == null) {
      return 2;
    }
    return raw.clamp(1, 4);
  }

  /// Saves the preferred home section order.
  Future<void> saveHomeSectionOrder(List<HomeSection> order) async {
    final preferences = await SharedPreferences.getInstance();
    final payload = order.map((section) => section.storageKey).toList();
    await preferences.setString(_homeSectionOrderKey, jsonEncode(payload));
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

  /// Saves the preferred home shelf layout.
  Future<void> saveHomeShelfLayout(HomeShelfLayout layout) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_homeShelfLayoutKey, layout.name);
  }

  /// Saves the preferred home shelf grid row count.
  Future<void> saveHomeShelfGridRows(int rows) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_homeShelfGridRowsKey, rows);
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

  /// Loads the preferred corner radius style.
  Future<CornerRadiusStyle> loadCornerRadiusStyle() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_cornerRadiusStyleKey);
    return CornerRadiusStyleX.tryParse(raw) ??
        CornerRadiusStyle.babyProofed;
  }

  /// Saves the preferred corner radius style.
  Future<void> saveCornerRadiusStyle(CornerRadiusStyle style) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_cornerRadiusStyleKey, style.storageKey);
  }

  /// Loads the preferred accent color value.
  Future<int> loadAccentColorValue() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_accentColorKey) ?? _defaultAccentValue;
  }

  /// Saves the preferred accent color value.
  Future<void> saveAccentColorValue(int value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_accentColorKey, value);
  }

  /// Loads the preferred accent source.
  Future<AccentColorSource> loadAccentColorSource() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_accentSourceKey);
    return AccentColorSourceMeta.fromStorage(raw);
  }

  /// Saves the preferred accent source.
  Future<void> saveAccentColorSource(AccentColorSource source) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_accentSourceKey, source.storageKey);
  }

  /// Loads the preferred theme palette source.
  Future<ThemePaletteSource> loadThemePaletteSource() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_themePaletteSourceKey);
    return ThemePaletteSourceMeta.fromStorage(raw);
  }

  /// Saves the preferred theme palette source.
  Future<void> saveThemePaletteSource(ThemePaletteSource source) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themePaletteSourceKey, source.storageKey);
  }

  /// Loads the preferred layout density.
  Future<LayoutDensity> loadLayoutDensity() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_layoutDensityKey);
    switch (raw) {
      case 'sardine':
        return LayoutDensity.sardine;
      case 'spacious':
        return LayoutDensity.spacious;
      case 'comfortable':
      default:
        return LayoutDensity.comfortable;
    }
  }

  /// Saves the preferred layout density.
  Future<void> saveLayoutDensity(LayoutDensity density) async {
    final preferences = await SharedPreferences.getInstance();
    final value = switch (density) {
      LayoutDensity.sardine => 'sardine',
      LayoutDensity.comfortable => 'comfortable',
      LayoutDensity.spacious => 'spacious',
    };
    await preferences.setString(_layoutDensityKey, value);
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

  /// Loads whether favorites should be auto-downloaded for offline playback.
  Future<bool> loadAutoDownloadFavoritesEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_autoDownloadFavoritesKey) ?? false;
  }

  /// Saves whether favorites should be auto-downloaded for offline playback.
  Future<void> saveAutoDownloadFavoritesEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoDownloadFavoritesKey, enabled);
  }

  /// Loads whether favorited albums should be auto-downloaded.
  Future<bool> loadAutoDownloadFavoriteAlbums() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_autoDownloadFavoriteAlbumsKey) ?? true;
  }

  /// Saves whether favorited albums should be auto-downloaded.
  Future<void> saveAutoDownloadFavoriteAlbums(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoDownloadFavoriteAlbumsKey, enabled);
  }

  /// Loads whether favorited artists should be auto-downloaded.
  Future<bool> loadAutoDownloadFavoriteArtists() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_autoDownloadFavoriteArtistsKey) ?? true;
  }

  /// Saves whether favorited artists should be auto-downloaded.
  Future<void> saveAutoDownloadFavoriteArtists(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoDownloadFavoriteArtistsKey, enabled);
  }

  /// Loads whether favorited tracks should be auto-downloaded.
  Future<bool> loadAutoDownloadFavoriteTracks() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_autoDownloadFavoriteTracksKey) ?? true;
  }

  /// Saves whether favorited tracks should be auto-downloaded.
  Future<void> saveAutoDownloadFavoriteTracks(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoDownloadFavoriteTracksKey, enabled);
  }

  /// Loads whether auto-downloads are Wi-Fi only.
  Future<bool> loadAutoDownloadFavoritesWifiOnly() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_autoDownloadFavoritesWifiOnlyKey) ?? false;
  }

  /// Saves whether auto-downloads are Wi-Fi only.
  Future<void> saveAutoDownloadFavoritesWifiOnly(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoDownloadFavoritesWifiOnlyKey, enabled);
  }

  /// Loads whether Skyset writes should run on track changes.
  Future<bool> loadSkysetWriteOnTrackChange() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_skysetOnTrackChangeKey) ?? false;
  }

  /// Saves whether Skyset writes should run on track changes.
  Future<void> saveSkysetWriteOnTrackChange(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_skysetOnTrackChangeKey, enabled);
  }

  /// Loads whether Skyset writes should run on a periodic interval.
  Future<bool> loadSkysetWritePeriodic() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_skysetPeriodicKey) ?? false;
  }

  /// Saves whether Skyset writes should run on a periodic interval.
  Future<void> saveSkysetWritePeriodic(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_skysetPeriodicKey, enabled);
  }

  /// Loads the Skyset write interval in minutes.
  Future<int> loadSkysetIntervalMinutes() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getInt(_skysetIntervalMinutesKey) ?? 5;
    if (value < 1) {
      return 1;
    }
    if (value > 120) {
      return 120;
    }
    return value;
  }

  /// Saves the Skyset write interval in minutes.
  Future<void> saveSkysetIntervalMinutes(int minutes) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_skysetIntervalMinutesKey, minutes);
  }

  /// Loads the Skyset output path override.
  Future<String> loadSkysetOutputPath() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_skysetOutputPathKey) ?? '';
  }

  /// Saves the Skyset output path override.
  Future<void> saveSkysetOutputPath(String path) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_skysetOutputPathKey, path);
  }
}
