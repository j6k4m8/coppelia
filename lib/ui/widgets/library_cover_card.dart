import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'artwork_image.dart';

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
    final theme = Theme.of(context);
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    final cardRadius = clamped(22, min: 12, max: 26);
    Widget buildArtworkFallback() => Container(
          color: ColorTokens.cardFillStrong(context),
          child: Center(
            child: Icon(
              icon,
              size: clamped(32, min: 18, max: 36),
            ),
          ),
        );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onSecondaryTapDown: (details) =>
            onContextMenu?.call(details.globalPosition),
        child: Container(
          decoration: BoxDecoration(
            color: ColorTokens.cardFill(context),
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: ColorTokens.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(cardRadius),
                    topRight: Radius.circular(cardRadius),
                  ),
                  child: imageUrl == null
                      ? buildArtworkFallback()
                      : ArtworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: buildArtworkFallback(),
                        ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  space(16).clamp(10.0, 20.0),
                  space(12).clamp(8.0, 16.0),
                  space(16).clamp(10.0, 20.0),
                  space(16).clamp(8.0, 20.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: space(4).clamp(2.0, 6.0)),
                    _Subtitle(
                      subtitle: subtitle,
                      onTap: onSubtitleTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
