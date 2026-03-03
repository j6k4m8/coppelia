import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/download_task.dart';
import '../../models/playlist.dart';
import '../../models/media_item.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../state/track_list_style.dart';
import '../../core/color_tokens.dart';
import 'app_snack.dart';
import 'collection_header.dart';
import 'playlist_dialogs.dart';
import 'track_list_item.dart';
import 'track_table_header.dart';

class PlaylistOfflineActionState {
  const PlaylistOfflineActionState({
    required this.canDownload,
    required this.isOfflineReady,
    required this.isOfflinePending,
    required this.hasFailedDownloads,
    required this.label,
    required this.tooltip,
    required this.icon,
  });

  final bool canDownload;
  final bool isOfflineReady;
  final bool isOfflinePending;
  final bool hasFailedDownloads;
  final String label;
  final String tooltip;
  final IconData icon;
}

PlaylistOfflineActionState derivePlaylistOfflineActionState({
  required List<MediaItem> playlistTracks,
  required Set<String> pinnedAudio,
  required List<DownloadTask> downloadQueue,
}) {
  final playlistTrackUrls = playlistTracks.map((track) => track.streamUrl).toSet();
  final relatedDownloads = downloadQueue
      .where((task) => playlistTrackUrls.contains(task.track.streamUrl))
      .toList();
  final canDownload = playlistTracks.isNotEmpty;
  final allTracksPinned = canDownload &&
      playlistTracks.every((track) => pinnedAudio.contains(track.streamUrl));
  final isOfflineReady = allTracksPinned && relatedDownloads.isEmpty;
  final isOfflinePending = relatedDownloads.any(
    (task) => task.status != DownloadStatus.failed,
  );
  final hasFailedDownloads = relatedDownloads.any(
    (task) => task.status == DownloadStatus.failed,
  );
  final label = isOfflinePending
      ? 'Making Available Offline...'
      : isOfflineReady
          ? 'Remove from Offline'
          : hasFailedDownloads
              ? 'Retry Offline Download'
              : 'Make Available Offline';
  final tooltip = isOfflinePending
      ? 'Cancel Offline Request'
      : isOfflineReady
          ? 'Remove from Offline'
          : hasFailedDownloads
              ? 'Retry Offline Download'
              : 'Make Available Offline';
  final icon =
      isOfflineReady ? Icons.download_done_rounded : Icons.download_rounded;
  return PlaylistOfflineActionState(
    canDownload: canDownload,
    isOfflineReady: isOfflineReady,
    isOfflinePending: isOfflinePending,
    hasFailedDownloads: hasFailedDownloads,
    label: label,
    tooltip: tooltip,
    icon: icon,
  );
}

/// Playlist detail view with track listing.
class PlaylistDetailView extends StatefulWidget {
  /// Creates the playlist detail view.
  const PlaylistDetailView({super.key});

