import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/media_item.dart';
import '../../core/color_tokens.dart';
import 'track_row.dart';

/// Generic detail view for albums, artists, or genres.
class CollectionDetailView extends StatelessWidget {
  /// Creates a collection detail view.
  const CollectionDetailView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tracks,
    required this.onTrackTap,
    required this.nowPlaying,
    this.imageUrl,
    this.onPlayAll,
    this.onPlayNext,
    this.onAddToQueue,
    this.onAlbumTap,
    this.onArtistTap,
    this.headerFooter,
  });

  /// Title for the collection.
  final String title;

  /// Subtitle for the collection.
  final String subtitle;

  /// Tracks in the collection.
  final List<MediaItem> tracks;

  /// Artwork for the collection.
  final String? imageUrl;

  /// Callback for playing all tracks.
  final VoidCallback? onPlayAll;

  /// Handler when a track is tapped.
  final ValueChanged<MediaItem> onTrackTap;

  /// Handler when a track should play next.
  final ValueChanged<MediaItem>? onPlayNext;

  /// Handler when a track should be enqueued.
  final ValueChanged<MediaItem>? onAddToQueue;

  /// Handler when a track album should be opened.
  final ValueChanged<MediaItem>? onAlbumTap;

  /// Handler when a track artist should be opened.
  final ValueChanged<MediaItem>? onArtistTap;

  /// Currently playing track.
  final MediaItem? nowPlaying;

  /// Optional widget to render below the header.
  final Widget? headerFooter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: tracks.length + 1 + (headerFooter == null ? 0 : 1),
            separatorBuilder: (_, index) {
              if (index == 0 || (headerFooter != null && index == 1)) {
                return const SizedBox(height: 24);
              }
              return const SizedBox(height: 6);
            },
            itemBuilder: (context, index) {
              if (index == 0) {
                return _Header(
                  title: title,
                  subtitle: subtitle,
                  imageUrl: imageUrl,
                  onPlayAll: onPlayAll,
                );
              }
              if (headerFooter != null && index == 1) {
                return headerFooter!;
              }
              final trackIndex =
                  index - (headerFooter == null ? 1 : 2);
              final track = tracks[trackIndex];
              return TrackRow(
                track: track,
                index: trackIndex,
                isActive: nowPlaying?.id == track.id,
                onTap: () => onTrackTap(track),
                onPlayNext: onPlayNext == null
                    ? null
                    : () => onPlayNext!.call(track),
                onAddToQueue: onAddToQueue == null
                    ? null
                    : () => onAddToQueue!.call(track),
                onAlbumTap: onAlbumTap == null
                    ? null
                    : () => onAlbumTap!.call(track),
                onArtistTap: onArtistTap == null
                    ? null
                    : () => onArtistTap!.call(track),
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
    this.imageUrl,
    this.onPlayAll,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback? onPlayAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ColorTokens.heroGradient(context),
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: ColorTokens.border(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;
          final artwork = ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: imageUrl == null
                ? Container(
                    width: isNarrow ? 160 : 140,
                    height: isNarrow ? 160 : 140,
                    color: ColorTokens.cardFillStrong(context),
                    child: const Icon(Icons.library_music, size: 36),
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl!,
                    width: isNarrow ? 160 : 140,
                    height: isNarrow ? 160 : 140,
                    fit: BoxFit.cover,
                  ),
          );
          final details = Column(
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
                    ?.copyWith(color: ColorTokens.textSecondary(context)),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onPlayAll,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                  ),
                ],
              ),
            ],
          );
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                artwork,
                const SizedBox(height: 20),
                details,
              ],
            );
          }
          return Row(
            children: [
              artwork,
              const SizedBox(width: 24),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}
