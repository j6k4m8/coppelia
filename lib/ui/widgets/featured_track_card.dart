import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/media_item.dart';
import '../../core/color_tokens.dart';

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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: onTap,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ColorTokens.cardFill(context, 0.1),
              ColorTokens.cardFill(context, 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ColorTokens.border(context)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
                child: track.imageUrl == null
                    ? Container(
                      width: 72,
                      height: 72,
                      color: ColorTokens.cardFillStrong(context),
                      child: const Icon(Icons.music_note),
                    )
                  : CachedNetworkImage(
                      imageUrl: track.imageUrl!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: onArtistTap == null
                                  ? ColorTokens.textSecondary(context)
                                  : Theme.of(context)
                                      .colorScheme
                                      .primary,
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
