import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/artist.dart';
import '../../state/library_view.dart';
import 'artist_context_menu.dart';
import 'library_browse_view.dart';
import 'library_card.dart';
import 'library_list_tile.dart';

/// Shared browse view for artist collections.
class ArtistBrowseView extends StatelessWidget {
  const ArtistBrowseView({
    super.key,
    required this.view,
    required this.title,
    required this.artists,
    required this.onSelect,
    required this.onContextMenu,
  });

  final LibraryView view;
  final String title;
  final List<Artist> artists;
  final ValueChanged<Artist> onSelect;
  final void Function(BuildContext context, Offset position, Artist artist)
      onContextMenu;

  @override
  Widget build(BuildContext context) {
    return LibraryBrowseView<Artist>(
      view: view,
      title: title,
      items: artists,
      titleBuilder: (artist) => artist.name,
      subtitleBuilder: (artist) => formatArtistSubtitle(artist),
      gridItemBuilder: (context, artist) {
        final subtitle = formatArtistSubtitle(artist);
        return LibraryCard(
          title: artist.name,
          subtitle: subtitle,
          imageUrl: artist.imageUrl,
          icon: Icons.people_alt,
          onTap: () => onSelect(artist),
          onContextMenu: (position) =>
              onContextMenu(context, position, artist),
        );
      },
      listItemBuilder: (context, artist) {
        final subtitle = formatArtistSubtitle(artist);
        return LibraryListTile(
          title: artist.name,
          subtitle: subtitle,
          imageUrl: artist.imageUrl,
          icon: Icons.people_alt,
          onTap: () => onSelect(artist),
          onContextMenu: (position) =>
              onContextMenu(context, position, artist),
        );
      },
    );
  }
}
