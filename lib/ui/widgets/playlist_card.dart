import 'package:flutter/material.dart';

import '../../models/playlist.dart';
import 'playlist_tile.dart';

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
    return PlaylistTile(
      playlist: playlist,
      onTap: onTap,
      onPlay: onPlay,
    );
  }
}
