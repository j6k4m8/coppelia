import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../core/formatters.dart';
import '../../models/media_item.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'app_snack.dart';
import 'artwork_fallback.dart';
import 'artwork_image.dart';
import 'corner_radius.dart';
import 'context_menu.dart';
import 'playlist_dialogs.dart';

/// Row for a track listing.
class TrackRow extends StatelessWidget {
  /// Creates a track row.
  const TrackRow({
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
  });

  /// Track metadata.
  final MediaItem track;

  /// Display order number.
  final int index;

  /// Play handler.
  final VoidCallback onTap;

  /// Indicates if this track is playing.
  final bool isActive;

  /// Optional handler to play the track next.
  final VoidCallback? onPlayNext;

  /// Optional handler to add the track to the queue.
  final VoidCallback? onAddToQueue;

  /// Optional handler to toggle favorite state.
  final Future<String?> Function()? onToggleFavorite;

  /// Indicates if this track is favorited.
  final bool isFavorite;

  /// Indicates if the favorite state is updating.
  final bool isFavoriteUpdating;

  /// Optional handler to navigate to the album.
  final VoidCallback? onAlbumTap;

  /// Optional handler to navigate to the artist.
  final VoidCallback? onArtistTap;

  /// Optional handler for context menu navigation to album.
  final VoidCallback? onGoToAlbum;

  /// Optional handler for context menu navigation to artist.
  final VoidCallback? onGoToArtist;

  /// Optional handler to remove this track from a playlist.
  final Future<String?> Function()? onRemoveFromPlaylist;

  /// Whether to enable the context menu interactions.
  final bool enableContextMenu;

  /// Optional leading widget to show before the track index.
  final Widget? leading;

  /// Optional trailing widget to display at the end of the row.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isActive = this.isActive;
    final density =
        context.select((AppState state) => state.layoutDensity);
    final densityScale = density.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    final verticalPadding = density == LayoutDensity.sardine
        ? space(6).clamp(2.0, 8.0)
        : space(10).clamp(4.0, 14.0);
    final metaGap = density == LayoutDensity.sardine
        ? space(1).clamp(0.0, 2.0)
        : space(2).clamp(1.0, 4.0);
    final useSingleTap = !kIsWeb &&
        (Platform.isIOS || Platform.isAndroid || Platform.isFuchsia);
    final baseColor =
        isActive ? ColorTokens.activeRow(context) : Colors.transparent;
    final rowRadius =
        context.scaledRadius(clamped(14, min: 6, max: 16));
    final artSize = clamped(44, min: 24, max: 56);
    final artRadius =
        context.scaledRadius(clamped(10, min: 4, max: 12));
    final indexWidth = clamped(32, min: 16, max: 36);
    Widget buildArtworkFallback() => ArtworkFallback(
          width: artSize,
          height: artSize,
          icon: Icons.music_note,
          iconSize: clamped(18, min: 14, max: 20),
        );
    return Material(
      color: baseColor,
      borderRadius: BorderRadius.circular(rowRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(rowRadius),
        onTap: useSingleTap ? onTap : null,
        onDoubleTap: useSingleTap ? null : onTap,
        onLongPress: enableContextMenu
            ? () async {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) {
                  return;
                }
                final position =
                    box.localToGlobal(box.size.center(Offset.zero));
                await _showMenu(context, position);
              }
            : null,
        onSecondaryTapDown: enableContextMenu
            ? (details) => _showMenu(context, details.globalPosition)
            : null,
        hoverColor: ColorTokens.hoverRow(context),
        splashColor: ColorTokens.hoverRow(context),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: space(16),
            vertical: verticalPadding,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: space(8).clamp(4.0, 12.0)),
              ],
              SizedBox(
                width: indexWidth,
                child: Text(
                  '${index + 1}'.padLeft(2, '0'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColorTokens.textSecondary(context),
                      ),
                ),
              ),
              SizedBox(width: space(12).clamp(6.0, 16.0)),
              ClipRRect(
                borderRadius: BorderRadius.circular(artRadius),
                child: track.imageUrl == null
                    ? buildArtworkFallback()
                    : ArtworkImage(
                        imageUrl: track.imageUrl,
                        width: artSize,
                        height: artSize,
                        fit: BoxFit.cover,
                        placeholder: buildArtworkFallback(),
                      ),
              ),
              SizedBox(width: space(14).clamp(8.0, 18.0)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    SizedBox(height: metaGap),
                    _TrackMetaRow(
                      artistLabel: track.artists.isNotEmpty
                          ? track.artists.join(', ')
                          : 'Unknown Artist',
                      albumLabel: track.album,
                      onArtistTap: onArtistTap,
                      onAlbumTap: onAlbumTap,
                    ),
                  ],
                ),
              ),
              SizedBox(width: space(12).clamp(6.0, 16.0)),
              if (isFavoriteUpdating) ...[
                SizedBox(
                  width: clamped(14, min: 12, max: 16),
                  height: clamped(14, min: 12, max: 16),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(width: space(8).clamp(4.0, 10.0)),
              ] else if (isFavorite) ...[
                Icon(
                  Icons.favorite,
                  size: clamped(14, min: 12, max: 16),
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: space(8).clamp(4.0, 10.0)),
              ],
              Text(
                formatDuration(track.duration),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColorTokens.textSecondary(context),
                    ),
              ),
              if (trailing != null) ...[
                SizedBox(width: space(10).clamp(4.0, 14.0)),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, Offset position) async {
    final state = context.read<AppState>();
    final canManagePlaylists =
        state.session != null && !state.offlineMode;
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
        await runWithSnack(context, () => onToggleFavorite!.call());
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
        await runWithSnack(context, () => onRemoveFromPlaylist!.call());
      }
    } else if (action == _TrackMenuAction.goToAlbum) {
      onGoToAlbum?.call();
    } else if (action == _TrackMenuAction.goToArtist) {
      onGoToArtist?.call();
    }
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

class _TrackMetaRow extends StatelessWidget {
  const _TrackMetaRow({
    required this.artistLabel,
    required this.albumLabel,
    this.onArtistTap,
    this.onAlbumTap,
  });

  final String artistLabel;
  final String albumLabel;
  final VoidCallback? onArtistTap;
  final VoidCallback? onAlbumTap;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: ColorTokens.textSecondary(context, 0.55),
        );
    final linkStyle = baseStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
    );
    return Row(
      children: [
        Flexible(
          child: MouseRegion(
            cursor: onArtistTap == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onArtistTap,
              child: Text(
                artistLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: onArtistTap == null ? baseStyle : linkStyle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '•',
          style: TextStyle(
            color: ColorTokens.textSecondary(context, 0.4),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: MouseRegion(
            cursor: onAlbumTap == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAlbumTap,
              child: Text(
                albumLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: onAlbumTap == null ? baseStyle : linkStyle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
