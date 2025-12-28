import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../core/formatters.dart';
import '../../models/media_item.dart';
import '../../state/app_state.dart';
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

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.layout});

  final NowPlayingLayout layout;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final track = state.nowPlaying;
    final isFavorite =
        track == null ? false : state.isFavoriteTrack(track.id);
    final isUpdating =
        track == null ? false : state.isFavoriteTrackUpdating(track.id);
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
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
          const SizedBox(height: 20),
          _Artwork(track: track),
          const SizedBox(height: 20),
          Text(
            track?.title ?? 'Nothing queued',
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          _NowPlayingMeta(track: track),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: Listenable.merge([
              state.positionListenable,
              state.durationListenable,
              state.isBufferingListenable,
            ]),
            builder: (context, _) {
              final shouldPulse = track != null &&
                  !state.isNowPlayingCached &&
                  (state.isBuffering || state.isPreparingPlayback);
              return _ProgressScrubber(
                position: state.position,
                duration: state.duration,
                onSeek: state.seek,
                isBuffering: shouldPulse,
              );
            },
          ),
          const SizedBox(height: 12),
          Center(
            child: _Controls(
              isPlaying: state.isPlaying,
              onPlayPause: state.togglePlayback,
              onNext: state.nextTrack,
              onPrevious: state.previousTrack,
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: ColorTokens.border(context, 0.12)),
          const SizedBox(height: 16),
          Text(
            'Playing next',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: ColorTokens.textSecondary(context, 0.7)),
          ),
          const SizedBox(height: 12),
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
    final track = state.nowPlaying;
    final isFavorite =
        track == null ? false : state.isFavoriteTrack(track.id);
    final isUpdating =
        track == null ? false : state.isFavoriteTrackUpdating(track.id);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: BoxDecoration(
        color: ColorTokens.panelBackground(context),
        border: Border(
          top: BorderSide(color: ColorTokens.border(context)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track?.title ?? 'Nothing queued',
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              _NowPlayingMeta(track: track),
            ],
          );
          if (isNarrow) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _MiniArtwork(track: track),
                    const SizedBox(width: 12),
                    Expanded(child: titleBlock),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (track != null)
                      _FavoriteButton(
                        track: track,
                        isFavorite: isFavorite,
                        isUpdating: isUpdating,
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
                const SizedBox(height: 6),
                AnimatedBuilder(
                  animation: Listenable.merge([
                    state.positionListenable,
                    state.durationListenable,
                    state.isBufferingListenable,
                  ]),
                  builder: (context, _) {
                    final shouldPulse = track != null &&
                        !state.isNowPlayingCached &&
                        (state.isBuffering || state.isPreparingPlayback);
                    return _ProgressScrubber(
                      position: state.position,
                      duration: state.duration,
                      onSeek: state.seek,
                      compact: true,
                      isBuffering: shouldPulse,
                    );
                  },
                ),
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _MiniArtwork(track: track),
                  const SizedBox(width: 16),
                  Expanded(child: titleBlock),
                  if (track != null)
                    _FavoriteButton(
                      track: track,
                      isFavorite: isFavorite,
                      isUpdating: isUpdating,
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
              const SizedBox(height: 6),
              AnimatedBuilder(
                animation: Listenable.merge([
                  state.positionListenable,
                  state.durationListenable,
                  state.isBufferingListenable,
                ]),
                builder: (context, _) {
                  final shouldPulse = track != null &&
                      !state.isNowPlayingCached &&
                      (state.isBuffering || state.isPreparingPlayback);
                  return _ProgressScrubber(
                    position: state.position,
                    duration: state.duration,
                    onSeek: state.seek,
                    compact: true,
                    isBuffering: shouldPulse,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

}

class _QueueList extends StatelessWidget {
  const _QueueList({required this.queue, required this.nowPlaying});

  final List<MediaItem> queue;
  final MediaItem? nowPlaying;

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.only(bottom: 8),
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
        const SizedBox(width: 6),
        Text(
          '•',
          style: TextStyle(
            color: ColorTokens.textSecondary(context, 0.4),
          ),
        ),
        const SizedBox(width: 6),
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
    if (isUpdating) {
      return SizedBox(
        width: 18,
        height: 18,
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
          width: 24,
          height: 24,
          child: Center(
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 16,
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

class _ProgressScrubber extends StatefulWidget {
  const _ProgressScrubber({
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.isBuffering,
    this.compact = false,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final bool isBuffering;
  final bool compact;

  @override
  State<_ProgressScrubber> createState() => _ProgressScrubberState();
}

class _ProgressScrubberState extends State<_ProgressScrubber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isBuffering) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _ProgressScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBuffering && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isBuffering && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds;
    final currentMs = widget.position.inMilliseconds.clamp(0, totalMs);
    final value = totalMs > 0 ? currentMs / totalMs : 0.0;
    final height = widget.compact ? 32.0 : 40.0;
    final trackHeight = widget.compact ? 4.0 : 6.0;
    final thumbRadius = widget.compact ? 6.0 : 8.0;
    final overlayRadius = widget.compact ? 10.0 : 12.0;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final pulse = widget.isBuffering ? _controller.value : 0.0;
              final activeColor = Color.lerp(
                    primary.withOpacity(0.6),
                    primary,
                    pulse,
                  ) ??
                  primary;
              final inactiveColor = Color.lerp(
                    primary.withOpacity(0.14),
                    primary.withOpacity(0.28),
                    pulse,
                  ) ??
                  primary.withOpacity(0.2);
              return SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: trackHeight,
                  activeTrackColor: activeColor,
                  inactiveTrackColor: inactiveColor,
                  thumbColor: activeColor,
                  overlayColor: activeColor.withOpacity(0.15),
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
                          widget.onSeek(Duration(milliseconds: targetMs));
                        },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formatDuration(widget.position),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: ColorTokens.textSecondary(context)),
            ),
            Text(
              formatDuration(widget.duration),
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

class _Artwork extends StatelessWidget {
  const _Artwork({this.track});

  final MediaItem? track;

  @override
  Widget build(BuildContext context) {
    final imageUrl = track?.imageUrl;
    Widget buildArtworkFallback() => Container(
          color: ColorTokens.cardFillStrong(context),
          child: const Icon(Icons.music_note, size: 48),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 1,
        child: ArtworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: buildArtworkFallback(),
        ),
      ),
    );
  }
}

class _MiniArtwork extends StatelessWidget {
  const _MiniArtwork({this.track});

  final MediaItem? track;

  @override
  Widget build(BuildContext context) {
    final imageUrl = track?.imageUrl;
    Widget buildArtworkFallback() => Container(
          width: 56,
          height: 56,
          color: ColorTokens.cardFillStrong(context),
          child: const Icon(Icons.music_note, size: 24),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 56,
        height: 56,
        child: ArtworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: buildArtworkFallback(),
        ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          onPressed: onPrevious,
        ),
        FilledButton(
          onPressed: onPlayPause,
          style: FilledButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(14),
          ),
          child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          onPressed: onNext,
        ),
      ],
    );
  }
}