  @override
  State<PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends State<PlaylistDetailView> {
  String? _activePlaylistId;
  Set<String> _visibleColumns = {
    'title',
    'artist',
    'album',
    'duration',
    'favorite',
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final leftGutter = (32 * densityScale).clamp(16.0, 40.0).toDouble();
    final rightGutter = (24 * densityScale).clamp(12.0, 32.0).toDouble();
    final playlist = state.selectedPlaylist;
    if (playlist == null) {
      return const SizedBox.shrink();
    }
    if (playlist.id != _activePlaylistId) {
      _activePlaylistId = playlist.id;
    }
    final canEdit =
        state.session != null && !state.offlineMode && !state.offlineOnlyFilter;
    final pinned = state.pinnedAudio;
    final fullPlaylistTracks = state.playlistTracks;
    final offlineTracks = fullPlaylistTracks
        .where((track) => pinned.contains(track.streamUrl))
        .toList();
    final displayTracks =
        state.offlineOnlyFilter ? offlineTracks : fullPlaylistTracks;
    final offlineState = derivePlaylistOfflineActionState(
      playlistTracks: fullPlaylistTracks,
      pinnedAudio: pinned,
      downloadQueue: state.downloadQueue,
    );
    final offlineOnPressed = offlineState.canDownload
        ? () => (offlineState.isOfflineReady || offlineState.isOfflinePending)
            ? state.unpinPlaylistOffline(playlist)
            : state.makePlaylistAvailableOffline(playlist)
        : null;
    final canReorder = canEdit &&
        displayTracks.isNotEmpty &&
        displayTracks.every((track) => track.playlistItemId != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: canReorder
              ? ReorderableListView.builder(
                  itemCount: displayTracks.length +
                      (state.trackListStyle == TrackListStyle.table ? 2 : 1),
                  padding: EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0),
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) {
                    final headerCount =
                        state.trackListStyle == TrackListStyle.table ? 2 : 1;
                    if (oldIndex < headerCount || newIndex < headerCount) {
                      return;
                    }
                    final tracks = List<MediaItem>.from(displayTracks);
                    final oldTrackIndex = oldIndex - headerCount;
                    var newTrackIndex = newIndex - headerCount;
                    if (newTrackIndex > oldTrackIndex) {
                      newTrackIndex -= 1;
                    }
                    final moved = tracks.removeAt(oldTrackIndex);
                    tracks.insert(newTrackIndex, moved);
                    _handleReorder(context, playlist, tracks);
                  },
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        key: const ValueKey('playlist-header'),
                        padding: EdgeInsets.only(bottom: space(24)),
                        child: _PlaylistHeader(
                          playlist: playlist,
                          tracks: displayTracks,
                          canEdit: canEdit,
                          offlineLabel: offlineState.label,
                          offlineTooltip: offlineState.tooltip,
                          offlineIcon: offlineState.icon,
                          isOfflinePending: offlineState.isOfflinePending,
                          onOfflineAction: offlineOnPressed,
                          onRename: () => _handleRename(context, playlist),
                          onDelete: () => _handleDelete(context, playlist),
                        ),
                      );
                    }
                    if (state.trackListStyle == TrackListStyle.table &&
                        index == 1) {
                      return TrackTableHeader(
                        key: const ValueKey('playlist-table-header'),
                        onVisibleColumnsChanged: (columns) {
                          setState(() {
                            _visibleColumns = columns;
                          });
                        },
                      );
                    }
                    final headerCount =
                        state.trackListStyle == TrackListStyle.table ? 2 : 1;
                    final trackIndex = index - headerCount;
                    final track = displayTracks[trackIndex];
                    final handle = ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        Icons.drag_handle,
                        size: space(20).clamp(16.0, 22.0),
                        color: ColorTokens.textSecondary(context, 0.7),
                      ),
                    );
                    return Padding(
                      key: ValueKey(
                        'playlist-track-${track.playlistItemId ?? track.id}',
                      ),
                      padding: EdgeInsets.only(
                        bottom: space(6).clamp(4.0, 10.0),
                      ),
                      child: TrackListItem(
                        track: track,
                        index: trackIndex,
                        isActive: state.nowPlaying?.id == track.id,
                        onTap: () => state.playFromList(displayTracks, track),
                        onPlayNext: () => state.playNext(track),
                        onAddToQueue: () => state.enqueueTrack(track),
                        isFavorite: state.isFavoriteTrack(track.id),
                        isFavoriteUpdating:
                            state.isFavoriteTrackUpdating(track.id),
                        onToggleFavorite: () => state.setTrackFavorite(
                          track,
                          !state.isFavoriteTrack(track.id),
                        ),
                        onAlbumTap: track.albumId == null
                            ? null
                            : () => state.selectAlbumById(track.albumId!),
                        onArtistTap: track.artistIds.isEmpty
                            ? null
                            : () => state.selectArtistById(
                                  track.artistIds.first,
                                ),
                        onGoToAlbum: track.albumId == null
                            ? null
                            : () => state.selectAlbumById(track.albumId!),
                        onGoToArtist: track.artistIds.isEmpty
                            ? null
                            : () => state.selectArtistById(
                                  track.artistIds.first,
                                ),
                        onRemoveFromPlaylist: () =>
                            state.removeTrackFromPlaylist(track, playlist),
                        leading: handle,
                        visibleColumns: _visibleColumns,
                      ),
                    );
                  },
                )
              : ListView.separated(
                  itemCount: displayTracks.length +
                      (state.trackListStyle == TrackListStyle.table ? 2 : 1),
                  padding: EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0),
                  separatorBuilder: (_, index) {
                    return SizedBox(
                      height:
                          index == 0 ? space(24) : space(6).clamp(4.0, 10.0),
                    );
                  },
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _PlaylistHeader(
                        playlist: playlist,
                        tracks: displayTracks,
                        canEdit: canEdit,
                        offlineLabel: offlineState.label,
                        offlineTooltip: offlineState.tooltip,
                        offlineIcon: offlineState.icon,
                        isOfflinePending: offlineState.isOfflinePending,
                        onOfflineAction: offlineOnPressed,
                        onRename: () => _handleRename(context, playlist),
                        onDelete: () => _handleDelete(context, playlist),
                      );
                    }
                    if (state.trackListStyle == TrackListStyle.table &&
                        index == 1) {
                      return TrackTableHeader(
                        key: const ValueKey('playlist-table-header'),
                        onVisibleColumnsChanged: (columns) {
                          setState(() {
                            _visibleColumns = columns;
                          });
                        },
                      );
                    }
                    final headerCount =
                        state.trackListStyle == TrackListStyle.table ? 2 : 1;
                    final trackIndex = index - headerCount;
                    final track = displayTracks[trackIndex];
                    return TrackListItem(
                      track: track,
                      index: trackIndex,
                      isActive: state.nowPlaying?.id == track.id,
                      onTap: () => state.playFromList(displayTracks, track),
                      onPlayNext: () => state.playNext(track),
                      onAddToQueue: () => state.enqueueTrack(track),
                      isFavorite: state.isFavoriteTrack(track.id),
                      isFavoriteUpdating:
                          state.isFavoriteTrackUpdating(track.id),
                      onToggleFavorite: () => state.setTrackFavorite(
                        track,
                        !state.isFavoriteTrack(track.id),
                      ),
                      onAlbumTap: track.albumId == null
                          ? null
                          : () => state.selectAlbumById(track.albumId!),
                      onArtistTap: track.artistIds.isEmpty
                          ? null
                          : () => state.selectArtistById(track.artistIds.first),
                      onGoToAlbum: track.albumId == null
                          ? null
                          : () => state.selectAlbumById(track.albumId!),
                      onGoToArtist: track.artistIds.isEmpty
                          ? null
                          : () => state.selectArtistById(
                                track.artistIds.first,
                              ),
                      onRemoveFromPlaylist: () =>
                          state.removeTrackFromPlaylist(track, playlist),
                      visibleColumns: _visibleColumns,
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _handleReorder(
    BuildContext context,
    Playlist playlist,
    List<MediaItem> tracks,
  ) {
    unawaited(() async {
      await runWithSnack(
        context,
        () => context.read<AppState>().reorderPlaylistTracks(playlist, tracks),
      );
    }());
  }

  Future<void> _handleRename(BuildContext context, Playlist playlist) async {
    final name = await promptPlaylistName(
      context,
      title: 'Rename playlist',
      initialName: playlist.name,
      confirmLabel: 'Rename',
    );
    if (!context.mounted) {
      return;
    }
    if (name == null) {
      return;
    }
    await runWithSnack(
      context,
      () => context.read<AppState>().renamePlaylist(playlist, name),
    );
  }

  Future<void> _handleDelete(BuildContext context, Playlist playlist) async {
    final confirmed = await confirmPlaylistDelete(context, playlist);
    if (!context.mounted) {
      return;
    }
    if (!confirmed) {
      return;
    }
    await runWithSnack(
      context,
      () => context.read<AppState>().deletePlaylist(playlist),
    );
  }
}

