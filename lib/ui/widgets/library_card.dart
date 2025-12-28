import 'package:flutter/material.dart';

import '../../core/color_tokens.dart';
import 'artwork_image.dart';

/// Card for album, artist, or genre tiles.
class LibraryCard extends StatelessWidget {
  /// Creates a library card.
  const LibraryCard({
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
    Widget buildArtworkFallback() => Container(
          color: ColorTokens.cardFillStrong(context),
          child: Center(child: Icon(icon, size: 32)),
        );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onSecondaryTapDown: (details) =>
          onContextMenu?.call(details.globalPosition),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ColorTokens.cardFill(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: ColorTokens.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ArtworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: buildArtworkFallback(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            _Subtitle(
              subtitle: subtitle,
              onTap: onSubtitleTap,
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
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(
          subtitle,
          style: linkStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
