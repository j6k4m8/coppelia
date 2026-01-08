import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/album.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import 'album_context_menu.dart';
import 'library_card.dart';
import 'library_list_tile.dart';
import 'offline_browse_view.dart';

/// Displays offline-ready albums.
class OfflineAlbumsView extends StatelessWidget {
  /// Creates the offline albums view.
  const OfflineAlbumsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return OfflineBrowseView<Album>(
      view: LibraryView.offlineAlbums,
      future: state.loadOfflineAlbums(),
      titleBuilder: (album) => album.name,
      subtitleBuilder: (album) => album.artistName,
      gridItemBuilder: (context, album) => LibraryCard(
        title: album.name,
        subtitle: album.artistName,
        imageUrl: album.imageUrl,
        icon: Icons.album,
        onTap: () => state.selectAlbum(album, offlineOnly: true),
        onSubtitleTap: canLinkArtist(album)
            ? () => state.selectArtistByName(album.artistName)
            : null,
        onContextMenu: (position) => showAlbumContextMenu(
          context,
          position,
          album,
          state,
        ),
      ),
      listItemBuilder: (context, album) => LibraryListTile(
        title: album.name,
        subtitle: album.artistName,
        imageUrl: album.imageUrl,
        icon: Icons.album,
        onTap: () => state.selectAlbum(album, offlineOnly: true),
        onSubtitleTap: canLinkArtist(album)
            ? () => state.selectArtistByName(album.artistName)
            : null,
        onContextMenu: (position) => showAlbumContextMenu(
          context,
          position,
          album,
          state,
        ),
      ),
    );
  }

}
