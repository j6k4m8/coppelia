part of 'app_state.dart';

extension AppStateSessionExtension on AppState {
  /// Initializes cached state and refreshes library.
  Future<void> bootstrap() async {
    await AppInfo.load();
    final deviceId = await _settingsStore.loadDeviceId();
    _client.updateDeviceInfo(
      deviceId: deviceId,
      deviceName: _platformDeviceName(),
    );
    _session = await _sessionStore.loadSession();
    if (_session != null) {
      _client.updateSession(_session!);
    }
    _themeMode = await _settingsStore.loadThemeMode();
    _fontFamily = await _settingsStore.loadFontFamily();
    _fontScale = await _settingsStore.loadFontScale();
    _accentColorValue = await _settingsStore.loadAccentColorValue();
    _accentColorSource = await _settingsStore.loadAccentColorSource();
    _themePaletteSource = await _settingsStore.loadThemePaletteSource();
    _telemetryPlayback = await _settingsStore.loadPlaybackTelemetry();
    _telemetryProgress = await _settingsStore.loadProgressTelemetry();
    _telemetryHistory = await _settingsStore.loadHistoryTelemetry();
    _gaplessPlayback = await _settingsStore.loadGaplessPlayback();
    _downloadsWifiOnly = await _settingsStore.loadDownloadsWifiOnly();
    _downloadsPaused = await _settingsStore.loadDownloadsPaused();
    _autoDownloadFavoritesEnabled =
        await _settingsStore.loadAutoDownloadFavoritesEnabled();
    _autoDownloadFavoriteAlbums =
        await _settingsStore.loadAutoDownloadFavoriteAlbums();
    _autoDownloadFavoriteArtists =
        await _settingsStore.loadAutoDownloadFavoriteArtists();
    _autoDownloadFavoriteTracks =
        await _settingsStore.loadAutoDownloadFavoriteTracks();
    _autoDownloadFavoritesWifiOnly =
        await _settingsStore.loadAutoDownloadFavoritesWifiOnly();
    _settingsShortcutEnabled =
        await _settingsStore.loadSettingsShortcutEnabled();
    _settingsShortcut = await _settingsStore.loadSettingsShortcut();
    _searchShortcutEnabled = await _settingsStore.loadSearchShortcutEnabled();
    _searchShortcut = await _settingsStore.loadSearchShortcut();
    _preferLocalSearch = await _settingsStore.loadPreferLocalSearch();
    _layoutDensity = await _settingsStore.loadLayoutDensity();
    _cornerRadiusStyle = await _settingsStore.loadCornerRadiusStyle();
    _trackListStyle = await _settingsStore.loadTrackListStyle();
    _trackStatusIconsEnabled =
        await _settingsStore.loadTrackStatusIconsEnabled();
    _nowPlayingLayout = await _settingsStore.loadNowPlayingLayout();
    _homeShelfLayout = await _settingsStore.loadHomeShelfLayout();
    _homeShelfGridRows = await _settingsStore.loadHomeShelfGridRows();
    _offlineMode = await _settingsStore.loadOfflineMode();
    _cacheMaxBytes = await _cacheStore.loadCacheMaxBytes();
    _homeSectionVisibility = await _settingsStore.loadHomeSectionVisibility();
    _homeSectionOrder = await _settingsStore.loadHomeSectionOrder();
    _sidebarVisibility = await _settingsStore.loadSidebarVisibility();
    _sidebarWidth = await _settingsStore.loadSidebarWidth();
    _sidebarCollapsed = await _settingsStore.loadSidebarCollapsed();
    _smartLists = await _settingsStore.loadSmartLists();
    _pinnedAudio = await _cacheStore.loadPinnedAudio();
    _ensureHomeInHistory();
    unawaited(refreshMediaCacheBytes());
    await _loadCachedLibrary();
    await _applyPlaybackSettings();
    if (_offlineMode) {
      await _applyOfflineModeData();
    }
    await _restorePlaybackResumeState();
    unawaited(_maybeUpdateNowPlayingPalette(_nowPlaying));
    _isBootstrapping = false;
    _notify();

    if (_session != null && !_offlineMode) {
      await refreshLibrary();
    }
  }

