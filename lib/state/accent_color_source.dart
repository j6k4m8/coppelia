/// Source for the app accent color.
enum AccentColorSource {
  /// Use a predefined palette.
  preset,

  /// Use a custom hex color.
  custom,

  /// Use the now playing artwork color.
  nowPlaying,
}

extension AccentColorSourceMeta on AccentColorSource {
  /// Short label for UI.
  String get label {
    switch (this) {
      case AccentColorSource.preset:
        return 'Presets';
      case AccentColorSource.custom:
        return 'Custom';
      case AccentColorSource.nowPlaying:
        return 'Now playing';
    }
  }

  /// Storage key for persistence.
  String get storageKey {
    switch (this) {
      case AccentColorSource.preset:
        return 'preset';
      case AccentColorSource.custom:
        return 'custom';
      case AccentColorSource.nowPlaying:
        return 'now_playing';
    }
  }

  /// Parses a stored key into a source.
  static AccentColorSource fromStorage(String? raw) {
    switch (raw) {
      case 'custom':
        return AccentColorSource.custom;
      case 'now_playing':
        return AccentColorSource.nowPlaying;
      case 'preset':
      default:
        return AccentColorSource.preset;
    }
  }
}
