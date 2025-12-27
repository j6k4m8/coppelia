/// Layout modes for the now playing surface.
enum NowPlayingLayout {
  /// Docked on the right side.
  side,

  /// Docked along the bottom edge.
  bottom,
}

/// Human-friendly labels for layouts.
extension NowPlayingLayoutLabel on NowPlayingLayout {
  /// Label for UI controls.
  String get label {
    switch (this) {
      case NowPlayingLayout.side:
        return 'Side panel';
      case NowPlayingLayout.bottom:
        return 'Bottom bar';
    }
  }
}
