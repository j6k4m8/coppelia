import 'package:flutter/material.dart';

import '../../core/color_tokens.dart';
import '../../core/formatters.dart';
import '../../models/media_item.dart';
import 'artwork_image.dart';
import 'context_menu.dart';

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
    this.onAlbumTap,
    this.onArtistTap,
    this.onGoToAlbum,
    this.onGoToArtist,
  });

  /// Track metadata.
  final MediaItem track;

  /// Display order number.
  final int index;

  /// Double-tap handler.
  final VoidCallback onTap;

  /// Indicates if this track is playing.
  final bool isActive;

  /// Optional handler to play the track next.
  final VoidCallback? onPlayNext;

  /// Optional handler to add the track to the queue.
  final VoidCallback? onAddToQueue;

  /// Optional handler to navigate to the album.
  final VoidCallback? onAlbumTap;

  /// Optional handler to navigate to the artist.
  final VoidCallback? onArtistTap;

  /// Optional handler for context menu navigation to album.
  final VoidCallback? onGoToAlbum;

  /// Optional handler for context menu navigation to artist.
  final VoidCallback? onGoToArtist;

  @override
  Widget build(BuildContext context) {
    final isActive = this.isActive;
    final baseColor =
        isActive ? ColorTokens.activeRow(context) : Colors.transparent;
    Widget buildArtworkFallback() => Container(
          width: 44,
          height: 44,
          color: ColorTokens.cardFillStrong(context),
          child: const Icon(Icons.music_note, size: 18),
        );
    return Material(
      color: baseColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {},
        onDoubleTap: onTap,
        onSecondaryTapDown: (details) =>
            _showMenu(context, details.globalPosition),
        hoverColor: ColorTokens.hoverRow(context),
        splashColor: ColorTokens.hoverRow(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '${index + 1}'.padLeft(2, '0'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColorTokens.textSecondary(context),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: track.imageUrl == null
                    ? buildArtworkFallback()
                    : ArtworkImage(
                        imageUrl: track.imageUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        placeholder: buildArtworkFallback(),
                      ),
              ),
              const SizedBox(width: 14),
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
                    const SizedBox(height: 2),
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
              const SizedBox(width: 12),
              Text(
                formatDuration(track.duration),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColorTokens.textSecondary(context),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, Offset position) async {
    if (onPlayNext == null &&
        onAddToQueue == null &&
        onGoToAlbum == null &&
        onGoToArtist == null) {
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
    if (action == _TrackMenuAction.play) {
      onTap();
    } else if (action == _TrackMenuAction.playNext) {
      onPlayNext?.call();
    } else if (action == _TrackMenuAction.addToQueue) {
      onAddToQueue?.call();
    } else if (action == _TrackMenuAction.goToAlbum) {
      onGoToAlbum?.call();
    } else if (action == _TrackMenuAction.goToArtist) {
      onGoToArtist?.call();
    }
  }
}

enum _TrackMenuAction { play, playNext, addToQueue, goToAlbum, goToArtist }

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
