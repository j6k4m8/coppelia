import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import 'collection_detail_view.dart';
import 'collection_header.dart';

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
    final pinned = state.pinnedAudio;
    final offlineTracks = state.genreTracks
        .where((track) => pinned.contains(track.streamUrl))
        .toList();
    final displayTracks =
        state.offlineOnlyFilter ? offlineTracks : state.genreTracks;

    final onPlayAll = displayTracks.isEmpty
        ? null
        : () => state.playFromList(displayTracks, displayTracks.first);
    final onShuffle = displayTracks.isEmpty
        ? null
        : () => state.playShuffledList(displayTracks);

    return CollectionDetailView(
      title: genre.name,
      subtitle: '${genre.trackCount} tracks',
      imageUrl: genre.imageUrl,
      tracks: displayTracks,
      nowPlaying: state.nowPlaying,
      onPlayAll: onPlayAll,
      onShuffle: onShuffle,
      onTrackTap: (track) => state.playFromList(displayTracks, track),
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
      headerActionSpecs: [
        HeaderActionSpec(
          icon: Icons.play_arrow,
          label: 'Play',
          tooltip: 'Play',
          onPressed: onPlayAll,
        ),
        HeaderActionSpec(
          icon: Icons.shuffle,
          label: 'Shuffle',
          tooltip: 'Shuffle',
          tonal: true,
          onPressed: onShuffle,
        ),
      ],
    );
  }
}
