import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../core/color_tokens.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'artwork_image.dart';

/// Prominent card for spotlight tracks.
class FeaturedTrackCard extends StatelessWidget {
  /// Creates a featured track card.
  const FeaturedTrackCard({
    super.key,
    required this.track,
    required this.onTap,
    this.onArtistTap,
  });

  /// Track to display.
  final MediaItem track;

  /// Tap handler.
  final VoidCallback onTap;

  /// Optional handler for tapping the artist label.
  final VoidCallback? onArtistTap;

  @override
  Widget build(BuildContext context) {
    final useSingleTap = !kIsWeb &&
        (Platform.isIOS || Platform.isAndroid || Platform.isFuchsia);
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    final artSize = clamped(72, min: 40, max: 88);
    Widget buildArtworkFallback({double? size}) => Container(
          width: size,
          height: size,
          color: ColorTokens.cardFillStrong(context),
          child: Icon(
            Icons.music_note,
            size: size == null ? 24 : 20,
          ),
        );
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: useSingleTap ? onTap : null,
      onDoubleTap: useSingleTap ? null : onTap,
      child: Container(
        width: clamped(260, min: 170, max: 300),
        padding: EdgeInsets.all(space(16).clamp(10.0, 20.0)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ColorTokens.cardFill(context, 0.1),
              ColorTokens.cardFill(context, 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(
            clamped(24, min: 14, max: 28),
          ),
          border: Border.all(color: ColorTokens.border(context)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(
                clamped(16, min: 8, max: 20),
              ),
              child: track.imageUrl == null
                  ? buildArtworkFallback(size: artSize)
                  : ArtworkImage(
                      imageUrl: track.imageUrl,
                      width: artSize,
                      height: artSize,
                      fit: BoxFit.cover,
                      placeholder: buildArtworkFallback(size: artSize),
                    ),
            ),
            SizedBox(width: space(16).clamp(8.0, 20.0)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  SizedBox(height: space(4).clamp(2.0, 6.0)),
                  MouseRegion(
                    cursor: onArtistTap == null
                        ? SystemMouseCursors.basic
                        : SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onArtistTap,
                      child: Text(
                        track.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onArtistTap == null
                              ? ColorTokens.textSecondary(context)
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
