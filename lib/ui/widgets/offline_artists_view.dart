import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/artist.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import 'context_menu.dart';
import 'library_browse_view.dart';
import 'library_card.dart';
import 'library_list_tile.dart';
import 'offline_empty_view.dart';

/// Displays offline-ready artists.
class OfflineArtistsView extends StatelessWidget {
  /// Creates the offline artists view.
  const OfflineArtistsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return FutureBuilder<List<Artist>>(
      future: state.loadOfflineArtists(),
      builder: (context, snapshot) {
        final artists = snapshot.data ?? const <Artist>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            artists.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (artists.isEmpty) {
          return OfflineEmptyView(
            title: LibraryView.offlineArtists.title,
            subtitle: LibraryView.offlineArtists.subtitle,
          );
        }
        return LibraryBrowseView<Artist>(
          view: LibraryView.offlineArtists,
          title: LibraryView.offlineArtists.title,
          items: artists,
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
              onTap: () => state.selectArtist(artist, offlineOnly: true),
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
              onTap: () => state.selectArtist(artist, offlineOnly: true),
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
    );
  }

  Future<void> _showArtistMenu(
    BuildContext context,
    Offset position,
    Artist artist,
    AppState state,
  ) async {
    final isFavorite = state.isFavoriteArtist(artist.id);
    final isPinned = await state.isArtistPinned(artist);
    if (!context.mounted) {
      return;
    }
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
          child: isFavorite
              ? const Row(
                  children: [
                    Icon(Icons.favorite, size: 16),
                    SizedBox(width: 8),
                    Text('Unfavorite'),
                  ],
                )
              : const Text('Favorite'),
        ),
        PopupMenuItem(
          value: isPinned
              ? _ArtistAction.unpinOffline
              : _ArtistAction.makeAvailableOffline,
          child: isPinned
              ? const Row(
                  children: [
                    Icon(Icons.download_done_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Unpin from Offline'),
                  ],
                )
              : const Text('Make Available Offline'),
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
    if (selection == _ArtistAction.makeAvailableOffline) {
      await state.makeArtistAvailableOffline(artist);
    }
    if (selection == _ArtistAction.unpinOffline) {
      await state.unpinArtistOffline(artist);
    }
  }
}

enum _ArtistAction {
  play,
  open,
  favorite,
  makeAvailableOffline,
  unpinOffline,
}
