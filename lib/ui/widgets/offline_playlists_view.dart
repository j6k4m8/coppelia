import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import 'playlist_tile.dart';
import 'library_list_tile.dart';
import 'offline_browse_view.dart';

/// Displays offline-ready playlists.
class OfflinePlaylistsView extends StatelessWidget {
  /// Creates the offline playlists view.
  const OfflinePlaylistsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return OfflineBrowseView<Playlist>(
      view: LibraryView.offlinePlaylists,
      future: state.loadOfflinePlaylists(),
      titleBuilder: (playlist) => playlist.name,
      subtitleBuilder: (playlist) => '${playlist.trackCount} tracks',
      gridItemBuilder: (context, playlist) => PlaylistTile(
        playlist: playlist,
        onTap: () => state.selectPlaylist(playlist, offlineOnly: true),
      ),
      listItemBuilder: (context, playlist) => LibraryListTile(
        title: playlist.name,
        subtitle: '${playlist.trackCount} tracks',
        imageUrl: playlist.imageUrl,
        icon: Icons.playlist_play,
        onTap: () => state.selectPlaylist(playlist, offlineOnly: true),
      ),
    );
  }
}
