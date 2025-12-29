/// Source for theme palette styling.
enum ThemePaletteSource {
  /// Use the default theme colors.
  defaultPalette,

  /// Use the now playing artwork palette.
  nowPlaying,
}

extension ThemePaletteSourceMeta on ThemePaletteSource {
  /// UI label for the palette mode.
  String get label {
    switch (this) {
      case ThemePaletteSource.defaultPalette:
        return 'Default';
      case ThemePaletteSource.nowPlaying:
        return 'Now playing';
    }
  }

  /// Storage key for persistence.
  String get storageKey {
    switch (this) {
      case ThemePaletteSource.defaultPalette:
        return 'default';
      case ThemePaletteSource.nowPlaying:
        return 'now_playing';
    }
  }

  /// Parses a stored key into a palette source.
  static ThemePaletteSource fromStorage(String? raw) {
    switch (raw) {
      case 'now_playing':
        return ThemePaletteSource.nowPlaying;
      case 'default':
      default:
        return ThemePaletteSource.defaultPalette;
    }
  }
}
