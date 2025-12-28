import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../models/media_item.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../core/color_tokens.dart';
import 'artwork_image.dart';
import 'track_row.dart';

/// Playlist detail view with track listing.
class PlaylistDetailView extends StatelessWidget {
  /// Creates the playlist detail view.
  const PlaylistDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final playlist = state.selectedPlaylist;
    if (playlist == null) {
      return const SizedBox.shrink();
    }
    final pinned = state.pinnedAudio;
    final offlineTracks = state.playlistTracks
        .where((track) => pinned.contains(track.streamUrl))
        .toList();
    final showOfflineFilter = offlineTracks.isNotEmpty;
    final displayTracks = state.offlineOnlyFilter
        ? offlineTracks
        : state.playlistTracks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: displayTracks.length + 1,
            separatorBuilder: (_, index) {
              return SizedBox(
                height: index == 0
                    ? space(24)
                    : space(6).clamp(4.0, 10.0),
              );
            },
            itemBuilder: (context, index) {
              if (index == 0) {
                return _PlaylistHeader(
                  playlist: playlist,
                  tracks: displayTracks,
                  showOfflineFilter: showOfflineFilter,
                  offlineOnly: state.offlineOnlyFilter,
                  onToggleOfflineOnly: state.setOfflineOnlyFilter,
                );
              }
              final trackIndex = index - 1;
              final track = displayTracks[trackIndex];
              return TrackRow(
                track: track,
                index: trackIndex,
                isActive: state.nowPlaying?.id == track.id,
                onTap: () => state.playFromList(displayTracks, track),
                onPlayNext: () => state.playNext(track),
                onAddToQueue: () => state.enqueueTrack(track),
                isFavorite: state.isFavoriteTrack(track.id),
                isFavoriteUpdating: state.isFavoriteTrackUpdating(track.id),
                onToggleFavorite: () => state.setTrackFavorite(
                  track,
                  !state.isFavoriteTrack(track.id),
                ),
                onAlbumTap: track.albumId == null
                    ? null
                    : () => state.selectAlbumById(track.albumId!),
                onArtistTap: track.artistIds.isEmpty
                    ? null
                    : () => state.selectArtistById(track.artistIds.first),
                onGoToAlbum: track.albumId == null
                    ? null
                    : () => state.selectAlbumById(track.albumId!),
                onGoToArtist: track.artistIds.isEmpty
                    ? null
                    : () => state.selectArtistById(track.artistIds.first),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlaylistHeader extends StatelessWidget {
  const _PlaylistHeader({
    required this.playlist,
    required this.tracks,
    required this.showOfflineFilter,
    required this.offlineOnly,
    required this.onToggleOfflineOnly,
  });

  final Playlist playlist;
  final List<MediaItem> tracks;
  final bool showOfflineFilter;
  final bool offlineOnly;
  final ValueChanged<bool> onToggleOfflineOnly;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    Widget buildArtworkFallback(bool isNarrow) => Container(
          width: clamped(isNarrow ? 160 : 140, min: 110, max: 190),
          height: clamped(isNarrow ? 160 : 140, min: 110, max: 190),
          color: ColorTokens.cardFillStrong(context),
          child: Icon(
            Icons.queue_music,
            size: clamped(36, min: 26, max: 42),
          ),
        );
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;
          final artworkSize =
              clamped(isNarrow ? 160 : 140, min: 110, max: 190);
          final artwork = ClipRRect(
            borderRadius: BorderRadius.circular(
              clamped(20, min: 12, max: 24),
            ),
            child: ArtworkImage(
              imageUrl: playlist.imageUrl,
              width: artworkSize,
              height: artworkSize,
              fit: BoxFit.cover,
              placeholder: buildArtworkFallback(isNarrow),
            ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                playlist.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: space(8)),
              Text(
                '${playlist.trackCount} tracks',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: ColorTokens.textSecondary(context)),
              ),
              SizedBox(height: space(16)),
              Wrap(
                spacing: space(12),
                runSpacing: space(8),
                children: [
                  FilledButton.icon(
                    onPressed: tracks.isEmpty
                        ? null
                        : () => state.playFromList(tracks, tracks.first),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                  ),
                  if (tracks.isNotEmpty)
                    FilledButton.tonalIcon(
                      onPressed: () => state.playShuffledList(tracks),
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Shuffle'),
                    ),
                  if (showOfflineFilter)
                    FilterChip(
                      label: const Text('Offline only'),
                      selected: offlineOnly,
                      onSelected: onToggleOfflineOnly,
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
                SizedBox(height: space(20)),
                details,
              ],
            );
          }
          return Row(
            children: [
              artwork,
              SizedBox(width: space(24)),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}
