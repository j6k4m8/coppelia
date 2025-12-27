import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

/// Registers playback shortcuts for media keys.
class PlaybackShortcuts extends StatelessWidget {
  /// Creates the shortcut wrapper.
  const PlaybackShortcuts({super.key, required this.child});

  /// Child widget tree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Shortcuts(
      shortcuts: const {
        LogicalKeySet(LogicalKeyboardKey.mediaPlayPause): TogglePlaybackIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaTrackNext): NextTrackIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaTrackPrevious):
            PreviousTrackIntent(),
        LogicalKeySet(LogicalKeyboardKey.space): TogglePlaybackIntent(),
      },
      child: Actions(
        actions: {
          TogglePlaybackIntent: CallbackAction<TogglePlaybackIntent>(
            onInvoke: (_) => state.togglePlayback(),
          ),
          NextTrackIntent: CallbackAction<NextTrackIntent>(
            onInvoke: (_) => state.nextTrack(),
          ),
          PreviousTrackIntent: CallbackAction<PreviousTrackIntent>(
            onInvoke: (_) => state.previousTrack(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

/// Intent to toggle playback.
class TogglePlaybackIntent extends Intent {
  /// Creates a toggle playback intent.
  const TogglePlaybackIntent();
}

/// Intent to move to the next track.
class NextTrackIntent extends Intent {
  /// Creates a next track intent.
  const NextTrackIntent();
}

/// Intent to move to the previous track.
class PreviousTrackIntent extends Intent {
  /// Creates a previous track intent.
  const PreviousTrackIntent();
}
