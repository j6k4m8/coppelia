import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../state/app_state.dart';
import '../../state/track_list_style.dart';
import 'track_row.dart';
import 'track_table_row.dart';

/// Builds either a card or table track item based on user preference.
class TrackListItem extends StatelessWidget {
  const TrackListItem({
    super.key,
    required this.track,
    required this.index,
    required this.onTap,
    this.isActive = false,
    this.onPlayNext,
    this.onAddToQueue,
    this.onToggleFavorite,
    this.isFavorite = false,
    this.isFavoriteUpdating = false,
    this.onAlbumTap,
    this.onArtistTap,
    this.onGoToAlbum,
    this.onGoToArtist,
    this.onRemoveFromPlaylist,
    this.enableContextMenu = true,
    this.leading,
    this.trailing,
    this.visibleColumns,
  });

  final MediaItem track;
  final int index;
  final VoidCallback onTap;
  final bool isActive;
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;
  final Future<String?> Function()? onToggleFavorite;
  final bool isFavorite;
  final bool isFavoriteUpdating;
  final VoidCallback? onAlbumTap;
  final VoidCallback? onArtistTap;
  final VoidCallback? onGoToAlbum;
  final VoidCallback? onGoToArtist;
  final Future<String?> Function()? onRemoveFromPlaylist;
  final bool enableContextMenu;
  final Widget? leading;
  final Widget? trailing;
  final Set<String>? visibleColumns;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    
    if (state.trackListStyle == TrackListStyle.table) {
      return TrackTableRow(
        track: track,
        index: index,
        onTap: onTap,
        isActive: isActive,
        visibleColumns: visibleColumns ?? {'title', 'artist', 'album', 'duration', 'favorite'},
        isFavorite: isFavorite,
        onToggleFavorite: onToggleFavorite,
      );
    }
    
    return TrackRow(
      track: track,
      index: index,
      onTap: onTap,
      isActive: isActive,
      onPlayNext: onPlayNext,
      onAddToQueue: onAddToQueue,
      onToggleFavorite: onToggleFavorite,
      isFavorite: isFavorite,
      isFavoriteUpdating: isFavoriteUpdating,
      onAlbumTap: onAlbumTap,
      onArtistTap: onArtistTap,
      onGoToAlbum: onGoToAlbum,
      onGoToArtist: onGoToArtist,
      onRemoveFromPlaylist: onRemoveFromPlaylist,
      enableContextMenu: enableContextMenu,
      leading: leading,
      trailing: trailing,
    );
  }
}
