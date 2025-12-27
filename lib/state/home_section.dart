/// Sections that can be shown on the Home overview.
enum HomeSection {
  /// Featured tracks shelf.
  featured,

  /// Recently played shelf.
  recent,

  /// Playlists shelf.
  playlists,
}

extension HomeSectionMetadata on HomeSection {
  /// Stable key for persistence.
  String get storageKey {
    switch (this) {
      case HomeSection.featured:
        return 'featured';
      case HomeSection.recent:
        return 'recent';
      case HomeSection.playlists:
        return 'playlists';
    }
  }

  /// Label used in settings.
  String get label {
    switch (this) {
      case HomeSection.featured:
        return 'Featured';
      case HomeSection.recent:
        return 'Recently played';
      case HomeSection.playlists:
        return 'Playlists';
    }
  }

  /// Short description for settings.
  String get description {
    switch (this) {
      case HomeSection.featured:
        return 'Show the curated track shelf.';
      case HomeSection.recent:
        return 'Show your recently played shelf.';
      case HomeSection.playlists:
        return 'Show playlists on Home.';
    }
  }
}
