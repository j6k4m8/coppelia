import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../models/album.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'app_snack.dart';
import 'collection_detail_view.dart';
import 'section_header.dart';

/// Detail view for a single album.
class AlbumDetailView extends StatelessWidget {
  /// Creates the album detail view.
  const AlbumDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final album = state.selectedAlbum;
    if (album == null) {
      return const SizedBox.shrink();
    }
    final artistName = album.artistName;
    final canLinkArtist =
        artistName.isNotEmpty && artistName != 'Unknown Artist';
    final subtitle = '${album.trackCount} tracks • $artistName';
    final subtitleWidget = _AlbumSubtitle(
      trackCount: album.trackCount,
      artistName: artistName,
      onArtistTap:
          canLinkArtist ? () => state.selectArtistByName(artistName) : null,
    );
    final headerImageUrl =
        album.imageUrl ?? (state.albumTracks.isNotEmpty
            ? state.albumTracks.first.imageUrl
            : null);
    final isFavorite = state.isFavoriteAlbum(album.id);
    final isFavoriteUpdating = state.isFavoriteAlbumUpdating(album.id);
    final canDownload = state.albumTracks.isNotEmpty;
    final pinnedFuture = state.isAlbumPinned(album);
    final pinned = state.pinnedAudio;
    final offlineTracks = state.albumTracks
        .where((track) => pinned.contains(track.streamUrl))
        .toList();
    final displayTracks =
        state.offlineOnlyFilter ? offlineTracks : state.albumTracks;
    return CollectionDetailView(
      title: album.name,
      subtitle: subtitle,
      subtitleWidget: subtitleWidget,
      imageUrl: headerImageUrl,
      tracks: displayTracks,
      nowPlaying: state.nowPlaying,
      onPlayAll: displayTracks.isEmpty
          ? null
          : () => state.playFromList(displayTracks, displayTracks.first),
      onShuffle: displayTracks.isEmpty
          ? null
          : () => state.playShuffledList(displayTracks),
      onTrackTap: (track) => state.playFromList(displayTracks, track),
      onPlayNext: state.playNext,
      onAddToQueue: state.enqueueTrack,
      onAlbumTap: (track) {
        if (track.albumId != null) {
          state.selectAlbumById(track.albumId!);
        }
      },
      onArtistTap: (track) {
        if (track.artistIds.isNotEmpty) {
          state.selectArtistById(track.artistIds.first);
        }
      },
      headerFooter: canLinkArtist
          ? _ArtistInlineLink(
              artistName: artistName,
              onTap: () => state.selectArtistByName(artistName),
            )
          : null,
      headerActions: [
        OutlinedButton.icon(
          onPressed: isFavoriteUpdating
              ? null
              : () => runWithSnack(
                    context,
                    () => state.setAlbumFavorite(album, !isFavorite),
                  ),
          icon: isFavoriteUpdating
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          label: Text(isFavorite ? 'Unfavorite' : 'Favorite'),
        ),
        FutureBuilder<bool>(
          future: pinnedFuture,
          builder: (context, snapshot) {
            final isPinned = snapshot.data ?? false;
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            return OutlinedButton.icon(
              onPressed: canDownload && !isLoading
                  ? () => isPinned
                      ? state.unpinAlbumOffline(album)
                      : state.makeAlbumAvailableOffline(album)
                  : null,
              icon: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Icon(
                      isPinned
                          ? Icons.download_done_rounded
                          : Icons.download_rounded,
                    ),
              label: Text(
                isPinned ? 'Remove from Offline' : 'Make Available Offline',
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ArtistInlineLink extends StatelessWidget {
  const _ArtistInlineLink({
    required this.artistName,
    required this.onTap,
  });

  final String artistName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    return Padding(
      padding: EdgeInsets.only(top: 16 * densityScale),
      child: SectionHeader(
        title: 'Artist',
        action: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Text(
              artistName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumSubtitle extends StatelessWidget {
  const _AlbumSubtitle({
    required this.trackCount,
    required this.artistName,
    this.onArtistTap,
  });

  final int trackCount;
  final String artistName;
  final VoidCallback? onArtistTap;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final baseStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: ColorTokens.textSecondary(context));
    final linkStyle = baseStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    return Row(
      children: [
        Text(
          '$trackCount tracks',
          style: baseStyle,
        ),
        SizedBox(width: space(6).clamp(4.0, 10.0)),
        Text(
          '•',
          style: TextStyle(
            color: ColorTokens.textSecondary(context, 0.4),
          ),
        ),
        SizedBox(width: space(6).clamp(4.0, 10.0)),
        Flexible(
          child: onArtistTap == null
              ? Text(
                  artistName,
                  style: baseStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onArtistTap,
                    child: Text(
                      artistName,
                      style: linkStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
