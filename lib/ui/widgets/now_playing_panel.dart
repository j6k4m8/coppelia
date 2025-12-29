import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/color_tokens.dart';
import '../../core/formatters.dart';
import '../../models/media_item.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../state/library_view.dart';
import '../../state/now_playing_layout.dart';
import 'artwork_image.dart';

/// Right-side panel for playback and queue control.
class NowPlayingPanel extends StatelessWidget {
  /// Creates the now playing panel.
  const NowPlayingPanel({
    super.key,
    this.layout = NowPlayingLayout.side,
  });

  /// Layout preference for the panel.
  final NowPlayingLayout layout;

  @override
  Widget build(BuildContext context) {
    return layout == NowPlayingLayout.side
        ? _SidePanel(layout: layout)
        : _BottomBar(layout: layout);
  }
}

({MediaItem? previous, MediaItem? next}) _adjacentTracks(
  List<MediaItem> queue,
  MediaItem? current,
) {
  if (current == null) {
    return (previous: null, next: null);
  }
  final index = queue.indexWhere((item) => item.id == current.id);
  if (index == -1) {
    return (previous: null, next: null);
  }
  return (
    previous: index > 0 ? queue[index - 1] : null,
    next: index + 1 < queue.length ? queue[index + 1] : null,
  );
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.layout});

  final NowPlayingLayout layout;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final isTouch = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.fuchsia);
    final track = state.nowPlaying;
    final isFavorite = track == null ? false : state.isFavoriteTrack(track.id);
    final isUpdating =
        track == null ? false : state.isFavoriteTrackUpdating(track.id);
    final neighbors = _adjacentTracks(state.queue, track);
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24).scale(densityScale),
      decoration: BoxDecoration(
        color: ColorTokens.panelBackground(context),
        border: Border(
          left: BorderSide(color: ColorTokens.border(context)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Now playing',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (track != null)
                _FavoriteButton(
                  track: track,
                  isFavorite: isFavorite,
                  isUpdating: isUpdating,
                ),
            ],
          ),
          SizedBox(height: space(20)),
          _SwipeTrackSwitcher(
            current: track,
            previous: neighbors.previous,
            next: neighbors.next,
            onNext: state.nextTrack,
            onPrevious: state.previousTrack,
            enabled: isTouch && track != null,
            onTap:
                track == null ? null : () => _openExpandedNowPlaying(context),
            builder: (item) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Artwork(track: item),
                  SizedBox(height: space(20)),
                  Text(
                    item?.title ?? 'Nothing queued',
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: space(6).clamp(4.0, 10.0)),
                  _NowPlayingMeta(track: item),
                ],
              );
            },
          ),
          SizedBox(height: space(20)),
          AnimatedBuilder(
            animation: Listenable.merge([
              state.positionListenable,
              state.durationListenable,
            ]),
            builder: (context, _) {
              return _ProgressScrubber(
                position: state.position,
                duration: state.duration,
                onSeek: state.seek,
              );
            },
          ),
          SizedBox(height: space(12)),
          Center(
            child: _Controls(
              isPlaying: state.isPlaying,
              onPlayPause: state.togglePlayback,
              onNext: state.nextTrack,
              onPrevious: state.previousTrack,
            ),
          ),
          SizedBox(height: space(20)),
          Divider(color: ColorTokens.border(context, 0.12)),
          SizedBox(height: space(16)),
          Text(
            'Playing next',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: ColorTokens.textSecondary(context, 0.7)),
          ),
          SizedBox(height: space(12)),
          Expanded(
            child: _QueueList(queue: state.queue, nowPlaying: track),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.layout});

  final NowPlayingLayout layout;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final isTouch = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.fuchsia);
    final track = state.nowPlaying;
    final isFavorite = track == null ? false : state.isFavoriteTrack(track.id);
    final isUpdating =
        track == null ? false : state.isFavoriteTrackUpdating(track.id);
    final neighbors = _adjacentTracks(state.queue, track);
    final panel = Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16).scale(densityScale),
      decoration: BoxDecoration(
        color: ColorTokens.panelBackground(context),
        border: Border(
          top: BorderSide(color: ColorTokens.border(context)),
        ),
      ),
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 680;
            Widget buildTitleBlock(MediaItem? item) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item?.title ?? 'Nothing queued',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: space(4).clamp(2.0, 6.0)),
                  _NowPlayingMeta(track: item),
                ],
              );
            }

            Widget buildMiniRow(MediaItem? item) {
              return Row(
                children: [
                  _MiniArtwork(track: item),
                  SizedBox(width: space(12).clamp(8.0, 16.0)),
                  Expanded(child: buildTitleBlock(item)),
                ],
              );
            }
            if (isNarrow) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SwipeTrackSwitcher(
                    current: track,
                    previous: neighbors.previous,
                    next: neighbors.next,
                    onNext: state.nextTrack,
                    onPrevious: state.previousTrack,
                    enabled: isTouch && track != null,
                    onTap: track == null
                        ? null
                        : () => _openExpandedNowPlaying(context),
                    builder: buildMiniRow,
                  ),
                  SizedBox(height: space(10).clamp(6.0, 14.0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (track != null)
                        _FavoriteButton(
                          track: track,
                          isFavorite: isFavorite,
                          isUpdating: isUpdating,
                        ),
                      if (track != null)
                        _RepeatButton(
                          mode: state.repeatMode,
                          onTap: state.toggleRepeatMode,
                        ),
                      IconButton(
                        icon: const Icon(Icons.queue_music),
                        onPressed: () =>
                            state.selectLibraryView(LibraryView.queue),
                      ),
                      _Controls(
                        isPlaying: state.isPlaying,
                        onPlayPause: state.togglePlayback,
                        onNext: state.nextTrack,
                        onPrevious: state.previousTrack,
                      ),
                    ],
                  ),
                  SizedBox(height: space(6).clamp(4.0, 10.0)),
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        state.positionListenable,
                        state.durationListenable,
                      ]),
                      builder: (context, _) {
                        return _ProgressScrubber(
                          position: state.position,
                          duration: state.duration,
                          onSeek: state.seek,
                          compact: true,
                        );
                      },
                    ),
                  ),
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SwipeTrackSwitcher(
                        current: track,
                        previous: neighbors.previous,
                        next: neighbors.next,
                        onNext: state.nextTrack,
                        onPrevious: state.previousTrack,
                        enabled: isTouch && track != null,
                        onTap: track == null
                            ? null
                            : () => _openExpandedNowPlaying(context),
                        builder: (item) {
                          return Row(
                            children: [
                              _MiniArtwork(track: item),
                              SizedBox(
                                width: space(16).clamp(10.0, 20.0),
                              ),
                              Expanded(child: buildTitleBlock(item)),
                            ],
                          );
                        },
                      ),
                    ),
                    if (track != null)
                      _FavoriteButton(
                        track: track,
                        isFavorite: isFavorite,
                        isUpdating: isUpdating,
                      ),
                    if (track != null)
                      _RepeatButton(
                        mode: state.repeatMode,
                        onTap: state.toggleRepeatMode,
                      ),
                    IconButton(
                      icon: const Icon(Icons.queue_music),
                      onPressed: () =>
                          state.selectLibraryView(LibraryView.queue),
                    ),
                    _Controls(
                      isPlaying: state.isPlaying,
                      onPlayPause: state.togglePlayback,
                      onNext: state.nextTrack,
                      onPrevious: state.previousTrack,
                    ),
                  ],
                ),
                SizedBox(height: space(6).clamp(4.0, 10.0)),
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      state.positionListenable,
                      state.durationListenable,
                    ]),
                    builder: (context, _) {
                      return _ProgressScrubber(
                        position: state.position,
                        duration: state.duration,
                        onSeek: state.seek,
                        compact: true,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (!isTouch || track == null) {
      return panel;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -300) {
          _openExpandedNowPlaying(context);
        }
      },
      child: panel,
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({required this.queue, required this.nowPlaying});

  final List<MediaItem> queue;
  final MediaItem? nowPlaying;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    if (queue.isEmpty) {
      return Text(
        'Queue is empty.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: ColorTokens.textSecondary(context)),
      );
    }
    final startIndex = nowPlaying == null
        ? 0
        : queue.indexWhere((item) => item.id == nowPlaying!.id);
    final safeIndex = startIndex < 0 ? 0 : startIndex;
    final visibleQueue = queue.sublist(safeIndex);
    return ListView.builder(
      itemCount: visibleQueue.length,
      itemBuilder: (context, index) {
        final item = visibleQueue[index];
        return Padding(
          padding: EdgeInsets.only(bottom: space(8).clamp(4.0, 12.0)),
          child: Text(
            item.title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: item.id == nowPlaying?.id
                      ? ColorTokens.textPrimary(context)
                      : ColorTokens.textSecondary(context),
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}

class _NowPlayingMeta extends StatelessWidget {
  const _NowPlayingMeta({required this.track});

  final MediaItem? track;

  @override
  Widget build(BuildContext context) {
    if (track == null) {
      return Text(
        'Pick a track to start listening.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: ColorTokens.textSecondary(context)),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final state = context.read<AppState>();
    final baseStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: ColorTokens.textSecondary(context));
    final linkStyle = baseStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
    );
    final artistLabel = track!.artists.isNotEmpty
        ? track!.artists.join(', ')
        : 'Unknown Artist';
    return Row(
      children: [
        Flexible(
          child: MouseRegion(
            cursor: track!.artistIds.isEmpty
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: track!.artistIds.isEmpty
                  ? null
                  : () => state.selectArtistById(track!.artistIds.first),
              child: Text(
                artistLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: track!.artistIds.isEmpty ? baseStyle : linkStyle,
              ),
            ),
          ),
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
          child: MouseRegion(
            cursor: track!.albumId == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: track!.albumId == null
                  ? null
                  : () => state.selectAlbumById(track!.albumId!),
              child: Text(
                track!.album,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: track!.albumId == null ? baseStyle : linkStyle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.track,
    required this.isFavorite,
    required this.isUpdating,
  });

  final MediaItem track;
  final bool isFavorite;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    if (isUpdating) {
      return SizedBox(
        width: clamped(18, min: 14, max: 22),
        height: clamped(18, min: 14, max: 22),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.primary,
        ),
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => state.setTrackFavorite(track, !isFavorite),
        child: SizedBox(
          width: clamped(24, min: 18, max: 30),
          height: clamped(24, min: 18, max: 30),
          child: Center(
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              size: clamped(16, min: 12, max: 20),
              color: isFavorite
                  ? theme.colorScheme.primary
                  : ColorTokens.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressScrubber extends StatelessWidget {
  const _ProgressScrubber({
    required this.position,
    required this.duration,
    required this.onSeek,
    this.compact = false,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds;
    final currentMs = position.inMilliseconds.clamp(0, totalMs);
    final value = totalMs > 0 ? currentMs / totalMs : 0.0;
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    final height =
        ((compact ? 32.0 : 40.0) * densityScale).clamp(24.0, 52.0);
    final trackHeight =
        ((compact ? 4.0 : 6.0) * densityScale).clamp(2.0, 8.0);
    final thumbRadius =
        ((compact ? 6.0 : 8.0) * densityScale).clamp(4.0, 10.0);
    final overlayRadius =
        ((compact ? 10.0 : 12.0) * densityScale).clamp(6.0, 14.0);
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: trackHeight,
              activeTrackColor: primary,
              inactiveTrackColor: primary.withOpacity(0.2),
              thumbColor: primary,
              overlayColor: primary.withOpacity(0.15),
              thumbShape:
                  RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
              overlayShape:
                  RoundSliderOverlayShape(overlayRadius: overlayRadius),
            ),
            child: Slider(
              value: value,
              onChanged: totalMs <= 0
                  ? null
                  : (newValue) {
                      final targetMs = (totalMs * newValue).round();
                      onSeek(Duration(milliseconds: targetMs));
                    },
            ),
          ),
        ),
        SizedBox(
          height: (6 * densityScale).clamp(4.0, 10.0),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formatDuration(position),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: ColorTokens.textSecondary(context)),
            ),
            Text(
              formatDuration(duration),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: ColorTokens.textSecondary(context)),
            ),
          ],
        ),
      ],
    );
  }
}

class _SwipeTrackSwitcher extends StatefulWidget {
  const _SwipeTrackSwitcher({
    required this.current,
    required this.previous,
    required this.next,
    required this.onNext,
    required this.onPrevious,
    required this.builder,
    this.onTap,
    this.enabled = true,
  });

  final MediaItem? current;
  final MediaItem? previous;
  final MediaItem? next;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Widget Function(MediaItem? track) builder;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<_SwipeTrackSwitcher> createState() => _SwipeTrackSwitcherState();
}

class _SwipeTrackSwitcherState extends State<_SwipeTrackSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragRange = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
  }

  @override
  void didUpdateWidget(covariant _SwipeTrackSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current?.id != widget.current?.id) {
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _clampDrag(double value, {required bool hasPrevious, required bool hasNext}) {
    final minDrag = hasNext ? -_dragRange : 0.0;
    final maxDrag = hasPrevious ? _dragRange : 0.0;
    return value.clamp(minDrag, maxDrag);
  }

  Future<void> _settleDrag({
    required double target,
    required VoidCallback action,
  }) async {
    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
    action();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasPrevious = widget.previous != null;
        final hasNext = widget.next != null;
        _dragRange = (constraints.maxWidth * 1.0)
            .clamp(220.0, 520.0)
            .toDouble();
        final canDrag = widget.enabled && (hasPrevious || hasNext);
        final baseContent = ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final offset = _clampDrag(
                _controller.value,
                hasPrevious: hasPrevious,
                hasNext: hasNext,
              );
              final progress =
                  _dragRange == 0 ? 0.0 : (offset / _dragRange).clamp(-1.0, 1.0);
              final absProgress = progress.abs();
              final scaledProgress =
                  (absProgress + 0.3 * absProgress * absProgress)
                      .clamp(0.0, 1.0);
              final scaledOffset =
                  _dragRange == 0 ? 0.0 : _dragRange * scaledProgress * progress.sign;
              final currentOpacity =
                  (1 - 0.35 * absProgress).clamp(0.55, 1.0);
              const peekStart = 0.2;
              final previousOpacity = progress > peekStart
                  ? ((progress - peekStart) / (1 - peekStart))
                      .clamp(0.0, 1.0)
                  : 0.0;
              final nextOpacity = progress < -peekStart
                  ? ((-progress - peekStart) / (1 - peekStart))
                      .clamp(0.0, 1.0)
                  : 0.0;
              Widget buildSlot(MediaItem? item) {
                return SizedBox(
                  width: constraints.maxWidth,
                  child: widget.builder(item),
                );
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  if (hasPrevious)
                    IgnorePointer(
                      child: Opacity(
                        opacity: previousOpacity,
                        child: Transform.translate(
                          offset: Offset(scaledOffset - _dragRange, 0),
                          child: buildSlot(widget.previous),
                        ),
                      ),
                    ),
                  if (hasNext)
                    IgnorePointer(
                      child: Opacity(
                        opacity: nextOpacity,
                        child: Transform.translate(
                          offset: Offset(scaledOffset + _dragRange, 0),
                          child: buildSlot(widget.next),
                        ),
                      ),
                    ),
                  Opacity(
                    opacity: currentOpacity,
                    child: Transform.translate(
                      offset: Offset(scaledOffset, 0),
                      child: buildSlot(widget.current),
                    ),
                  ),
                ],
              );
            },
          ),
        );
        final interactiveChild = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onHorizontalDragStart: canDrag
              ? (_) {
                  _controller.stop();
                }
              : null,
          onHorizontalDragUpdate: canDrag
              ? (details) {
                  _controller.value = _clampDrag(
                    _controller.value + details.delta.dx,
                    hasPrevious: hasPrevious,
                    hasNext: hasNext,
                  );
                }
              : null,
          onHorizontalDragEnd: canDrag
              ? (details) {
                  if (_dragRange == 0) {
                    return;
                  }
                  final velocity = details.primaryVelocity ?? 0;
                  final progress =
                      (_controller.value / _dragRange).clamp(-1.0, 1.0);
                  if (hasNext && (progress < -0.45 || velocity < -800)) {
                    _settleDrag(target: -_dragRange, action: widget.onNext);
                    return;
                  }
                  if (hasPrevious && (progress > 0.45 || velocity > 800)) {
                    _settleDrag(target: _dragRange, action: widget.onPrevious);
                    return;
                  }
                  _controller.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                  );
                }
              : null,
          child: baseContent,
        );
        if (widget.onTap == null) {
          return interactiveChild;
        }
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: interactiveChild,
        );
      },
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({this.track, this.onTap});

  final MediaItem? track;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    final imageUrl = track?.imageUrl;
    Widget buildArtworkFallback() => Container(
          color: ColorTokens.cardFillStrong(context),
          child: Icon(
            Icons.music_note,
            size: clamped(48, min: 34, max: 60),
          ),
        );
    final artwork = ClipRRect(
      borderRadius: BorderRadius.circular(
        clamped(24, min: 14, max: 30),
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: ArtworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: buildArtworkFallback(),
        ),
      ),
    );
    if (onTap == null) {
      return artwork;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: artwork,
      ),
    );
  }
}

