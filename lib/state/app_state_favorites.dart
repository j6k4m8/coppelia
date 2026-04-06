part of 'app_state.dart';

extension AppStateFavoritesExtension on AppState {
  void _applyAlbumFavoriteLocal(Album album, bool isFavorite) {
    _favoriteAlbums = _updatedFavoriteCollection(
      current: _favoriteAlbums,
      item: album,
      isFavorite: isFavorite,
      idOf: (value) => value.id,
      compare: (left, right) => left.name.compareTo(right.name),
    );
  }

  void _applyArtistFavoriteLocal(Artist artist, bool isFavorite) {
    _favoriteArtists = _updatedFavoriteCollection(
      current: _favoriteArtists,
      item: artist,
      isFavorite: isFavorite,
      idOf: (value) => value.id,
      compare: (left, right) => left.name.compareTo(right.name),
    );
  }

  void _applyTrackFavoriteLocal(MediaItem track, bool isFavorite) {
    _favoriteTracks = _updatedFavoriteCollection(
      current: _favoriteTracks,
      item: track,
      isFavorite: isFavorite,
      idOf: (value) => value.id,
      compare: (left, right) => left.title.compareTo(right.title),
    );
  }

  Future<void> _syncAlbumFavoriteOffline(
    Album album,
    bool isFavorite,
  ) async {
    if (!_autoDownloadFavoritesEnabled || !_autoDownloadFavoriteAlbums) {
      return;
    }
    if (isFavorite) {
      await makeAlbumAvailableOffline(
        album,
        requiresWifi: _autoDownloadFavoritesWifiOnly,
      );
      return;
    }
    await unpinAlbumOffline(album);
  }

  Future<void> _syncArtistFavoriteOffline(
    Artist artist,
    bool isFavorite,
  ) async {
    if (!_autoDownloadFavoritesEnabled || !_autoDownloadFavoriteArtists) {
      return;
    }
    if (isFavorite) {
      await makeArtistAvailableOffline(
        artist,
        requiresWifi: _autoDownloadFavoritesWifiOnly,
      );
      return;
    }
    await unpinArtistOffline(artist);
  }

  Future<void> _syncTrackFavoriteOffline(
    MediaItem track,
    bool isFavorite,
  ) async {
    if (!_autoDownloadFavoritesEnabled || !_autoDownloadFavoriteTracks) {
      return;
    }
    if (isFavorite) {
      await makeTrackAvailableOffline(
        track,
        requiresWifi: _autoDownloadFavoritesWifiOnly,
      );
      return;
    }
    await unpinTrackOffline(track);
  }

  /// Updates the favorite status for an album.
  Future<String?> setAlbumFavorite(Album album, bool isFavorite) {
    return _setFavoriteState(
      itemId: album.id,
      isFavorite: isFavorite,
      wasFavorite: isFavoriteAlbum(album.id),
      inFlight: _favoriteAlbumUpdatesInFlight,
      applyLocal: (next) => _applyAlbumFavoriteLocal(album, next),
      persistLocal: () => _cacheStore.saveFavoriteAlbums(_favoriteAlbums),
      syncOffline: (next) => _syncAlbumFavoriteOffline(album, next),
      fallbackMessage: 'Unable to update album favorite.',
    );
  }

  /// Updates the favorite status for an artist.
  Future<String?> setArtistFavorite(Artist artist, bool isFavorite) {
    return _setFavoriteState(
      itemId: artist.id,
      isFavorite: isFavorite,
      wasFavorite: isFavoriteArtist(artist.id),
      inFlight: _favoriteArtistUpdatesInFlight,
      applyLocal: (next) => _applyArtistFavoriteLocal(artist, next),
      persistLocal: () => _cacheStore.saveFavoriteArtists(_favoriteArtists),
      syncOffline: (next) => _syncArtistFavoriteOffline(artist, next),
      fallbackMessage: 'Unable to update artist favorite.',
      confirmRemote: () => _client.fetchFavoriteState(artist.id),
      serverMismatchMessage: 'Server did not update artist favorite.',
    );
  }

  /// Updates the favorite status for a track.
  Future<String?> setTrackFavorite(MediaItem track, bool isFavorite) {
    return _setFavoriteState(
      itemId: track.id,
      isFavorite: isFavorite,
      wasFavorite: isFavoriteTrack(track.id),
      inFlight: _favoriteTrackUpdatesInFlight,
      applyLocal: (next) => _applyTrackFavoriteLocal(track, next),
      persistLocal: () => _cacheStore.saveFavoriteTracks(_favoriteTracks),
      syncOffline: (next) => _syncTrackFavoriteOffline(track, next),
      fallbackMessage: 'Unable to update track favorite.',
    );
  }

  Future<String?> _setFavoriteState({
    required String itemId,
    required bool isFavorite,
    required bool wasFavorite,
    required Set<String> inFlight,
    required void Function(bool nextValue) applyLocal,
    required Future<void> Function() persistLocal,
    required Future<void> Function(bool nextValue) syncOffline,
    required String fallbackMessage,
    Future<bool?> Function()? confirmRemote,
    String? serverMismatchMessage,
  }) async {
    if (inFlight.contains(itemId) || wasFavorite == isFavorite) {
      return null;
    }
    inFlight.add(itemId);
    applyLocal(isFavorite);
    _refreshSelectedSmartList();
    _notify();
    if (_offlineMode) {
      await persistLocal();
      inFlight.remove(itemId);
      _notify();
      return null;
    }
    try {
      await _client.setFavorite(itemId: itemId, isFavorite: isFavorite);
      await persistLocal();
      _refreshSelectedSmartList();
      unawaited(syncOffline(isFavorite));
      final confirmed = confirmRemote == null ? null : await confirmRemote();
      if (confirmed != null && confirmed != isFavorite) {
        applyLocal(wasFavorite);
        await persistLocal();
        _refreshSelectedSmartList();
        _notify();
        return serverMismatchMessage ?? fallbackMessage;
      }
      return null;
    } catch (error) {
      applyLocal(wasFavorite);
      await persistLocal();
      _refreshSelectedSmartList();
      return _requestErrorMessage(
        error,
        fallback: fallbackMessage,
      );
    } finally {
      inFlight.remove(itemId);
      _notify();
    }
  }

  List<T> _updatedFavoriteCollection<T>({
    required List<T> current,
    required T item,
    required bool isFavorite,
    required String Function(T value) idOf,
    required int Function(T left, T right) compare,
  }) {
    final itemId = idOf(item);
    final next = current.where((value) => idOf(value) != itemId).toList();
    if (isFavorite) {
      next.add(item);
    }
    next.sort(compare);
    return next;
  }
}
