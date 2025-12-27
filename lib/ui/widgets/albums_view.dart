import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/album.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import 'context_menu.dart';
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
        onContextMenu: (position) => _showAlbumMenu(
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
        onContextMenu: (position) => _showAlbumMenu(
          context,
          position,
          album,
          state,
        ),
      ),
    );
  }

  Future<void> _showAlbumMenu(
    BuildContext context,
    Offset position,
    Album album,
    AppState state,
  ) async {
    final canGoToArtist =
        album.artistName.isNotEmpty && album.artistName != 'Unknown Artist';
    final selection = await showContextMenu<_AlbumAction>(
      context,
      position,
      [
        const PopupMenuItem(
          value: _AlbumAction.play,
          child: Text('Play'),
        ),
        const PopupMenuItem(
          value: _AlbumAction.open,
          child: Text('Open'),
        ),
        if (canGoToArtist)
          const PopupMenuItem(
            value: _AlbumAction.goToArtist,
            child: Text('Go to Artist'),
          ),
      ],
    );
    if (selection == _AlbumAction.play) {
      await state.playAlbum(album);
    }
    if (selection == _AlbumAction.open) {
      await state.selectAlbum(album);
    }
    if (selection == _AlbumAction.goToArtist) {
      await state.selectArtistByName(album.artistName);
    }
  }
}

enum _AlbumAction { play, open, goToArtist }
