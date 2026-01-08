import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'artwork_fallback.dart';
import 'artwork_image.dart';

/// Layout style for a media card.
enum MediaCardLayout { vertical, horizontal }

/// Shared media card with flush artwork and padded text.
class MediaCard extends StatelessWidget {
  /// Creates a media card.
  const MediaCard({
    super.key,
    required this.layout,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.onDoubleTap,
    this.imageUrl,
    this.fallbackIcon = Icons.library_music,
    this.onSubtitleTap,
    this.onContextMenu,
    this.artOverlay,
    this.artOverlayAlignment = Alignment.bottomRight,
    this.artOverlayPadding,
    this.backgroundColor,
    this.backgroundGradient,
    this.borderRadius,
    this.artAspectRatio,
    this.width,
  });

  /// Layout variant for the card.
  final MediaCardLayout layout;

  /// Primary title.
  final String title;

  /// Secondary subtitle.
  final String subtitle;

  /// Tap handler.
  final VoidCallback? onTap;

  /// Optional double tap handler.
  final VoidCallback? onDoubleTap;

  /// Artwork URL.
  final String? imageUrl;

  /// Fallback icon when artwork is missing.
  final IconData fallbackIcon;

  /// Optional handler for tapping the subtitle text.
  final VoidCallback? onSubtitleTap;

  /// Context menu trigger.
  final ValueChanged<Offset>? onContextMenu;

  /// Optional overlay inside the artwork region.
  final Widget? artOverlay;

  /// Alignment for the artwork overlay.
  final Alignment artOverlayAlignment;

  /// Padding for the artwork overlay.
  final EdgeInsets? artOverlayPadding;

  /// Optional background color override.
  final Color? backgroundColor;

  /// Optional background gradient override.
  final Gradient? backgroundGradient;

  /// Optional radius override.
  final double? borderRadius;

  /// Optional aspect ratio override for vertical layouts.
  final double? artAspectRatio;

  /// Optional fixed width override.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final densityScale =
        context.select((AppState state) => state.layoutDensity.scaleDouble);
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    final cardRadius = borderRadius ?? clamped(22, min: 12, max: 26);
    final iconSize = clamped(32, min: 18, max: 36);
    final overlayPadding = artOverlayPadding ??
        EdgeInsets.all(space(10).clamp(4.0, 12.0));
    Widget buildArtworkFallback({double? iconOverride}) => ArtworkFallback(
          icon: fallbackIcon,
          iconSize: iconOverride ?? iconSize,
        );
    final baseDecoration = BoxDecoration(
      color: backgroundColor ?? ColorTokens.cardFill(context),
      gradient: backgroundGradient,
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(color: ColorTokens.border(context)),
    );
    final clickEnabled = onTap != null || onDoubleTap != null;
    final isCompactVertical =
        layout == MediaCardLayout.vertical && artAspectRatio != null;
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: onSubtitleTap == null
          ? ColorTokens.textSecondary(context)
          : theme.colorScheme.primary,
      fontWeight: onSubtitleTap == null ? FontWeight.normal : FontWeight.w600,
      height: isCompactVertical ? 1.1 : null,
    );

    Widget buildSubtitle() {
      if (onSubtitleTap == null) {
        return Text(
          subtitle,
          style: subtitleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSubtitleTap,
          child: Text(
            subtitle,
            style: subtitleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    Widget buildArtWidget({double? iconOverride}) {
      final art = imageUrl == null
          ? buildArtworkFallback(iconOverride: iconOverride)
          : ArtworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: buildArtworkFallback(iconOverride: iconOverride),
            );
      if (artOverlay == null) {
        return art;
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          art,
          Align(
            alignment: artOverlayAlignment,
            child: Padding(
              padding: overlayPadding,
              child: artOverlay,
            ),
          ),
        ],
      );
    }

    Widget buildContent({required Widget art, required Widget text}) {
      return MouseRegion(
        cursor: clickEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onLongPressStart: onContextMenu == null
              ? null
              : (details) => onContextMenu!.call(details.globalPosition),
          onSecondaryTapDown: onContextMenu == null
              ? null
              : (details) => onContextMenu!.call(details.globalPosition),
          child: Container(
            width: width,
            decoration: baseDecoration,
            child: layout == MediaCardLayout.vertical
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      art,
                      Flexible(
                        fit: FlexFit.loose,
                        child: text,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [art, Expanded(child: text)],
                  ),
          ),
        ),
      );
    }

    if (layout == MediaCardLayout.horizontal) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final cardHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : clamped(104, min: 76, max: 132);
          final iconOverride = (cardHeight * 0.28).clamp(18.0, 34.0);
          final art = ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(cardRadius),
              bottomLeft: Radius.circular(cardRadius),
            ),
            child: SizedBox(
              width: cardHeight,
              child: buildArtWidget(iconOverride: iconOverride),
            ),
          );
          final text = Padding(
            padding: EdgeInsets.symmetric(
              horizontal: space(16).clamp(10.0, 20.0),
              vertical: space(12).clamp(8.0, 18.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                SizedBox(height: space(4).clamp(2.0, 6.0)),
                buildSubtitle(),
              ],
            ),
          );
          return SizedBox(
            height: cardHeight,
            child: buildContent(art: art, text: text),
          );
        },
      );
    }

    final artBody = ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(cardRadius),
        topRight: Radius.circular(cardRadius),
      ),
      child: buildArtWidget(),
    );
    final art = artAspectRatio == null
        ? Expanded(child: artBody)
        : AspectRatio(
            aspectRatio: artAspectRatio!,
            child: artBody,
          );
    final textPadding = isCompactVertical
        ? EdgeInsets.fromLTRB(
            space(10).clamp(6.0, 14.0),
            space(6).clamp(3.0, 8.0),
            space(10).clamp(6.0, 14.0),
            space(6).clamp(3.0, 8.0),
          )
        : EdgeInsets.fromLTRB(
            space(16).clamp(10.0, 20.0),
            space(10).clamp(6.0, 14.0),
            space(16).clamp(10.0, 20.0),
            space(12).clamp(6.0, 16.0),
          );
    final titleStyle = isCompactVertical
        ? theme.textTheme.titleSmall?.copyWith(height: 1.1)
        : theme.textTheme.titleMedium;
    final subtitleGap =
        isCompactVertical ? space(2).clamp(1.0, 3.0) : space(3).clamp(1.0, 5.0);
    final text = Padding(
      padding: textPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: titleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: subtitleGap),
          buildSubtitle(),
        ],
      ),
    );
    return buildContent(art: art, text: text);
  }
}
