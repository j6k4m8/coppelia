import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
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
    final density =
        context.select((AppState state) => state.layoutDensity);
    final densityScale = density.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    final verticalPadding = density == LayoutDensity.sardine
        ? space(6).clamp(2.0, 8.0)
        : space(10).clamp(4.0, 12.0);
    final subtitleGap = density == LayoutDensity.sardine
        ? space(2).clamp(0.0, 3.0)
        : space(4).clamp(2.0, 6.0);
    final artSize = clamped(48, min: 24, max: 56);
    Widget buildArtworkFallback() => Container(
          width: artSize,
          height: artSize,
          color: ColorTokens.cardFillStrong(context),
          child: Icon(icon, size: clamped(20, min: 14, max: 24)),
        );
    final titleStyle = density == LayoutDensity.sardine
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.titleMedium;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPressStart: (details) =>
          onContextMenu?.call(details.globalPosition),
      onSecondaryTapDown: (details) =>
          onContextMenu?.call(details.globalPosition),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: space(12).clamp(6.0, 16.0),
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: ColorTokens.cardFill(context, 0.04),
          borderRadius: BorderRadius.circular(
            clamped(16, min: 8, max: 20),
          ),
          border: Border.all(color: ColorTokens.border(context)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(
                clamped(12, min: 6, max: 16),
              ),
              child: ArtworkImage(
                imageUrl: imageUrl,
                width: artSize,
                height: artSize,
                fit: BoxFit.cover,
                placeholder: buildArtworkFallback(),
              ),
            ),
            SizedBox(width: space(14).clamp(6.0, 18.0)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  SizedBox(height: subtitleGap),
                  _Subtitle(
                    subtitle: subtitle,
                    onTap: onSubtitleTap,
                  ),
                ],
              ),
            ),
            SizedBox(width: space(8).clamp(3.0, 10.0)),
            Icon(
              Icons.chevron_right,
              size: clamped(18, min: 12, max: 20),
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
