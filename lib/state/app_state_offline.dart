part of 'app_state.dart';

extension AppStateOfflineExtension on AppState {
  /// Updates whether downloads are limited to Wi-Fi.
  Future<void> setDownloadsWifiOnly(bool enabled) async {
    _downloadsWifiOnly = enabled;
    await _settingsStore.saveDownloadsWifiOnly(enabled);
    _notify();
    unawaited(_processDownloadQueue());
  }

  /// Updates whether downloads are paused.
  Future<void> setDownloadsPaused(bool paused) async {
    _downloadsPaused = paused;
    await _settingsStore.saveDownloadsPaused(paused);
    _notify();
    if (!paused) {
      unawaited(_processDownloadQueue());
    }
  }

  /// Updates auto-download preference for favorites.
  Future<void> setAutoDownloadFavoritesEnabled(bool enabled) async {
    _autoDownloadFavoritesEnabled = enabled;
    await _settingsStore.saveAutoDownloadFavoritesEnabled(enabled);
    _notify();
    if (enabled) {
      unawaited(_prefetchFavoriteDownloads());
    }
  }

  /// Updates auto-download preference for favorited albums.
  Future<void> setAutoDownloadFavoriteAlbums(bool enabled) async {
    _autoDownloadFavoriteAlbums = enabled;
    await _settingsStore.saveAutoDownloadFavoriteAlbums(enabled);
    _notify();
    if (enabled && _autoDownloadFavoritesEnabled) {
      unawaited(_prefetchFavoriteDownloads(albumsOnly: true));
    }
  }

  /// Updates auto-download preference for favorited artists.
  Future<void> setAutoDownloadFavoriteArtists(bool enabled) async {
    _autoDownloadFavoriteArtists = enabled;
    await _settingsStore.saveAutoDownloadFavoriteArtists(enabled);
    _notify();
    if (enabled && _autoDownloadFavoritesEnabled) {
      unawaited(_prefetchFavoriteDownloads(artistsOnly: true));
    }
  }

  /// Updates auto-download preference for favorited tracks.
  Future<void> setAutoDownloadFavoriteTracks(bool enabled) async {
    _autoDownloadFavoriteTracks = enabled;
    await _settingsStore.saveAutoDownloadFavoriteTracks(enabled);
    _notify();
    if (enabled && _autoDownloadFavoritesEnabled) {
      unawaited(_prefetchFavoriteDownloads(tracksOnly: true));
    }
  }

  /// Updates Wi-Fi only auto-download preference.
  Future<void> setAutoDownloadFavoritesWifiOnly(bool enabled) async {
    _autoDownloadFavoritesWifiOnly = enabled;
    await _settingsStore.saveAutoDownloadFavoritesWifiOnly(enabled);
    _notify();
    if (enabled && _autoDownloadFavoritesEnabled) {
      unawaited(_prefetchFavoriteDownloads());
    }
  }

