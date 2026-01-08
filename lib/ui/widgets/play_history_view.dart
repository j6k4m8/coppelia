import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../core/color_tokens.dart';
import 'track_list_section.dart';
import 'track_row.dart';

/// Displays recent playback history.
class PlayHistoryView extends StatelessWidget {
  /// Creates the play history view.
  const PlayHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final history = state.playHistory;
    if (history.isEmpty) {
      return Center(
        child: Text(
          'No play history yet.',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: ColorTokens.textSecondary(context)),
        ),
      );
    }
    return TrackListSection(
      title: 'Playback / History',
      subtitle: '${history.length} tracks',
      itemCount: history.length,
      itemBuilder: (context, index) {
        final track = history[index];
        return TrackRow(
          track: track,
          index: index,
          isActive: state.nowPlaying?.id == track.id,
          onTap: () => state.playFromList(history, track),
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
