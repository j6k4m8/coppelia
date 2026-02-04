/// Visual style for track list display.
enum TrackListStyle {
  /// Card-based layout (current default).
  card,

  /// Table layout with columns.
  table,
}

extension TrackListStyleMeta on TrackListStyle {
  /// Display label for UI.
  String get label {
    switch (this) {
      case TrackListStyle.card:
        return 'Card';
      case TrackListStyle.table:
        return 'Table';
    }
  }
}
