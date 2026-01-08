import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/album.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import 'album_context_menu.dart';
import 'library_browse_view.dart';
import 'library_card.dart';
import 'library_list_tile.dart';

/// Displays album browsing grid.
class AlbumsView extends StatelessWidget {
  /// Creates the albums view.
  const AlbumsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return LibraryBrowseView<Album>(
      view: LibraryView.albums,
      title: 'Albums',
      items: state.albums,
      titleBuilder: (album) => album.name,
      subtitleBuilder: (album) => album.artistName,
      gridItemBuilder: (context, album) => LibraryCard(
        title: album.name,
        subtitle: album.artistName,
        imageUrl: album.imageUrl,
        icon: Icons.album,
        onTap: () => state.selectAlbum(album),
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
        onTap: () => state.selectAlbum(album),
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
