import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/media_item.dart';
import '../../state/app_state.dart';

/// Right-side panel for playback and queue control.
class NowPlayingPanel extends StatelessWidget {
  /// Creates the now playing panel.
  const NowPlayingPanel({super.key});

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
            'Queue',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: state.queue.length,
              itemBuilder: (context, index) {
                final item = state.queue[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: item.id == track?.id
                              ? Colors.white
                              : Colors.white60,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
