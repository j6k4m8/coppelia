class GridMetrics {
  const GridMetrics({
    required this.columns,
    required this.itemWidth,
    required this.itemHeight,
    required this.aspectRatio,
    required this.spacing,
  });

  final int columns;
  final double itemWidth;
  final double itemHeight;
  final double aspectRatio;
  final double spacing;

  static GridMetrics fromWidth({
    required double width,
    required double itemAspectRatio,
    required double itemMinWidth,
    required double spacing,
  }) {
    final crossAxisCount = (width / itemMinWidth).floor();
    final columns = crossAxisCount < 1 ? 1 : crossAxisCount;
    final totalSpacing = spacing * (columns - 1);
    final itemWidth = (width - totalSpacing) / columns;
    final itemHeight = itemWidth / itemAspectRatio;
    return GridMetrics(
      columns: columns,
      itemWidth: itemWidth,
      itemHeight: itemHeight,
      aspectRatio: itemAspectRatio,
      spacing: spacing,
    );
  }

  double offsetForIndex(int index) {
    final row = (index / columns).floor();
    return row * (itemHeight + spacing);
  }
}
