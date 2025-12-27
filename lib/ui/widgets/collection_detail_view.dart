import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/media_item.dart';
import 'track_row.dart';

/// Generic detail view for albums, artists, or genres.
class CollectionDetailView extends StatelessWidget {
  /// Creates a collection detail view.
  const CollectionDetailView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tracks,
    required this.onBack,
    required this.onTrackTap,
    required this.nowPlaying,
    this.imageUrl,
    this.onPlayAll,
  });

  /// Title for the collection.
  final String title;

  /// Subtitle for the collection.
  final String subtitle;

  /// Tracks in the collection.
  final List<MediaItem> tracks;

  /// Artwork for the collection.
  final String? imageUrl;

  /// Callback for back navigation.
  final VoidCallback onBack;

  /// Callback for playing all tracks.
  final VoidCallback? onPlayAll;

  /// Handler when a track is tapped.
  final ValueChanged<MediaItem> onTrackTap;

  /// Currently playing track.
  final MediaItem? nowPlaying;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          title: title,
          subtitle: subtitle,
          imageUrl: imageUrl,
          onBack: onBack,
          onPlayAll: onPlayAll,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.separated(
            itemCount: tracks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final track = tracks[index];
              return TrackRow(
                track: track,
                index: index,
                isActive: nowPlaying?.id == track.id,
                onTap: () => onTrackTap(track),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.imageUrl,
    this.onPlayAll,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onBack;
  final VoidCallback? onPlayAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1F2433),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: imageUrl == null
                ? Container(
                    width: 140,
                    height: 140,
                    color: Colors.white10,
                    child: const Icon(Icons.library_music, size: 36),
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl!,
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white60),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: onPlayAll,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: onBack,
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
