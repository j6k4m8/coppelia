import 'package:flutter/material.dart';
import 'glass_empty_state.dart';

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
    return GlassEmptyState(
      icon: Icons.download_done_rounded,
      title: title,
      subtitle: subtitle,
      footer: 'Nothing downloaded yet.',
    );
  }
}
