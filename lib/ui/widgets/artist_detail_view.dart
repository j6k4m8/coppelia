import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import 'collection_detail_view.dart';

/// Detail view for a single artist.
class ArtistDetailView extends StatelessWidget {
  /// Creates the artist detail view.
  const ArtistDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final artist = state.selectedArtist;
    if (artist == null) {
      return const SizedBox.shrink();
    }
    final subtitle = artist.albumCount > 0
        ? '${artist.albumCount} albums • ${artist.trackCount} tracks'
        : '${artist.trackCount} tracks';
    return CollectionDetailView(
      title: artist.name,
      subtitle: subtitle,
      imageUrl: artist.imageUrl,
      tracks: state.artistTracks,
      nowPlaying: state.nowPlaying,
      onBack: state.clearBrowseSelection,
      onPlayAll: state.artistTracks.isEmpty
          ? null
          : () => state.playFromArtist(state.artistTracks.first),
      onTrackTap: state.playFromArtist,
      onPlayNext: state.playNext,
      onAddToQueue: state.enqueueTrack,
    );
  }
}
