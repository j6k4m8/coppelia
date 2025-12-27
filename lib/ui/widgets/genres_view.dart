import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/genre.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import 'context_menu.dart';
import 'library_browse_view.dart';
import 'library_card.dart';
import 'library_list_tile.dart';

/// Displays genre browsing grid.
class GenresView extends StatelessWidget {
  /// Creates the genres view.
  const GenresView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return LibraryBrowseView<Genre>(
      view: LibraryView.genres,
      title: 'Genres',
      items: state.genres,
      titleBuilder: (genre) => genre.name,
      subtitleBuilder: (genre) => '${genre.trackCount} tracks',
      gridItemBuilder: (context, genre) => LibraryCard(
        title: genre.name,
        subtitle: '${genre.trackCount} tracks',
        imageUrl: genre.imageUrl,
        icon: Icons.auto_awesome_motion,
        onTap: () => state.selectGenre(genre),
        onContextMenu: (position) => _showGenreMenu(
          context,
          position,
          genre,
          state,
        ),
      ),
      listItemBuilder: (context, genre) => LibraryListTile(
        title: genre.name,
        subtitle: '${genre.trackCount} tracks',
        imageUrl: genre.imageUrl,
        icon: Icons.auto_awesome_motion,
        onTap: () => state.selectGenre(genre),
      ),
    );
  }

  Future<void> _showGenreMenu(
    BuildContext context,
    Offset position,
    Genre genre,
    AppState state,
  ) async {
    final selection = await showContextMenu<_GenreAction>(
      context,
      position,
      [
        const PopupMenuItem(
          value: _GenreAction.play,
          child: Text('Play'),
        ),
        const PopupMenuItem(
          value: _GenreAction.open,
          child: Text('Open'),
        ),
      ],
    );
    if (selection == _GenreAction.play) {
      await state.playGenre(genre);
    }
    if (selection == _GenreAction.open) {
      await state.selectGenre(genre);
    }
  }
}

enum _GenreAction { play, open }
