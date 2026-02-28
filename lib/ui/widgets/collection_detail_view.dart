import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../models/media_item.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'artwork_fallback.dart';
import 'artwork_image.dart';
import 'collection_header.dart';
import 'corner_radius.dart';
import 'track_list_item.dart';
import 'track_table_header.dart';
import '../../state/track_list_style.dart';
import 'header_controls.dart';

/// Generic detail view for albums, artists, or genres.
class CollectionDetailView extends StatefulWidget {
  /// Creates a collection detail view.
  const CollectionDetailView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tracks,
    required this.onTrackTap,
    required this.nowPlaying,
    this.imageUrl,
    this.subtitleWidget,
    this.onPlayAll,
    this.onShuffle,
    this.onPlayNext,
    this.onAddToQueue,
    this.onAlbumTap,
    this.onArtistTap,
    this.headerFooter,
    this.headerActions = const [],
    this.headerActionSpecs = const [],
  });

  /// Title for the collection.
  final String title;

  /// Subtitle for the collection.
  final String subtitle;

  /// Tracks in the collection.
  final List<MediaItem> tracks;

  /// Artwork for the collection.
  final String? imageUrl;

  /// Optional custom subtitle widget.
  final Widget? subtitleWidget;

  /// Callback for playing all tracks.
  final VoidCallback? onPlayAll;

  /// Callback for shuffling tracks.
  final VoidCallback? onShuffle;

  /// Handler when a track is tapped.
  final ValueChanged<MediaItem> onTrackTap;

  /// Handler when a track should play next.
  final ValueChanged<MediaItem>? onPlayNext;

  /// Handler when a track should be enqueued.
  final ValueChanged<MediaItem>? onAddToQueue;

  /// Handler when a track album should be opened.
  final ValueChanged<MediaItem>? onAlbumTap;

  /// Handler when a track artist should be opened.
  final ValueChanged<MediaItem>? onArtistTap;

  /// Currently playing track.
  final MediaItem? nowPlaying;

  /// Optional widget to render below the header.
  final Widget? headerFooter;

  /// Optional extra actions for the header.
  final List<Widget> headerActions;

  /// Preferred action model for consistent responsive rendering.
  ///
  /// When provided, these actions will be rendered instead of [headerActions].
  final List<HeaderActionSpec> headerActionSpecs;

  @override
  State<CollectionDetailView> createState() => _CollectionDetailViewState();
}

class _CollectionDetailViewState extends State<CollectionDetailView> {
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

    final hasTableHeader = state.trackListStyle == TrackListStyle.table;
    final headerOffset =
        (widget.headerFooter == null ? 1 : 2) + (hasTableHeader ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: widget.tracks.length + headerOffset,
            padding: EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0),
            separatorBuilder: (_, index) {
              if (index == 0 ||
                  (widget.headerFooter != null && index == 1) ||
                  (hasTableHeader && index == headerOffset - 1)) {
                return SizedBox(height: space(24));
              }
              return SizedBox(height: space(6).clamp(4.0, 10.0));
            },
            itemBuilder: (context, index) {
              if (index == 0) {
                return _Header(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  subtitleWidget: widget.subtitleWidget,
                  imageUrl: widget.imageUrl,
                  onPlayAll: widget.onPlayAll,
                  onShuffle: widget.onShuffle,
                  actions: widget.headerActions,
                  actionSpecs: widget.headerActionSpecs,
                );
              }
              if (widget.headerFooter != null && index == 1) {
                return widget.headerFooter!;
              }
              if (hasTableHeader && index == headerOffset - 1) {
                return TrackTableHeader(
                  key: const ValueKey('collection-table-header'),
                  onVisibleColumnsChanged: (columns) {
                    setState(() {
                      _visibleColumns = columns;
                    });
                  },
                );
              }
              final trackIndex = index - headerOffset;
              final track = widget.tracks[trackIndex];
              final canGoToAlbum =
                  widget.onAlbumTap != null && track.albumId != null;
              final canGoToArtist =
                  widget.onArtistTap != null && track.artistIds.isNotEmpty;
              return TrackListItem(
                track: track,
                index: trackIndex,
                isActive: widget.nowPlaying?.id == track.id,
                onTap: () => widget.onTrackTap(track),
                onPlayNext: widget.onPlayNext == null
                    ? null
                    : () => widget.onPlayNext!.call(track),
                onAddToQueue: widget.onAddToQueue == null
                    ? null
                    : () => widget.onAddToQueue!.call(track),
                isFavorite: state.isFavoriteTrack(track.id),
                isFavoriteUpdating: state.isFavoriteTrackUpdating(track.id),
                onToggleFavorite: () => state.setTrackFavorite(
                  track,
                  !state.isFavoriteTrack(track.id),
                ),
                onAlbumTap:
                    canGoToAlbum ? () => widget.onAlbumTap!.call(track) : null,
                onArtistTap: canGoToArtist
                    ? () => widget.onArtistTap!.call(track)
                    : null,
                visibleColumns: _visibleColumns,
                onGoToAlbum:
                    canGoToAlbum ? () => widget.onAlbumTap!.call(track) : null,
                onGoToArtist: canGoToArtist
                    ? () => widget.onArtistTap!.call(track)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    this.subtitleWidget,
    this.imageUrl,
    this.onPlayAll,
    this.onShuffle,
    this.actions = const [],
    this.actionSpecs = const [],
  });

