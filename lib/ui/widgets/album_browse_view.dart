import 'package:flutter/material.dart';

import '../../models/album.dart';
import '../../state/library_view.dart';
import 'album_context_menu.dart';
import 'library_browse_view.dart';
import 'library_card.dart';
import 'library_list_tile.dart';

/// Shared browse view for album collections.
class AlbumBrowseView extends StatelessWidget {
  const AlbumBrowseView({
    super.key,
    required this.view,
    required this.title,
    required this.albums,
    required this.onSelect,
    required this.onSelectArtist,
    required this.onContextMenu,
  });

  final LibraryView view;
  final String title;
  final List<Album> albums;
  final ValueChanged<Album> onSelect;
  final ValueChanged<Album> onSelectArtist;
  final void Function(BuildContext context, Offset position, Album album)
      onContextMenu;

  @override
  Widget build(BuildContext context) {
    return LibraryBrowseView<Album>(
      view: view,
      title: title,
      items: albums,
      titleBuilder: (album) => album.name,
      subtitleBuilder: (album) => album.artistName,
      gridItemBuilder: (context, album) => LibraryCard(
        title: album.name,
        subtitle: album.artistName,
        imageUrl: album.imageUrl,
        icon: Icons.album,
        onTap: () => onSelect(album),
        onSubtitleTap:
            canLinkArtist(album) ? () => onSelectArtist(album) : null,
        onContextMenu: (position) => onContextMenu(context, position, album),
      ),
      listItemBuilder: (context, album) => LibraryListTile(
        title: album.name,
        subtitle: album.artistName,
        imageUrl: album.imageUrl,
        icon: Icons.album,
        onTap: () => onSelect(album),
        onSubtitleTap:
            canLinkArtist(album) ? () => onSelectArtist(album) : null,
        onContextMenu: (position) => onContextMenu(context, position, album),
      ),
    );
  }
}
