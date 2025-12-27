import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/color_tokens.dart';

/// Compact list tile for library items.
class LibraryListTile extends StatelessWidget {
  /// Creates a library list tile.
  const LibraryListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.imageUrl,
    this.icon = Icons.library_music,
  });

  /// Primary title.
  final String title;

  /// Secondary subtitle.
  final String subtitle;

  /// Tap handler.
  final VoidCallback onTap;

  /// Artwork URL.
  final String? imageUrl;

  /// Fallback icon.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ColorTokens.cardFill(context, 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorTokens.border(context)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl == null
                  ? Container(
                      width: 48,
                      height: 48,
                      color: ColorTokens.cardFillStrong(context),
                      child: Icon(icon, size: 20),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: ColorTokens.textSecondary(context)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: ColorTokens.textSecondary(context, 0.55),
            ),
          ],
        ),
      ),
    );
  }
}
