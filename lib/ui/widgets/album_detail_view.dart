import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../models/download_task.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'app_snack.dart';
import 'collection_detail_view.dart';
import 'collection_header.dart';

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
    final headerImageUrl = album.imageUrl ??
        (state.albumTracks.isNotEmpty
            ? state.albumTracks.first.imageUrl
            : null);
    final isFavorite = state.isFavoriteAlbum(album.id);
    final isFavoriteUpdating = state.isFavoriteAlbumUpdating(album.id);
    final canDownload = state.albumTracks.isNotEmpty;
    final pinned = state.pinnedAudio;
    final offlineTracks = state.albumTracks
        .where((track) => pinned.contains(track.streamUrl))
        .toList();
    final albumTrackUrls =
        state.albumTracks.map((track) => track.streamUrl).toSet();
    final relatedDownloads = state.downloadQueue
        .where((task) => albumTrackUrls.contains(task.track.streamUrl))
        .toList();
    final displayTracks =
        state.offlineOnlyFilter ? offlineTracks : state.albumTracks;
    final allTracksPinned = canDownload &&
        state.albumTracks.every((track) => pinned.contains(track.streamUrl));
    final isOfflineReady = allTracksPinned && relatedDownloads.isEmpty;
    final isOfflinePending = relatedDownloads.any(
      (task) => task.status != DownloadStatus.failed,
    );
    final hasFailedDownloads = relatedDownloads.any(
      (task) => task.status == DownloadStatus.failed,
    );

    final favoriteIcon = isFavorite ? Icons.favorite : Icons.favorite_border;
    final offlineLabel = isOfflinePending
        ? 'Making Available Offline...'
        : isOfflineReady
            ? 'Remove from Offline'
            : hasFailedDownloads
                ? 'Retry Offline Download'
                : 'Make Available Offline';
    final offlineTooltip = isOfflinePending
        ? 'Cancel Offline Request'
        : isOfflineReady
            ? 'Remove from Offline'
            : hasFailedDownloads
                ? 'Retry Offline Download'
                : 'Make Available Offline';
    final offlineIcon =
        isOfflineReady ? Icons.download_done_rounded : Icons.download_rounded;
    final offlineOnPressed = canDownload
        ? () => (isOfflineReady || isOfflinePending)
            ? state.unpinAlbumOffline(album)
            : state.makeAlbumAvailableOffline(album)
        : null;

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
      headerActionSpecs: [
        HeaderActionSpec(
          icon: favoriteIcon,
          label: isFavorite ? 'Unfavorite' : 'Favorite',
          tooltip: isFavorite ? 'Unfavorite' : 'Favorite',
          outlined: true,
          onPressed: isFavoriteUpdating
              ? null
              : () => runWithSnack(
                    context,
                    () => state.setAlbumFavorite(album, !isFavorite),
                  ),
        ),
        HeaderActionSpec(
          icon: offlineIcon,
          label: offlineLabel,
          tooltip: offlineTooltip,
          isLoading: isOfflinePending,
          outlined: true,
          onPressed: offlineOnPressed,
        ),
      ],
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
              : Icon(favoriteIcon),
          label: Text(isFavorite ? 'Unfavorite' : 'Favorite'),
        ),
        OutlinedButton.icon(
          onPressed: offlineOnPressed,
          icon: isOfflinePending
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : Icon(offlineIcon),
          label: Text(offlineLabel),
        ),
      ],
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
