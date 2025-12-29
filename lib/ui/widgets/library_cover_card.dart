import 'package:flutter/material.dart';

import 'media_card.dart';

/// Artwork-forward card with flush cover and padded text.
class LibraryCoverCard extends StatelessWidget {
  /// Creates a cover-forward card.
  const LibraryCoverCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.imageUrl,
    this.icon = Icons.library_music,
    this.onContextMenu,
    this.onSubtitleTap,
  });

  /// Primary title.
  final String title;

  /// Secondary subtitle.
  final String subtitle;

  /// Artwork URL.
  final String? imageUrl;

  /// Fallback icon when artwork is missing.
  final IconData icon;

  /// Tap handler.
  final VoidCallback onTap;

  /// Context menu trigger.
  final ValueChanged<Offset>? onContextMenu;

  /// Optional handler for tapping the subtitle text.
  final VoidCallback? onSubtitleTap;

  @override
  Widget build(BuildContext context) {
    return MediaCard(
      layout: MediaCardLayout.vertical,
      title: title,
      subtitle: subtitle,
      imageUrl: imageUrl,
      fallbackIcon: icon,
      onTap: onTap,
      onSubtitleTap: onSubtitleTap,
      onContextMenu: onContextMenu,
    );
  }
}
