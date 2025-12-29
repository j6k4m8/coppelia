import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../models/media_item.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../core/color_tokens.dart';
import 'app_snack.dart';
import 'artwork_image.dart';
import 'playlist_dialogs.dart';
import 'track_row.dart';

/// Playlist detail view with track listing.
class PlaylistDetailView extends StatefulWidget {
  /// Creates the playlist detail view.
  const PlaylistDetailView({super.key});

  @override
  State<PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends State<PlaylistDetailView> {
  String? _activePlaylistId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final leftGutter =
        (32 * densityScale).clamp(16.0, 40.0).toDouble();
    final rightGutter =
        (24 * densityScale).clamp(12.0, 32.0).toDouble();
    final playlist = state.selectedPlaylist;
    if (playlist == null) {
      return const SizedBox.shrink();
    }
    if (playlist.id != _activePlaylistId) {
      _activePlaylistId = playlist.id;
    }
    final canEdit = state.session != null &&
        !state.offlineMode &&
        !state.offlineOnlyFilter;
    final pinned = state.pinnedAudio;
    final offlineTracks = state.playlistTracks
        .where((track) => pinned.contains(track.streamUrl))
        .toList();
    final displayTracks = state.offlineOnlyFilter
        ? offlineTracks
        : state.playlistTracks;
    final canReorder = canEdit &&
        displayTracks.isNotEmpty &&
        displayTracks.every((track) => track.playlistItemId != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: canReorder
              ? ReorderableListView.builder(
                  itemCount: displayTracks.length + 1,
                  padding:
                      EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0),
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex == 0 || newIndex == 0) {
                      return;
                    }
                    final tracks = List<MediaItem>.from(displayTracks);
                    final oldTrackIndex = oldIndex - 1;
                    var newTrackIndex = newIndex - 1;
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
                          offlineOnly: state.offlineOnlyFilter,
                          onToggleOfflineOnly: state.setOfflineOnlyFilter,
                          canEdit: canEdit,
                          canReorder: canReorder,
                          onRename: () => _handleRename(context, playlist),
                          onDelete: () => _handleDelete(context, playlist),
                        ),
                      );
                    }
                    final trackIndex = index - 1;
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
                      child: TrackRow(
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
                      ),
                    );
                  },
                )
              : ListView.separated(
                  itemCount: displayTracks.length + 1,
                  padding:
                      EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0),
                  separatorBuilder: (_, index) {
                    return SizedBox(
                      height: index == 0
                          ? space(24)
                          : space(6).clamp(4.0, 10.0),
                    );
                  },
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _PlaylistHeader(
                        playlist: playlist,
                        tracks: displayTracks,
                        offlineOnly: state.offlineOnlyFilter,
                        onToggleOfflineOnly: state.setOfflineOnlyFilter,
                        canEdit: canEdit,
                        canReorder: canReorder,
                        onRename: () => _handleRename(context, playlist),
                        onDelete: () => _handleDelete(context, playlist),
                      );
                    }
                    final trackIndex = index - 1;
                    final track = displayTracks[trackIndex];
                    return TrackRow(
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
                          : () =>
                              state.selectArtistById(track.artistIds.first),
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
        () => context
            .read<AppState>()
            .reorderPlaylistTracks(playlist, tracks),
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
    required this.offlineOnly,
    required this.onToggleOfflineOnly,
    required this.canEdit,
    required this.canReorder,
    required this.onRename,
    required this.onDelete,
  });

  final Playlist playlist;
  final List<MediaItem> tracks;
  final bool offlineOnly;
  final ValueChanged<bool> onToggleOfflineOnly;
  final bool canEdit;
  final bool canReorder;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    Widget buildArtworkFallback(bool isNarrow) => Container(
          width: clamped(isNarrow ? 160 : 140, min: 110, max: 190),
          height: clamped(isNarrow ? 160 : 140, min: 110, max: 190),
          color: ColorTokens.cardFillStrong(context),
          child: Icon(
            Icons.queue_music,
            size: clamped(36, min: 26, max: 42),
          ),
        );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(space(24).clamp(14.0, 32.0)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ColorTokens.heroGradient(context),
        ),
        borderRadius: BorderRadius.circular(
          clamped(26, min: 16, max: 30),
        ),
        border: Border.all(color: ColorTokens.border(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;
          final artworkSize =
              clamped(isNarrow ? 160 : 140, min: 110, max: 190);
          final artwork = ClipRRect(
            borderRadius: BorderRadius.circular(
              clamped(20, min: 12, max: 24),
            ),
            child: ArtworkImage(
              imageUrl: playlist.imageUrl,
              width: artworkSize,
              height: artworkSize,
              fit: BoxFit.cover,
              placeholder: buildArtworkFallback(isNarrow),
            ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                playlist.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: space(8)),
              Text(
                '${playlist.trackCount} tracks',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: ColorTokens.textSecondary(context)),
              ),
              SizedBox(height: space(16)),
              Wrap(
                spacing: space(12),
                runSpacing: space(8),
                children: [
                  FilledButton.icon(
                    onPressed: tracks.isEmpty
                        ? null
                        : () => state.playFromList(tracks, tracks.first),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                  ),
                  if (tracks.isNotEmpty)
                    FilledButton.tonalIcon(
                      onPressed: () => state.playShuffledList(tracks),
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Shuffle'),
                    ),
                  if (canEdit)
                    PopupMenuButton<_PlaylistHeaderAction>(
                      tooltip: 'Playlist options',
                      onSelected: (value) {
                        if (value == _PlaylistHeaderAction.rename) {
                          onRename?.call();
                        } else if (value == _PlaylistHeaderAction.delete) {
                          onDelete?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: _PlaylistHeaderAction.rename,
                          child: Text('Rename'),
                        ),
                        const PopupMenuItem(
                          value: _PlaylistHeaderAction.delete,
                          child: Text('Delete'),
                        ),
                      ],
                      icon: const Icon(Icons.more_horiz),
                    ),
                ],
              ),
            ],
          );
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                artwork,
                SizedBox(height: space(20)),
                details,
              ],
            );
          }
          return Row(
            children: [
              artwork,
              SizedBox(width: space(24)),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

enum _PlaylistHeaderAction {
  rename,
  delete,
}
