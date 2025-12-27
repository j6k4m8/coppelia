import 'package:flutter/material.dart';

import '../../state/library_view.dart';
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
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.favorite,
              size: 32,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(view.title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            SizedBox(
              width: 360,
              child: Text(
                view.subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Coming soon.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