class _MiniArtwork extends StatelessWidget {
  const _MiniArtwork({this.track, this.onTap});

  final MediaItem? track;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    final imageUrl = track?.imageUrl;
    final artSize = clamped(56, min: 40, max: 68);
    Widget buildArtworkFallback() => Container(
          width: artSize,
          height: artSize,
          color: ColorTokens.cardFillStrong(context),
          child: Icon(
            Icons.music_note,
            size: clamped(24, min: 16, max: 28),
          ),
        );
    final artwork = ClipRRect(
      borderRadius: BorderRadius.circular(
        clamped(14, min: 10, max: 18),
      ),
      child: SizedBox(
        width: artSize,
        height: artSize,
        child: ArtworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: buildArtworkFallback(),
        ),
      ),
    );
    if (onTap == null) {
      return artwork;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: artwork,
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.isPlaying,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
  });

  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    final iconSize = clamped(24, min: 18, max: 28);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          iconSize: iconSize,
          icon: const Icon(Icons.skip_previous),
          onPressed: onPrevious,
        ),
        FilledButton(
          onPressed: onPlayPause,
          style: FilledButton.styleFrom(
            shape: const CircleBorder(),
            padding: EdgeInsets.all(
              clamped(14, min: 10, max: 18),
            ),
          ),
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            size: clamped(22, min: 16, max: 26),
          ),
        ),
        IconButton(
          iconSize: iconSize,
          icon: const Icon(Icons.skip_next),
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _RepeatButton extends StatelessWidget {
  const _RepeatButton({
    required this.mode,
    required this.onTap,
  });

  final LoopMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    final isActive = mode != LoopMode.off;
    final icon = mode == LoopMode.one ? Icons.repeat_one : Icons.repeat;
    final color = isActive
        ? Theme.of(context).colorScheme.primary
        : ColorTokens.textSecondary(context, 0.6);
    return IconButton(
      icon: Icon(icon, color: color),
      iconSize: clamped(20, min: 16, max: 24),
      onPressed: onTap,
      tooltip: mode == LoopMode.one
          ? 'Repeat one'
          : mode == LoopMode.all
              ? 'Repeat all'
              : 'Repeat off',
    );
  }
}

