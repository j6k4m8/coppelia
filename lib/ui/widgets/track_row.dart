import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/media_item.dart';

/// Row for a track listing.
class TrackRow extends StatelessWidget {
  /// Creates a track row.
  const TrackRow({
    super.key,
    required this.track,
    required this.index,
    required this.onTap,
    this.isActive = false,
  });

  /// Track metadata.
  final MediaItem track;

  /// Display order number.
  final int index;

  /// Tap handler.
  final VoidCallback onTap;

  /// Indicates if this track is playing.
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.12) : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${index + 1}'.padLeft(2, '0'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: track.imageUrl == null
                  ? Container(
                      width: 44,
                      height: 44,
                      color: Colors.white10,
                      child: const Icon(Icons.music_note, size: 18),
                    )
                  : CachedNetworkImage(
                      imageUrl: track.imageUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatDuration(track.duration),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white60,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
