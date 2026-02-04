import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../models/media_item.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../state/track_list_style.dart';
import 'track_list_section.dart';
import 'track_row.dart';
import 'track_table_row.dart';

typedef TrackTapCallback = void Function(MediaItem track, int index);

/// Configurable track list page for simple track collections.
class TrackListView extends StatelessWidget {
  const TrackListView({
    super.key,
    required this.title,
    required this.tracks,
    required this.onTapTrack,
    this.subtitle,
    this.trailing,
    this.emptyMessage,
    this.listBottomPadding,
    this.controller,
    this.enableAlbumArtistNav = true,
    this.enableGoToActions = true,
    this.enableContextMenu = true,
    this.reorderable = false,
    this.onReorder,
    this.showDragHandle = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? emptyMessage;
  final List<MediaItem> tracks;
  final TrackTapCallback onTapTrack;
  final double? listBottomPadding;
  final ScrollController? controller;
  final bool enableAlbumArtistNav;
  final bool enableGoToActions;
  final bool enableContextMenu;
  final bool reorderable;
  final ReorderCallback? onReorder;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final gap = space(6).clamp(4.0, 10.0);

    if (tracks.isEmpty && emptyMessage != null) {
      return Center(
        child: Text(
          emptyMessage!,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: ColorTokens.textSecondary(context)),
        ),
      );
    }

    final albumNavEnabled = enableAlbumArtistNav && !state.offlineOnlyFilter;

    Widget buildRow(
      BuildContext context,
      int index, {
      Widget? leading,
    }) {
      final track = tracks[index];
      final isFavorite = state.isFavoriteTrack(track.id);
      
      // Use table row if table style is selected
      if (state.trackListStyle == TrackListStyle.table) {
        return TrackTableRow(
          track: track,
          index: index,
          onTap: () => onTapTrack(track, index),
          isActive: state.nowPlaying?.id == track.id,
        );
      }
      
      // Otherwise use card style
      return TrackRow(
        track: track,
        index: index,
        isActive: state.nowPlaying?.id == track.id,
        onTap: () => onTapTrack(track, index),
        onPlayNext: () => state.playNext(track),
        onAddToQueue: () => state.enqueueTrack(track),
        isFavorite: isFavorite,
        isFavoriteUpdating: state.isFavoriteTrackUpdating(track.id),
        onToggleFavorite: () =>
            state.setTrackFavorite(track, !isFavorite),
        onAlbumTap: albumNavEnabled && track.albumId != null
            ? () => state.selectAlbumById(track.albumId!)
            : null,
        onArtistTap: albumNavEnabled && track.artistIds.isNotEmpty
            ? () => state.selectArtistById(track.artistIds.first)
            : null,
        onGoToAlbum: enableGoToActions && track.albumId != null
            ? () => state.selectAlbumById(track.albumId!)
            : null,
        onGoToArtist: enableGoToActions && track.artistIds.isNotEmpty
            ? () => state.selectArtistById(track.artistIds.first)
            : null,
        enableContextMenu: enableContextMenu,
        leading: leading,
      );
    }

    return TrackListSection(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      listBottomPadding: listBottomPadding,
      controller: controller,
      bodyBuilder: reorderable
          ? (context, listPadding, _) {
              return ReorderableListView.builder(
                padding: listPadding,
                buildDefaultDragHandles: false,
                itemCount: tracks.length,
                onReorder: onReorder ?? (_, __) {},
                itemBuilder: (context, index) {
                  Widget? handle;
                  if (showDragHandle) {
                    handle = ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        Icons.drag_handle,
                        size: space(20).clamp(16.0, 22.0),
                        color: ColorTokens.textSecondary(context, 0.7),
                      ),
                    );
                  }
                  final row = buildRow(context, index, leading: handle);
                  return Padding(
                    key: ObjectKey(tracks[index]),
                    padding: EdgeInsets.only(bottom: gap),
                    child: row,
                  );
                },
              );
            }
          : null,
      itemCount: reorderable ? null : tracks.length,
      itemBuilder: reorderable ? null : buildRow,
    );
  }
}
