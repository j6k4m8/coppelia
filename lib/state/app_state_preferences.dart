part of 'app_state.dart';

extension AppStatePreferencesExtension on AppState {
  /// Updates the browse layout for a library view.
  void setBrowseLayout(LibraryView view, BrowseLayout layout) {
    _browseLayouts[view] = layout;
    _notify();
  }

  /// Updates the visibility of a home section.
  Future<void> setHomeSectionVisible(
    HomeSection section,
    bool visible,
  ) async {
    _homeSectionVisibility[section] = visible;
    await _settingsStore.saveHomeSectionVisibility(_homeSectionVisibility);
    _notify();
    if (section == HomeSection.jumpIn && visible) {
      unawaited(loadJumpIn(force: true));
    }
  }

  /// Updates the ordering of home sections.
  Future<void> reorderHomeSections(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) {
      return;
    }
    final list = List<HomeSection>.from(_homeSectionOrder);
    if (oldIndex < 0 || oldIndex >= list.length) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = list.removeAt(oldIndex);
    final target = newIndex.clamp(0, list.length);
    list.insert(target, moved);
    _homeSectionOrder = list;
    await _settingsStore.saveHomeSectionOrder(_homeSectionOrder);
    _notify();
  }

  /// Updates the visibility of a sidebar item.
  Future<void> setSidebarItemVisible(
    SidebarItem item,
    bool visible,
  ) async {
    _sidebarVisibility[item] = visible;
    await _settingsStore.saveSidebarVisibility(_sidebarVisibility);
    _notify();
  }

  /// Updates the theme preference.
  Future<void> setThemeMode(ThemeMode mode) async {
    await _savePreference(
      apply: () => _themeMode = mode,
      persist: () => _settingsStore.saveThemeMode(mode),
    );
  }

  /// Updates playback telemetry preference.
  Future<void> setTelemetryPlayback(bool enabled) async {
    await _savePreference(
      apply: () => _telemetryPlayback = enabled,
      persist: () => _settingsStore.savePlaybackTelemetry(enabled),
    );
  }

  /// Updates playback progress telemetry preference.
  Future<void> setTelemetryProgress(bool enabled) async {
    await _savePreference(
      apply: () => _telemetryProgress = enabled,
      persist: () => _settingsStore.saveProgressTelemetry(enabled),
    );
  }

  /// Updates playback history telemetry preference.
  Future<void> setTelemetryHistory(bool enabled) async {
    await _savePreference(
      apply: () => _telemetryHistory = enabled,
      persist: () => _settingsStore.saveHistoryTelemetry(enabled),
    );
  }

  /// Updates the gapless playback preference.
  Future<void> setGaplessPlayback(bool enabled) async {
    if (_gaplessPlayback == enabled) {
      return;
    }
    await _savePreference(
      apply: () => _gaplessPlayback = enabled,
      persist: () => _settingsStore.saveGaplessPlayback(enabled),
      afterSave: _applyPlaybackSettings,
    );
  }

  /// Updates the font family preference.
  Future<void> setFontFamily(String? family) async {
    await _savePreference(
      apply: () => _fontFamily = family,
      persist: () => _settingsStore.saveFontFamily(family),
    );
  }

  /// Updates the font scale preference.
  Future<void> setFontScale(double scale) async {
    await _savePreference(
      apply: () => _fontScale = scale,
      persist: () => _settingsStore.saveFontScale(scale),
    );
  }

  /// Updates the accent color preference.
  Future<void> setAccentColor(Color color) async {
    final colorValue = color.toARGB32();
    await _savePreference(
      apply: () => _accentColorValue = colorValue,
      persist: () => _settingsStore.saveAccentColorValue(colorValue),
    );
  }

  /// Updates the accent color source preference.
  Future<void> setAccentColorSource(AccentColorSource source) async {
    await _savePreference(
      apply: () => _accentColorSource = source,
      persist: () => _settingsStore.saveAccentColorSource(source),
      afterSave: () async {
        if (source == AccentColorSource.nowPlaying) {
          unawaited(_maybeUpdateNowPlayingPalette(_nowPlaying));
        }
      },
    );
  }

  /// Updates the theme palette source preference.
  Future<void> setThemePaletteSource(ThemePaletteSource source) async {
    await _savePreference(
      apply: () => _themePaletteSource = source,
      persist: () => _settingsStore.saveThemePaletteSource(source),
      afterSave: () async {
        if (source == ThemePaletteSource.nowPlaying) {
          unawaited(_maybeUpdateNowPlayingPalette(_nowPlaying));
        }
      },
    );
  }

  /// Updates the settings shortcut enabled preference.
  Future<void> setSettingsShortcutEnabled(bool enabled) async {
    await _savePreference(
      apply: () => _settingsShortcutEnabled = enabled,
      persist: () => _settingsStore.saveSettingsShortcutEnabled(enabled),
    );
  }

  /// Updates the settings shortcut preference.
  Future<void> setSettingsShortcut(KeyboardShortcut shortcut) async {
    await _savePreference(
      apply: () => _settingsShortcut = shortcut,
      persist: () => _settingsStore.saveSettingsShortcut(shortcut),
    );
  }

  /// Updates the search shortcut enabled preference.
  Future<void> setSearchShortcutEnabled(bool enabled) async {
    await _savePreference(
      apply: () => _searchShortcutEnabled = enabled,
      persist: () => _settingsStore.saveSearchShortcutEnabled(enabled),
    );
  }

  /// Updates the search shortcut preference.
  Future<void> setSearchShortcut(KeyboardShortcut shortcut) async {
    await _savePreference(
      apply: () => _searchShortcut = shortcut,
      persist: () => _settingsStore.saveSearchShortcut(shortcut),
    );
  }

  /// Updates the prefer local search preference.
  Future<void> setPreferLocalSearch(bool enabled) async {
    await _savePreference(
      apply: () => _preferLocalSearch = enabled,
      persist: () => _settingsStore.savePreferLocalSearch(enabled),
    );
  }

  /// Updates the layout density preference.
  Future<void> setLayoutDensity(LayoutDensity density) async {
    await _savePreference(
      apply: () => _layoutDensity = density,
      persist: () => _settingsStore.saveLayoutDensity(density),
    );
  }

  /// Updates the corner radius style preference.
  Future<void> setCornerRadiusStyle(CornerRadiusStyle style) async {
    await _savePreference(
      apply: () => _cornerRadiusStyle = style,
      persist: () => _settingsStore.saveCornerRadiusStyle(style),
    );
  }

  /// Updates the track list style preference.
  Future<void> setTrackListStyle(TrackListStyle style) async {
    await _savePreference(
      apply: () => _trackListStyle = style,
      persist: () => _settingsStore.saveTrackListStyle(style),
    );
  }

  /// Updates whether track timestamp status icons are shown.
  Future<void> setTrackStatusIconsEnabled(bool enabled) async {
    await _savePreference(
      apply: () => _trackStatusIconsEnabled = enabled,
      persist: () => _settingsStore.saveTrackStatusIconsEnabled(enabled),
    );
  }

  /// Updates the now playing layout preference.
  Future<void> setNowPlayingLayout(NowPlayingLayout layout) async {
    await _savePreference(
      apply: () => _nowPlayingLayout = layout,
      persist: () => _settingsStore.saveNowPlayingLayout(layout),
    );
  }

  /// Updates the home shelf layout preference.
  Future<void> setHomeShelfLayout(HomeShelfLayout layout) async {
    await _savePreference(
      apply: () => _homeShelfLayout = layout,
      persist: () => _settingsStore.saveHomeShelfLayout(layout),
    );
  }

  /// Updates the home shelf grid row count.
  Future<void> setHomeShelfGridRows(int rows) async {
    await _savePreference(
      apply: () => _homeShelfGridRows = rows,
      persist: () => _settingsStore.saveHomeShelfGridRows(rows),
    );
  }

  /// Updates the sidebar width preference.
  Future<void> setSidebarWidth(
    double width, {
    bool persist = true,
  }) async {
    _sidebarWidth = width;
    if (persist) {
      await _settingsStore.saveSidebarWidth(width);
    }
    _notify();
  }

  /// Updates the sidebar collapsed preference.
  Future<void> setSidebarCollapsed(
    bool collapsed, {
    bool persist = true,
  }) async {
    _sidebarCollapsed = collapsed;
    if (persist) {
      await _settingsStore.saveSidebarCollapsed(collapsed);
    }
    _notify();
  }

  /// Updates the sidebar overlay open state.
  void setSidebarOverlayOpen(bool open) {
    if (_sidebarOverlayOpen == open) {
      return;
    }
    _sidebarOverlayOpen = open;
    _notify();
  }

  /// Toggles the sidebar overlay open state.
  void toggleSidebarOverlayOpen() {
    setSidebarOverlayOpen(!_sidebarOverlayOpen);
  }

  /// Clears cached metadata entries.
  Future<void> clearMetadataCache() async {
    await _cacheStore.clearMetadata();
    await refreshLibrary();
  }

  /// Clears cached audio files.
  Future<void> clearAudioCache() async {
    await _cacheStore.clearAudioCache();
    await refreshMediaCacheBytes();
  }

  /// Returns the estimated cached media size in bytes.
  Future<int> getMediaCacheBytes() async {
    return _cacheStore.getMediaCacheBytes();
  }

  /// Refreshes cached media size counters.
  Future<void> refreshMediaCacheBytes() async {
    final totalBytes = await _cacheStore.getMediaCacheBytes();
    _mediaCacheBytesNotifier.value = totalBytes;
    final pinnedBytes = await _cacheStore.getPinnedMediaBytes(_pinnedAudio);
    _pinnedCacheBytesNotifier.value = pinnedBytes;
  }

  /// Returns the estimated size of pinned downloads.
  Future<int> getPinnedCacheBytes() async {
    return _cacheStore.getPinnedMediaBytes(_pinnedAudio);
  }

  /// Updates the cache size limit.
  Future<void> setCacheMaxBytes(int bytes) async {
    _cacheMaxBytes = bytes;
    await _cacheStore.saveCacheMaxBytes(bytes);
    await refreshMediaCacheBytes();
    _notify();
  }

  /// Returns cached audio entries for display.
  Future<List<CachedAudioEntry>> getCachedAudioEntries() async {
    return _cacheStore.loadCachedAudioEntries();
  }

  /// Opens the cached media location in the OS file manager.
  Future<void> showMediaCacheLocation() async {
    await _cacheStore.openMediaCacheLocation();
  }

  /// Removes a cached audio entry and its file.
  Future<void> evictCachedAudio(String streamUrl) async {
    await _cacheStore.evictCachedAudio(streamUrl);
    await refreshMediaCacheBytes();
  }

  Future<void> _savePreference({
    required void Function() apply,
    required Future<void> Function() persist,
    Future<void> Function()? afterSave,
  }) async {
    apply();
    await persist();
    _notify();
    if (afterSave != null) {
      await afterSave();
    }
  }
}
