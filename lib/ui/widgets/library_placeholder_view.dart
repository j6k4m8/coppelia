import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../state/library_view.dart';
import '../../core/color_tokens.dart';
import 'glass_container.dart';

/// Placeholder content for upcoming library sections.
class LibraryPlaceholderView extends StatelessWidget {
  /// Creates a placeholder view.
  const LibraryPlaceholderView({super.key, required this.view});

  /// Selected library view.
  final LibraryView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Center(
      child: GlassContainer(
        padding: EdgeInsets.all(space(32).clamp(16.0, 40.0)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.favorite,
              size: space(32).clamp(24.0, 40.0),
              color: theme.colorScheme.primary,
            ),
            SizedBox(height: space(16)),
            Text(view.title, style: theme.textTheme.headlineMedium),
            SizedBox(height: space(8)),
            SizedBox(
              width: space(360).clamp(220.0, 420.0),
              child: Text(
                view.subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ColorTokens.textSecondary(context, 0.7),
                ),
              ),
            ),
            SizedBox(height: space(16)),
            Text(
              'Coming soon.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: ColorTokens.textSecondary(context, 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
