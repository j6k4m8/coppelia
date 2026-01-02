import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/album.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import 'app_snack.dart';
import 'context_menu.dart';
import 'library_browse_view.dart';
import 'library_cover_card.dart';
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
      gridItemBuilder: (context, album) => LibraryCoverCard(
        title: album.name,
        subtitle: album.artistName,
        imageUrl: album.imageUrl,
        icon: Icons.album,
        onTap: () => state.selectAlbum(album),
        onSubtitleTap: _canLinkArtist(album)
            ? () => state.selectArtistByName(album.artistName)
            : null,
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
        onSubtitleTap: _canLinkArtist(album)
            ? () => state.selectArtistByName(album.artistName)
            : null,
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
    final canGoToArtist = _canLinkArtist(album);
    final isFavorite = state.isFavoriteAlbum(album.id);
    final isPinned = await state.isAlbumPinned(album);
    if (!context.mounted) {
      return;
    }
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
        PopupMenuItem(
          value: _AlbumAction.favorite,
          child: isFavorite
              ? const Row(
                  children: [
                    Icon(Icons.favorite, size: 16),
                    SizedBox(width: 8),
                    Text('Unfavorite'),
                  ],
                )
              : const Text('Favorite'),
        ),
        PopupMenuItem(
          value: isPinned
              ? _AlbumAction.unpinOffline
              : _AlbumAction.makeAvailableOffline,
          child: isPinned
              ? const Row(
                  children: [
                    Icon(Icons.download_done_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Unpin from Offline'),
                  ],
                )
              : const Text('Make Available Offline'),
        ),
        if (canGoToArtist)
          const PopupMenuItem(
            value: _AlbumAction.goToArtist,
            child: Text('Go to Artist'),
          ),
      ],
    );
    if (!context.mounted) {
      return;
    }
    if (selection == _AlbumAction.play) {
      await state.playAlbum(album);
    }
    if (selection == _AlbumAction.open) {
      await state.selectAlbum(album);
    }
    if (selection == _AlbumAction.goToArtist) {
      await state.selectArtistByName(album.artistName);
    }
    if (selection == _AlbumAction.favorite) {
      if (!context.mounted) {
        return;
      }
      await runWithSnack(
        context,
        () => state.setAlbumFavorite(album, !isFavorite),
      );
    }
    if (selection == _AlbumAction.makeAvailableOffline) {
      await state.makeAlbumAvailableOffline(album);
    }
    if (selection == _AlbumAction.unpinOffline) {
      await state.unpinAlbumOffline(album);
    }
  }
}

enum _AlbumAction {
  play,
  open,
  favorite,
  makeAvailableOffline,
  unpinOffline,
  goToArtist
}

bool _canLinkArtist(Album album) {
  final artist = album.artistName;
  return artist.isNotEmpty && artist != 'Unknown Artist';
}
