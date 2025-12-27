import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/genre.dart';
import '../../state/app_state.dart';
import 'context_menu.dart';
import 'library_card.dart';
import 'section_header.dart';

/// Displays genre browsing grid.
class GenresView extends StatelessWidget {
  /// Creates the genres view.
  const GenresView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Genres',
          action: Text(
            '${state.genres.length} genres',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white60),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = (constraints.maxWidth / 220).floor();
              final columns = crossAxisCount.clamp(2, 5);
              return GridView.builder(
                itemCount: state.genres.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (context, index) {
                  final genre = state.genres[index];
                  return LibraryCard(
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
                  );
                },
              );
            },
          ),
        ),
      ],
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
