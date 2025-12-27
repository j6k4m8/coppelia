import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/album.dart';
import '../../state/app_state.dart';
import 'collection_detail_view.dart';
import 'section_header.dart';

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
    final artistName = album.artistName;
    final canLinkArtist =
        artistName.isNotEmpty && artistName != 'Unknown Artist';
    final subtitle = '${album.trackCount} tracks • $artistName';
    return CollectionDetailView(
      title: album.name,
      subtitle: subtitle,
      imageUrl: album.imageUrl,
      tracks: state.albumTracks,
      nowPlaying: state.nowPlaying,
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
      headerFooter: canLinkArtist
          ? _ArtistInlineLink(
              artistName: artistName,
              onTap: () => state.selectArtistByName(artistName),
            )
          : null,
    );
  }
}

class _ArtistInlineLink extends StatelessWidget {
  const _ArtistInlineLink({
    required this.artistName,
    required this.onTap,
  });

  final String artistName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SectionHeader(
        title: 'Artist',
        action: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Text(
              artistName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
