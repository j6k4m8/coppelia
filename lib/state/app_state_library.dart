part of 'app_state.dart';

extension AppStateLibraryExtension on AppState {
  /// Selects a playlist and loads its tracks.
  Future<void> selectPlaylist(
    Playlist playlist, {
    bool offlineOnly = false,
  }) async {
    if (_selectedView != LibraryView.home) {
      _recordViewHistory(_selectedView);
    }
    _selectedPlaylist = playlist;
    _selectedSmartList = null;
    _selectedView = LibraryView.home;
    _offlineOnlyFilter = offlineOnly;
    clearBrowseSelection(notify: false);
    clearSearch(notify: false);
    _notify();
    final cached = await _cacheStore.loadPlaylistTracks(playlist.id);
    if (cached.isNotEmpty) {
      _playlistTracks = cached;
      _notify();
    }
    if (_offlineMode) {
      return;
    }
    try {
      final tracks = await _client.fetchPlaylistTracks(playlist.id);
      _playlistTracks = tracks;
      await _cacheStore.savePlaylistTracks(playlist.id, tracks);
      _notify();
    } catch (_) {
      // Keep cached tracks if refresh fails.
    }
  }

  /// Loads a playlist and starts playback without navigating.
  Future<void> playPlaylist(Playlist playlist) async {
    final logService = await LogService.instance;
    await logService.info(
      'playPlaylist: Starting "${playlist.name}" (${playlist.id}), offline=$_offlineMode',
    );

    List<MediaItem> tracks = const [];
    if (_offlineMode) {
      await logService
          .info('playPlaylist: Loading cached tracks for offline mode');
      tracks = await _cacheStore.loadPlaylistTracks(playlist.id);
      final filtered = _filterPinnedTracks(tracks);
      if (filtered.isEmpty) {
        await logService.warning(
          'playPlaylist: No pinned tracks available in offline mode',
        );
        return;
      }
      await logService
          .info('playPlaylist: Playing ${filtered.length} pinned tracks');
      await _playFromList(filtered, filtered.first);
      return;
    }
    try {
      await logService.info('playPlaylist: Fetching tracks from server');
      tracks = await _client.fetchPlaylistTracks(playlist.id);
      await logService
          .info('playPlaylist: Fetched ${tracks.length} tracks, caching');
      await _cacheStore.savePlaylistTracks(playlist.id, tracks);
    } catch (error, stackTrace) {
      await logService.error(
        'playPlaylist: Failed to fetch from server, trying cache',
        error,
        stackTrace,
      );
      tracks = await _cacheStore.loadPlaylistTracks(playlist.id);
    }
    if (tracks.isEmpty) {
      await logService.warning('playPlaylist: No tracks available');
      return;
    }
    await _playFromList(tracks, tracks.first);
  }

  /// Builds and plays a Smart List without navigating.
  Future<void> playSmartList(SmartList list) async {
    await _ensureSmartListSourceLoaded();
    final tracks = _buildSmartListTracks(list);
    if (tracks.isEmpty) {
      return;
    }
    await _playFromList(tracks, tracks.first);
  }

  /// Clears the current playlist selection.
  void clearPlaylistSelection() {
    _selectedPlaylist = null;
    _playlistTracks = [];
    _selectedView = LibraryView.home;
    clearBrowseSelection(notify: false);
    _notify();
  }

  /// Selects a Smart List and loads its tracks.
  Future<void> selectSmartList(SmartList list) async {
    if (_selectedView != LibraryView.home) {
      _recordViewHistory(_selectedView);
    }
    _selectedSmartList = list;
    _selectedView = LibraryView.home;
    _offlineOnlyFilter = false;
    _selectedPlaylist = null;
    _playlistTracks = [];
    clearBrowseSelection(notify: false);
    clearSearch(notify: false);
    _notify();
    await _loadSmartListTracks(list);
  }

  /// Clears the current Smart List selection.
  void clearSmartListSelection() {
    _selectedSmartList = null;
    _smartListTracks = [];
    _selectedView = LibraryView.home;
    clearBrowseSelection(notify: false);
    _notify();
  }

  /// Creates and stores a Smart List.
  Future<SmartList> createSmartList(SmartList list) async {
    _smartLists = [..._smartLists, list]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await _settingsStore.saveSmartLists(_smartLists);
    _notify();
    return list;
  }

  /// Updates a Smart List definition.
  Future<void> updateSmartList(SmartList list) async {
    final index = _smartLists.indexWhere((entry) => entry.id == list.id);
    if (index == -1) {
      return;
    }
    _smartLists = List<SmartList>.from(_smartLists);
    _smartLists[index] = list;
    _smartLists.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    await _settingsStore.saveSmartLists(_smartLists);
    if (_selectedSmartList?.id == list.id) {
      _selectedSmartList = list;
      await _loadSmartListTracks(list);
    }
    _notify();
  }

  /// Deletes a Smart List.
  Future<void> deleteSmartList(SmartList list) async {
    _smartLists = _smartLists.where((entry) => entry.id != list.id).toList();
    await _settingsStore.saveSmartLists(_smartLists);
    if (_selectedSmartList?.id == list.id) {
      clearSmartListSelection();
    } else {
      _notify();
    }
  }

  /// Creates a new playlist.
  Future<Playlist?> createPlaylist({
    required String name,
    List<MediaItem> initialTracks = const [],
  }) async {
    if (_session == null || _offlineMode) {
      return null;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final playlist = await _client.createPlaylist(
        name: trimmed,
        itemIds: initialTracks.map((track) => track.id).toList(),
      );
      final created = playlist.id.isEmpty
          ? Playlist(
              id: playlist.id,
              name: trimmed,
              trackCount: initialTracks.length,
              imageUrl: playlist.imageUrl,
            )
          : playlist;
      _playlists = [..._playlists, created]..sort(_comparePlaylists);
      await _cacheStore.savePlaylists(_playlists);
      _updatePlaylistStats(1);
      _notifyListenersLater();
      if (created.id.isNotEmpty && initialTracks.isNotEmpty) {
        final tracks = await _client.fetchPlaylistTracks(created.id);
        await _cacheStore.savePlaylistTracks(created.id, tracks);
        if (_selectedPlaylist?.id == created.id) {
          _playlistTracks = tracks;
          _notify();
        }
      }
      return created;
    } catch (_) {
      return null;
    }
  }

