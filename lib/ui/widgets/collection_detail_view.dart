import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../models/media_item.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'artwork_image.dart';
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
    this.subtitleWidget,
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

  /// Optional custom subtitle widget.
  final Widget? subtitleWidget;

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
    final state = context.read<AppState>();
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: tracks.length + 1 + (headerFooter == null ? 0 : 1),
            separatorBuilder: (_, index) {
              if (index == 0 || (headerFooter != null && index == 1)) {
                return SizedBox(height: space(24));
              }
              return SizedBox(height: space(6).clamp(4.0, 10.0));
            },
            itemBuilder: (context, index) {
              if (index == 0) {
                return _Header(
                  title: title,
                  subtitle: subtitle,
                  subtitleWidget: subtitleWidget,
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
              final canGoToAlbum =
                  onAlbumTap != null && track.albumId != null;
              final canGoToArtist =
                  onArtistTap != null && track.artistIds.isNotEmpty;
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
                isFavorite: state.isFavoriteTrack(track.id),
                isFavoriteUpdating: state.isFavoriteTrackUpdating(track.id),
                onToggleFavorite: () => state.setTrackFavorite(
                  track,
                  !state.isFavoriteTrack(track.id),
                ),
                onAlbumTap: canGoToAlbum
                    ? () => onAlbumTap!.call(track)
                    : null,
                onArtistTap: canGoToArtist
                    ? () => onArtistTap!.call(track)
                    : null,
                onGoToAlbum: canGoToAlbum
                    ? () => onAlbumTap!.call(track)
                    : null,
                onGoToArtist: canGoToArtist
                    ? () => onArtistTap!.call(track)
                    : null,
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
    this.subtitleWidget,
    this.imageUrl,
    this.onPlayAll,
  });

  final String title;
  final String subtitle;
  final Widget? subtitleWidget;
  final String? imageUrl;
  final VoidCallback? onPlayAll;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        final theme = Theme.of(context);
        Widget buildArtworkFallback({double? size}) => Container(
              width: size,
              height: size,
              color: ColorTokens.cardFillStrong(context),
              child: Icon(
                Icons.library_music,
                size: size == null
                    ? clamped(42, min: 32, max: 48)
                    : clamped(36, min: 26, max: 42),
              ),
            );
        final artworkSize = clamped(isNarrow ? 160 : 140, min: 110, max: 190);
        final artwork = ClipRRect(
          borderRadius: BorderRadius.circular(
            clamped(20, min: 12, max: 24),
          ),
          child: ArtworkImage(
            imageUrl: imageUrl,
            width: artworkSize,
            height: artworkSize,
            fit: BoxFit.cover,
            placeholder: buildArtworkFallback(size: artworkSize),
          ),
        );
        Widget details({
          TextStyle? titleStyle,
          TextStyle? subtitleStyle,
        }) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: titleStyle ?? theme.textTheme.headlineMedium,
              ),
              SizedBox(height: space(8)),
              subtitleWidget ??
                  Text(
                    subtitle,
                    style: subtitleStyle ??
                        theme.textTheme.bodyMedium?.copyWith(
                          color: ColorTokens.textSecondary(context),
                        ),
                  ),
              SizedBox(height: space(16)),
              Wrap(
                spacing: space(12),
                runSpacing: space(8),
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
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(space(24).clamp(14.0, 32.0)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: ColorTokens.heroGradient(context),
            ),
            borderRadius: BorderRadius.circular(
              clamped(26, min: 16, max: 30),
            ),
            border: Border.all(color: ColorTokens.border(context)),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    artwork,
                    SizedBox(height: space(20)),
                    details(),
                  ],
                )
              : Row(
                  children: [
                    artwork,
                    SizedBox(width: space(24)),
                    Expanded(child: details()),
                  ],
                ),
        );
      },
    );
  }
}
