/// Sidebar navigation items that can be toggled in Settings.
enum SidebarItem {
  /// Home view.
  home,

  /// Settings view.
  settings,

  /// Favorite albums.
  favoritesAlbums,

  /// Favorite songs.
  favoritesSongs,

  /// Favorite artists.
  favoritesArtists,

  /// Browse albums.
  browseAlbums,

  /// Browse artists.
  browseArtists,

  /// Browse genres.
  browseGenres,

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
      case SidebarItem.browseAlbums:
        return 'browse_albums';
      case SidebarItem.browseArtists:
        return 'browse_artists';
      case SidebarItem.browseGenres:
        return 'browse_genres';
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
        return 'Songs';
      case SidebarItem.favoritesArtists:
        return 'Artists';
      case SidebarItem.browseAlbums:
        return 'Albums';
      case SidebarItem.browseArtists:
        return 'Artists';
      case SidebarItem.browseGenres:
        return 'Genres';
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
