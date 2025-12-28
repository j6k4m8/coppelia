import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import 'collection_detail_view.dart';

/// Detail view for a single genre.
class GenreDetailView extends StatelessWidget {
  /// Creates the genre detail view.
  const GenreDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final genre = state.selectedGenre;
    if (genre == null) {
      return const SizedBox.shrink();
    }
    return CollectionDetailView(
      title: genre.name,
      subtitle: '${genre.trackCount} tracks',
      imageUrl: genre.imageUrl,
      tracks: state.genreTracks,
      nowPlaying: state.nowPlaying,
      onPlayAll: state.genreTracks.isEmpty
          ? null
          : () => state.playFromGenre(state.genreTracks.first),
      onShuffle: state.genreTracks.isEmpty
          ? null
          : () => state.playShuffledList(state.genreTracks),
      onTrackTap: state.playFromGenre,
      onPlayNext: state.playNext,
      onAddToQueue: state.enqueueTrack,
      onAlbumTap: (track) {
        if (track.albumId != null) {
          state.selectAlbumById(track.albumId!);
        }
      },
      onArtistTap: (track) {
        if (track.artistIds.isNotEmpty) {
          state.selectArtistById(track.artistIds.first);
        }
      },
    );
  }
}
