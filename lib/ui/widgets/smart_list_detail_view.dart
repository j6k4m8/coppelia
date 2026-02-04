import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/smart_list.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../core/color_tokens.dart';
import 'collection_header.dart';
import 'corner_radius.dart';
import 'smart_list_dialogs.dart';
import 'track_list_item.dart';

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
                } else if (value == _SmartListAction.rename) {
                  _renameSmartList(context, smartList);
                } else if (value == _SmartListAction.duplicate) {
                  _duplicateSmartList(context, smartList);
                } else if (value == _SmartListAction.delete) {
                  _deleteSmartList(context, smartList);
                } else if (value == _SmartListAction.toggleHome) {
                  final updated = smartList.copyWith(
                    showOnHome: !smartList.showOnHome,
                  );
                  state.updateSmartList(updated);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _SmartListAction.edit,
                  child: Text('Edit rules'),
                ),
                const PopupMenuItem(
                  value: _SmartListAction.rename,
                  child: Text('Rename'),
                ),
                const PopupMenuItem(
                  value: _SmartListAction.duplicate,
                  child: Text('Duplicate'),
                ),
                PopupMenuItem(
                  value: _SmartListAction.toggleHome,
                  child: Text(
                    smartList.showOnHome ? 'Remove from Home' : 'Add to Home',
                  ),
                ),
                const PopupMenuItem(
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
            onBack: state.goBack,
            onSearch: state.requestSearchFocus,
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
        return TrackListItem(
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

  Future<void> _renameSmartList(
    BuildContext context,
    SmartList smartList,
  ) async {
    final controller = TextEditingController(text: smartList.name);
    String value = controller.text;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rename smart list'),
          content: TextField(
            controller: controller,
            autofocus: true,
            onChanged: (text) => setState(() {
              value = text;
            }),
            onSubmitted: (_) => Navigator.of(context).pop(value),
            decoration: const InputDecoration(hintText: 'Smart list name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: value.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(value),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    final trimmed = result?.trim();
    if (!context.mounted || trimmed == null || trimmed.isEmpty) {
      return;
    }
    await context
        .read<AppState>()
        .updateSmartList(smartList.copyWith(name: trimmed));
  }

  Future<void> _duplicateSmartList(
    BuildContext context,
    SmartList smartList,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final copy = smartList.copyWith(
      id: 'smart-$now',
      name: '${smartList.name} Copy',
    );
    final created = await context.read<AppState>().createSmartList(copy);
    if (context.mounted) {
      await context.read<AppState>().selectSmartList(created);
    }
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
        borderRadius: BorderRadius.circular(context.scaledRadius(16)),
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
  rename,
  duplicate,
  toggleHome,
  delete,
}
