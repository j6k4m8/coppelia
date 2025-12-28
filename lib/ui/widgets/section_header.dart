import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/layout_density.dart';

/// Title row for content sections.
class SectionHeader extends StatelessWidget {
  /// Creates a section header.
  const SectionHeader({super.key, required this.title, this.action});

  /// Section title.
  final String title;

  /// Optional trailing widget.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final densityScale =
        context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        if (action == null) {
          return Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          );
        }
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: space(6).clamp(4.0, 10.0)),
              action!,
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            action!,
          ],
        );
      },
    );
  }
}
