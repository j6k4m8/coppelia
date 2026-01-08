import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../core/color_tokens.dart';
import 'header_action.dart';
import 'track_list_section.dart';
import 'track_row.dart';

/// Displays the current playback queue.
class QueueView extends StatelessWidget {
  /// Creates the queue view.
  const QueueView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
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
    return TrackListSection(
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
          HeaderAction(
            label: 'Clear',
            onTap: state.clearQueue,
          ),
        ],
      ),
      itemCount: queue.length,
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
    );
  }
}
