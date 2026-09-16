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
    final generation = _captureServerGeneration();
    if (_session == null || _offlineMode) {
      return null;
    }
    final tracks = await _loadAllLibraryTracksForOfflineAction();
    if (!_isCurrentServerGeneration(generation)) return null;
    if (tracks.isEmpty) {
      return null;
    }
    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    if (!_isCurrentServerGeneration(generation)) return null;
    final cachedBytesByKey = <String, int>{
      for (final entry in cachedEntries) entry.cacheKey: entry.bytes,
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
      final cachedBytes = cachedBytesByKey[_audioKey(track.streamUrl)];
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
    if (!_isCurrentServerGeneration(generation)) return null;
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
    final generation = _captureServerGeneration();
    const emptyResult = WholeLibraryOfflineResult(
      trackCount: 0,
      newlyPinnedCount: 0,
      newlyQueuedCount: 0,
      retriedFailedCount: 0,
      alreadyPinnedCount: 0,
      wholeLibraryPinnedTrackCount: 0,
    );
    if (normalizedTracks.isEmpty) {
      return emptyResult;
    }

    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    if (!_isCurrentServerGeneration(generation)) return emptyResult;
    final cachedKeys = cachedEntries.map((entry) => entry.cacheKey).toSet();
    _cachedAudio = cachedKeys;

    final nextPinnedAudio = Set<String>.from(_pinnedAudio);
    final storedWholeLibraryPins =
        await _cacheStore.loadWholeLibraryPinnedAudio();
    if (!_isCurrentServerGeneration(generation)) return emptyResult;
    final nextWholeLibraryPinnedAudio =
        Set<String>.from(storedWholeLibraryPins);
    final pinnedItemsToSave = <MediaItem>[];
    var newlyPinnedCount = 0;
    var newlyQueuedCount = 0;
    var retriedFailedCount = 0;
    var alreadyPinnedCount = 0;

    for (final track in normalizedTracks) {
      final key = _audioKey(track.streamUrl);
      _cancelledOfflineRequests.remove(key);
      final wasPinned = nextPinnedAudio.contains(key);
      if (wasPinned) {
        alreadyPinnedCount += 1;
      } else {
        nextPinnedAudio.add(key);
        nextWholeLibraryPinnedAudio.add(key);
        pinnedItemsToSave.add(track);
        newlyPinnedCount += 1;
      }

      if (cachedKeys.contains(key)) {
        continue;
      }

      final existingIndex = _indexOfDownload(track.streamUrl);
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

    if (!_isCurrentServerGeneration(generation)) return emptyResult;
    _pinnedAudio = nextPinnedAudio;
    await _cacheStore.savePinnedAudio(_pinnedAudio);
    if (!_isCurrentServerGeneration(generation)) return emptyResult;
    if (pinnedItemsToSave.isNotEmpty) {
      await _cacheStore.savePinnedAudioItems(pinnedItemsToSave);
      if (!_isCurrentServerGeneration(generation)) return emptyResult;
    }
    await _cacheStore.saveWholeLibraryPinnedAudio(nextWholeLibraryPinnedAudio);
    if (!_isCurrentServerGeneration(generation)) return emptyResult;

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

    final keysToRemove = wholeLibraryPinnedAudio.map(_audioKey).toSet();
    _pinnedAudio.removeAll(keysToRemove);
    _downloadQueue.removeWhere(
      (task) => keysToRemove.contains(_audioKey(task.track.streamUrl)),
    );
    _downloadStatusByKey.removeWhere((key, _) => keysToRemove.contains(key));
    _downloadProgressTimestamps
        .removeWhere((key, _) => keysToRemove.contains(key));
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
    final generation = _captureServerGeneration();
    final shouldAlbums =
        _autoDownloadFavoriteAlbums && !artistsOnly && !tracksOnly;
    final shouldArtists =
        _autoDownloadFavoriteArtists && !albumsOnly && !tracksOnly;
    final shouldTracks =
        _autoDownloadFavoriteTracks && !albumsOnly && !artistsOnly;
    if (shouldAlbums) {
      for (final album in _favoriteAlbums) {
        if (!_isCurrentServerGeneration(generation)) return;
        await makeAlbumAvailableOffline(
          album,
          requiresWifi: _autoDownloadFavoritesWifiOnly,
        );
      }
    }
    if (shouldArtists) {
      for (final artist in _favoriteArtists) {
        if (!_isCurrentServerGeneration(generation)) return;
        await makeArtistAvailableOffline(
          artist,
          requiresWifi: _autoDownloadFavoritesWifiOnly,
        );
      }
    }
    if (shouldTracks) {
      for (final track in _favoriteTracks) {
        if (!_isCurrentServerGeneration(generation)) return;
        await makeTrackAvailableOffline(
          track,
          requiresWifi: _autoDownloadFavoritesWifiOnly,
        );
      }
    }
  }

  int? _indexOfDownload(String streamUrl) {
    final key = _audioKey(streamUrl);
    final index = _downloadQueue.indexWhere(
      (task) => _audioKey(task.track.streamUrl) == key,
    );
    return index == -1 ? null : index;
  }

  void _addDownloadTask(DownloadTask task) {
    _downloadQueue.add(task);
    _downloadStatusByKey[_audioKey(task.track.streamUrl)] = task.status;
  }

  void _replaceDownloadTaskAt(int index, DownloadTask task) {
    _downloadQueue[index] = task;
    _downloadStatusByKey[_audioKey(task.track.streamUrl)] = task.status;
  }

  void _removeDownloadTaskAt(int index) {
    final removed = _downloadQueue.removeAt(index);
    _downloadStatusByKey.remove(_audioKey(removed.track.streamUrl));
  }

  Future<void> _queueDownload(
    MediaItem track, {
    bool requiresWifi = false,
  }) async {
    final generation = _captureServerGeneration();
    final normalized = _normalizeTrackForPlayback(track);
    _clearCancelledOfflineRequest(normalized.streamUrl);
    final existingIndex = _indexOfDownload(normalized.streamUrl);
    if (existingIndex != null) {
      final existing = _downloadQueue[existingIndex];
      if (existing.status == DownloadStatus.failed) {
        retryDownload(existing);
      }
      return;
    }
    final cached = await _cacheStore.isAudioCached(normalized);
    if (!_isCurrentServerGeneration(generation) ||
        _isOfflineRequestCancelled(normalized.streamUrl)) {
      return;
    }
    if (cached) {
      await _cacheStore.touchCachedAudio(normalized);
      if (!_isCurrentServerGeneration(generation)) return;
      _cachedAudio.add(_audioKey(normalized.streamUrl));
      return;
    }
    if (_indexOfDownload(normalized.streamUrl) != null) return;
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
    final generation = _captureServerGeneration();
    final pinnedTracks = await _cacheStore.loadPinnedAudioItems();
    if (!_isCurrentServerGeneration(generation)) return;
    var queuedAny = false;
    for (final track in pinnedTracks) {
      final normalized = _normalizeTrackForPlayback(track);
      final key = _audioKey(normalized.streamUrl);
      if (!_pinnedAudio.contains(key)) {
        continue;
      }
      if (_cachedAudio.contains(key)) {
        continue;
      }
      final cached = await _cacheStore.isAudioCached(normalized);
      if (!_isCurrentServerGeneration(generation)) return;
      if (!_pinnedAudio.contains(key)) continue;
      if (cached) {
        _cachedAudio.add(key);
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
    final key = _audioKey(streamUrl);
    final last = _downloadProgressTimestamps[key];
    final pivot = currentProgress ?? 0.0;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 250) &&
        (newProgress - pivot).abs() < 0.01) {
      return true;
    }
    _downloadProgressTimestamps[key] = now;
    return false;
  }

  bool _isOfflineRequestCancelled(String streamUrl) =>
      _cancelledOfflineRequests.contains(_audioKey(streamUrl));

  void _clearCancelledOfflineRequest(String streamUrl) {
    _cancelledOfflineRequests.remove(_audioKey(streamUrl));
  }

  void _removeDownload(String streamUrl) {
    final index = _indexOfDownload(streamUrl);
    if (index == null) {
      return;
    }
    _removeDownloadTaskAt(index);
    _downloadProgressTimestamps.remove(_audioKey(streamUrl));
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

  Future<void> _downloadTrack(
      DownloadTask task, _ServerGeneration serverGeneration) async {
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
        if (_isOfflineRequestCancelled(streamUrl)) {
          _clearCancelledOfflineRequest(streamUrl);
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
          _cachedAudio.add(_audioKey(streamUrl));
          _removeDownload(streamUrl);
          unawaited(refreshMediaCacheBytes());
        }
      }
    } catch (error) {
      if (!_isCurrentServerGeneration(serverGeneration)) {
        return;
      }
      if (_isOfflineRequestCancelled(streamUrl)) {
        _clearCancelledOfflineRequest(streamUrl);
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
    final generation = _captureServerGeneration();
    final tracks = await _loadPlaylistTracksForOffline(playlist);
    if (!_isCurrentServerGeneration(generation)) return;
    await _setTracksAvailableOffline(
      tracks,
      pinned: true,
      requiresWifi: requiresWifi,
    );
  }

  /// Removes a playlist from offline pinning.
  Future<void> unpinPlaylistOffline(Playlist playlist) async {
    final generation = _captureServerGeneration();
    final tracks = await _loadPlaylistTracksForOffline(playlist);
    if (!_isCurrentServerGeneration(generation)) return;
    await _setTracksAvailableOffline(tracks, pinned: false);
  }

  /// Pins all tracks in an album for offline playback.
  Future<void> makeAlbumAvailableOffline(
    Album album, {
    bool requiresWifi = false,
  }) async {
    final generation = _captureServerGeneration();
    final tracks = await _loadAlbumTracksForOffline(album);
    if (!_isCurrentServerGeneration(generation)) return;
    await _setTracksAvailableOffline(
      tracks,
      pinned: true,
      requiresWifi: requiresWifi,
    );
  }

  /// Removes an album from offline pinning.
  Future<void> unpinAlbumOffline(Album album) async {
    final generation = _captureServerGeneration();
    final tracks = await _loadAlbumTracksForOffline(album);
    if (!_isCurrentServerGeneration(generation)) return;
    await _setTracksAvailableOffline(tracks, pinned: false);
  }

  /// Pins all tracks for an artist for offline playback.
  Future<void> makeArtistAvailableOffline(
    Artist artist, {
    bool requiresWifi = false,
  }) async {
    final generation = _captureServerGeneration();
    final tracks = await _loadArtistTracksForOffline(artist);
    if (!_isCurrentServerGeneration(generation)) return;
    await _setTracksAvailableOffline(
      tracks,
      pinned: true,
      requiresWifi: requiresWifi,
    );
  }

  /// Removes an artist from offline pinning.
  Future<void> unpinArtistOffline(Artist artist) async {
    final generation = _captureServerGeneration();
    final tracks = await _loadArtistTracksForOffline(artist);
    if (!_isCurrentServerGeneration(generation)) return;
    await _setTracksAvailableOffline(tracks, pinned: false);
  }

  Future<void> _setTracksAvailableOffline(
    List<MediaItem> tracks, {
    required bool pinned,
    bool requiresWifi = false,
  }) async {
    // Stop as soon as the active server changes: a later iteration would
    // normalize against the new session and write into the wrong scope.
    final generation = _captureServerGeneration();
    for (final track in tracks) {
      if (!_isCurrentServerGeneration(generation)) return;
      final normalized = _normalizeTrackForPlayback(track);
      final key = _audioKey(normalized.streamUrl);
      if (pinned) {
        _cancelledOfflineRequests.remove(key);
        await _cacheStore.setPinnedAudioItem(normalized, true);
        if (!_isCurrentServerGeneration(generation)) return;
        await _cacheStore.setWholeLibraryPinnedAudio(
            normalized.streamUrl, false);
        if (!_isCurrentServerGeneration(generation)) return;
        _pinnedAudio.add(key);
        await _queueDownload(normalized, requiresWifi: requiresWifi);
      } else {
        _cancelledOfflineRequests.add(key);
        await _cacheStore.setPinnedAudio(normalized.streamUrl, false);
        if (!_isCurrentServerGeneration(generation)) return;
        await _cacheStore.setWholeLibraryPinnedAudio(
            normalized.streamUrl, false);
        if (!_isCurrentServerGeneration(generation)) return;
        _pinnedAudio.remove(key);
        _removeDownload(normalized.streamUrl);
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
      includesTrack: (track) => track.albumId == album.id,
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
    bool Function(MediaItem track)? includesTrack,
  }) async {
    List<MediaItem> includedTracks(List<MediaItem> tracks) {
      return includesTrack == null
          ? tracks
          : tracks.where(includesTrack).toList();
    }

    final generation = _captureServerGeneration();
    final cached = includedTracks(await loadCached(id));
    if (!_isCurrentServerGeneration(generation)) return [];
    if (cached.isNotEmpty) {
      return cached;
    }
    if (_offlineMode) {
      return [];
    }
    try {
      final tracks = includedTracks(await fetchRemote(id));
      if (!_isCurrentServerGeneration(generation)) return [];
      await saveCached(id, tracks);
      if (!_isCurrentServerGeneration(generation)) return [];
      return tracks;
    } catch (_) {
      return [];
    }
  }

  /// Returns whether a track is pinned for offline playback.
  Future<bool> isTrackPinned(MediaItem track) async {
    final key = _audioKey(track.streamUrl);
    return _pinnedAudio.isNotEmpty
        ? _pinnedAudio.contains(key)
        : await _cacheStore.isPinnedAudio(key);
  }

  /// Returns whether any tracks in an album are pinned for offline playback.
  Future<bool> isAlbumPinned(Album album) async {
    if (_pinnedAudio.isEmpty) {
      return false;
    }
    final tracks = _tracksForAlbumId(
      await _cacheStore.loadAlbumTracks(album.id),
      album.id,
    );
    if (tracks.isNotEmpty) {
      return tracks.any(isTrackPinnedInMemory);
    }
    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    return cachedEntries.any(
      (entry) =>
          _pinnedAudio.contains(entry.cacheKey) &&
          entry.mediaItem?.albumId == album.id,
    );
  }

  /// Returns whether any tracks for an artist are pinned for offline playback.
  Future<bool> isArtistPinned(Artist artist) async {
    if (_pinnedAudio.isEmpty) {
      return false;
    }
    final tracks = await _cacheStore.loadArtistTracks(artist.id);
    if (tracks.isNotEmpty) {
      return tracks.any(isTrackPinnedInMemory);
    }
    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    return cachedEntries.any(
      (entry) =>
          _pinnedAudio.contains(entry.cacheKey) &&
          (entry.mediaItem?.artistIds.contains(artist.id) ?? false),
    );
  }

  /// Returns offline-ready albums based on pinned tracks.
  Future<List<Album>> loadOfflineAlbums() async {
    if (_pinnedAudio.isEmpty) {
      return [];
    }
    final cachedEntries = await _cacheStore.loadCachedAudioEntries();
    final pinnedAlbumIds = cachedEntries
        .where((entry) => _pinnedAudio.contains(entry.cacheKey))
        .map((entry) => entry.mediaItem?.albumId)
        .whereType<String>()
        .toSet();
    if (pinnedAlbumIds.isEmpty) {
      return [];
    }
    final albums = await _cacheStore.loadAlbums();
    final offline = albums
        .where((album) => pinnedAlbumIds.contains(album.id))
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
    final pinnedArtistIds = cachedEntries
        .where((entry) => _pinnedAudio.contains(entry.cacheKey))
        .expand((entry) => entry.mediaItem?.artistIds ?? const <String>[])
        .toSet();
    if (pinnedArtistIds.isEmpty) {
      return [];
    }
    final artists = await _cacheStore.loadArtists();
    final offline = artists
        .where((artist) => pinnedArtistIds.contains(artist.id))
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
      if (tracks.any(isTrackPinnedInMemory)) {
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
        .where((entry) => _pinnedAudio.contains(entry.cacheKey))
        .map(_mediaItemFromCachedEntry)
        .toList();
  }

  Future<List<MediaItem>> _loadAllLibraryTracksForOfflineAction() async {
    final generation = _captureServerGeneration();
    if (_offlineMode) {
      return loadOfflineTracks();
    }
    if (_session == null) {
      return const <MediaItem>[];
    }
    await _refreshSmartListSource();
    if (!_isCurrentServerGeneration(generation)) return const <MediaItem>[];
    if (_libraryTracks.isEmpty) {
      await _loadCachedLibraryTrackSnapshot();
      if (!_isCurrentServerGeneration(generation)) return const <MediaItem>[];
    }
    return _deduplicateTracksForOffline(_libraryTracks);
  }

  List<MediaItem> _deduplicateTracksForOffline(Iterable<MediaItem> tracks) {
    final deduplicated = <String, MediaItem>{};
    for (final track in tracks) {
      final normalized = _normalizeTrackForPlayback(track);
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
    final generation = _captureServerGeneration();
    Future<void> load<T>(Future<T> result, void Function(T) apply) async {
      final value = await result;
      if (_isCurrentServerGeneration(generation)) apply(value);
    }

    await Future.wait([
      load(_cacheStore.loadPlaylists(), (value) => _playlists = value),
      load(
          _cacheStore.loadFeaturedTracks(), (value) => _featuredTracks = value),
      load(_cacheStore.loadAlbums(), (value) => _albums = value),
      load(_cacheStore.loadRecentlyAddedAlbums(),
          (value) => _recentlyAddedAlbums = value),
      load(_cacheStore.loadArtists(), (value) => _artists = value),
      load(_cacheStore.loadGenres(), (value) => _genres = value),
      load(
          _cacheStore.loadFavoriteAlbums(), (value) => _favoriteAlbums = value),
      load(_cacheStore.loadFavoriteArtists(),
          (value) => _favoriteArtists = value),
      load(
          _cacheStore.loadFavoriteTracks(), (value) => _favoriteTracks = value),
      load(_cacheStore.loadLibraryTracks(), (value) => _libraryTracks = value),
      load(_cacheStore.loadRecentTracks(), (value) => _recentTracks = value),
      load(_cacheStore.loadPlayHistory(), (value) => _playHistory = value),
      load(_cacheStore.loadLibraryStats(), (value) => _libraryStats = value),
    ]);
    if (!_isCurrentServerGeneration(generation)) return;
    if (_libraryTracks.isNotEmpty) {
      _tracksOffset = _libraryTracks.length;
      _hasMoreTracks = false;
      _libraryTracksFromOfflineSnapshot = false;
    }
    _notify();
  }

  Future<void> _applyOfflineModeData() async {
    final generation = _captureServerGeneration();
    _isLoadingLibrary = true;
    clearSearch(notify: false);
    _notify();
    final pins = await _cacheStore.loadPinnedAudio();
    if (!_isCurrentServerGeneration(generation)) return;
    _pinnedAudio = pins.map(_audioKey).toSet();
    final (
      tracks,
      albums,
      artists,
      playlists,
      genres,
      stats,
      favorites,
      favoriteAlbums,
      favoriteArtists
    ) = await (
      loadOfflineTracks(),
      loadOfflineAlbums(),
      loadOfflineArtists(),
      loadOfflinePlaylists(),
      _cacheStore.loadGenres(),
      _cacheStore.loadLibraryStats(),
      _cacheStore.loadFavoriteTracks(),
      _cacheStore.loadFavoriteAlbums(),
      _cacheStore.loadFavoriteArtists(),
    ).wait;
    if (!_isCurrentServerGeneration(generation)) return;
    final albumIds = albums.map((album) => album.id).toSet();
    final artistIds = artists.map((artist) => artist.id).toSet();
    _libraryTracks = tracks;
    _tracksOffset = tracks.length;
    _hasMoreTracks = false;
    _isLoadingTracks = false;
    _libraryTracksFromOfflineSnapshot = true;
    _featuredTracks = tracks;
    _recentTracks = tracks;
    _albums = albums;
    _recentlyAddedAlbums = _recentlyAddedAlbums
        .where((album) => albumIds.contains(album.id))
        .toList();
    _artists = artists;
    _playlists = playlists;
    _genres = genres;
    _libraryStats = stats;
    _favoriteTracks = _filterPinnedTracks(favorites);
    _favoriteAlbums =
        favoriteAlbums.where((album) => albumIds.contains(album.id)).toList();
    _favoriteArtists = favoriteArtists
        .where((artist) => artistIds.contains(artist.id))
        .toList();
    await _refreshSelectedDetailsForOfflineMode();
    if (!_isCurrentServerGeneration(generation)) return;
    _jumpInTrack = _randomFromList(tracks);
    _jumpInAlbum = _randomFromList(albums);
    _jumpInArtist = _randomFromList(artists);
    _lastJumpInRefreshAt = DateTime.now();
    _refreshSelectedSmartList();
    _isLoadingLibrary = false;
    _notify();
  }

  Future<void> _refreshSelectedDetailsForOfflineMode() async {
    final generation = _captureServerGeneration();
    final playlist = _selectedPlaylist;
    final album = _selectedAlbum;
    final artist = _selectedArtist;
    final genre = _selectedGenre;
    if (playlist != null) {
      final tracks = await _cacheStore.loadPlaylistTracks(playlist.id);
      if (!_isCurrentServerGeneration(generation)) return;
      if (_selectedPlaylist == playlist) _playlistTracks = tracks;
    }
    if (album != null) {
      final cached = await _cacheStore.loadAlbumTracks(album.id);
      if (!_isCurrentServerGeneration(generation)) return;
      final filtered = _filterPinnedTracks(_tracksForAlbumId(cached, album.id));
      final tracks =
          filtered.isNotEmpty ? filtered : await _offlineTracksForAlbum(album);
      if (!_isCurrentServerGeneration(generation)) return;
      if (_selectedAlbum == album) _albumTracks = tracks;
    }
    if (artist != null) {
      final cached = await _cacheStore.loadArtistTracks(artist.id);
      if (!_isCurrentServerGeneration(generation)) return;
      final filtered = _filterPinnedTracks(cached);
      final tracks = filtered.isNotEmpty
          ? filtered
          : await _offlineTracksForArtist(artist);
      if (!_isCurrentServerGeneration(generation)) return;
      if (_selectedArtist == artist) _artistTracks = tracks;
    }
    if (genre != null) {
      final cached = await _cacheStore.loadGenreTracks(genre.id);
      if (!_isCurrentServerGeneration(generation)) return;
      if (_selectedGenre == genre) _genreTracks = _filterPinnedTracks(cached);
    }
  }
}
