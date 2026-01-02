import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../core/color_tokens.dart';
import 'page_header.dart';
import 'track_row.dart';

/// Displays the current playback queue.
class QueueView extends StatelessWidget {
  /// Creates the queue view.
  const QueueView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final leftGutter =
        (32 * densityScale).clamp(16.0, 40.0).toDouble();
    final rightGutter =
        (24 * densityScale).clamp(12.0, 32.0).toDouble();
    final queue = state.queue;
    if (queue.isEmpty) {
      return Center(
        child: Text(
          'Queue is empty.',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: ColorTokens.textSecondary(context)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0),
          child: PageHeader(
            title: 'Queue',
            trailing: Row(
              children: [
                Text(
                  '${queue.length} tracks',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: ColorTokens.textSecondary(context)),
                ),
                const SizedBox(width: 8),
                _HeaderAction(
                  label: 'Clear',
                  onTap: state.clearQueue,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: space(16)),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0),
            itemCount: queue.length,
            separatorBuilder: (_, __) =>
                SizedBox(height: space(6).clamp(4.0, 10.0)),
            itemBuilder: (context, index) {
              final track = queue[index];
              return TrackRow(
                track: track,
                index: index,
                isActive: state.nowPlaying?.id == track.id,
                onTap: () => state.playQueueIndex(index),
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

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
