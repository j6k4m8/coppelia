/// Sidebar navigation items that can be toggled in Settings.
enum SidebarItem {
  /// Home view.
  home,

  /// Settings view.
  settings,

  /// Favorite albums.
  favoritesAlbums,

  /// Favorite tracks.
  favoritesSongs,

  /// Favorite artists.
  favoritesArtists,

  /// Offline albums.
  offlineAlbums,

  /// Offline artists.
  offlineArtists,

  /// Offline playlists.
  offlinePlaylists,

  /// Offline tracks.
  offlineTracks,

  /// Browse albums.
  browseAlbums,

  /// Browse artists.
  browseArtists,

  /// Browse genres.
  browseGenres,

  /// Browse playlists.
  browsePlaylists,

  /// Browse tracks.
  browseTracks,

  /// Playback history.
  history,

  /// Playback queue.
  queue,

  /// Playlists section.
  playlists,
}

extension SidebarItemMetadata on SidebarItem {
  /// Stable key for persistence.
  String get storageKey {
    switch (this) {
      case SidebarItem.home:
        return 'home';
      case SidebarItem.settings:
        return 'settings';
      case SidebarItem.favoritesAlbums:
        return 'favorites_albums';
      case SidebarItem.favoritesSongs:
        return 'favorites_songs';
      case SidebarItem.favoritesArtists:
        return 'favorites_artists';
      case SidebarItem.offlineAlbums:
        return 'offline_albums';
      case SidebarItem.offlineArtists:
        return 'offline_artists';
      case SidebarItem.offlinePlaylists:
        return 'offline_playlists';
      case SidebarItem.offlineTracks:
        return 'offline_tracks';
      case SidebarItem.browseAlbums:
        return 'browse_albums';
      case SidebarItem.browseArtists:
        return 'browse_artists';
      case SidebarItem.browseGenres:
        return 'browse_genres';
      case SidebarItem.browsePlaylists:
        return 'browse_playlists';
      case SidebarItem.browseTracks:
        return 'browse_tracks';
      case SidebarItem.history:
        return 'history';
      case SidebarItem.queue:
        return 'queue';
      case SidebarItem.playlists:
        return 'playlists';
    }
  }

  /// Label used in settings.
  String get label {
    switch (this) {
      case SidebarItem.home:
        return 'Home';
      case SidebarItem.settings:
        return 'Settings';
      case SidebarItem.favoritesAlbums:
        return 'Albums';
      case SidebarItem.favoritesSongs:
        return 'Tracks';
      case SidebarItem.favoritesArtists:
        return 'Artists';
      case SidebarItem.offlineAlbums:
        return 'Albums';
      case SidebarItem.offlineArtists:
        return 'Artists';
      case SidebarItem.offlinePlaylists:
        return 'Playlists';
      case SidebarItem.offlineTracks:
        return 'Tracks';
      case SidebarItem.browseAlbums:
        return 'Albums';
      case SidebarItem.browseArtists:
        return 'Artists';
      case SidebarItem.browseGenres:
        return 'Genres';
      case SidebarItem.browsePlaylists:
        return 'Playlists';
      case SidebarItem.browseTracks:
        return 'Tracks';
      case SidebarItem.history:
        return 'History';
      case SidebarItem.queue:
        return 'Queue';
      case SidebarItem.playlists:
        return 'Playlists';
    }
  }
}