  /// Updates the ordering of pending downloads.
  void reorderDownloadQueue(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) {
      return;
    }
    if (oldIndex < 0 || oldIndex >= _downloadQueue.length) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final task = _downloadQueue.removeAt(oldIndex);
    final target = newIndex.clamp(0, _downloadQueue.length);
    _downloadQueue.insert(target, task);
    _notify();
  }

  /// Retries a failed download.
  void retryDownload(DownloadTask task) {
    final index = _indexOfDownload(task.track.streamUrl);
    if (index == null) {
      return;
    }
    final queuedTask = _downloadQueue[index].copyWith(
      status: DownloadStatus.queued,
      progress: null,
      totalBytes: null,
      downloadedBytes: null,
      errorMessage: null,
    );
    _replaceDownloadTaskAt(index, queuedTask);
    _notify();
    unawaited(_processDownloadQueue());
  }

  /// Updates the offline mode preference.
  Future<void> setOfflineMode(bool enabled) async {
    if (_offlineMode == enabled) {
      return;
    }
    _offlineMode = enabled;
    await _settingsStore.saveOfflineMode(enabled);
    if (enabled) {
      await _applyOfflineModeData();
      return;
    }
    _offlineOnlyFilter = false;
    _libraryTracks = [];
    _tracksOffset = 0;
    _hasMoreTracks = true;
    _isLoadingTracks = false;
    _tracksLoadCompleter = null;
    _libraryTracksFromOfflineSnapshot = false;
    _notify();
    if (_session != null) {
      unawaited(refreshLibrary());
    }
    unawaited(_processDownloadQueue());
  }

  /// Updates the offline-only filter for detail views.
  void setOfflineOnlyFilter(bool enabled) {
    final next = _offlineMode ? true : enabled;
    if (_offlineOnlyFilter == next) {
      return;
    }
    _offlineOnlyFilter = next;
    _notify();
  }

  /// Returns how many tracks are tracked by the whole-library offline action.
  Future<int> getWholeLibraryOfflineTrackCount() async {
    final tracked = await _cacheStore.loadWholeLibraryPinnedAudio();
    return tracked.length;
  }

  /// Builds preview data for downloading the whole library offline.
  Future<WholeLibraryOfflinePreview?>
      prepareWholeLibraryOfflinePreview() async {
    if (_session == null || _offlineMode) {
      return null;
    }
    final tracks = await _loadAllLibraryTracksForOfflineAction();
    if (tracks.isEmpty) {
      return null;
    }
    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    final cachedBytesByUrl = <String, int>{
      for (final entry in cachedEntries) entry.streamUrl: entry.bytes,
    };
    final knownBitrates = tracks
        .map((track) => track.bitrate)
        .whereType<int>()
        .where((bitrate) => bitrate > 0)
        .toList()
      ..sort();
    final fallbackBitrate = knownBitrates.isEmpty
        ? 256000
        : knownBitrates[knownBitrates.length ~/ 2];
    var estimatedTotalBytes = 0;
    var estimatedRemainingBytes = 0;
    var cachedTrackCount = 0;
    for (final track in tracks) {
      final cachedBytes = cachedBytesByUrl[track.streamUrl];
      if (cachedBytes != null) {
        estimatedTotalBytes += cachedBytes;
        cachedTrackCount += 1;
        continue;
      }
      final estimatedBytes = _estimateTrackBytes(track, fallbackBitrate);
      estimatedTotalBytes += estimatedBytes;
      estimatedRemainingBytes += estimatedBytes;
    }
    final wholeLibraryPinnedTrackCount =
        (await _cacheStore.loadWholeLibraryPinnedAudio()).length;
    return WholeLibraryOfflinePreview(
      tracks: tracks,
      trackCount: tracks.length,
      cachedTrackCount: cachedTrackCount,
      estimatedTotalBytes: estimatedTotalBytes,
      estimatedRemainingBytes: estimatedRemainingBytes,
      cacheMaxBytes: _cacheMaxBytes,
      downloadsWifiOnly: _downloadsWifiOnly,
      downloadsPaused: _downloadsPaused,
      wholeLibraryPinnedTrackCount: wholeLibraryPinnedTrackCount,
    );
  }

  /// Pins and queues the current library for offline playback in bulk.
  Future<WholeLibraryOfflineResult> makeWholeLibraryAvailableOffline(
    List<MediaItem> tracks,
  ) async {
    final normalizedTracks = _deduplicateTracksForOffline(tracks);
    if (normalizedTracks.isEmpty) {
      return const WholeLibraryOfflineResult(
        trackCount: 0,
        newlyPinnedCount: 0,
        newlyQueuedCount: 0,
        retriedFailedCount: 0,
        alreadyPinnedCount: 0,
        wholeLibraryPinnedTrackCount: 0,
      );
    }

    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    final cachedUrls = cachedEntries.map((entry) => entry.streamUrl).toSet();
    _cachedAudio = cachedUrls;

    final nextPinnedAudio = Set<String>.from(_pinnedAudio);
    final nextWholeLibraryPinnedAudio =
        Set<String>.from(await _cacheStore.loadWholeLibraryPinnedAudio());
    final pinnedItemsToSave = <MediaItem>[];
    final pinnedItemsToForget = <String>{};
    var newlyPinnedCount = 0;
    var newlyQueuedCount = 0;
    var retriedFailedCount = 0;
    var alreadyPinnedCount = 0;

    for (final track in normalizedTracks) {
      final keys = _offlineKeysForTrack(track);
      for (final key in keys) {
        _cancelledOfflineRequests.remove(key);
      }

      final wasPinned = keys.any(nextPinnedAudio.contains);
      if (wasPinned) {
        alreadyPinnedCount += 1;
      } else {
        nextPinnedAudio.add(track.streamUrl);
        nextWholeLibraryPinnedAudio.add(track.streamUrl);
        pinnedItemsToSave.add(track);
        newlyPinnedCount += 1;
      }

      for (final key in keys.where((key) => key != track.streamUrl)) {
        if (nextPinnedAudio.remove(key)) {
          pinnedItemsToForget.add(key);
        }
        nextWholeLibraryPinnedAudio.remove(key);
      }

      if (keys.any(cachedUrls.contains)) {
        _cachedAudio.addAll(keys);
        continue;
      }

      final existingIndex = _indexOfDownloadForKeys(keys);
      if (existingIndex != null) {
        final existing = _downloadQueue[existingIndex];
        if (existing.status == DownloadStatus.failed) {
          _replaceDownloadTaskAt(
            existingIndex,
            existing.copyWith(
              status: DownloadStatus.queued,
              progress: null,
              totalBytes: null,
              downloadedBytes: null,
              errorMessage: null,
            ),
          );
          retriedFailedCount += 1;
        }
        continue;
      }

      _addDownloadTask(
        DownloadTask(
          track: track,
          status: DownloadStatus.queued,
          queuedAt: DateTime.now(),
        ),
      );
      newlyQueuedCount += 1;
    }

    _pinnedAudio = nextPinnedAudio;
    await _cacheStore.savePinnedAudio(_pinnedAudio);
    if (pinnedItemsToSave.isNotEmpty) {
      await _cacheStore.savePinnedAudioItems(pinnedItemsToSave);
    }
    if (pinnedItemsToForget.isNotEmpty) {
      await _cacheStore.forgetPinnedAudioItems(pinnedItemsToForget);
    }
    await _cacheStore.saveWholeLibraryPinnedAudio(nextWholeLibraryPinnedAudio);

    _refreshSelectedSmartList();
    unawaited(refreshMediaCacheBytes());
    _notify();
    if (!_downloadsPaused) {
      unawaited(_processDownloadQueue());
    }

    return WholeLibraryOfflineResult(
      trackCount: normalizedTracks.length,
      newlyPinnedCount: newlyPinnedCount,
      newlyQueuedCount: newlyQueuedCount,
      retriedFailedCount: retriedFailedCount,
      alreadyPinnedCount: alreadyPinnedCount,
      wholeLibraryPinnedTrackCount: nextWholeLibraryPinnedAudio.length,
    );
  }

  /// Removes the tracked whole-library offline selection.
  Future<WholeLibraryOfflineRemovalResult>
      removeWholeLibraryOfflineSelection() async {
    final wholeLibraryPinnedAudio =
        await _cacheStore.loadWholeLibraryPinnedAudio();
    if (wholeLibraryPinnedAudio.isEmpty) {
      return const WholeLibraryOfflineRemovalResult(removedTrackCount: 0);
    }

    final keysToRemove = <String>{};
    for (final streamUrl in wholeLibraryPinnedAudio) {
      keysToRemove.addAll(_offlineKeysForStreamUrl(streamUrl));
    }

    _pinnedAudio.removeWhere(keysToRemove.contains);
    _downloadQueue.removeWhere((task) {
      if (!keysToRemove.contains(task.track.streamUrl)) {
        return false;
      }
      _downloadStatusByUrl.remove(task.track.streamUrl);
      _downloadProgressTimestamps.remove(task.track.streamUrl);
      return true;
    });
    _downloadStatusByUrl
        .removeWhere((streamUrl, _) => keysToRemove.contains(streamUrl));
    _downloadProgressTimestamps
        .removeWhere((streamUrl, _) => keysToRemove.contains(streamUrl));
    _cancelledOfflineRequests.addAll(keysToRemove);

    await _cacheStore.savePinnedAudio(_pinnedAudio);
    await _cacheStore.forgetPinnedAudioItems(keysToRemove);
    await _cacheStore.saveWholeLibraryPinnedAudio(<String>{});

    _refreshSelectedSmartList();
    unawaited(refreshMediaCacheBytes());
    _notify();

    return WholeLibraryOfflineRemovalResult(
      removedTrackCount: wholeLibraryPinnedAudio.length,
    );
  }

  Future<bool> _canDownloadOverNetwork({bool requireWifi = false}) async {
    if (_offlineMode) {
      return false;
    }
    final needsWifi = _downloadsWifiOnly || requireWifi;
    if (!needsWifi) {
      return true;
    }
    if (kIsWeb) {
      return true;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        try {
          final statuses = await Connectivity().checkConnectivity();
          return statuses.any(_networkConnectivityWhitelist.contains);
        } catch (_) {
          return false;
        }
      case TargetPlatform.fuchsia:
        return true;
    }
  }

  Future<void> _prefetchFavoriteDownloads({
    bool albumsOnly = false,
    bool artistsOnly = false,
    bool tracksOnly = false,
  }) async {
    if (!_autoDownloadFavoritesEnabled) {
      return;
    }
    final shouldAlbums =
        _autoDownloadFavoriteAlbums && !artistsOnly && !tracksOnly;
    final shouldArtists =
        _autoDownloadFavoriteArtists && !albumsOnly && !tracksOnly;
    final shouldTracks =
        _autoDownloadFavoriteTracks && !albumsOnly && !artistsOnly;
    if (shouldAlbums) {
      for (final album in _favoriteAlbums) {
        await makeAlbumAvailableOffline(
          album,
          requiresWifi: _autoDownloadFavoritesWifiOnly,
        );
      }
    }
    if (shouldArtists) {
      for (final artist in _favoriteArtists) {
        await makeArtistAvailableOffline(
          artist,
          requiresWifi: _autoDownloadFavoritesWifiOnly,
        );
      }
    }
    if (shouldTracks) {
      for (final track in _favoriteTracks) {
        await makeTrackAvailableOffline(
          track,
          requiresWifi: _autoDownloadFavoritesWifiOnly,
        );
      }
    }
  }

  int? _indexOfDownload(String streamUrl) {
    final index = _downloadQueue.indexWhere(
      (task) => task.track.streamUrl == streamUrl,
    );
    return index == -1 ? null : index;
  }

  int? _indexOfDownloadForKeys(Set<String> streamUrls) {
    final index = _downloadQueue.indexWhere(
      (task) => streamUrls.contains(task.track.streamUrl),
    );
    return index == -1 ? null : index;
  }

  void _addDownloadTask(DownloadTask task) {
    _downloadQueue.add(task);
    _downloadStatusByUrl[task.track.streamUrl] = task.status;
  }

  void _replaceDownloadTaskAt(int index, DownloadTask task) {
    _downloadQueue[index] = task;
    _downloadStatusByUrl[task.track.streamUrl] = task.status;
  }

  void _removeDownloadTaskAt(int index) {
    final removed = _downloadQueue.removeAt(index);
    _downloadStatusByUrl.remove(removed.track.streamUrl);
  }

  Future<void> _queueDownload(
    MediaItem track, {
    bool requiresWifi = false,
  }) async {
    final normalized = _normalizeTrackForOffline(track);
    _cancelledOfflineRequests.remove(normalized.streamUrl);
    final existingIndex = _indexOfDownload(normalized.streamUrl);
    if (existingIndex != null) {
      final existing = _downloadQueue[existingIndex];
      if (existing.status == DownloadStatus.failed) {
        retryDownload(existing);
      }
      return;
    }
    final cached = await _cacheStore.isAudioCached(normalized);
    if (cached) {
      await _cacheStore.touchCachedAudio(normalized);
      _cachedAudio.add(normalized.streamUrl);
      return;
    }
    _addDownloadTask(
      DownloadTask(
        track: normalized,
        status: DownloadStatus.queued,
        queuedAt: DateTime.now(),
        requiresWifi: requiresWifi,
      ),
    );
    _notify();
    unawaited(_processDownloadQueue());
  }

  Future<void> _resumePinnedDownloads() async {
    if (_offlineMode) {
      return;
    }
    final pinnedTracks = await _cacheStore.loadPinnedAudioItems();
    var queuedAny = false;
    for (final track in pinnedTracks) {
      final normalized = _normalizeTrackForOffline(track);
      if (!_pinnedAudio.contains(normalized.streamUrl)) {
        continue;
      }
      if (_cachedAudio.contains(normalized.streamUrl)) {
        continue;
      }
      if (await _cacheStore.isAudioCached(normalized)) {
        _cachedAudio.add(normalized.streamUrl);
        continue;
      }
      if (_indexOfDownload(normalized.streamUrl) != null) {
        continue;
      }
      _addDownloadTask(
        DownloadTask(
          track: normalized,
          status: DownloadStatus.queued,
          queuedAt: DateTime.now(),
          requiresWifi: _autoDownloadFavoritesWifiOnly,
        ),
      );
      queuedAny = true;
    }
    if (!queuedAny) {
      return;
    }
    _notify();
    if (!_downloadsPaused) {
      unawaited(_processDownloadQueue());
    }
  }

  void _resetWaitingDownloads() {
    var updated = false;
    for (var i = 0; i < _downloadQueue.length; i += 1) {
      final task = _downloadQueue[i];
      if (task.status == DownloadStatus.waitingForWifi) {
        _replaceDownloadTaskAt(
          i,
          task.copyWith(status: DownloadStatus.queued),
        );
        updated = true;
      }
    }
    if (updated) {
      _notify();
    }
  }

  void _updateDownloadTask(
    String streamUrl, {
    DownloadStatus? status,
    double? progress,
    int? totalBytes,
    int? downloadedBytes,
    String? errorMessage,
  }) {
    final index = _indexOfDownload(streamUrl);
    if (index == null) {
      return;
    }
    final existing = _downloadQueue[index];
    if (progress != null &&
        _shouldThrottleProgress(
          streamUrl,
          progress,
          existing.progress,
        )) {
      return;
    }
    final nextTask = existing.copyWith(
      status: status,
      progress: progress,
      totalBytes: totalBytes,
      downloadedBytes: downloadedBytes,
      errorMessage: errorMessage,
    );
    _replaceDownloadTaskAt(index, nextTask);
    _notify();
  }

  bool _shouldThrottleProgress(
    String streamUrl,
    double newProgress,
    double? currentProgress,
  ) {
    final now = DateTime.now();
    final last = _downloadProgressTimestamps[streamUrl];
    final pivot = currentProgress ?? 0.0;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 250) &&
        (newProgress - pivot).abs() < 0.01) {
      return true;
    }
    _downloadProgressTimestamps[streamUrl] = now;
    return false;
  }

  void _removeDownload(String streamUrl) {
    final index = _indexOfDownload(streamUrl);
    if (index == null) {
      return;
    }
    _removeDownloadTaskAt(index);
    _downloadProgressTimestamps.remove(streamUrl);
    _notify();
  }

  Future<void> _processDownloadQueue() async {
    if (_isProcessingDownloads || _downloadsPaused) {
      return;
    }
    final serverGeneration = _captureServerGeneration();
    _isProcessingDownloads = true;
    try {
      _resetWaitingDownloads();
      while (true) {
        if (_downloadsPaused || !_isCurrentServerGeneration(serverGeneration)) {
          break;
        }
        DownloadTask? next;
        for (final task in List<DownloadTask>.from(_downloadQueue)) {
          if (task.status != DownloadStatus.queued) {
            continue;
          }
          final canDownload = await _canDownloadOverNetwork(
            requireWifi: task.requiresWifi,
          );
          if (!_isCurrentServerGeneration(serverGeneration)) {
            break;
          }
          if (canDownload) {
            next = task;
            break;
          }
          _updateDownloadTask(
            task.track.streamUrl,
            status: DownloadStatus.waitingForWifi,
          );
        }
        if (next == null) {
          break;
        }
        await _downloadTrack(next, serverGeneration);
      }
    } finally {
      if (_isCurrentServerGeneration(serverGeneration)) {
        _isProcessingDownloads = false;
      }
    }
  }

  Future<void> _downloadTrack(DownloadTask task, int serverGeneration) async {
    if (!_isCurrentServerGeneration(serverGeneration)) {
      return;
    }
    final streamUrl = task.track.streamUrl;
    _updateDownloadTask(streamUrl, status: DownloadStatus.downloading);
    try {
      await for (final response in _cacheStore.downloadAudioWithProgress(
        task.track,
        headers: _playbackHeaders(),
      )) {
        if (!_isCurrentServerGeneration(serverGeneration)) {
          return;
        }
        if (_cancelledOfflineRequests.contains(streamUrl)) {
          _cancelledOfflineRequests.remove(streamUrl);
          _removeDownload(streamUrl);
          return;
        }
        if (response is DownloadProgress) {
          _updateDownloadTask(
            streamUrl,
            progress: response.progress,
            totalBytes: response.totalSize,
            downloadedBytes: response.downloaded,
          );
        } else if (response is FileInfo) {
          _cachedAudio.add(streamUrl);
          _removeDownload(streamUrl);
          unawaited(refreshMediaCacheBytes());
        }
      }
    } catch (error) {
      if (!_isCurrentServerGeneration(serverGeneration)) {
        return;
      }
      if (_cancelledOfflineRequests.contains(streamUrl)) {
        _cancelledOfflineRequests.remove(streamUrl);
        _removeDownload(streamUrl);
        return;
      }
      _updateDownloadTask(
        streamUrl,
        status: DownloadStatus.failed,
        errorMessage: error.toString(),
      );
    }
  }

  /// Pins a track for offline playback.
  Future<void> makeTrackAvailableOffline(
    MediaItem track, {
    bool requiresWifi = false,
  }) async {
    await _setTracksAvailableOffline(
      [track],
      pinned: true,
      requiresWifi: requiresWifi,
    );
  }

  /// Removes a track from offline pinning.
  Future<void> unpinTrackOffline(MediaItem track) async {
    await _setTracksAvailableOffline([track], pinned: false);
  }

  /// Pins all tracks in a playlist for offline playback.
  Future<void> makePlaylistAvailableOffline(
    Playlist playlist, {
    bool requiresWifi = false,
  }) async {
    final tracks = await _loadPlaylistTracksForOffline(playlist);
    await _setTracksAvailableOffline(
      tracks,
      pinned: true,
      requiresWifi: requiresWifi,
    );
  }

  /// Removes a playlist from offline pinning.
  Future<void> unpinPlaylistOffline(Playlist playlist) async {
    final tracks = await _loadPlaylistTracksForOffline(playlist);
    await _setTracksAvailableOffline(tracks, pinned: false);
  }

  /// Pins all tracks in an album for offline playback.
  Future<void> makeAlbumAvailableOffline(
    Album album, {
    bool requiresWifi = false,
  }) async {
    final tracks = await _loadAlbumTracksForOffline(album);
    await _setTracksAvailableOffline(
      tracks,
      pinned: true,
      requiresWifi: requiresWifi,
    );
  }

  /// Removes an album from offline pinning.
  Future<void> unpinAlbumOffline(Album album) async {
    final tracks = await _loadAlbumTracksForOffline(album);
    await _setTracksAvailableOffline(tracks, pinned: false);
  }

  /// Pins all tracks for an artist for offline playback.
  Future<void> makeArtistAvailableOffline(
    Artist artist, {
    bool requiresWifi = false,
  }) async {
    final tracks = await _loadArtistTracksForOffline(artist);
    await _setTracksAvailableOffline(
      tracks,
      pinned: true,
      requiresWifi: requiresWifi,
    );
  }

  /// Removes an artist from offline pinning.
  Future<void> unpinArtistOffline(Artist artist) async {
    final tracks = await _loadArtistTracksForOffline(artist);
    await _setTracksAvailableOffline(tracks, pinned: false);
  }

  Future<void> _setTracksAvailableOffline(
    List<MediaItem> tracks, {
    required bool pinned,
    bool requiresWifi = false,
  }) async {
    for (final track in tracks) {
      final normalized = _normalizeTrackForOffline(track);
      final keys = _offlineKeysForTrack(track);
      if (pinned) {
        for (final key in keys) {
          _cancelledOfflineRequests.remove(key);
        }
        await _cacheStore.setPinnedAudioItem(normalized, true);
        await _cacheStore.setWholeLibraryPinnedAudio(
            normalized.streamUrl, false);
        _pinnedAudio.add(normalized.streamUrl);
        for (final key in keys.where((key) => key != normalized.streamUrl)) {
          await _cacheStore.setPinnedAudio(key, false);
          await _cacheStore.setWholeLibraryPinnedAudio(key, false);
          _pinnedAudio.remove(key);
        }
        await _queueDownload(normalized, requiresWifi: requiresWifi);
      } else {
        for (final key in keys) {
          _cancelledOfflineRequests.add(key);
          await _cacheStore.setPinnedAudio(key, false);
          await _cacheStore.setWholeLibraryPinnedAudio(key, false);
          _pinnedAudio.remove(key);
          _removeDownload(key);
        }
      }
    }
    _refreshSelectedSmartList();
    unawaited(refreshMediaCacheBytes());
    _notify();
  }

  Future<List<MediaItem>> _loadAlbumTracksForOffline(Album album) {
    return _loadTracksForOfflineSource(
      id: album.id,
      loadCached: _cacheStore.loadAlbumTracks,
      fetchRemote: _client.fetchAlbumTracks,
      saveCached: _cacheStore.saveAlbumTracks,
    );
  }

  Future<List<MediaItem>> _loadArtistTracksForOffline(Artist artist) {
    return _loadTracksForOfflineSource(
      id: artist.id,
      loadCached: _cacheStore.loadArtistTracks,
      fetchRemote: _client.fetchArtistTracks,
      saveCached: _cacheStore.saveArtistTracks,
    );
  }

  Future<List<MediaItem>> _loadPlaylistTracksForOffline(Playlist playlist) {
    return _loadTracksForOfflineSource(
      id: playlist.id,
      loadCached: _cacheStore.loadPlaylistTracks,
      fetchRemote: _client.fetchPlaylistTracks,
      saveCached: _cacheStore.savePlaylistTracks,
    );
  }

  Future<List<MediaItem>> _loadTracksForOfflineSource({
    required String id,
    required Future<List<MediaItem>> Function(String id) loadCached,
    required Future<List<MediaItem>> Function(String id) fetchRemote,
    required Future<void> Function(String id, List<MediaItem> tracks)
        saveCached,
  }) async {
    final cached = await loadCached(id);
    if (cached.isNotEmpty) {
      return cached;
    }
    if (_offlineMode) {
      return [];
    }
    try {
      final tracks = await fetchRemote(id);
      await saveCached(id, tracks);
      return tracks;
    } catch (_) {
      return [];
    }
  }

  /// Returns whether a track is pinned for offline playback.
  Future<bool> isTrackPinned(MediaItem track) async {
    final keys = _offlineKeysForTrack(track);
    if (_pinnedAudio.isNotEmpty) {
      return keys.any(_pinnedAudio.contains);
    }
    for (final key in keys) {
      if (await _cacheStore.isPinnedAudio(key)) {
        return true;
      }
    }
    return false;
  }

  /// Returns whether any tracks in an album are pinned for offline playback.
  Future<bool> isAlbumPinned(Album album) async {
    if (_pinnedAudio.isEmpty) {
      return false;
    }
    final tracks = await _cacheStore.loadAlbumTracks(album.id);
    if (tracks.isNotEmpty) {
      return tracks.any(_isTrackPinnedInMemory);
    }
    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    final albumName = album.name.trim().toLowerCase();
    return cachedEntries.any(
      (entry) =>
          _pinnedAudio.contains(entry.streamUrl) &&
          entry.album.trim().toLowerCase() == albumName,
    );
  }

  /// Returns whether any tracks for an artist are pinned for offline playback.
  Future<bool> isArtistPinned(Artist artist) async {
    if (_pinnedAudio.isEmpty) {
      return false;
    }
    final tracks = await _cacheStore.loadArtistTracks(artist.id);
    if (tracks.isNotEmpty) {
      return tracks.any(_isTrackPinnedInMemory);
    }
    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    final artistName = artist.name.trim().toLowerCase();
    return cachedEntries.any(
      (entry) =>
          _pinnedAudio.contains(entry.streamUrl) &&
          entry.artists.any(
            (name) => name.trim().toLowerCase() == artistName,
          ),
    );
  }

  /// Returns offline-ready albums based on pinned tracks.
  Future<List<Album>> loadOfflineAlbums() async {
    if (_pinnedAudio.isEmpty) {
      return [];
    }
    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    final pinnedAlbums = cachedEntries
        .where((entry) => _pinnedAudio.contains(entry.streamUrl))
        .map((entry) => entry.album.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    if (pinnedAlbums.isEmpty) {
      return [];
    }
    final albums = await _cacheStore.loadAlbums();
    final offline = albums
        .where(
            (album) => pinnedAlbums.contains(album.name.trim().toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return offline;
  }

  /// Returns offline-ready artists based on pinned tracks.
  Future<List<Artist>> loadOfflineArtists() async {
    if (_pinnedAudio.isEmpty) {
      return [];
    }
    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    final pinnedArtists = <String>{};
    for (final entry in cachedEntries) {
      if (!_pinnedAudio.contains(entry.streamUrl)) {
        continue;
      }
      for (final artist in entry.artists) {
        final normalized = artist.trim().toLowerCase();
        if (normalized.isNotEmpty) {
          pinnedArtists.add(normalized);
        }
      }
    }
    if (pinnedArtists.isEmpty) {
      return [];
    }
    final artists = await _cacheStore.loadArtists();
    final offline = artists
        .where((artist) =>
            pinnedArtists.contains(artist.name.trim().toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return offline;
  }

  /// Returns offline-ready playlists based on pinned tracks.
  Future<List<Playlist>> loadOfflinePlaylists() async {
    if (_pinnedAudio.isEmpty) {
      return [];
    }
    final playlists = await _cacheStore.loadPlaylists();
    final offline = <Playlist>[];
    for (final playlist in playlists) {
      final tracks = await _cacheStore.loadPlaylistTracks(playlist.id);
      if (tracks.any(_isTrackPinnedInMemory)) {
        offline.add(playlist);
      }
    }
    offline.sort((a, b) => a.name.compareTo(b.name));
    return offline;
  }

  /// Returns offline-ready tracks based on pinned audio.
  Future<List<MediaItem>> loadOfflineTracks() async {
    if (_pinnedAudio.isEmpty) {
      return [];
    }
    final cached = await _cacheStore.loadCachedAudioEntries();
    return cached
        .where((entry) => _pinnedAudio.contains(entry.streamUrl))
        .map(_mediaItemFromCachedEntry)
        .toList();
  }

  Future<List<MediaItem>> _loadAllLibraryTracksForOfflineAction() async {
    if (_offlineMode) {
      return loadOfflineTracks();
    }
    if (_session == null) {
      return const <MediaItem>[];
    }
    await _refreshSmartListSource();
    if (_libraryTracks.isEmpty) {
      await _loadCachedLibraryTrackSnapshot();
    }
    return _deduplicateTracksForOffline(_libraryTracks);
  }

  List<MediaItem> _deduplicateTracksForOffline(Iterable<MediaItem> tracks) {
    final deduplicated = <String, MediaItem>{};
    for (final track in tracks) {
      final normalized = _normalizeTrackForOffline(track);
      deduplicated.putIfAbsent(normalized.streamUrl, () => normalized);
    }
    return deduplicated.values.toList(growable: false);
  }

  int _estimateTrackBytes(MediaItem track, int fallbackBitrate) {
    final bitrate = track.bitrate != null && track.bitrate! > 0
        ? track.bitrate!
        : fallbackBitrate;
    if (bitrate <= 0 || track.duration <= Duration.zero) {
      return 0;
    }
    return max(
      0,
      (track.duration.inMilliseconds * bitrate) ~/ 8000,
    );
  }

  Future<void> _loadCachedLibrary() async {
    _playlists = await _cacheStore.loadPlaylists();
    _featuredTracks = await _cacheStore.loadFeaturedTracks();
    _albums = await _cacheStore.loadAlbums();
    _recentlyAddedAlbums = await _cacheStore.loadRecentlyAddedAlbums();
    _artists = await _cacheStore.loadArtists();
    _genres = await _cacheStore.loadGenres();
    _favoriteAlbums = await _cacheStore.loadFavoriteAlbums();
    _favoriteArtists = await _cacheStore.loadFavoriteArtists();
    _favoriteTracks = await _cacheStore.loadFavoriteTracks();
    _libraryTracks = await _cacheStore.loadLibraryTracks();
    if (_libraryTracks.isNotEmpty) {
      _tracksOffset = _libraryTracks.length;
      _hasMoreTracks = false;
      _libraryTracksFromOfflineSnapshot = false;
    }
    _recentTracks = await _cacheStore.loadRecentTracks();
    _playHistory = await _cacheStore.loadPlayHistory();
    _libraryStats = await _cacheStore.loadLibraryStats();
    _notify();
  }

  Future<void> _applyOfflineModeData() async {
    _isLoadingLibrary = true;
    clearSearch(notify: false);
    _notify();
    _pinnedAudio = (await _cacheStore.loadPinnedAudio())
        .map(_canonicalStreamUrlForStreamUrl)
        .toSet();
    final offlineTracks = await loadOfflineTracks();
    final offlineAlbums = await loadOfflineAlbums();
    final offlineArtists = await loadOfflineArtists();
    final offlinePlaylists = await loadOfflinePlaylists();
    _genres = await _cacheStore.loadGenres();
    _libraryStats = await _cacheStore.loadLibraryStats();
    final offlineAlbumIds = offlineAlbums.map((album) => album.id).toSet();
    final offlineArtistIds = offlineArtists.map((artist) => artist.id).toSet();
    _libraryTracks = offlineTracks;
    _tracksOffset = offlineTracks.length;
    _hasMoreTracks = false;
    _isLoadingTracks = false;
    _libraryTracksFromOfflineSnapshot = true;
    _featuredTracks = offlineTracks;
    _recentTracks = offlineTracks;
    _albums = offlineAlbums;
    _recentlyAddedAlbums = _recentlyAddedAlbums
        .where((album) => offlineAlbumIds.contains(album.id))
        .toList();
    _artists = offlineArtists;
    _playlists = offlinePlaylists;
    final cachedFavorites = await _cacheStore.loadFavoriteTracks();
    _favoriteTracks = _filterPinnedTracks(cachedFavorites);
    final cachedFavoriteAlbums = await _cacheStore.loadFavoriteAlbums();
    _favoriteAlbums = cachedFavoriteAlbums
        .where((album) => offlineAlbumIds.contains(album.id))
        .toList();
    final cachedFavoriteArtists = await _cacheStore.loadFavoriteArtists();
    _favoriteArtists = cachedFavoriteArtists
        .where((artist) => offlineArtistIds.contains(artist.id))
        .toList();
    await _refreshSelectedDetailsForOfflineMode();
    _jumpInTrack = _randomFromList(offlineTracks);
    _jumpInAlbum = _randomFromList(offlineAlbums);
    _jumpInArtist = _randomFromList(offlineArtists);
    _lastJumpInRefreshAt = DateTime.now();
    if (_selectedSmartList != null) {
      _smartListTracks = _buildSmartListTracks(_selectedSmartList!);
    }
    _isLoadingLibrary = false;
    _notify();
  }

  Future<void> _refreshSelectedDetailsForOfflineMode() async {
    if (_selectedPlaylist != null) {
      _playlistTracks =
          await _cacheStore.loadPlaylistTracks(_selectedPlaylist!.id);
    }
    if (_selectedAlbum != null) {
      final cached = await _cacheStore.loadAlbumTracks(_selectedAlbum!.id);
      final filtered = _filterPinnedTracks(cached);
      _albumTracks = filtered.isNotEmpty
          ? filtered
          : await _offlineTracksForAlbum(_selectedAlbum!);
    }
    if (_selectedArtist != null) {
      final cached = await _cacheStore.loadArtistTracks(_selectedArtist!.id);
      final filtered = _filterPinnedTracks(cached);
      _artistTracks = filtered.isNotEmpty
          ? filtered
          : await _offlineTracksForArtist(_selectedArtist!);
    }
    if (_selectedGenre != null) {
      final cached = await _cacheStore.loadGenreTracks(_selectedGenre!.id);
      _genreTracks = _filterPinnedTracks(cached);
    }
  }
}
