import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'glass_container.dart';

/// Shared empty state content for glass panels.
class GlassEmptyState extends StatelessWidget {
  const GlassEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.footer,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String footer;

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
              icon,
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
              footer,
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
