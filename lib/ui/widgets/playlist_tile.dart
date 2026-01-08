import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'media_card.dart';
import 'play_overlay_button.dart';

/// Shared playlist card used across library and search views.
class PlaylistTile extends StatelessWidget {
  const PlaylistTile({
    super.key,
    required this.playlist,
    required this.onTap,
    this.onPlay,
    this.width,
  });

  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final double? width;

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
      width: width ?? clamped(200, min: 130, max: 240),
      artOverlay: onPlay == null ? null : PlayOverlayButton(onTap: onPlay!),
    );
  }
}
