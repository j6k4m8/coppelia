/// Navigation targets for the library area.
enum LibraryView {
  /// Home overview with featured content.
  home,

  /// Favorite albums section.
  favoritesAlbums,

  /// Favorite songs section.
  favoritesSongs,

  /// Favorite artists section.
  favoritesArtists,
}

/// Display helpers for library views.
extension LibraryViewLabels on LibraryView {
  /// Short title for the view.
  String get title {
    switch (this) {
      case LibraryView.home:
        return 'Home';
      case LibraryView.favoritesAlbums:
        return 'Favorite Albums';
      case LibraryView.favoritesSongs:
        return 'Favorite Songs';
      case LibraryView.favoritesArtists:
        return 'Favorite Artists';
    }
  }

  /// Supporting subtitle for the view.
  String get subtitle {
    switch (this) {
      case LibraryView.home:
        return 'Featured playlists and recent picks.';
      case LibraryView.favoritesAlbums:
        return 'Quick access to albums you love.';
      case LibraryView.favoritesSongs:
        return 'Tracks you have starred in Jellyfin.';
      case LibraryView.favoritesArtists:
        return 'Artists you keep on repeat.';
    }
  }
}
