import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../state/app_state.dart';
import 'header_action.dart';
import 'track_list_view.dart';

/// Displays the current playback queue.
class QueueView extends StatelessWidget {
  /// Creates the queue view.
  const QueueView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final queue = state.queue;
    return TrackListView(
      title: 'Queue',
      trailing: Row(
        children: [
          Text(
            '${queue.length} tracks',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: ColorTokens.textSecondary(context)),
          ),
          const SizedBox(width: 8),
          HeaderAction(
            label: 'Clear',
            onTap: state.clearQueue,
          ),
        ],
      ),
      emptyMessage: 'Queue is empty.',
      tracks: queue,
      onTapTrack: (_, index) => state.playQueueIndex(index),
      reorderable: true,
      onReorder: state.reorderQueue,
      showDragHandle: true,
    );
  }
}
