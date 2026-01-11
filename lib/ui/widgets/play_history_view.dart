import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import 'track_list_view.dart';

/// Displays recent playback history.
class PlayHistoryView extends StatelessWidget {
  /// Creates the play history view.
  const PlayHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final history = state.playHistory;
    return TrackListView(
      title: 'Playback / History',
      subtitle: '${history.length} tracks',
      emptyMessage: 'No play history yet.',
      tracks: history,
      onTapTrack: (track, _) => state.playFromList(history, track),
    );
  }
}
