import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/smart_list.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../core/color_tokens.dart';
import 'collection_header.dart';
import 'smart_list_dialogs.dart';
import 'track_row.dart';

/// Smart List detail view with dynamic tracks.
class SmartListDetailView extends StatelessWidget {
  /// Creates the smart list detail view.
  const SmartListDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final leftGutter =
        (32 * densityScale).clamp(16.0, 40.0).toDouble();
    final rightGutter =
        (24 * densityScale).clamp(12.0, 32.0).toDouble();
    final smartList = state.selectedSmartList;
    if (smartList == null) {
      return const SizedBox.shrink();
    }
    final tracks = state.smartListTracks;
    final isLoading = state.isLoadingSmartList;
    final showEmpty = tracks.isEmpty && !isLoading;
    final itemCount = tracks.length + (showEmpty ? 2 : 1);
    return ListView.separated(
      itemCount: itemCount,
      padding: EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0),
      separatorBuilder: (_, index) => SizedBox(
        height: index == 0 ? space(20) : space(6).clamp(4.0, 10.0),
      ),
      itemBuilder: (context, index) {
        if (index == 0) {
          final actions = <Widget>[
            FilledButton.icon(
              onPressed: tracks.isEmpty
                  ? null
                  : () => state.playFromList(tracks, tracks.first),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
            ),
            if (tracks.length > 1)
              FilledButton.tonalIcon(
                onPressed: () => state.playShuffledList(tracks),
                icon: const Icon(Icons.shuffle),
                label: const Text('Shuffle'),
              ),
            PopupMenuButton<_SmartListAction>(
              tooltip: 'Smart list options',
              onSelected: (value) {
                if (value == _SmartListAction.edit) {
                  _editSmartList(context, smartList);
                } else if (value == _SmartListAction.delete) {
                  _deleteSmartList(context, smartList);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _SmartListAction.edit,
                  child: Text('Edit rules'),
                ),
                PopupMenuItem(
                  value: _SmartListAction.delete,
                  child: Text('Delete'),
                ),
              ],
              icon: const Icon(Icons.more_horiz),
            ),
          ];
          return CollectionHeader(
            title: smartList.name,
            subtitle: isLoading
                ? 'Building smart list...'
                : '${tracks.length} tracks',
            imageUrl: null,
            fallbackIcon: Icons.auto_awesome,
            actions: actions,
          );
        }
        if (showEmpty && index == 1) {
          return _EmptySmartListView();
        }
        if (index - 1 >= tracks.length) {
          return const SizedBox.shrink();
        }
        final trackIndex = index - 1;
        final track = tracks[trackIndex];
        return TrackRow(
          track: track,
          index: trackIndex,
          isActive: state.nowPlaying?.id == track.id,
          onTap: () => state.playFromList(tracks, track),
          onPlayNext: () => state.playNext(track),
          onAddToQueue: () => state.enqueueTrack(track),
          isFavorite: state.isFavoriteTrack(track.id),
          isFavoriteUpdating: state.isFavoriteTrackUpdating(track.id),
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
              : () => state.selectArtistById(track.artistIds.first),
        );
      },
    );
  }

  Future<void> _editSmartList(
    BuildContext context,
    SmartList smartList,
  ) async {
    final updated = await showSmartListEditorDialog(
      context,
      initial: smartList,
    );
    if (!context.mounted || updated == null) {
      return;
    }
    await context.read<AppState>().updateSmartList(updated);
  }

  Future<void> _deleteSmartList(
    BuildContext context,
    SmartList smartList,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Smart List?'),
        content: Text('“${smartList.name}” will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (result == true && context.mounted) {
      await context.read<AppState>().deleteSmartList(smartList);
    }
  }
}

class _EmptySmartListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final densityScale =
        context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Container(
      padding: EdgeInsets.all(space(24).clamp(16.0, 32.0)),
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorTokens.border(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
          SizedBox(width: space(12)),
          Expanded(
            child: Text(
              'No tracks match these rules yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

enum _SmartListAction {
  edit,
  delete,
}
