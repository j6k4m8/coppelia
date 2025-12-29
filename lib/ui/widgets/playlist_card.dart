import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'media_card.dart';

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
    final densityScale =
        context.select((AppState state) => state.layoutDensity.scaleDouble);
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    return MediaCard(
      layout: MediaCardLayout.vertical,
      title: playlist.name,
      subtitle: '${playlist.trackCount} tracks',
      imageUrl: playlist.imageUrl,
      fallbackIcon: Icons.queue_music,
      onTap: onTap,
      width: clamped(200, min: 130, max: 240),
      artOverlay: onPlay == null ? null : _PlayOverlayButton(onTap: onPlay!),
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
