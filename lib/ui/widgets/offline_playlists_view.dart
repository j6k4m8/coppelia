import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import 'library_browse_view.dart';
import 'library_card.dart';
import 'library_list_tile.dart';
import 'offline_section_loader.dart';

/// Displays offline-ready playlists.
class OfflinePlaylistsView extends StatelessWidget {
  /// Creates the offline playlists view.
  const OfflinePlaylistsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return OfflineSectionLoader<Playlist>(
      future: state.loadOfflinePlaylists(),
      emptyTitle: LibraryView.offlinePlaylists.title,
      emptySubtitle: LibraryView.offlinePlaylists.subtitle,
      builder: (context, playlists) {
        return LibraryBrowseView<Playlist>(
          view: LibraryView.offlinePlaylists,
          title: LibraryView.offlinePlaylists.title,
          items: playlists,
          titleBuilder: (playlist) => playlist.name,
          subtitleBuilder: (playlist) => '${playlist.trackCount} tracks',
          gridItemBuilder: (context, playlist) => LibraryCard(
            title: playlist.name,
            subtitle: '${playlist.trackCount} tracks',
            imageUrl: playlist.imageUrl,
            icon: Icons.playlist_play,
            onTap: () =>
                state.selectPlaylist(playlist, offlineOnly: true),
          ),
          listItemBuilder: (context, playlist) => LibraryListTile(
            title: playlist.name,
            subtitle: '${playlist.trackCount} tracks',
            imageUrl: playlist.imageUrl,
            icon: Icons.playlist_play,
            onTap: () =>
                state.selectPlaylist(playlist, offlineOnly: true),
          ),
        );
      },
    );
  }
}
