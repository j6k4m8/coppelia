import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/artist.dart';
import '../../core/formatters.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import 'artist_context_menu.dart';
import 'library_browse_view.dart';
import 'library_card.dart';
import 'library_list_tile.dart';

/// Displays favorited artists.
class FavoriteArtistsView extends StatelessWidget {
  /// Creates the favorite artists view.
  const FavoriteArtistsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return LibraryBrowseView<Artist>(
      view: LibraryView.favoritesArtists,
      title: 'Favorite Artists',
      items: state.favoriteArtists,
      titleBuilder: (artist) => artist.name,
      subtitleBuilder: (artist) => formatArtistSubtitle(artist),
      gridItemBuilder: (context, artist) {
        final subtitle = formatArtistSubtitle(artist);
        return LibraryCard(
          title: artist.name,
          subtitle: subtitle,
          imageUrl: artist.imageUrl,
          icon: Icons.people_alt,
          onTap: () => state.selectArtist(artist),
          onContextMenu: (position) => showArtistContextMenu(
            context,
            position,
            artist,
            state,
          ),
        );
      },
      listItemBuilder: (context, artist) {
        final subtitle = formatArtistSubtitle(artist);
        return LibraryListTile(
          title: artist.name,
          subtitle: subtitle,
          imageUrl: artist.imageUrl,
          icon: Icons.people_alt,
          onTap: () => state.selectArtist(artist),
          onContextMenu: (position) => showArtistContextMenu(
            context,
            position,
            artist,
            state,
          ),
        );
      },
    );
  }
}

enum _ArtistAction {
  play,
  open,
  favorite,
  makeAvailableOffline,
  unpinOffline
}
