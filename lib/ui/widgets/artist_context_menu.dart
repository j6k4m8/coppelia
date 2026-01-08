import 'package:flutter/material.dart';

import '../../models/artist.dart';
import '../../state/app_state.dart';
import 'app_snack.dart';
import 'context_menu.dart';

enum _ArtistAction { play, open, favorite, makeAvailableOffline, unpinOffline }

Future<void> showArtistContextMenu(
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
  if (!context.mounted) {
    return;
  }
  if (selection == _ArtistAction.play) {
    await state.playArtist(artist);
  }
  if (selection == _ArtistAction.open) {
    await state.selectArtist(artist);
  }
  if (selection == _ArtistAction.favorite) {
    if (!context.mounted) {
      return;
    }
    await runWithSnack(
      context,
      () => state.setArtistFavorite(artist, !isFavorite),
    );
  }
  if (selection == _ArtistAction.makeAvailableOffline) {
    await state.makeArtistAvailableOffline(artist);
  }
  if (selection == _ArtistAction.unpinOffline) {
    await state.unpinArtistOffline(artist);
  }
}
