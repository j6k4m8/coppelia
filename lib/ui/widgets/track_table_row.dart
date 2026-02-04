import 'package:flutter/material.dart';

import '../../core/color_tokens.dart';
import '../../core/formatters.dart';
import '../../models/media_item.dart';

/// Table-style row for track listings.
class TrackTableRow extends StatelessWidget {
  /// Creates a track table row.
  const TrackTableRow({
    super.key,
    required this.track,
    required this.index,
    required this.onTap,
    this.isActive = false,
    this.columnWidths = const {
      'index': 60.0,
      'title': 300.0,
      'artist': 200.0,
      'album': 200.0,
      'duration': 80.0,
    },
  });

  final MediaItem track;
  final int index;
  final VoidCallback onTap;
  final bool isActive;
  final Map<String, double> columnWidths;

  @override
  Widget build(BuildContext context) {
    final textColor = isActive
        ? Theme.of(context).colorScheme.primary
        : ColorTokens.textPrimary(context);

    final secondaryColor = isActive
        ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
        : ColorTokens.textSecondary(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Index
            SizedBox(
              width: columnWidths['index'],
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 13,
                ),
              ),
            ),
            // Title
            SizedBox(
              width: columnWidths['title'],
              child: Text(
                track.title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Artist
            SizedBox(
              width: columnWidths['artist'],
              child: Text(
                track.artists.join(', '),
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Album
            SizedBox(
              width: columnWidths['album'],
              child: Text(
                track.album,
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Duration
            SizedBox(
              width: columnWidths['duration'],
              child: Text(
                formatDuration(track.duration),
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 13,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