  /// Renames an existing playlist.
  Future<String?> renamePlaylist(Playlist playlist, String name) async {
    if (_session == null || _offlineMode) {
      return 'Playlists are unavailable offline.';
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == playlist.name) {
      return null;
    }
    final updated = Playlist(
      id: playlist.id,
      name: trimmed,
      trackCount: playlist.trackCount,
      imageUrl: playlist.imageUrl,
    );
    final previous = _playlists;
    _playlists = _playlists
        .map((item) => item.id == playlist.id ? updated : item)
        .toList()
      ..sort(_comparePlaylists);
    await _cacheStore.savePlaylists(_playlists);
    _notify();
    try {
      await _client.renamePlaylist(playlistId: playlist.id, name: trimmed);
      if (_selectedPlaylist?.id == playlist.id) {
        _selectedPlaylist = updated;
        _notify();
      }
      return null;
    } catch (error) {
      _playlists = previous;
      await _cacheStore.savePlaylists(_playlists);
      _notify();
      return _requestErrorMessage(
        error,
        fallback: 'Unable to rename playlist.',
      );
    }
  }

  /// Deletes a playlist.
  Future<String?> deletePlaylist(Playlist playlist) async {
    if (_session == null || _offlineMode) {
      return 'Playlists are unavailable offline.';
    }
    final previous = _playlists;
    _playlists = _playlists.where((item) => item.id != playlist.id).toList();
    await _cacheStore.savePlaylists(_playlists);
    _updatePlaylistStats(-1);
    if (_selectedPlaylist?.id == playlist.id) {
      clearPlaylistSelection();
    } else {
      _notify();
    }
    try {
      await _client.deletePlaylist(playlist.id);
      return null;
    } catch (error) {
      _playlists = previous;
      await _cacheStore.savePlaylists(_playlists);
      _updatePlaylistStats(1);
      _notify();
      return _requestErrorMessage(
        error,
        fallback: 'Unable to delete playlist.',
      );
    }
  }

  /// Adds a track to the selected playlist.
  Future<String?> addTrackToPlaylist(
    MediaItem track,
    Playlist playlist,
  ) async {
    return addTracksToPlaylist(playlist, [track]);
  }

  /// Adds tracks to a playlist.
  Future<String?> addTracksToPlaylist(
    Playlist playlist,
    List<MediaItem> tracks,
  ) async {
    if (_session == null || _offlineMode || tracks.isEmpty) {
      return 'Playlists are unavailable offline.';
    }
    try {
      await _client.addToPlaylist(
        playlistId: playlist.id,
        itemIds: tracks.map((track) => track.id).toList(),
      );
      if (_selectedPlaylist?.id == playlist.id) {
        final refreshed = await _client.fetchPlaylistTracks(playlist.id);
        _playlistTracks = refreshed;
        await _cacheStore.savePlaylistTracks(playlist.id, refreshed);
        _notify();
      }
      _updatePlaylistTrackCount(playlist, tracks.length);
      return null;
    } catch (error) {
      return _requestErrorMessage(
        error,
        fallback: 'Unable to add to playlist.',
      );
    }
  }

  /// Removes a track from a playlist.
  Future<String?> removeTrackFromPlaylist(
    MediaItem track,
    Playlist playlist,
  ) async {
    if (_session == null || _offlineMode) {
      return 'Playlists are unavailable offline.';
    }
    try {
      await _client.removeFromPlaylist(
        playlistId: playlist.id,
        entryIds:
            track.playlistItemId == null ? const [] : [track.playlistItemId!],
        itemIds: track.playlistItemId == null ? [track.id] : const [],
      );
      if (_selectedPlaylist?.id == playlist.id) {
        final updated = List<MediaItem>.from(_playlistTracks);
        if (track.playlistItemId != null) {
          updated.removeWhere(
            (item) => item.playlistItemId == track.playlistItemId,
          );
        } else {
          final index = updated.indexWhere((item) => item.id == track.id);
          if (index != -1) {
            updated.removeAt(index);
          }
        }
        _playlistTracks = updated;
        await _cacheStore.savePlaylistTracks(playlist.id, updated);
        _notify();
      }
      _updatePlaylistTrackCount(playlist, -1);
      return null;
    } catch (error) {
      return _requestErrorMessage(
        error,
        fallback: 'Unable to remove from playlist.',
      );
    }
  }

  /// Reorders tracks within a playlist.
  Future<String?> reorderPlaylistTracks(
    Playlist playlist,
    List<MediaItem> orderedTracks,
  ) async {
    if (_session == null || _offlineMode) {
      return 'Playlists are unavailable offline.';
    }
    final entryIds =
        orderedTracks.map((track) => track.playlistItemId).toList();
    if (entryIds.any((id) => id == null)) {
      return 'Unable to reorder this playlist.';
    }
    final previous = _playlistTracks;
    _playlistTracks = orderedTracks;
    await _cacheStore.savePlaylistTracks(playlist.id, orderedTracks);
    _notify();
    try {
      await _client.reorderPlaylist(
        playlistId: playlist.id,
        entryIds: entryIds.whereType<String>().toList(),
      );
      return null;
    } catch (error) {
      final fallback = await _attemptPlaylistRebuildReorder(
        playlist,
        orderedTracks,
        error,
      );
      if (fallback == null) {
        return null;
      }
      _playlistTracks = previous;
      await _cacheStore.savePlaylistTracks(playlist.id, previous);
      _notify();
      return fallback;
    }
  }