void _openExpandedNowPlaying(BuildContext context) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withOpacity(0.55),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, __) => const _NowPlayingExpandedView(),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.16),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

class _NowPlayingExpandedView extends StatelessWidget {
  const _NowPlayingExpandedView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final track = state.nowPlaying;
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final isTouch = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.fuchsia);
    final padding = EdgeInsets.all(space(24).clamp(16.0, 32.0));
    final theme = Theme.of(context);
    final isFavorite = track == null ? false : state.isFavoriteTrack(track.id);
    final isUpdating =
        track == null ? false : state.isFavoriteTrackUpdating(track.id);
    final neighbors = _adjacentTracks(state.queue, track);
    final topBar = Row(
      children: [
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );

    Widget content = SafeArea(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: ColorTokens.backgroundGradient(context),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            topBar,
            SizedBox(height: space(18)),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxArt = math.min(
                    constraints.maxHeight * 0.72,
                    constraints.maxWidth * 0.86,
                  );
                  final artworkSize = maxArt.clamp(240.0, 620.0).toDouble();
                  return _SwipeTrackSwitcher(
                    current: track,
                    previous: neighbors.previous,
                    next: neighbors.next,
                    onNext: state.nextTrack,
                    onPrevious: state.previousTrack,
                    enabled: isTouch && track != null,
                    builder: (item) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Center(
                              child: _ExpandedArtwork(
                                track: item,
                                size: artworkSize,
                              ),
                            ),
                          ),
                          SizedBox(height: space(12)),
                          Text(
                            item?.title ?? 'Nothing queued',
                            style: theme.textTheme.headlineMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: space(8)),
                          _NowPlayingMeta(track: item),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: space(20)),
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  state.positionListenable,
                  state.durationListenable,
                ]),
                builder: (context, _) {
                  return _ProgressScrubber(
                    position: state.position,
                    duration: state.duration,
                    onSeek: state.seek,
                  );
                },
              ),
            ),
            SizedBox(height: space(18)),
            RepaintBoundary(
              child: Row(
                children: [
                  if (track != null)
                    _FavoriteButton(
                      track: track,
                      isFavorite: isFavorite,
                      isUpdating: isUpdating,
                    ),
                  if (track != null)
                    _RepeatButton(
                      mode: state.repeatMode,
                      onTap: state.toggleRepeatMode,
                    ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: _Controls(
                        isPlaying: state.isPlaying,
                        onPlayPause: state.togglePlayback,
                        onNext: state.nextTrack,
                        onPrevious: state.previousTrack,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.queue_music),
                    onPressed: () {
                      Navigator.of(context).maybePop();
                      state.selectLibraryView(LibraryView.queue);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (isTouch) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 300) {
            Navigator.of(context).maybePop();
          }
        },
        child: content,
      );
    }
    return Material(
      color: Colors.transparent,
      child: content,
    );
  }
}

class _ExpandedLink extends StatelessWidget {
  const _ExpandedLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _ExpandedArtwork extends StatelessWidget {
  const _ExpandedArtwork({required this.track, required this.size});

  final MediaItem? track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    final imageUrl = track?.imageUrl;
    Widget buildArtworkFallback() => Container(
          color: ColorTokens.cardFillStrong(context),
          child: Icon(
            Icons.music_note,
            size: clamped(60, min: 40, max: 84),
          ),
        );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          clamped(28, min: 18, max: 34),
        ),
        border: Border.all(color: ColorTokens.border(context, 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          clamped(28, min: 18, max: 34),
        ),
        child: ArtworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: buildArtworkFallback(),
        ),
      ),
    );
  }
}
