import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Card for album, artist, or genre tiles.
class LibraryCard extends StatelessWidget {
  /// Creates a library card.
  const LibraryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.imageUrl,
    this.icon = Icons.library_music,
    this.onContextMenu,
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) =>
          onContextMenu?.call(details.globalPosition),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageUrl == null
                      ? Container(
                          color: Colors.white.withOpacity(0.08),
                          child: Center(child: Icon(icon, size: 32)),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white60),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
