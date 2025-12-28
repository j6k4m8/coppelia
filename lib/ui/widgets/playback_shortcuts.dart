import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/library_view.dart';

/// Registers playback shortcuts for media keys.
class PlaybackShortcuts extends StatelessWidget {
  /// Creates the shortcut wrapper.
  const PlaybackShortcuts({super.key, required this.child});

  /// Child widget tree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final shortcuts = <ShortcutActivator, Intent>{
      LogicalKeySet(LogicalKeyboardKey.mediaPlayPause):
          TogglePlaybackIntent(),
      LogicalKeySet(LogicalKeyboardKey.mediaTrackNext): NextTrackIntent(),
      LogicalKeySet(LogicalKeyboardKey.mediaTrackPrevious):
          PreviousTrackIntent(),
      LogicalKeySet(LogicalKeyboardKey.space): TogglePlaybackWithSpaceIntent(),
    };
    if (state.settingsShortcutEnabled) {
      shortcuts[state.settingsShortcut.toKeySet()] = OpenSettingsIntent();
    }
    if (state.searchShortcutEnabled) {
      shortcuts[state.searchShortcut.toKeySet()] = FocusSearchIntent();
    }
    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          TogglePlaybackIntent: CallbackAction<TogglePlaybackIntent>(
            onInvoke: (_) => state.togglePlayback(),
          ),
          TogglePlaybackWithSpaceIntent:
              CallbackAction<TogglePlaybackWithSpaceIntent>(
            onInvoke: (_) {
              if (_isTextEditing()) {
                return null;
              }
              return state.togglePlayback();
            },
          ),
          NextTrackIntent: CallbackAction<NextTrackIntent>(
            onInvoke: (_) => state.nextTrack(),
          ),
          PreviousTrackIntent: CallbackAction<PreviousTrackIntent>(
            onInvoke: (_) => state.previousTrack(),
          ),
          OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
            onInvoke: (_) {
              if (state.session == null) {
                return null;
              }
              return state.selectLibraryView(LibraryView.settings);
            },
          ),
          FocusSearchIntent: CallbackAction<FocusSearchIntent>(
            onInvoke: (_) => state.requestSearchFocus(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }

  bool _isTextEditing() {
    final focus = FocusManager.instance.primaryFocus;
    final context = focus?.context;
    if (context == null) {
      return false;
    }
    final widget = context.widget;
    if (widget is EditableText) {
      return true;
    }
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}

/// Intent to toggle playback.
class TogglePlaybackIntent extends Intent {
  /// Creates a toggle playback intent.
  const TogglePlaybackIntent();
}

/// Intent to toggle playback with spacebar.
class TogglePlaybackWithSpaceIntent extends Intent {
  /// Creates a toggle playback intent for spacebar.
  const TogglePlaybackWithSpaceIntent();
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

/// Intent to open the settings view.
class OpenSettingsIntent extends Intent {
  /// Creates an open settings intent.
  const OpenSettingsIntent();
}

/// Intent to focus the search field.
class FocusSearchIntent extends Intent {
  /// Creates a focus search intent.
  const FocusSearchIntent();
}
