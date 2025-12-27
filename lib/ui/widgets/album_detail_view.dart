import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import 'collection_detail_view.dart';

/// Detail view for a single album.
class AlbumDetailView extends StatelessWidget {
  /// Creates the album detail view.
  const AlbumDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final album = state.selectedAlbum;
    if (album == null) {
      return const SizedBox.shrink();
    }
    return CollectionDetailView(
      title: album.name,
      subtitle: '${album.trackCount} tracks • ${album.artistName}',
      imageUrl: album.imageUrl,
      tracks: state.albumTracks,
      nowPlaying: state.nowPlaying,
      onBack: state.clearBrowseSelection,
      onPlayAll: state.albumTracks.isEmpty
          ? null
          : () => state.playFromAlbum(state.albumTracks.first),
      onTrackTap: state.playFromAlbum,
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
