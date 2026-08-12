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
    try {
      final serverBootstrap = await _serverStore.bootstrap();
      _savedServers = serverBootstrap.servers;
      await _completePendingServerRemovals();
      if (serverBootstrap.migratedServerId case final migratedServerId?) {
        await _cacheStore.migrateLegacyData(migratedServerId);
        await _settingsStore.migrateLegacySmartLists(migratedServerId);
        await _serverStore.completeLegacyDataMigration(migratedServerId);
      }
      if (serverBootstrap.active case final active?) {
        _activateServerScope(active);
      }
    } catch (error, stackTrace) {
      final logService = await LogService.instance;
      await logService.error('Session migration failed', error, stackTrace);
      _authError =
          'Your previous session could not be restored. Please sign in again.';
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
    _sidebarSwipeEnabled = await _settingsStore.loadSidebarSwipeEnabled();
    _nowPlayingSwipeEnabled = await _settingsStore.loadNowPlayingSwipeEnabled();
    _nowPlayingExpandGestureEnabled =
        await _settingsStore.loadNowPlayingExpandGestureEnabled();
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
    final storedPinnedAudio = await _cacheStore.loadPinnedAudio();
    _pinnedAudio =
        storedPinnedAudio.map(_canonicalStreamUrlForStreamUrl).toSet();
    if (!setEquals(_pinnedAudio, storedPinnedAudio)) {
      await _cacheStore.savePinnedAudio(_pinnedAudio);
    }
    unawaited(refreshMediaCacheBytes());
    await _loadCachedLibrary();
    await _applyPlaybackSettings();
    if (_offlineMode) {
      await _applyOfflineModeData();
    } else {
      unawaited(_resumePinnedDownloads());
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
    String? serverName,
  }) async {
    _authError = null;
    _notify();
    final previousSession = _session;
    try {
      final session = await _client.authenticate(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      final stored = await _serverStore.addAuthenticatedServer(
        session,
        name: serverName,
      );
      final transition = _beginServerTransition();
      if (previousSession != null) {
        // authenticate() updates the client eagerly; restore the old session
        // so its playback stop telemetry cannot be sent to the new server.
        _client.updateSession(previousSession);
        await _stopForServerSwitch(transition);
      }
      if (!_isCurrentServerGeneration(transition)) {
        return false;
      }
      _savedServers = await _serverStore.loadServers();
      if (!_isCurrentServerGeneration(transition)) {
        return false;
      }
      await _activateStoredServer(
        stored,
        refresh: true,
        restoreCachedData: false,
        serverGeneration: transition,
      );
      return true;
    } catch (error, stackTrace) {
      if (previousSession != null) {
        _client.updateSession(previousSession);
      } else {
        _client.clearSession();
      }
      final logService = await LogService.instance;
      await logService.error('Sign in failed', error, stackTrace);
      _authError = error.toString();
      _notify();
      return false;
    }
  }

  /// Switches to a saved server address, retaining each server's local data.
  Future<bool> switchServer(
    String serverId, {
    String? addressId,
  }) async {
    final transition = _beginServerTransition();
    final next = await _serverStore.activate(serverId, addressId: addressId);
    if (!_isCurrentServerGeneration(transition)) {
      return false;
    }
    if (next == null) {
      _authError = 'This server needs to be signed in again.';
      _notify();
      return false;
    }
    await _stopForServerSwitch(transition);
    if (!_isCurrentServerGeneration(transition)) {
      return false;
    }
    _savedServers = await _serverStore.loadServers();
    if (!_isCurrentServerGeneration(transition)) {
      return false;
    }
    await _activateStoredServer(
      next,
      refresh: true,
      serverGeneration: transition,
    );
    return true;
  }

  /// Adds a token-validated address to a saved server.
  Future<void> addServerAddress(
    String serverId, {
    required String name,
    required String url,
  }) async {
    final server = _savedServers.firstWhere((entry) => entry.id == serverId);
    final stored = await _serverStore.sessionFor(server);
    if (stored == null) {
      throw StateError('This server needs to be signed in again.');
    }
    final candidate = AuthSession(
      accessToken: stored.session.accessToken,
      serverUrl: JellyfinClient.normalizeServerUrl(url),
      userId: server.userId,
      userName: server.userName,
    );
    await _client.validateSession(candidate);
    _savedServers = await _serverStore.addAddress(
      server.id,
      name: name,
      url: candidate.serverUrl,
    );
    if (_activeServer?.id == server.id) {
      _activeServer =
          _savedServers.firstWhere((entry) => entry.id == server.id);
    }
    _notify();
  }

  /// Updates a server address after validating the saved token against it.
  Future<void> updateServerAddress(
    String serverId,
    String addressId, {
    required String name,
    required String url,
  }) async {
    final server = _savedServers.firstWhere((entry) => entry.id == serverId);
    final updatedActiveAddress = _activeServer?.id == serverId &&
        _activeServer?.activeAddress.id == addressId;
    final stored = await _serverStore.sessionFor(server);
    if (stored == null) {
      throw StateError('This server needs to be signed in again.');
    }
    final candidate = AuthSession(
      accessToken: stored.session.accessToken,
      serverUrl: JellyfinClient.normalizeServerUrl(url),
      userId: server.userId,
      userName: server.userName,
    );
    await _client.validateSession(candidate);
    _savedServers = await _serverStore.updateAddress(
      serverId,
      addressId,
      name: name,
      url: candidate.serverUrl,
    );
    if (_activeServer?.id == serverId) {
      _activeServer = _savedServers.firstWhere((entry) => entry.id == serverId);
    }
    if (updatedActiveAddress) {
      await switchServer(serverId, addressId: addressId);
      return;
    }
    _notify();
  }

  /// Renames a saved server.
  Future<void> renameServer(String serverId, String name) async {
    _savedServers = await _serverStore.renameServer(serverId, name);
    if (_activeServer?.id == serverId) {
      _activeServer = _savedServers.firstWhere((entry) => entry.id == serverId);
    }
    _notify();
  }

  /// Removes a saved address. The final address cannot be removed.
  Future<void> removeServerAddress(String serverId, String addressId) async {
    final removedActiveAddress = _activeServer?.id == serverId &&
        _activeServer?.activeAddress.id == addressId;
    _savedServers = await _serverStore.removeAddress(serverId, addressId);
    if (_activeServer?.id == serverId) {
      _activeServer = _savedServers.firstWhere((entry) => entry.id == serverId);
    }
    if (removedActiveAddress) {
      await switchServer(serverId, addressId: _activeServer!.activeAddress.id);
      return;
    }
    _notify();
  }

  /// Removes a saved server and all of its local data.
  Future<void> removeServer(String serverId) async {
    final isActive = _activeServer?.id == serverId;
    final transition = isActive ? _beginServerTransition() : null;
    final previous = isActive && _activeServer != null && _session != null
        ? StoredServerSession(server: _activeServer!, session: _session!)
        : null;
    if (isActive) {
      await _stopForServerSwitch(transition!);
      if (!_isCurrentServerGeneration(transition)) {
        return;
      }
    }
    StoredServerSession? next;
    try {
      next = await _serverStore.removeServer(serverId);
    } catch (_) {
      if (previous != null && _isCurrentServerGeneration(transition!)) {
        await _activateStoredServer(previous, refresh: false);
      }
      rethrow;
    }
    _savedServers = await _serverStore.loadServers();
    await _completeServerRemoval(serverId);
    if (!isActive) {
      _notify();
      return;
    }
    if (next == null) {
      _session = null;
      _activeServer = null;
      _client.clearSession();
      _cacheStore.activateScope(null);
      _settingsStore.activateSmartListScope(null);
      _clearServerState();
      _notify();
      return;
    }
    await _activateStoredServer(next, refresh: isActive);
  }

  void _activateServerScope(StoredServerSession stored) {
    _session = stored.session;
    _activeServer = stored.server;
    _client.updateSession(stored.session);
    _cacheStore.activateScope(stored.server.id);
    _settingsStore.activateSmartListScope(stored.server.id);
  }

  Future<void> _completePendingServerRemovals() async {
    for (final serverId in await _serverStore.pendingServerRemovals()) {
      await _completeServerRemoval(serverId);
    }
  }

  Future<void> _completeServerRemoval(String serverId) async {
    try {
      await _cacheStore.clearScope(serverId);
      await _settingsStore.clearSmartListsScope(serverId);
      await _serverStore.completeServerRemoval(serverId);
    } catch (error, stackTrace) {
      final logService = await LogService.instance;
      await logService.error(
        'Deferred server data cleanup failed for $serverId',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _activateStoredServer(
    StoredServerSession stored, {
    required bool refresh,
    bool restoreCachedData = true,
    int? serverGeneration,
  }) async {
    final generation = serverGeneration ?? _captureServerGeneration();
    if (!_isCurrentServerGeneration(generation)) {
      return;
    }
    _activateServerScope(stored);
    _clearServerState();
    if (restoreCachedData) {
      _smartLists = await _settingsStore.loadSmartLists();
      if (!_isCurrentServerGeneration(generation)) return;
      final storedPinnedAudio = await _cacheStore.loadPinnedAudio();
      if (!_isCurrentServerGeneration(generation)) return;
      _pinnedAudio = storedPinnedAudio.toSet();
      unawaited(refreshMediaCacheBytes());
      await _loadCachedLibrary();
      if (!_isCurrentServerGeneration(generation)) return;
      if (_offlineMode) {
        await _applyOfflineModeData();
        if (!_isCurrentServerGeneration(generation)) return;
      } else {
        unawaited(_resumePinnedDownloads());
      }
      await _restorePlaybackResumeState();
      if (!_isCurrentServerGeneration(generation)) return;
    }
    unawaited(_maybeUpdateNowPlayingPalette(_nowPlaying));
    if (refresh && !_offlineMode) {
      await refreshLibrary();
    }
    if (_isCurrentServerGeneration(generation)) {
      _notify();
    }
  }

  Future<void> _stopForServerSwitch(int serverGeneration) async {
    final track = _nowPlaying;
    if (track != null) {
      await _cacheStore.savePlaybackResumeState(
        PlaybackResumeState(track: track, position: _position),
      );
      if (!_isCurrentServerGeneration(serverGeneration)) {
        return;
      }
    }
    _maybeReportStoppedForSession(
      track: track,
      sessionId: _playSessionId,
      completed: false,
    );
    await _playback.clearQueue(keepCurrent: false);
    if (!_isCurrentServerGeneration(serverGeneration)) {
      return;
    }
    unawaited(_nowPlayingService.clear());
    _clearServerState();
  }

  void _clearServerState() {
    _libraryError = null;
    _isLoadingLibrary = false;
    _selectedPlaylist = null;
    _selectedSmartList = null;
    _selectedView = LibraryView.home;
    _viewHistory.clear();
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
    _recentlyAddedAlbums = [];
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
    _cachedAudio.clear();
    _isProcessingDownloads = false;
    _resetPlaybackRuntimeState(clearNowPlaying: true, clearReporting: true);
    _lastPlaybackPersistAt = null;
  }

  /// Refreshes library data and Home content.
  Future<void> refreshLibrary() async {
    if (_session == null) {
      return;
    }
    final serverGeneration = _captureServerGeneration();
    if (_offlineMode) {
      await _applyOfflineModeData();
      return;
    }
    _isLoadingLibrary = true;
    _libraryError = null;
    _notify();
    try {
      final playlists = await _client.fetchPlaylists();
      if (!_isCurrentServerGeneration(serverGeneration)) return;
      _playlists = playlists;
      await _cacheStore.savePlaylists(playlists);
      if (!_isCurrentServerGeneration(serverGeneration)) return;
      final stats = await _client.fetchLibraryStats();
      if (!_isCurrentServerGeneration(serverGeneration)) return;
      _libraryStats = stats;
      await _cacheStore.saveLibraryStats(stats);
      if (!_isCurrentServerGeneration(serverGeneration)) return;
      List<MediaItem> recent;
      try {
        recent = await _client.fetchRecentlyPlayedTracks();
      } catch (_) {
        recent = await _client.fetchRecentTracks();
      }
      if (!_isCurrentServerGeneration(serverGeneration)) return;
      _recentTracks = recent;
      await _cacheStore.saveRecentTracks(recent);
      if (!_isCurrentServerGeneration(serverGeneration)) return;
      final featured = await _client.fetchRecentTracks();
      if (!_isCurrentServerGeneration(serverGeneration)) return;
      _featuredTracks = featured;
      await _cacheStore.saveFeaturedTracks(featured);
      if (!_isCurrentServerGeneration(serverGeneration)) return;
      try {
        final recentlyAddedAlbums = await _client.fetchRecentlyAddedAlbums();
        if (!_isCurrentServerGeneration(serverGeneration)) return;
        _recentlyAddedAlbums = recentlyAddedAlbums;
        await _cacheStore.saveRecentlyAddedAlbums(recentlyAddedAlbums);
        if (!_isCurrentServerGeneration(serverGeneration)) return;
      } catch (_) {
        // Keep the cached shelf when the optional Home query fails.
      }

      await _loadAlbums(serverGeneration: serverGeneration);
      if (!_isCurrentServerGeneration(serverGeneration)) return;
      await _loadArtists(serverGeneration: serverGeneration);
      if (!_isCurrentServerGeneration(serverGeneration)) return;
      await _loadGenres(serverGeneration: serverGeneration);
      if (!_isCurrentServerGeneration(serverGeneration)) return;
      await _loadFavoriteAlbums(serverGeneration: serverGeneration);
      if (!_isCurrentServerGeneration(serverGeneration)) return;
      await _loadFavoriteArtists(serverGeneration: serverGeneration);
      if (!_isCurrentServerGeneration(serverGeneration)) return;
      await _loadFavoriteTracks(serverGeneration: serverGeneration);
      if (!_isCurrentServerGeneration(serverGeneration)) return;
      if (_smartLists.isNotEmpty) {
        unawaited(_refreshSmartListSource());
      }
      _refreshSelectedSmartList();
      if (isHomeSectionVisible(HomeSection.jumpIn)) {
        unawaited(loadJumpIn(force: true));
      }
    } catch (error, stackTrace) {
      if (!_isCurrentServerGeneration(serverGeneration)) return;
      final logService = await LogService.instance;
      await logService.error('Library refresh failed', error, stackTrace);
      _libraryError =
          'Could not refresh ${_activeServer?.name ?? 'server'}: $error';
      // Keep cached content if refresh fails.
    }
    if (_isCurrentServerGeneration(serverGeneration)) {
      _isLoadingLibrary = false;
      _notify();
    }
  }
}
