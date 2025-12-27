import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/media_item.dart';

/// Prominent card for spotlight tracks.
class FeaturedTrackCard extends StatelessWidget {
  /// Creates a featured track card.
  const FeaturedTrackCard({
    super.key,
    required this.track,
    required this.onTap,
  });

  /// Track to display.
  final MediaItem track;

  /// Tap handler.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: track.imageUrl == null
                  ? Container(
                      width: 72,
                      height: 72,
                      color: Colors.white10,
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
                  Text(
                    track.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white60,
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
