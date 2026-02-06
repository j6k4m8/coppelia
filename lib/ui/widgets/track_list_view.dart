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
import 'track_table_header.dart';

typedef TrackTapCallback = void Function(MediaItem track, int index);

/// Configurable track list page for simple track collections.
class TrackListView extends StatefulWidget {
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
  State<TrackListView> createState() => _TrackListViewState();
}

class _TrackListViewState extends State<TrackListView> {
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
    final gap = space(6).clamp(4.0, 10.0);

    if (widget.tracks.isEmpty && widget.emptyMessage != null) {
      return Center(
        child: Text(
          widget.emptyMessage!,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: ColorTokens.textSecondary(context)),
        ),
      );
    }

    final albumNavEnabled =
        widget.enableAlbumArtistNav && !state.offlineOnlyFilter;

    Widget buildRow(
      BuildContext context,
      int index, {
      Widget? leading,
    }) {
      final track = widget.tracks[index];
      final isFavorite = state.isFavoriteTrack(track.id);
      final albumNavEnabled = widget.enableAlbumArtistNav;

      // Use table row if table style is selected
      if (state.trackListStyle == TrackListStyle.table) {
        return TrackTableRow(
          track: track,
          index: index,
          onTap: () => widget.onTapTrack(track, index),
          isActive: state.nowPlaying?.id == track.id,
          visibleColumns: _visibleColumns,
          isFavorite: isFavorite,
          onToggleFavorite: () => state.setTrackFavorite(track, !isFavorite),
          onAlbumTap: albumNavEnabled && track.albumId != null
              ? () => state.selectAlbumById(track.albumId!)
              : null,
          onArtistTap: albumNavEnabled && track.artistIds.isNotEmpty
              ? () => state.selectArtistById(track.artistIds.first)
              : null,
          onPlayNext: () => state.playNext(track),
          onAddToQueue: () => state.enqueueTrack(track),
          onGoToAlbum: widget.enableGoToActions && track.albumId != null
              ? () => state.selectAlbumById(track.albumId!)
              : null,
          onGoToArtist: widget.enableGoToActions && track.artistIds.isNotEmpty
              ? () => state.selectArtistById(track.artistIds.first)
              : null,
        );
      }

      // Otherwise use card style
      return TrackRow(
        track: track,
        index: index,
        isActive: state.nowPlaying?.id == track.id,
        onTap: () => widget.onTapTrack(track, index),
        onPlayNext: () => state.playNext(track),
        onAddToQueue: () => state.enqueueTrack(track),
        isFavorite: isFavorite,
        isFavoriteUpdating: state.isFavoriteTrackUpdating(track.id),
        onToggleFavorite: () => state.setTrackFavorite(track, !isFavorite),
        onAlbumTap: albumNavEnabled && track.albumId != null
            ? () => state.selectAlbumById(track.albumId!)
            : null,
        onArtistTap: albumNavEnabled && track.artistIds.isNotEmpty
            ? () => state.selectArtistById(track.artistIds.first)
            : null,
        onGoToAlbum: widget.enableGoToActions && track.albumId != null
            ? () => state.selectAlbumById(track.albumId!)
            : null,
        onGoToArtist: widget.enableGoToActions && track.artistIds.isNotEmpty
            ? () => state.selectArtistById(track.artistIds.first)
            : null,
        enableContextMenu: widget.enableContextMenu,
        leading: leading,
      );
    }

    // Add table header when in table mode
    final tableHeader = state.trackListStyle == TrackListStyle.table
        ? TrackTableHeader(
            onVisibleColumnsChanged: (columns) {
              setState(() {
                _visibleColumns = columns;
              });
            },
          )
        : null;

    return TrackListSection(
      title: widget.title,
      subtitle: widget.subtitle,
      trailing: widget.trailing,
      listBottomPadding: widget.listBottomPadding,
      controller: widget.controller,
      headerWidget: tableHeader,
      bodyBuilder: widget.reorderable
          ? (context, listPadding, _) {
              return ReorderableListView.builder(
                padding: listPadding,
                buildDefaultDragHandles: false,
                itemCount: widget.tracks.length,
                onReorder: widget.onReorder ?? (_, __) {},
                itemBuilder: (context, index) {
                  Widget? handle;
                  if (widget.showDragHandle) {
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
                    key: ObjectKey(widget.tracks[index]),
                    padding: EdgeInsets.only(bottom: gap),
                    child: row,
                  );
                },
              );
            }
          : null,
      itemCount: widget.reorderable ? null : widget.tracks.length,
      itemBuilder: widget.reorderable ? null : buildRow,
    );
  }
}
