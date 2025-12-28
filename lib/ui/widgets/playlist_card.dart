import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../core/color_tokens.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'artwork_image.dart';

/// Artwork tile for a playlist.
class PlaylistCard extends StatelessWidget {
  /// Creates a playlist card.
  const PlaylistCard({
    super.key,
    required this.playlist,
    required this.onTap,
    this.onPlay,
  });

  /// Playlist metadata.
  final Playlist playlist;

  /// Tap handler.
  final VoidCallback onTap;

  /// Optional handler to play the playlist.
  final VoidCallback? onPlay;

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
              Icons.queue_music,
              size: clamped(32, min: 18, max: 36),
            ),
          ),
        );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: clamped(200, min: 130, max: 240),
          decoration: BoxDecoration(
            color: ColorTokens.cardFill(context),
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: ColorTokens.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(cardRadius),
                    topRight: Radius.circular(cardRadius),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      playlist.imageUrl == null
                          ? buildArtworkFallback()
                          : ArtworkImage(
                              imageUrl: playlist.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: buildArtworkFallback(),
                            ),
                      if (onPlay != null)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: EdgeInsets.all(
                              space(10).clamp(4.0, 12.0),
                            ),
                            child: _PlayOverlayButton(onTap: onPlay!),
                          ),
                        ),
                    ],
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
                      playlist.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: space(4).clamp(2.0, 6.0)),
                    Text(
                      '${playlist.trackCount} tracks',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ColorTokens.textSecondary(context),
                      ),
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

class _PlayOverlayButton extends StatelessWidget {
  const _PlayOverlayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final densityScale =
        context.watch<AppState>().layoutDensity.scaleDouble;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    final background = isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.white.withOpacity(0.92);
    final borderColor =
        isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.08);
    final iconColor = isDark ? Colors.white : Colors.black87;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: clamped(40, min: 24, max: 48),
          height: clamped(40, min: 24, max: 48),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: background,
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.play_arrow,
              size: clamped(18, min: 12, max: 22),
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
