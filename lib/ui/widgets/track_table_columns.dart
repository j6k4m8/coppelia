/// Column configuration for track tables.
class TrackTableColumns {
  static const double indexWidth = 50.0;
  static const double durationWidth = 80.0;
  static const double favoriteWidth = 50.0;
  static const double playCountWidth = 80.0;
  static const double bpmWidth = 70.0;
  static const double columnGap = 16.0;

  /// Calculate widths for flexible columns based on available space.
  static Map<String, double> calculateFlexWidths(
    double availableWidth,
    Set<String> visibleColumns,
  ) {
    // Subtract fixed widths
    double remaining = availableWidth;
    remaining -= indexWidth; // Always visible

    if (visibleColumns.contains('duration')) remaining -= durationWidth;
    if (visibleColumns.contains('favorite')) remaining -= favoriteWidth;
    if (visibleColumns.contains('playCount')) remaining -= playCountWidth;
    if (visibleColumns.contains('bpm')) remaining -= bpmWidth;

    // Count gaps between all visible columns + index
    int columnCount = 1; // index
    if (visibleColumns.contains('title')) columnCount++;
    if (visibleColumns.contains('artist')) columnCount++;
    if (visibleColumns.contains('album')) columnCount++;
    if (visibleColumns.contains('genre')) columnCount++;
    if (visibleColumns.contains('playCount')) columnCount++;
    if (visibleColumns.contains('bpm')) columnCount++;
    if (visibleColumns.contains('duration')) columnCount++;
    if (visibleColumns.contains('favorite')) columnCount++;

    final totalGaps = (columnCount - 1) * columnGap;
    remaining -= totalGaps;

    // Distribute remaining space among flex columns
    int flexUnits = 0;
    if (visibleColumns.contains('title')) flexUnits += 3;
    if (visibleColumns.contains('artist')) flexUnits += 2;
    if (visibleColumns.contains('album')) flexUnits += 2;
    if (visibleColumns.contains('genre')) flexUnits += 2;

    final flexUnit = flexUnits > 0 ? remaining / flexUnits : 0.0;

    return {
      'index': indexWidth,
      'title': visibleColumns.contains('title') ? flexUnit * 3 : 0,
      'artist': visibleColumns.contains('artist') ? flexUnit * 2 : 0,
      'album': visibleColumns.contains('album') ? flexUnit * 2 : 0,
      'genre': visibleColumns.contains('genre') ? flexUnit * 2 : 0,
      'playCount': playCountWidth,
      'bpm': bpmWidth,
      'duration': durationWidth,
      'favorite': favoriteWidth,
    };
  }
}
