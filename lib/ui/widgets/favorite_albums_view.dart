import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/album.dart';
import '../../state/app_state.dart';
import 'context_menu.dart';
import 'library_card.dart';
import 'section_header.dart';

/// Displays favorited albums.
class FavoriteAlbumsView extends StatelessWidget {
  /// Creates the favorite albums view.
  const FavoriteAlbumsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Favorite Albums',
          action: Text(
            '${state.favoriteAlbums.length} albums',
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
                itemCount: state.favoriteAlbums.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (context, index) {
                  final album = state.favoriteAlbums[index];
                  return LibraryCard(
                    title: album.name,
                    subtitle: album.artistName,
                    imageUrl: album.imageUrl,
                    icon: Icons.album,
                    onTap: () => state.selectAlbum(album),
                    onContextMenu: (position) => _showAlbumMenu(
                      context,
                      position,
                      album,
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

  Future<void> _showAlbumMenu(
    BuildContext context,
    Offset position,
    Album album,
    AppState state,
  ) async {
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
      ],
    );
    if (selection == _AlbumAction.play) {
      await state.playAlbum(album);
    }
    if (selection == _AlbumAction.open) {
      await state.selectAlbum(album);
    }
  }
}

enum _AlbumAction { play, open }
