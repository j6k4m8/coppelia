import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/color_tokens.dart';
import '../../core/formatters.dart';
import '../../models/media_item.dart';
import 'track_context_menu.dart';

/// Table-style row for track listings.
class TrackTableRow extends StatelessWidget {
  /// Creates a track table row.
  const TrackTableRow({
    super.key,
    required this.track,
    required this.index,
    required this.onTap,
    this.isActive = false,
    this.visibleColumns = const {
      'title',
      'artist',
      'album',
      'duration',
      'favorite'
    },
    this.isFavorite = false,
    this.onToggleFavorite,
    this.onAlbumTap,
    this.onArtistTap,
    this.onPlayNext,
    this.onAddToQueue,
    this.onGoToAlbum,
    this.onGoToArtist,
    this.onRemoveFromPlaylist,
  });

  final MediaItem track;
  final int index;
  final VoidCallback onTap;
  final bool isActive;
  final Set<String> visibleColumns;
  final bool isFavorite;
  final Future<String?> Function()? onToggleFavorite;
  final VoidCallback? onAlbumTap;
  final VoidCallback? onArtistTap;
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onGoToAlbum;
  final VoidCallback? onGoToArtist;
  final Future<String?> Function()? onRemoveFromPlaylist;

  @override
  Widget build(BuildContext context) {
    final useSingleTap =
        !kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isFuchsia);

    final textColor = isActive
        ? Theme.of(context).colorScheme.primary
        : ColorTokens.textPrimary(context);

    final secondaryColor = isActive
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)
        : ColorTokens.textSecondary(context);

    return Material(
      color: isActive
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      child: InkWell(
        onTap: useSingleTap ? onTap : null,
        onDoubleTap: useSingleTap ? null : onTap,
        onLongPress: () async {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final position = box.localToGlobal(box.size.center(Offset.zero));
          await showTrackContextMenu(
            context: context,
            position: position,
            track: track,
            onTap: onTap,
            onPlayNext: onPlayNext,
            onAddToQueue: onAddToQueue,
            onToggleFavorite: onToggleFavorite,
            isFavorite: isFavorite,
            onGoToAlbum: onGoToAlbum,
            onGoToArtist: onGoToArtist,
            onRemoveFromPlaylist: onRemoveFromPlaylist,
          );
        },
        onSecondaryTapDown: (details) async {
          await showTrackContextMenu(
            context: context,
            position: details.globalPosition,
            track: track,
            onTap: onTap,
            onPlayNext: onPlayNext,
            onAddToQueue: onAddToQueue,
            onToggleFavorite: onToggleFavorite,
            isFavorite: isFavorite,
            onGoToAlbum: onGoToAlbum,
            onGoToArtist: onGoToArtist,
            onRemoveFromPlaylist: onRemoveFromPlaylist,
          );
        },
        hoverColor: ColorTokens.hoverRow(context),
        splashColor: ColorTokens.hoverRow(context),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Index
              SizedBox(
                width: 40,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Title
              if (visibleColumns.contains('title'))
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      track.title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              if (visibleColumns.contains('title')) const SizedBox(width: 16),
              // Artist
              if (visibleColumns.contains('artist'))
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: onArtistTap,
                    child: MouseRegion(
                      cursor: onArtistTap != null
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.basic,
                      child: Text(
                        track.artists.join(', '),
                        style: TextStyle(
                          color: onArtistTap != null
                              ? Theme.of(context).colorScheme.primary
                              : secondaryColor,
                          fontSize: 13,
                          fontWeight: onArtistTap != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              if (visibleColumns.contains('artist')) const SizedBox(width: 16),
              // Album
              if (visibleColumns.contains('album'))
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: onAlbumTap,
                    child: MouseRegion(
                      cursor: onAlbumTap != null
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.basic,
                      child: Text(
                        track.album,
                        style: TextStyle(
                          color: onAlbumTap != null
                              ? Theme.of(context).colorScheme.primary
                              : secondaryColor,
                          fontSize: 13,
                          fontWeight: onAlbumTap != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              if (visibleColumns.contains('album')) const SizedBox(width: 16),
              // Genre
              if (visibleColumns.contains('genre'))
                Expanded(
                  flex: 2,
                  child: Text(
                    track.genres.join(', '),
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (visibleColumns.contains('genre')) const SizedBox(width: 16),
              // Play count
              if (visibleColumns.contains('playCount'))
                SizedBox(
                  width: 80,
                  child: Text(
                    track.playCount?.toString() ?? '—',
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              if (visibleColumns.contains('playCount'))
                const SizedBox(width: 16),
              // BPM
              if (visibleColumns.contains('bpm'))
                SizedBox(
                  width: 70,
                  child: Text(
                    track.bpm?.toString() ?? '—',
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              if (visibleColumns.contains('bpm')) const SizedBox(width: 16),
              // Duration
              if (visibleColumns.contains('duration'))
                SizedBox(
                  width: 80,
                  child: Text(
                    formatDuration(track.duration),
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              if (visibleColumns.contains('duration'))
                const SizedBox(width: 16),
              // Favorite toggle
              if (visibleColumns.contains('favorite'))
                SizedBox(
                  width: 50,
                  child: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: isFavorite
                          ? Theme.of(context).colorScheme.primary
                          : secondaryColor,
                    ),
                    onPressed: onToggleFavorite,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