  /// Navigates to a library view.
  void selectLibraryView(LibraryView view, {bool recordHistory = true}) {
    if (recordHistory && view != _selectedView) {
      _recordViewHistory(_selectedView);
    }
    _selectedView = view;
    _selectedPlaylist = null;
    _playlistTracks = [];
    _selectedSmartList = null;
    _smartListTracks = [];
    if (!_isOfflineLibraryView(view) && !_offlineMode) {
      _offlineOnlyFilter = false;
    }
    clearBrowseSelection(notify: false);
    if (view != LibraryView.home) {
      clearSearch(notify: false);
    }
    _notify();
    if (view == LibraryView.albums) {
      unawaited(loadAlbums());
    }
    if (view == LibraryView.artists) {
      unawaited(loadArtists());
    }
    if (view == LibraryView.genres) {
      unawaited(loadGenres());
    }
    if (view == LibraryView.tracks) {
      unawaited(loadLibraryTracks());
    }
    if (view == LibraryView.favoritesAlbums) {
      unawaited(loadFavoriteAlbums());
    }
    if (view == LibraryView.favoritesArtists) {
      unawaited(loadFavoriteArtists());
    }
    if (view == LibraryView.favoritesSongs) {
      unawaited(loadFavoriteTracks());
    }
  }

  /// Navigates back to the previous library view.
  void goBack() {
    if (_isSearching) {
      clearSearch();
      return;
    }

    if (_viewHistory.isEmpty) {
      return;
    }
    final previous = _viewHistory.removeLast();
    selectLibraryView(previous, recordHistory: false);
  }

  /// Navigates to an album by identifier.
  Future<void> selectAlbumById(String albumId) async {
    if (_albums.isEmpty) {
      await loadAlbums();
    }
    Album? match;
    for (final album in _albums) {
      if (album.id == albumId) {
        match = album;
        break;
      }
    }
    if (match != null) {
      await selectAlbum(match, offlineOnly: offlineOnlyFilter);
    }
  }

  /// Navigates to an artist by identifier.
  Future<void> selectArtistById(String artistId) async {
    if (_artists.isEmpty) {
      await loadArtists();
    }
    Artist? match;
    for (final artist in _artists) {
      if (artist.id == artistId) {
        match = artist;
        break;
      }
    }
    if (match != null) {
      await selectArtist(match, offlineOnly: offlineOnlyFilter);
    }
  }