class _PlaylistHeader extends StatelessWidget {
  const _PlaylistHeader({
    required this.playlist,
    required this.tracks,
    required this.canEdit,
    required this.offlineLabel,
    required this.offlineTooltip,
    required this.offlineIcon,
    required this.isOfflinePending,
    required this.onOfflineAction,
    required this.onRename,
    required this.onDelete,
  });

  final Playlist playlist;
  final List<MediaItem> tracks;
  final bool canEdit;
  final String offlineLabel;
  final String offlineTooltip;
  final IconData offlineIcon;
  final bool isOfflinePending;
  final VoidCallback? onOfflineAction;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final overflowKey = GlobalKey();
    final actionSpecs = <HeaderActionSpec>[
      HeaderActionSpec(
        icon: Icons.play_arrow,
        label: 'Play',
        tooltip: 'Play',
        onPressed: tracks.isEmpty
            ? null
            : () => state.playFromList(tracks, tracks.first),
      ),
      if (tracks.isNotEmpty)
        HeaderActionSpec(
          icon: Icons.shuffle,
          label: 'Shuffle',
          tooltip: 'Shuffle',
          tonal: true,
          onPressed: () => state.playShuffledList(tracks),
        ),
      HeaderActionSpec(
        icon: offlineIcon,
        label: offlineLabel,
        tooltip: offlineTooltip,
        isLoading: isOfflinePending,
        outlined: true,
        onPressed: onOfflineAction,
      ),
      if (canEdit)
        HeaderActionSpec(
          icon: Icons.more_horiz,
          label: 'Playlist options',
          tooltip: 'Playlist options',
          iconKey: overflowKey,
          menuItems: const [
            PopupMenuItem(
              value: _PlaylistHeaderAction.rename,
              child: Text('Rename'),
            ),
            PopupMenuItem(
              value: _PlaylistHeaderAction.delete,
              child: Text('Delete'),
            ),
          ],
          onMenuSelected: (value) {
            if (value == _PlaylistHeaderAction.rename) {
              onRename?.call();
            } else if (value == _PlaylistHeaderAction.delete) {
              onDelete?.call();
            }
          },
          onPressed: () {
            // Icon-only mode: manually anchor the menu to the overflow icon.
            final box =
                overflowKey.currentContext?.findRenderObject() as RenderBox?;
            final overlay =
                Overlay.of(context).context.findRenderObject() as RenderBox;
            const menuDx = -8.0;
            const menuDy = 6.0;
            final position = box != null
                ? RelativeRect.fromRect(
                    Rect.fromPoints(
                      box.localToGlobal(
                        const Offset(menuDx, menuDy),
                        ancestor: overlay,
                      ),
                      box.localToGlobal(
                        box.size.bottomRight(Offset.zero),
                        ancestor: overlay,
                      ),
                    ),
                    Offset.zero & overlay.size,
                  )
                : const RelativeRect.fromLTRB(100, 100, 0, 0);

            showMenu<_PlaylistHeaderAction>(
              context: context,
              position: position,
              items: const [
                PopupMenuItem(
                  value: _PlaylistHeaderAction.rename,
                  child: Text('Rename'),
                ),
                PopupMenuItem(
                  value: _PlaylistHeaderAction.delete,
                  child: Text('Delete'),
                ),
              ],
            ).then((value) {
              if (value == null) return;
              if (value == _PlaylistHeaderAction.rename) {
                onRename?.call();
              } else if (value == _PlaylistHeaderAction.delete) {
                onDelete?.call();
              }
            });
          },
        ),
    ];
    return CollectionHeader(
      title: playlist.name,
      subtitle: '${playlist.trackCount} tracks',
      imageUrl: playlist.imageUrl,
      fallbackIcon: Icons.queue_music,
      actionSpecs: actionSpecs,
      actions: const [],
      onBack: state.goBack,
      onSearch: state.requestSearchFocus,
    );
  }
}

enum _PlaylistHeaderAction {
  rename,
  delete,
}