  final String title;
  final String subtitle;
  final Widget? subtitleWidget;
  final String? imageUrl;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;
  final List<Widget> actions;
  final List<HeaderActionSpec> actionSpecs;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    final cardRadius = context.scaledRadius(clamped(26, min: 16, max: 30));
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        final iconOnlyActions = constraints.maxWidth < 420;
        final theme = Theme.of(context);

        final resolvedHeaderActions =
            (iconOnlyActions && actionSpecs.isNotEmpty)
                ? CollectionHeader.buildActionsFromSpecs(
                    context,
                    actionSpecs,
                    iconOnly: true,
                    densityScale: densityScale,
                  )
                : null;

        Widget iconOnlyButton({
          required String tooltip,
          required VoidCallback? onPressed,
          required Widget icon,
          bool tonal = false,
        }) {
          final button = tonal
              ? IconButton.filledTonal(
                  onPressed: onPressed,
                  icon: icon,
                  iconSize: clamped(22, min: 18, max: 24),
                  padding: EdgeInsets.all(space(10).clamp(8.0, 12.0)),
                )
              : IconButton.filled(
                  onPressed: onPressed,
                  icon: icon,
                  iconSize: clamped(22, min: 18, max: 24),
                  padding: EdgeInsets.all(space(10).clamp(8.0, 12.0)),
                );
          return Tooltip(message: tooltip, child: button);
        }

        Widget buildArtworkFallback() => ArtworkFallback(
              icon: Icons.library_music,
              iconSize: clamped(42, min: 30, max: 48),
            );
        final artworkExtent = clamped(isNarrow ? 240 : 200, min: 160, max: 260);
        Widget details() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineMedium,
              ),
              SizedBox(height: space(8)),
              subtitleWidget ??
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: ColorTokens.textSecondary(context),
                    ),
                  ),
              SizedBox(height: space(16)),
              Wrap(
                spacing: space(12),
                runSpacing: space(8),
                children: [
                  iconOnlyActions
                      ? iconOnlyButton(
                          tooltip: 'Play',
                          onPressed: onPlayAll,
                          icon: const Icon(Icons.play_arrow),
                        )
                      : FilledButton.icon(
                          onPressed: onPlayAll,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play'),
                        ),
                  if (onShuffle != null)
                    iconOnlyActions
                        ? iconOnlyButton(
                            tooltip: 'Shuffle',
                            onPressed: onShuffle,
                            icon: const Icon(Icons.shuffle),
                            tonal: true,
                          )
                        : FilledButton.tonalIcon(
                            onPressed: onShuffle,
                            icon: const Icon(Icons.shuffle),
                            label: const Text('Shuffle'),
                          ),
                  if (resolvedHeaderActions != null) ...resolvedHeaderActions,
                  if (resolvedHeaderActions == null) ...actions,
                ],
              ),
            ],
          );
        }

        final card = Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: ColorTokens.heroGradient(context),
            ),
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: ColorTokens.border(context)),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(cardRadius),
                        topRight: Radius.circular(cardRadius),
                      ),
                      child: SizedBox(
                        height: artworkExtent,
                        child: imageUrl == null
                            ? buildArtworkFallback()
                            : ArtworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: buildArtworkFallback(),
                              ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        space(22).clamp(14.0, 28.0),
                        space(18).clamp(12.0, 24.0),
                        space(22).clamp(14.0, 28.0),
                        space(22).clamp(14.0, 28.0),
                      ),
                      child: details(),
                    ),
                  ],
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(cardRadius),
                          bottomLeft: Radius.circular(cardRadius),
                        ),
                        child: SizedBox(
                          width: artworkExtent,
                          child: imageUrl == null
                              ? buildArtworkFallback()
                              : ArtworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: buildArtworkFallback(),
                                ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            space(24).clamp(16.0, 30.0),
                            space(20).clamp(12.0, 26.0),
                            space(24).clamp(16.0, 30.0),
                            space(20).clamp(12.0, 26.0),
                          ),
                          child: details(),
                        ),
                      ),
                    ],
                  ),
                ),
        );
        return ClipRRect(
          borderRadius: BorderRadius.circular(cardRadius),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              card,
              Positioned(
                top: space(12).clamp(6.0, 18.0),
                left: space(12).clamp(6.0, 18.0),
                right: space(12).clamp(6.0, 18.0),
                child: Row(
                  children: [
                    SidebarMenuButton(gap: space(8)),
                    HeaderControlButton(
                      icon: Icons.arrow_back_ios_new,
                      onTap: context.read<AppState>().canGoBack
                          ? context.read<AppState>().goBack
                          : null,
                    ),
                    const Spacer(),
                    SearchCircleButton(
                      onTap: context.read<AppState>().requestSearchFocus,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
