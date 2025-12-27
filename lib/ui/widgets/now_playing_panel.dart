import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../core/formatters.dart';
import '../../models/media_item.dart';
import '../../state/app_state.dart';
import '../../state/now_playing_layout.dart';

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
          Text(
            'Now playing',
            style: Theme.of(context).textTheme.titleMedium,
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
          _ProgressBar(
            position: state.position,
            duration: state.duration,
            onSeek: state.seek,
          ),
          const SizedBox(height: 12),
          _Controls(
            isPlaying: state.isPlaying,
            onPlayPause: state.togglePlayback,
            onNext: state.nextTrack,
            onPrevious: state.previousTrack,
          ),
          if (track != null) ...[
            const SizedBox(height: 16),
            _MiniWaveform(trackId: track.id),
          ],
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
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: BoxDecoration(
        color: ColorTokens.panelBackground(context),
        border: Border(
          top: BorderSide(color: ColorTokens.border(context)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _MiniArtwork(track: track),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
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
                ),
              ),
              IconButton(
                icon: const Icon(Icons.queue_music),
                onPressed: () => _showQueue(context, state),
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
          _ProgressBar(
            position: state.position,
            duration: state.duration,
            onSeek: state.seek,
          ),
          if (track != null) ...[
            const SizedBox(height: 8),
            _MiniWaveform(trackId: track.id, compact: true),
          ],
        ],
      ),
    );
  }

  Future<void> _showQueue(BuildContext context, AppState state) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10131A),
          title: const Text('Queue'),
          content: SizedBox(
            width: 360,
            height: 320,
            child: _QueueList(
              queue: state.queue,
              nowPlaying: state.nowPlaying,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: track!.artistIds.isEmpty
                ? null
                : () => state.selectArtistById(track!.artistIds.first),
            child: Text(
              artistLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  track!.artistIds.isEmpty ? baseStyle : linkStyle,
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
      ],
    );
  }
}

class _MiniWaveform extends StatelessWidget {
  const _MiniWaveform({
    required this.trackId,
    this.compact = false,
  });

  final String trackId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bars = _buildBars(trackId, compact ? 18 : 26);
    return SizedBox(
      height: compact ? 26 : 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: bars
            .map(
              (height) => Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    height: height,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  List<double> _buildBars(String seed, int count) {
    final random = Random(seed.hashCode);
    return List<double>.generate(
      count,
      (_) => 8 + random.nextDouble() * (compact ? 14 : 20),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({this.track});

  final MediaItem? track;

  @override
  Widget build(BuildContext context) {
    final imageUrl = track?.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 1,
        child: imageUrl == null
            ? Container(
                color: ColorTokens.cardFillStrong(context),
                child: const Icon(Icons.music_note, size: 48),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 56,
        height: 56,
        child: imageUrl == null
            ? Container(
                color: ColorTokens.cardFillStrong(context),
                child: const Icon(Icons.music_note, size: 24),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final maxValue = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final rawValue = position.inMilliseconds.toDouble();
    final currentValue = rawValue < 0
        ? 0.0
        : (rawValue > maxValue ? maxValue : rawValue);
    return Column(
      children: [
        Slider(
          value: currentValue,
          min: 0,
          max: maxValue,
          onChanged: (value) => onSeek(Duration(milliseconds: value.toInt())),
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
