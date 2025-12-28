import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'glass_container.dart';

/// Empty state for offline sections.
class OfflineEmptyView extends StatelessWidget {
  /// Creates an offline empty view.
  const OfflineEmptyView({
    super.key,
    required this.title,
    required this.subtitle,
  });

  /// Title for the empty state.
  final String title;

  /// Supporting subtitle.
  final String subtitle;

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
              Icons.download_done_rounded,
              size: space(32).clamp(24.0, 40.0),
              color: theme.colorScheme.primary,
            ),
            SizedBox(height: space(16)),
            Text(title, style: theme.textTheme.headlineMedium),
            SizedBox(height: space(8)),
            SizedBox(
              width: space(360).clamp(220.0, 420.0),
              child: Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ColorTokens.textSecondary(context, 0.7),
                ),
              ),
            ),
            SizedBox(height: space(16)),
            Text(
              'Nothing downloaded yet.',
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
