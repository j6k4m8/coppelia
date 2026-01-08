import 'package:flutter/material.dart';
import '../../state/library_view.dart';
import 'glass_empty_state.dart';

/// Placeholder content for upcoming library sections.
class LibraryPlaceholderView extends StatelessWidget {
  /// Creates a placeholder view.
  const LibraryPlaceholderView({super.key, required this.view});

  /// Selected library view.
  final LibraryView view;

  @override
  Widget build(BuildContext context) {
    return GlassEmptyState(
      icon: Icons.favorite,
      title: view.title,
      subtitle: view.subtitle,
      footer: 'Coming soon.',
    );
  }
}