  Future<void> _applyPlaybackSettings() async {
    await _playback.setGaplessPlayback(_gaplessPlayback);
  }

  /// Attempts Jellyfin sign-in.
  Future<bool> signIn({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    _authError = null;
    _notify();
    try {
      final session = await _client.authenticate(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      _session = session;
      await _sessionStore.saveSession(session);
      await refreshLibrary();
      _notify();
      return true;
    } catch (error, stackTrace) {
      final logService = await LogService.instance;
      await logService.error('Sign in failed', error, stackTrace);
      _authError = error.toString();
      _notify();
      return false;
    }
  }

  /// Signs out and clears cached state.
  Future<void> signOut() async {
    await _cacheStore.savePlaybackResumeState(null);
    _session = null;
    _client.clearSession();
    _selectedPlaylist = null;
    _selectedSmartList = null;
    _selectedView = LibraryView.home;
    _viewHistory.clear();
    _ensureHomeInHistory();
    _selectedAlbum = null;
    _selectedArtist = null;
    _selectedGenre = null;
    _searchQuery = '';
    _searchResults = null;
    _isSearching = false;
    _isSearchLoading = false;
    _playlistTracks = [];
    _smartListTracks = [];
    _featuredTracks = [];
    _playlists = [];
    _albums = [];
    _artists = [];
    _genres = [];
    _libraryTracks = [];
    _trackBrowseLetter = null;
    _tracksLoadCompleter = null;
    _isLoadingTracks = false;
    _hasMoreTracks = true;
    _tracksOffset = 0;
    _libraryTracksFromOfflineSnapshot = false;
    _albumTracks = [];
    _artistTracks = [];
    _genreTracks = [];
    _favoriteAlbums = [];
    _favoriteArtists = [];
    _favoriteTracks = [];
    _recentTracks = [];
    _playHistory = [];
    _libraryStats = null;
    _jumpInTrack = null;
    _jumpInAlbum = null;
    _jumpInArtist = null;
    _isLoadingJumpIn = false;
    _lastJumpInRefreshAt = null;
    _queue = [];
    _downloadQueue.clear();
    _downloadStatusByUrl.clear();
    _cancelledOfflineRequests.clear();
    _isProcessingDownloads = false;
    _resetPlaybackRuntimeState(clearNowPlaying: true, clearReporting: true);
    _lastPlaybackPersistAt = null;
    unawaited(_nowPlayingService.clear());
    await _sessionStore.saveSession(null);
    _notify();
  }

  /// Refreshes playlists and featured tracks.
  Future<void> refreshLibrary() async {
    if (_session == null) {
      return;
    }
    if (_offlineMode) {
      await _applyOfflineModeData();
      return;
    }
    _isLoadingLibrary = true;
    _notify();
    try {
      final playlists = await _client.fetchPlaylists();
      _playlists = playlists;
      await _cacheStore.savePlaylists(playlists);
      final stats = await _client.fetchLibraryStats();
      _libraryStats = stats;
      await _cacheStore.saveLibraryStats(stats);
      List<MediaItem> recent;
      try {
        recent = await _client.fetchRecentlyPlayedTracks();
      } catch (_) {
        recent = await _client.fetchRecentTracks();
      }
      _recentTracks = recent;
      await _cacheStore.saveRecentTracks(recent);
      final featured = await _client.fetchRecentTracks();
      _featuredTracks = featured;
      await _cacheStore.saveFeaturedTracks(featured);

      await _loadAlbums();
      await _loadArtists();
      await _loadGenres();
      await _loadFavoriteAlbums();
      await _loadFavoriteArtists();
      await _loadFavoriteTracks();
      _refreshSelectedSmartList();
      if (isHomeSectionVisible(HomeSection.jumpIn)) {
        unawaited(loadJumpIn(force: true));
      }
    } catch (_) {
      // Keep cached content if refresh fails.
    }
    _isLoadingLibrary = false;
    _notify();
  }
}
