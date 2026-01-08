import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import 'track_list_section.dart';
import 'track_row.dart';

/// Displays favorite tracks list.
class FavoriteTracksView extends StatelessWidget {
  /// Creates the favorite tracks view.
  const FavoriteTracksView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final favorites = state.favoriteTracks;
    return TrackListSection(
      title: 'Favorites / Tracks',
      subtitle: '${favorites.length} tracks',
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final track = favorites[index];
        return TrackRow(
          track: track,
          index: index,
          isActive: state.nowPlaying?.id == track.id,
          onTap: () => state.playFromFavorites(track),
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
