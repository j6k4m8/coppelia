import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/artist.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import 'context_menu.dart';
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
      subtitleBuilder: (artist) => artist.albumCount > 0
          ? '${artist.albumCount} albums'
          : '${artist.trackCount} tracks',
      gridItemBuilder: (context, artist) {
        final subtitle = artist.albumCount > 0
            ? '${artist.albumCount} albums'
            : '${artist.trackCount} tracks';
        return LibraryCard(
          title: artist.name,
          subtitle: subtitle,
          imageUrl: artist.imageUrl,
          icon: Icons.people_alt,
          onTap: () => state.selectArtist(artist),
          onContextMenu: (position) => _showArtistMenu(
            context,
            position,
            artist,
            state,
          ),
        );
      },
      listItemBuilder: (context, artist) {
        final subtitle = artist.albumCount > 0
            ? '${artist.albumCount} albums'
            : '${artist.trackCount} tracks';
        return LibraryListTile(
          title: artist.name,
          subtitle: subtitle,
          imageUrl: artist.imageUrl,
          icon: Icons.people_alt,
          onTap: () => state.selectArtist(artist),
          onContextMenu: (position) => _showArtistMenu(
            context,
            position,
            artist,
            state,
          ),
        );
      },
    );
  }

  Future<void> _showArtistMenu(
    BuildContext context,
    Offset position,
    Artist artist,
    AppState state,
  ) async {
    final isFavorite = state.isFavoriteArtist(artist.id);
    final selection = await showContextMenu<_ArtistAction>(
      context,
      position,
      [
        const PopupMenuItem(
          value: _ArtistAction.play,
          child: Text('Play'),
        ),
        const PopupMenuItem(
          value: _ArtistAction.open,
          child: Text('Open'),
        ),
        PopupMenuItem(
          value: _ArtistAction.favorite,
          child: Text(isFavorite ? 'Unfavorite' : 'Favorite'),
        ),
      ],
    );
    if (selection == _ArtistAction.play) {
      await state.playArtist(artist);
    }
    if (selection == _ArtistAction.open) {
      await state.selectArtist(artist);
    }
    if (selection == _ArtistAction.favorite) {
      await state.setArtistFavorite(artist, !isFavorite);
    }
  }
}

enum _ArtistAction { play, open, favorite }
