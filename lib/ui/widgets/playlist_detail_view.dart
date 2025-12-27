import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../state/app_state.dart';
import 'track_row.dart';

/// Playlist detail view with track listing.
class PlaylistDetailView extends StatelessWidget {
  /// Creates the playlist detail view.
  const PlaylistDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final playlist = state.selectedPlaylist;
    if (playlist == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlaylistHeader(playlist: playlist),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.separated(
            itemCount: state.playlistTracks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final track = state.playlistTracks[index];
              return TrackRow(
                track: track,
                index: index,
                isActive: state.nowPlaying?.id == track.id,
                onTap: () => state.playFromPlaylist(track),
                onPlayNext: () => state.playNext(track),
                onAddToQueue: () => state.enqueueTrack(track),
                onAlbumTap: track.albumId == null
                    ? null
                    : () => state.selectAlbumById(track.albumId!),
                onArtistTap: track.artistIds.isEmpty
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
  const _PlaylistHeader({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1F2433),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: playlist.imageUrl == null
                ? Container(
                    width: 140,
                    height: 140,
                    color: Colors.white10,
                    child: const Icon(Icons.queue_music, size: 36),
                  )
                : CachedNetworkImage(
                    imageUrl: playlist.imageUrl!,
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${playlist.trackCount} tracks',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white60),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: state.playlistTracks.isEmpty
                          ? null
                          : () => state.playFromPlaylist(
                                state.playlistTracks.first,
                              ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: state.clearPlaylistSelection,
                      child: const Text('Back to library'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
