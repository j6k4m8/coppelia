import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/playlist.dart';
import '../../core/color_tokens.dart';

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
    Widget buildArtworkFallback() => Container(
          color: ColorTokens.cardFillStrong(context),
          child: const Center(
            child: Icon(Icons.queue_music, size: 32),
          ),
        );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ColorTokens.cardFill(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: ColorTokens.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      playlist.imageUrl == null
                          ? buildArtworkFallback()
                          : CachedNetworkImage(
                              imageUrl: playlist.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => buildArtworkFallback(),
                              errorWidget: (_, __, ___) =>
                                  buildArtworkFallback(),
                            ),
                      if (onPlay != null)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: _PlayOverlayButton(onTap: onPlay!),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                playlist.name,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${playlist.trackCount} tracks',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ColorTokens.textSecondary(context),
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
          width: 40,
          height: 40,
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
            child: Icon(Icons.play_arrow, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }
}
