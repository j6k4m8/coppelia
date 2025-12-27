/// Navigation targets for the library area.
enum LibraryView {
  /// Home overview with featured content.
  home,

  /// Browse albums.
  albums,

  /// Browse artists.
  artists,

  /// Browse genres.
  genres,

  /// Favorite albums section.
  favoritesAlbums,

  /// Favorite songs section.
  favoritesSongs,

  /// Favorite artists section.
  favoritesArtists,

  /// Application settings.
  settings,
}

/// Display helpers for library views.
extension LibraryViewLabels on LibraryView {
  /// Short title for the view.
  String get title {
    switch (this) {
      case LibraryView.home:
        return 'Home';
      case LibraryView.albums:
        return 'Albums';
      case LibraryView.artists:
        return 'Artists';
      case LibraryView.genres:
        return 'Genres';
      case LibraryView.favoritesAlbums:
        return 'Favorite Albums';
      case LibraryView.favoritesSongs:
        return 'Favorite Songs';
      case LibraryView.favoritesArtists:
        return 'Favorite Artists';
      case LibraryView.settings:
        return 'Settings';
    }
  }

  /// Supporting subtitle for the view.
  String get subtitle {
    switch (this) {
      case LibraryView.home:
        return 'Featured playlists and recent picks.';
      case LibraryView.albums:
        return 'Explore your full album library.';
      case LibraryView.artists:
        return 'All artists in your collection.';
      case LibraryView.genres:
        return 'Browse by mood and style.';
      case LibraryView.favoritesAlbums:
        return 'Quick access to albums you love.';
      case LibraryView.favoritesSongs:
        return 'Tracks you have starred in Jellyfin.';
      case LibraryView.favoritesArtists:
        return 'Artists you keep on repeat.';
      case LibraryView.settings:
        return 'Tune the player to your liking.';
    }
  }
}
