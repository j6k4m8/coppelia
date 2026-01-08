import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/album.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import 'album_context_menu.dart';
import 'album_browse_view.dart';

/// Displays album browsing grid.
class AlbumsView extends StatelessWidget {
  /// Creates the albums view.
  const AlbumsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return AlbumBrowseView(
      view: LibraryView.albums,
      title: 'Albums',
      albums: state.albums,
      onSelect: state.selectAlbum,
      onSelectArtist: (album) =>
          state.selectArtistByName(album.artistName),
      onContextMenu: (context, position, album) =>
          showAlbumContextMenu(context, position, album, state),
    );
  }
}
