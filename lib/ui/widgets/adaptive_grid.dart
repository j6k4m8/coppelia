import 'package:flutter/material.dart';
import 'grid_metrics.dart';

/// Adaptive grid with shared spacing and sizing rules.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.aspectRatio,
    required this.spacing,
    required this.targetMinWidth,
    this.columns,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double aspectRatio;
  final double spacing;
  final double targetMinWidth;
  final int? columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedColumns = columns ??
            GridMetrics.fromWidth(
              width: constraints.maxWidth,
              itemAspectRatio: aspectRatio,
              itemMinWidth: targetMinWidth,
              spacing: spacing,
            ).columns;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: resolvedColumns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
