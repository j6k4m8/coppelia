import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/artist.dart';
import '../../state/app_state.dart';
import 'context_menu.dart';
import 'library_card.dart';
import 'section_header.dart';

/// Displays favorited artists.
class FavoriteArtistsView extends StatelessWidget {
  /// Creates the favorite artists view.
  const FavoriteArtistsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Favorite Artists',
          action: Text(
            '${state.favoriteArtists.length} artists',
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
                itemCount: state.favoriteArtists.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (context, index) {
                  final artist = state.favoriteArtists[index];
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
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showArtistMenu(
    BuildContext context,
    Offset position,
    Artist artist,
    AppState state,
  ) async {
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
      ],
    );
    if (selection == _ArtistAction.play) {
      await state.playArtist(artist);
    }
    if (selection == _ArtistAction.open) {
      await state.selectArtist(artist);
    }
  }
}

enum _ArtistAction { play, open }