  /// Navigates to an artist by name.
  Future<void> selectArtistByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (_artists.isEmpty) {
      await loadArtists();
    }
    final target = trimmed.toLowerCase();
    Artist? match;
    for (final artist in _artists) {
      if (artist.name.trim().toLowerCase() == target) {
        match = artist;
        break;
      }
    }
    if (match == null) {
      return;
    }
    await selectArtist(match, offlineOnly: offlineOnlyFilter);
  }

  /// Performs a search across the library.
  Future<void> searchLibrary(String query) async {
    final trimmed = query.trim();
    final requestId = ++_searchRequestId;

    if (!_isSearching) {
      _isSearching = true;
    }

    if (trimmed.isEmpty) {
      _searchQuery = '';
      _searchResults = null;
      _isSearchLoading = false;
      _notify();
      return;
    }
    _searchQuery = query;
    _isSearchLoading = true;
    _notify();

    if (_offlineMode || _preferLocalSearch) {
      await LogService.instance.then((log) => log.info(
            'Search: Local search for: "$trimmed" '
            '(offline=$_offlineMode, preferLocal=$_preferLocalSearch)',
          ));

      _publishLocalSearchResults(trimmed, requestId);
      await _ensureLocalSearchSourceLoaded(trimmed, requestId);
      if (!_isSearchRequestActive(requestId, trimmed)) {
        return;
      }

      await LogService.instance.then((log) => log.info(
            'Search: Local results - ${_searchResults?.tracks.length ?? 0} tracks, '
            '${_searchResults?.albums.length ?? 0} albums, '
            '${_searchResults?.artists.length ?? 0} artists, '
            '${_searchResults?.genres.length ?? 0} genres, '
            '${_searchResults?.playlists.length ?? 0} playlists',
          ));

      _isSearchLoading = false;
      _notify();
      return;
    }

    await LogService.instance.then(
      (log) => log.info('Search: User initiated search for: "$trimmed"'),
    );

    try {
      final results = await _client.searchLibrary(trimmed);
      if (!_isSearchRequestActive(requestId, trimmed)) {
        return;
      }
      _searchResults = results;
      await LogService.instance.then((log) => log.info(
            'Search: Completed successfully, isEmpty=${_searchResults?.isEmpty}',
          ));
    } catch (error, stackTrace) {
      if (!_isSearchRequestActive(requestId, trimmed)) {
        return;
      }
      await LogService.instance
          .then((log) => log.error('Search: Failed', error, stackTrace));
      _searchResults = const SearchResults();
    } finally {
      if (_isSearchRequestActive(requestId, trimmed)) {
        _isSearchLoading = false;
        _notify();
      }
    }
  }

  bool _isSearchRequestActive(int requestId, String trimmedQuery) {
    if (requestId != _searchRequestId) {
      return false;
    }
    if (!_isSearching) {
      return false;
    }
    return _searchQuery.trim() == trimmedQuery;
  }

  List<MediaItem> _localSearchTrackSource() {
    if (!_offlineMode && _libraryTracksFromOfflineSnapshot) {
      return const <MediaItem>[];
    }
    return _libraryTracks;
  }

  void _publishLocalSearchResults(String query, int requestId) {
    if (!_isSearchRequestActive(requestId, query)) {
      return;
    }

    _searchResults = SearchService.searchLocal(
      query: query,
      allTracks: _localSearchTrackSource(),
      albums: _albums,
      artists: _artists,
      genres: _genres,
      playlists: _playlists,
    );
    _notify();
  }

  Future<void> _ensureLocalSearchSourceLoaded(
    String query,
    int requestId,
  ) async {
    if (_offlineMode || _session == null) {
      return;
    }
    if (!_isSearchRequestActive(requestId, query)) {
      return;
    }

    if (_albums.isEmpty) {
      await loadAlbums();
      if (!_isSearchRequestActive(requestId, query)) {
        return;
      }
      _publishLocalSearchResults(query, requestId);
    }
    if (_artists.isEmpty) {
      await loadArtists();
      if (!_isSearchRequestActive(requestId, query)) {
        return;
      }
      _publishLocalSearchResults(query, requestId);
    }
    if (_genres.isEmpty) {
      await loadGenres();
      if (!_isSearchRequestActive(requestId, query)) {
        return;
      }
      _publishLocalSearchResults(query, requestId);
    }
    if (_playlists.isEmpty) {
      try {
        final playlists = await _client.fetchPlaylists();
        _playlists = playlists;
        await _cacheStore.savePlaylists(playlists);
        if (!_isSearchRequestActive(requestId, query)) {
          return;
        }
        _publishLocalSearchResults(query, requestId);
      } catch (_) {
        // Keep cached playlists if refresh fails.
      }
    }

    if (_libraryTracksFromOfflineSnapshot || _libraryTracks.isEmpty) {
      await loadLibraryTracks(reset: true);
      if (!_isSearchRequestActive(requestId, query)) {
        return;
      }
      _publishLocalSearchResults(query, requestId);
    }

    while (_hasMoreTracks && _isSearchRequestActive(requestId, query)) {
      final beforeOffset = _tracksOffset;
      final beforeCount = _libraryTracks.length;
      await loadLibraryTracks();
      if (!_isSearchRequestActive(requestId, query)) {
        return;
      }
      if (_tracksOffset == beforeOffset &&
          _libraryTracks.length == beforeCount) {
        break;
      }
      _publishLocalSearchResults(query, requestId);
    }
  }

  /// Updates the search query without triggering a network request.
  void setSearchQuery(String query, {bool notify = true}) {
    _searchQuery = query;
    if (notify) {
      _notify();
    }
  }

  /// Clears the current search results.
  void clearSearch({bool notify = true}) {
    _searchQuery = '';
    _searchResults = null;
    _isSearching = false;
    _isSearchLoading = false;
    if (notify) {
      _notify();
    }
  }

  /// Cycles between repeat off, repeat all, and repeat one.
  Future<void> toggleRepeatMode() async {
    switch (_repeatMode) {
      case LoopMode.off:
        _repeatMode = LoopMode.all;
        break;
      case LoopMode.all:
        _repeatMode = LoopMode.one;
        break;
      case LoopMode.one:
        _repeatMode = LoopMode.off;
        break;
    }
    await _playback.setLoopMode(_repeatMode);
    _notify();
  }

  /// Updates the track browse letter highlight.
  void setTrackBrowseLetter(String? letter) {
    if (_trackBrowseLetter == letter) {
      return;
    }
    _trackBrowseLetter = letter;
    _notify();
  }

  /// Requests focus for the search field.
  void requestSearchFocus() {
    if (_searchQuery.isEmpty && !_isSearching) {
      _isSearching = true;
    }
    _searchFocusRequest += 1;
    _notify();
  }

  /// Loads albums, using cached results when possible.
  Future<void> loadAlbums() async {
    final cached = await _cacheStore.loadAlbums();
    if (cached.isNotEmpty) {
      _albums = cached;
      _notify();
    }
    if (_offlineMode) {
      _albums = await loadOfflineAlbums();
      _notify();
      return;
    }
    await _loadAlbums();
  }

  /// Loads artists, using cached results when possible.
  Future<void> loadArtists() async {
    final cached = await _cacheStore.loadArtists();
    if (cached.isNotEmpty) {
      _artists = cached;
      _notify();
    }
    if (_offlineMode) {
      _artists = await loadOfflineArtists();
      _notify();
      return;
    }
    await _loadArtists();
  }

  /// Loads genres, using cached results when possible.
  Future<void> loadGenres() async {
    final cached = await _cacheStore.loadGenres();
    if (cached.isNotEmpty) {
      _genres = cached;
      _notify();
    }
    if (_offlineMode) {
      return;
    }
    await _loadGenres();
  }

  /// Loads paginated tracks for the library browse view.
  Future<void> loadLibraryTracks({bool reset = false}) async {
    if (_session == null) {
      return;
    }
    if (_offlineMode) {
      final offlineTracks = await loadOfflineTracks();
      _libraryTracks = offlineTracks;
      _tracksOffset = offlineTracks.length;
      _hasMoreTracks = false;
      _isLoadingTracks = false;
      _libraryTracksFromOfflineSnapshot = true;
      _notify();
      return;
    }
    if (_isLoadingTracks) {
      await _tracksLoadCompleter?.future;
      return;
    }
    if (!reset && !_hasMoreTracks) {
      return;
    }
    if (reset) {
      _libraryTracks = [];
      _tracksOffset = 0;
      _hasMoreTracks = true;
      _libraryTracksFromOfflineSnapshot = false;
      _notify();
    }
    _isLoadingTracks = true;
    _tracksLoadCompleter = Completer<void>();
    _notify();
    try {
      final tracks = await _client.fetchLibraryTracks(
        startIndex: _tracksOffset,
        limit: AppState._tracksPageSize,
      );
      if (reset) {
        _libraryTracks = tracks;
      } else {
        _libraryTracks = [..._libraryTracks, ...tracks];
      }
      _libraryTracksFromOfflineSnapshot = false;
      _tracksOffset += tracks.length;
      if (tracks.length < AppState._tracksPageSize) {
        _hasMoreTracks = false;
      }
    } catch (_) {
      // Ignore load failures; keep whatever tracks we already have.
    } finally {
      _isLoadingTracks = false;
      _tracksLoadCompleter?.complete();
      _tracksLoadCompleter = null;
      _notify();
    }
  }

  /// Returns a random track from the library when available.
  Future<MediaItem?> getRandomTrack() async {
    if (_offlineMode) {
      return _randomFromList(_libraryTracks);
    }
    if (_session == null) {
      return null;
    }
    try {
      final track = await _client.fetchRandomTrack();
      if (track != null) {
        return track;
      }
    } catch (_) {}
    return _randomFromList(
          _featuredTracks.isNotEmpty ? _featuredTracks : _recentTracks,
        ) ??
        _randomFromList(_libraryTracks);
  }

  /// Returns a random album from the library when available.
  Future<Album?> getRandomAlbum() async {
    if (_offlineMode) {
      return _randomFromList(_albums);
    }
    if (_session == null) {
      return null;
    }
    try {
      final album = await _client.fetchRandomAlbum();
      if (album != null) {
        return album;
      }
    } catch (_) {}
    return _randomFromList(_albums.isNotEmpty ? _albums : _favoriteAlbums);
  }

  /// Returns a random artist from the library when available.
  Future<Artist?> getRandomArtist() async {
    if (_offlineMode) {
      return _randomFromList(_artists);
    }
    if (_session == null) {
      return null;
    }
    try {
      final artist = await _client.fetchRandomArtist();
      if (artist != null) {
        return artist;
      }
    } catch (_) {}
    return _randomFromList(_artists.isNotEmpty ? _artists : _favoriteArtists);
  }

  /// Loads the Jump in shelf picks.
  Future<void> loadJumpIn({bool force = false}) async {
    if (_offlineMode) {
      if (_isLoadingJumpIn) {
        return;
      }
      _isLoadingJumpIn = true;
      _notify();
      _jumpInTrack = _randomFromList(_libraryTracks) ?? _jumpInTrack;
      _jumpInAlbum = _randomFromList(_albums) ?? _jumpInAlbum;
      _jumpInArtist = _randomFromList(_artists) ?? _jumpInArtist;
      _lastJumpInRefreshAt = DateTime.now();
      _isLoadingJumpIn = false;
      _notify();
      return;
    }
    if (_session == null || _isLoadingJumpIn) {
      return;
    }
    if (!force &&
        _jumpInTrack != null &&
        _jumpInAlbum != null &&
        _jumpInArtist != null) {
      return;
    }
    _isLoadingJumpIn = true;
    _notify();
    try {
      final results = await Future.wait([
        getRandomTrack(),
        getRandomAlbum(),
        getRandomArtist(),
      ]);
      _jumpInTrack = results[0] as MediaItem? ?? _jumpInTrack;
      _jumpInAlbum = results[1] as Album? ?? _jumpInAlbum;
      _jumpInArtist = results[2] as Artist? ?? _jumpInArtist;
      _lastJumpInRefreshAt = DateTime.now();
    } finally {
      _isLoadingJumpIn = false;
      _notify();
    }
  }

  /// Plays a shuffled copy of the provided tracks.
  Future<void> playShuffledList(List<MediaItem> tracks) async {
    final selection =
        _offlineMode ? _filterPinnedTracks(tracks) : List.of(tracks);
    if (selection.isEmpty) {
      return;
    }
    selection.shuffle(_random);
    await _playFromList(selection, selection.first);
  }

  /// Loads favorite albums.
  Future<void> loadFavoriteAlbums() async {
    final cached = await _cacheStore.loadFavoriteAlbums();
    if (cached.isNotEmpty) {
      _favoriteAlbums = cached;
      _notify();
    }
    if (_offlineMode) {
      final offlineAlbums = await loadOfflineAlbums();
      final offlineIds = offlineAlbums.map((album) => album.id).toSet();
      _favoriteAlbums =
          cached.where((album) => offlineIds.contains(album.id)).toList();
      _notify();
      return;
    }
    await _loadFavoriteAlbums();
  }

  /// Loads favorite artists.
  Future<void> loadFavoriteArtists() async {
    final cached = await _cacheStore.loadFavoriteArtists();
    if (cached.isNotEmpty) {
      _favoriteArtists = cached;
      _notify();
    }
    if (_offlineMode) {
      final offlineArtists = await loadOfflineArtists();
      final offlineIds = offlineArtists.map((artist) => artist.id).toSet();
      _favoriteArtists =
          cached.where((artist) => offlineIds.contains(artist.id)).toList();
      _notify();
      return;
    }
    await _loadFavoriteArtists();
  }

  /// Loads favorite tracks.
  Future<void> loadFavoriteTracks() async {
    final cached = await _cacheStore.loadFavoriteTracks();
    if (cached.isNotEmpty) {
      _favoriteTracks = cached;
      _notify();
    }
    if (_offlineMode) {
      _favoriteTracks = _filterPinnedTracks(cached);
      _notify();
      return;
    }
    await _loadFavoriteTracks();
  }

  Future<void> _loadSmartListTracks(SmartList list) async {
    _isLoadingSmartList = true;
    _notify();

    if (_libraryTracks.isEmpty && !_offlineMode) {
      await loadLibraryTracks();
    }

    _smartListTracks = _buildSmartListTracks(list);
    _isLoadingSmartList = false;
    _notify();
  }

  Future<void> _ensureSmartListSourceLoaded() async {
    if (_offlineMode) {
      if (_libraryTracks.isEmpty) {
        await loadLibraryTracks();
      }
      return;
    }
    while (_hasMoreTracks) {
      await loadLibraryTracks();
    }
  }

  List<MediaItem> _buildSmartListTracks(SmartList list) {
    if (list.scope != SmartListScope.tracks) {
      return [];
    }
    final filtered = _libraryTracks
        .where((track) => _matchesSmartListGroup(list.group, track))
        .toList();
    if (list.sorts.isNotEmpty) {
      filtered.sort((a, b) => _compareSmartListSorts(list.sorts, a, b));
    }
    final limit = list.limit;
    if (limit != null && limit > 0 && filtered.length > limit) {
      return filtered.take(limit).toList();
    }
    return filtered;
  }

  int _compareSmartListSorts(
    List<SmartListSort> sorts,
    MediaItem a,
    MediaItem b,
  ) {
    for (final sort in sorts) {
      final comparison = _compareSmartListField(sort.field, a, b);
      if (comparison != 0) {
        return sort.direction == SmartListSortDirection.desc
            ? -comparison
            : comparison;
      }
    }
    return 0;
  }

  int _compareSmartListField(
    SmartListField field,
    MediaItem a,
    MediaItem b,
  ) {
    switch (field) {
      case SmartListField.title:
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case SmartListField.album:
        return a.album.toLowerCase().compareTo(b.album.toLowerCase());
      case SmartListField.artist:
        return a.subtitle.toLowerCase().compareTo(b.subtitle.toLowerCase());
      case SmartListField.genre:
        return _joinGenres(a).compareTo(_joinGenres(b));
      case SmartListField.addedAt:
        return _compareDate(a.addedAt, b.addedAt);
      case SmartListField.playCount:
        return (a.playCount ?? 0).compareTo(b.playCount ?? 0);
      case SmartListField.lastPlayedAt:
        return _compareDate(a.lastPlayedAt, b.lastPlayedAt);
      case SmartListField.duration:
        return a.duration.compareTo(b.duration);
      case SmartListField.isFavorite:
        return _compareBool(isFavoriteTrack(a.id), isFavoriteTrack(b.id));
      case SmartListField.isDownloaded:
        return _compareBool(
          _pinnedAudio.contains(a.streamUrl),
          _pinnedAudio.contains(b.streamUrl),
        );
      case SmartListField.albumIsFavorite:
        return _compareBool(
          a.albumId != null && isFavoriteAlbum(a.albumId!),
          b.albumId != null && isFavoriteAlbum(b.albumId!),
        );
      case SmartListField.artistIsFavorite:
        return _compareBool(
          a.artistIds.any(isFavoriteArtist),
          b.artistIds.any(isFavoriteArtist),
        );
      case SmartListField.bpm:
        return (a.bpm ?? 0).compareTo(b.bpm ?? 0);
    }
  }

  int _compareBool(bool a, bool b) {
    if (a == b) {
      return 0;
    }
    return a ? 1 : -1;
  }

  int _compareDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return -1;
    }
    if (b == null) {
      return 1;
    }
    return a.compareTo(b);
  }

  bool _matchesSmartListGroup(SmartListGroup group, MediaItem track) {
    if (group.children.isEmpty) {
      switch (group.mode) {
        case SmartListGroupMode.all:
          return true;
        case SmartListGroupMode.any:
          return false;
        case SmartListGroupMode.not:
          return true;
      }
    }
    final matches = group.children.map((child) {
      if (child is SmartListRuleNode) {
        return _matchesSmartListRule(child.rule, track);
      }
      if (child is SmartListGroupNode) {
        return _matchesSmartListGroup(child.group, track);
      }
      return false;
    }).toList();
    switch (group.mode) {
      case SmartListGroupMode.all:
        return matches.every((match) => match);
      case SmartListGroupMode.any:
        return matches.any((match) => match);
      case SmartListGroupMode.not:
        return !matches.any((match) => match);
    }
  }

  bool _matchesSmartListRule(SmartListRule rule, MediaItem track) {
    switch (rule.field.valueType) {
      case SmartListValueType.text:
        return _evaluateTextRule(rule, _valueForTextField(rule.field, track));
      case SmartListValueType.number:
        final value = rule.field == SmartListField.playCount
            ? (track.playCount ?? 0).toDouble()
            : rule.field == SmartListField.bpm
                ? (track.bpm ?? 0).toDouble()
                : 0.0;
        return _evaluateNumberRule(rule, value);
      case SmartListValueType.duration:
        return _evaluateNumberRule(
          rule,
          track.duration.inSeconds.toDouble(),
          isDuration: true,
        );
      case SmartListValueType.date:
        final date = rule.field == SmartListField.addedAt
            ? track.addedAt
            : track.lastPlayedAt;
        return _evaluateDateRule(rule, date);
      case SmartListValueType.boolean:
        return _evaluateBoolRule(rule, _valueForBoolField(rule.field, track));
    }
  }

  String _valueForTextField(SmartListField field, MediaItem track) {
    switch (field) {
      case SmartListField.title:
        return track.title;
      case SmartListField.album:
        return track.album;
      case SmartListField.artist:
        return track.subtitle;
      case SmartListField.genre:
        return _joinGenres(track);
      default:
        return '';
    }
  }

  bool _valueForBoolField(SmartListField field, MediaItem track) {
    switch (field) {
      case SmartListField.isFavorite:
        return isFavoriteTrack(track.id);
      case SmartListField.isDownloaded:
        return _pinnedAudio.contains(track.streamUrl);
      case SmartListField.albumIsFavorite:
        return track.albumId != null && isFavoriteAlbum(track.albumId!);
      case SmartListField.artistIsFavorite:
        return track.artistIds.any(isFavoriteArtist);
      default:
        return false;
    }
  }

  String _joinGenres(MediaItem track) {
    return track.genres.map((genre) => genre.toLowerCase()).join(', ');
  }

  bool _evaluateTextRule(SmartListRule rule, String rawValue) {
    final value = rawValue.toLowerCase();
    final needle = rule.value.toLowerCase().trim();
    switch (rule.operatorType) {
      case SmartListOperator.contains:
        return needle.isNotEmpty && value.contains(needle);
      case SmartListOperator.doesNotContain:
        return needle.isNotEmpty ? !value.contains(needle) : true;
      case SmartListOperator.equals:
        return needle.isNotEmpty && value == needle;
      case SmartListOperator.notEquals:
        return needle.isNotEmpty ? value != needle : true;
      case SmartListOperator.startsWith:
        return needle.isNotEmpty && value.startsWith(needle);
      case SmartListOperator.endsWith:
        return needle.isNotEmpty && value.endsWith(needle);
      default:
        return false;
    }
  }

  bool _evaluateNumberRule(
    SmartListRule rule,
    double actualValue, {
    bool isDuration = false,
  }) {
    final value = _parseNumber(rule.value, isDuration: isDuration);
    final value2 = _parseNumber(rule.value2, isDuration: isDuration);
    if (value == null) {
      return false;
    }
    switch (rule.operatorType) {
      case SmartListOperator.equals:
        return actualValue == value;
      case SmartListOperator.notEquals:
        return actualValue != value;
      case SmartListOperator.greaterThan:
        return actualValue > value;
      case SmartListOperator.greaterThanOrEqual:
        return actualValue >= value;
      case SmartListOperator.lessThan:
        return actualValue < value;
      case SmartListOperator.lessThanOrEqual:
        return actualValue <= value;
      case SmartListOperator.between:
        if (value2 == null) {
          return false;
        }
        final min = value < value2 ? value : value2;
        final max = value > value2 ? value : value2;
        return actualValue >= min && actualValue <= max;
      default:
        return false;
    }
  }

  bool _evaluateDateRule(SmartListRule rule, DateTime? actual) {
    if (actual == null) {
      return rule.operatorType == SmartListOperator.notInLast;
    }
    switch (rule.operatorType) {
      case SmartListOperator.isBefore:
        final target = _parseDate(rule.value);
        return target != null && actual.isBefore(target);
      case SmartListOperator.isAfter:
        final target = _parseDate(rule.value);
        return target != null && actual.isAfter(target);
      case SmartListOperator.isOn:
        final target = _parseDate(rule.value);
        return target != null && _isSameDate(actual, target);
      case SmartListOperator.inLast:
        final delta = _parseRelativeDuration(rule.value);
        return delta != null && actual.isAfter(DateTime.now().subtract(delta));
      case SmartListOperator.notInLast:
        final delta = _parseRelativeDuration(rule.value);
        return delta != null && actual.isBefore(DateTime.now().subtract(delta));
      default:
        return false;
    }
  }

  bool _evaluateBoolRule(SmartListRule rule, bool actual) {
    switch (rule.operatorType) {
      case SmartListOperator.isTrue:
        return actual;
      case SmartListOperator.isFalse:
        return !actual;
      default:
        return false;
    }
  }

  double? _parseNumber(String? input, {bool isDuration = false}) {
    if (input == null) {
      return null;
    }
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (isDuration) {
      final duration = _parseDuration(trimmed);
      if (duration != null) {
        return duration.inSeconds.toDouble();
      }
    }
    return double.tryParse(trimmed);
  }

  Duration? _parseDuration(String input) {
    if (input.contains(':')) {
      final parts = input.split(':').map((part) => part.trim()).toList();
      if (parts.any((part) => part.isEmpty)) {
        return null;
      }
      final numbers = parts.map(int.tryParse).toList();
      if (numbers.any((value) => value == null)) {
        return null;
      }
      if (numbers.length == 2) {
        return Duration(minutes: numbers[0]!, seconds: numbers[1]!);
      }
      if (numbers.length == 3) {
        return Duration(
          hours: numbers[0]!,
          minutes: numbers[1]!,
          seconds: numbers[2]!,
        );
      }
    }
    final seconds = int.tryParse(input);
    if (seconds == null) {
      return null;
    }
    return Duration(seconds: seconds);
  }

  DateTime? _parseDate(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return DateTime.tryParse(trimmed);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Duration? _parseRelativeDuration(String input) {
    final trimmed = input.trim().toLowerCase();
    final match = RegExp(r'^(\d+)([dwmy])$').firstMatch(trimmed);
    if (match == null) {
      return null;
    }
    final amount = int.tryParse(match.group(1) ?? '');
    final unit = match.group(2);
    if (amount == null || amount <= 0 || unit == null) {
      return null;
    }
    switch (unit) {
      case 'd':
        return Duration(days: amount);
      case 'w':
        return Duration(days: amount * 7);
      case 'm':
        return Duration(days: amount * 30);
      case 'y':
        return Duration(days: amount * 365);
      default:
        return null;
    }
  }

  /// Selects an album and loads its tracks.
  Future<void> selectAlbum(Album album, {bool offlineOnly = false}) async {
    if (_selectedView != LibraryView.home) {
      _recordViewHistory(_selectedView);
    }
    _selectedAlbum = album;
    _selectedSmartList = null;
    _selectedArtist = null;
    _selectedGenre = null;
    _offlineOnlyFilter = offlineOnly;
    clearSearch(notify: false);
    _notify();
    final cached = await _cacheStore.loadAlbumTracks(album.id);
    if (cached.isNotEmpty) {
      _albumTracks = cached;
      _notify();
    }
    if (_offlineMode) {
      final filtered = _filterPinnedTracks(_albumTracks);
      _albumTracks =
          filtered.isNotEmpty ? filtered : await _offlineTracksForAlbum(album);
      _notify();
      return;
    }
    try {
      final tracks = await _client.fetchAlbumTracks(album.id);
      _albumTracks = tracks;
      await _cacheStore.saveAlbumTracks(album.id, tracks);
      _notify();
    } catch (_) {
      // Keep cached tracks if refresh fails.
    }
  }

  /// Loads an album and starts playback.
  Future<void> playAlbum(Album album) async {
    final logService = await LogService.instance;
    await logService.info(
      'playAlbum: Starting "${album.name}" (${album.id}), offline=$_offlineMode',
    );

    await selectAlbum(album);
    final tracks =
        _offlineMode ? _filterPinnedTracks(_albumTracks) : _albumTracks;
    if (tracks.isNotEmpty) {
      await logService.info('playAlbum: Playing ${tracks.length} tracks');
      await _playFromList(tracks, tracks.first);
    } else {
      await logService.warning('playAlbum: No tracks available');
    }
  }

  /// Selects an artist and loads their tracks.
  Future<void> selectArtist(Artist artist, {bool offlineOnly = false}) async {
    if (_selectedView != LibraryView.home) {
      _recordViewHistory(_selectedView);
    }
    _selectedArtist = artist;
    _selectedSmartList = null;
    _selectedAlbum = null;
    _selectedGenre = null;
    _offlineOnlyFilter = offlineOnly;
    clearSearch(notify: false);
    _notify();
    final cached = await _cacheStore.loadArtistTracks(artist.id);
    if (cached.isNotEmpty) {
      _artistTracks = cached;
      _notify();
    }
    if (_offlineMode) {
      final filtered = _filterPinnedTracks(_artistTracks);
      _artistTracks = filtered.isNotEmpty
          ? filtered
          : await _offlineTracksForArtist(artist);
      _notify();
      return;
    }
    try {
      final tracks = await _client.fetchArtistTracks(artist.id);
      _artistTracks = tracks;
      await _cacheStore.saveArtistTracks(artist.id, tracks);
      _notify();
    } catch (_) {
      // Keep cached tracks if refresh fails.
    }
  }

  /// Loads an artist and starts playback.
  Future<void> playArtist(Artist artist) async {
    await selectArtist(artist);
    final tracks =
        _offlineMode ? _filterPinnedTracks(_artistTracks) : _artistTracks;
    if (tracks.isNotEmpty) {
      await _playFromList(tracks, tracks.first);
    }
  }

  /// Selects a genre and loads its tracks.
  Future<void> selectGenre(Genre genre) async {
    if (_selectedView != LibraryView.home) {
      _recordViewHistory(_selectedView);
    }
    _selectedGenre = genre;
    _selectedSmartList = null;
    _selectedAlbum = null;
    _selectedArtist = null;
    clearSearch(notify: false);
    _notify();
    final cached = await _cacheStore.loadGenreTracks(genre.id);
    if (cached.isNotEmpty) {
      _genreTracks = cached;
      _notify();
    }
    if (_offlineMode) {
      return;
    }
    try {
      final tracks = await _client.fetchGenreTracks(genre.id);
      _genreTracks = tracks;
      await _cacheStore.saveGenreTracks(genre.id, tracks);
      _notify();
    } catch (_) {
      // Keep cached tracks if refresh fails.
    }
  }

  /// Loads a genre and starts playback.
  Future<void> playGenre(Genre genre) async {
    await selectGenre(genre);
    final tracks =
        _offlineMode ? _filterPinnedTracks(_genreTracks) : _genreTracks;
    if (tracks.isNotEmpty) {
      await _playFromList(tracks, tracks.first);
    }
  }

  /// Starts playback from a selected track.
  Future<void> playFromPlaylist(MediaItem track) async {
    await playFromList(_playlistTracks, track);
  }

  /// Plays tracks from the selected album.
  Future<void> playFromAlbum(MediaItem track) async {
    await playFromList(_albumTracks, track);
  }

  /// Plays tracks from the selected artist.
  Future<void> playFromArtist(MediaItem track) async {
    await playFromList(_artistTracks, track);
  }

  /// Plays tracks from the selected genre.
  Future<void> playFromGenre(MediaItem track) async {
    await playFromList(_genreTracks, track);
  }

  /// Plays tracks from favorites.
  Future<void> playFromFavorites(MediaItem track) async {
    await playFromList(_favoriteTracks, track);
  }

  /// Plays tracks from search results.
  Future<void> playFromSearch(MediaItem track) async {
    final tracks = _searchResults?.tracks ?? const <MediaItem>[];
    await playFromList(tracks, track);
  }

  /// Plays tracks from a provided list.
  Future<void> playFromList(List<MediaItem> tracks, MediaItem track) async {
    if (_offlineMode) {
      final filtered = _filterPinnedTracks(tracks);
      if (filtered.isEmpty) {
        return;
      }
      final match = filtered.firstWhere(
        (item) => item.id == track.id,
        orElse: () => filtered.first,
      );
      await _playFromList(filtered, match);
      return;
    }
    await _playFromList(tracks, track);
  }

  /// Plays featured tracks from the home shelf.
  Future<void> playFeatured(MediaItem track) async {
    await playFromList(_featuredTracks, track);
  }

  /// Clears album, artist, and genre selections.
  void clearBrowseSelection({bool notify = true}) {
    _selectedAlbum = null;
    _selectedArtist = null;
    _selectedGenre = null;
    _albumTracks = [];
    _artistTracks = [];
    _genreTracks = [];
    if (notify) {
      _notify();
    }
  }

  Future<void> _loadAlbums() async {
    await _loadRemoteCollection(
      fetch: _client.fetchAlbums,
      assign: (albums) => _albums = albums,
      save: _cacheStore.saveAlbums,
    );
  }

  Future<void> _loadArtists() async {
    await _loadRemoteCollection(
      fetch: _client.fetchArtists,
      assign: (artists) => _artists = artists,
      save: _cacheStore.saveArtists,
    );
  }

  Future<void> _loadGenres() async {
    await _loadRemoteCollection(
      fetch: _client.fetchGenres,
      assign: (genres) => _genres = genres,
      save: _cacheStore.saveGenres,
    );
  }

  Future<void> _loadFavoriteAlbums() async {
    await _loadRemoteCollection(
      fetch: _client.fetchFavoriteAlbums,
      assign: (albums) => _favoriteAlbums = albums,
      save: _cacheStore.saveFavoriteAlbums,
      afterLoad: () async {
        if (_autoDownloadFavoritesEnabled && _autoDownloadFavoriteAlbums) {
          unawaited(_prefetchFavoriteDownloads(albumsOnly: true));
        }
      },
    );
  }

  Future<void> _loadFavoriteArtists() async {
    await _loadRemoteCollection(
      fetch: _client.fetchFavoriteArtists,
      assign: (artists) => _favoriteArtists = artists,
      save: _cacheStore.saveFavoriteArtists,
      shouldApply: (artists) => artists.isNotEmpty || _favoriteArtists.isEmpty,
      afterLoad: () async {
        if (_autoDownloadFavoritesEnabled && _autoDownloadFavoriteArtists) {
          unawaited(_prefetchFavoriteDownloads(artistsOnly: true));
        }
      },
    );
  }

  Future<void> _loadFavoriteTracks() async {
    await _loadRemoteCollection(
      fetch: _client.fetchFavoriteTracks,
      assign: (tracks) => _favoriteTracks = tracks,
      save: _cacheStore.saveFavoriteTracks,
      afterLoad: () async {
        if (_autoDownloadFavoritesEnabled && _autoDownloadFavoriteTracks) {
          unawaited(_prefetchFavoriteDownloads(tracksOnly: true));
        }
      },
    );
  }

  Future<void> _loadRemoteCollection<T>({
    required Future<List<T>> Function() fetch,
    required void Function(List<T> values) assign,
    required Future<void> Function(List<T> values) save,
    bool Function(List<T> values)? shouldApply,
    Future<void> Function()? afterLoad,
  }) async {
    if (_session == null || _offlineMode) {
      return;
    }
    try {
      _isLoadingLibrary = true;
      _notify();
      final values = await fetch();
      if (shouldApply == null || shouldApply(values)) {
        assign(values);
        await save(values);
      }
    } catch (_) {
      // Use cached results when available.
    } finally {
      _isLoadingLibrary = false;
      _notify();
      if (afterLoad != null) {
        await afterLoad();
      }
    }
  }
}
