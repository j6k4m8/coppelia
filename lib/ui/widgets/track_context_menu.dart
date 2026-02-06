import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../state/app_state.dart';
import 'app_snack.dart';
import 'context_menu.dart';
import 'playlist_dialogs.dart';

/// Shows the context menu for a track and handles the selected action.
Future<void> showTrackContextMenu({
  required BuildContext context,
  required Offset position,
  required MediaItem track,
  required VoidCallback onTap,
  VoidCallback? onPlayNext,
  VoidCallback? onAddToQueue,
  Future<String?> Function()? onToggleFavorite,
  bool isFavorite = false,
  VoidCallback? onGoToAlbum,
  VoidCallback? onGoToArtist,
  Future<String?> Function()? onRemoveFromPlaylist,
}) async {
  final state = context.read<AppState>();
  final canManagePlaylists = state.session != null && !state.offlineMode;
  final isPinned = await state.isTrackPinned(track);
  if (!context.mounted) {
    return;
  }

  final items = <PopupMenuEntry<_TrackMenuAction>>[
    const PopupMenuItem(
      value: _TrackMenuAction.play,
      child: Text('Play'),
    ),
  ];

  if (onPlayNext != null) {
    items.add(
      const PopupMenuItem(
        value: _TrackMenuAction.playNext,
        child: Text('Play Next'),
      ),
    );
  }

  if (onAddToQueue != null) {
    items.add(
      const PopupMenuItem(
        value: _TrackMenuAction.addToQueue,
        child: Text('Add to Queue'),
      ),
    );
  }

  if (canManagePlaylists) {
    items.add(
      const PopupMenuItem(
        value: _TrackMenuAction.addToPlaylist,
        child: Text('Add to Playlist'),
      ),
    );
    if (onRemoveFromPlaylist != null) {
      items.add(
        const PopupMenuItem(
          value: _TrackMenuAction.removeFromPlaylist,
          child: Text('Remove from Playlist'),
        ),
      );
    }
  }

  if (onToggleFavorite != null) {
    items.add(
      PopupMenuItem(
        value: _TrackMenuAction.favorite,
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
    );
  }

  items.add(
    PopupMenuItem(
      value: isPinned
          ? _TrackMenuAction.unpinOffline
          : _TrackMenuAction.makeAvailableOffline,
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
  );

  if (onGoToAlbum != null) {
    items.add(
      const PopupMenuItem(
        value: _TrackMenuAction.goToAlbum,
        child: Text('Go to Album'),
      ),
    );
  }

  if (onGoToArtist != null) {
    items.add(
      const PopupMenuItem(
        value: _TrackMenuAction.goToArtist,
        child: Text('Go to Artist'),
      ),
    );
  }

  final action = await showContextMenu<_TrackMenuAction>(
    context,
    position,
    items,
  );

  if (!context.mounted) {
    return;
  }

  if (action == _TrackMenuAction.play) {
    onTap();
  } else if (action == _TrackMenuAction.playNext) {
    onPlayNext?.call();
  } else if (action == _TrackMenuAction.addToQueue) {
    onAddToQueue?.call();
  } else if (action == _TrackMenuAction.addToPlaylist) {
    final result = await showPlaylistPickerDialog(
      context,
      initialTracks: [track],
    );
    if (!context.mounted) {
      return;
    }
    if (result == null) {
      return;
    }
    if (!result.isNew) {
      if (!context.mounted) {
        return;
      }
      await runWithSnack(
        context,
        () => state.addTrackToPlaylist(track, result.playlist),
      );
    }
  } else if (action == _TrackMenuAction.favorite) {
    if (onToggleFavorite != null) {
      if (!context.mounted) {
        return;
      }
      await runWithSnack(context, () => onToggleFavorite.call());
    }
  } else if (action == _TrackMenuAction.makeAvailableOffline) {
    await state.makeTrackAvailableOffline(track);
  } else if (action == _TrackMenuAction.unpinOffline) {
    await state.unpinTrackOffline(track);
  } else if (action == _TrackMenuAction.removeFromPlaylist) {
    if (onRemoveFromPlaylist != null) {
      if (!context.mounted) {
        return;
      }
      await runWithSnack(context, () => onRemoveFromPlaylist.call());
    }
  } else if (action == _TrackMenuAction.goToAlbum) {
    onGoToAlbum?.call();
  } else if (action == _TrackMenuAction.goToArtist) {
    onGoToArtist?.call();
  }
}

enum _TrackMenuAction {
  play,
  playNext,
  addToQueue,
  addToPlaylist,
  favorite,
  makeAvailableOffline,
  unpinOffline,
  removeFromPlaylist,
  goToAlbum,
  goToArtist,
}
