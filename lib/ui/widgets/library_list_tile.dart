import 'package:flutter/material.dart';

import '../../core/color_tokens.dart';
import 'artwork_image.dart';

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
    this.onContextMenu,
    this.onSubtitleTap,
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

  /// Optional context menu handler.
  final ValueChanged<Offset>? onContextMenu;

  /// Optional handler for tapping the subtitle text.
  final VoidCallback? onSubtitleTap;

  @override
  Widget build(BuildContext context) {
    Widget buildArtworkFallback() => Container(
          width: 48,
          height: 48,
          color: ColorTokens.cardFillStrong(context),
          child: Icon(icon, size: 20),
        );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onSecondaryTapDown: (details) =>
          onContextMenu?.call(details.globalPosition),
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
              child: ArtworkImage(
                imageUrl: imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: buildArtworkFallback(),
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
                  _Subtitle(
                    subtitle: subtitle,
                    onTap: onSubtitleTap,
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

class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.subtitle, this.onTap});

  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: ColorTokens.textSecondary(context));
    final linkStyle = baseStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    if (onTap == null) {
      return Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: linkStyle,
        ),
      ),
    );
  }
}
