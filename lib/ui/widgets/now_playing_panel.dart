import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
        color: const Color(0xFF0F1218),
        border: Border(
          left: BorderSide(color: Colors.white.withOpacity(0.08)),
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
          Text(
            track?.subtitle ?? 'Pick a track to start listening.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white60),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
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
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
          Text(
            'Playing next',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Colors.white70),
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
        color: const Color(0xFF0F1218),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
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
                    Text(
                      track?.subtitle ?? 'Pick a track to start listening.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white60),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
            ?.copyWith(color: Colors.white60),
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
                      ? Colors.white
                      : Colors.white60,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
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
                color: Colors.white10,
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
                color: Colors.white10,
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
                  ?.copyWith(color: Colors.white60),
            ),
            Text(
              formatDuration(duration),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white60),
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
