import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../core/color_tokens.dart';
import 'section_header.dart';
import 'track_row.dart';

/// Displays the current playback queue.
class QueueView extends StatelessWidget {
  /// Creates the queue view.
  const QueueView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final queue = state.queue;
    if (queue.isEmpty) {
      return Center(
        child: Text(
          'Queue is empty.',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: ColorTokens.textSecondary(context)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Queue',
          action: Row(
            children: [
              Text(
                '${queue.length} tracks',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: ColorTokens.textSecondary(context)),
              ),
              const SizedBox(width: 8),
              _HeaderAction(
                label: 'Clear',
                onTap: state.clearQueue,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: queue.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final track = queue[index];
              return TrackRow(
                track: track,
                index: index,
                isActive: state.nowPlaying?.id == track.id,
                onTap: () => state.playQueueIndex(index),
                onPlayNext: () => state.playNext(track),
                onAddToQueue: () => state.enqueueTrack(track),
                onAlbumTap: track.albumId == null
                    ? null
                    : () => state.selectAlbumById(track.albumId!),
                onArtistTap: track.artistIds.isEmpty
                    ? null
                    : () => state.selectArtistById(track.artistIds.first),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.label, required this.onTap});

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
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
