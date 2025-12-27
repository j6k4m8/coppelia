import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl == null
                  ? Container(
                      width: 48,
                      height: 48,
                      color: Colors.white.withOpacity(0.08),
                      child: Icon(icon, size: 20),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white60),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
