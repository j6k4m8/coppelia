import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/library_view.dart';
import 'album_context_menu.dart';
import 'album_browse_view.dart';

/// Displays favorited albums.
class FavoriteAlbumsView extends StatelessWidget {
  /// Creates the favorite albums view.
  const FavoriteAlbumsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return AlbumBrowseView(
      view: LibraryView.favoritesAlbums,
      title: 'Favorite Albums',
      albums: state.favoriteAlbums,
      onSelect: state.selectAlbum,
      onSelectArtist: (album) =>
          state.selectArtistByName(album.artistName),
      onContextMenu: (context, position, album) =>
          showAlbumContextMenu(context, position, album, state),
    );
  }

}
