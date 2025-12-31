import 'dart:io';

import 'package:flutter/services.dart';

import '../models/media_item.dart';

/// Bridges playback metadata to macOS Now Playing.
class NowPlayingService {
  static const MethodChannel _channel =
      MethodChannel('coppelia/now_playing');

  /// Binds remote media commands to callbacks.
  void bind({
    required VoidCallback onPlay,
    required VoidCallback onPause,
    required VoidCallback onToggle,
    required VoidCallback onNext,
    required VoidCallback onPrevious,
    required ValueChanged<Duration> onSeek,
  }) {
    if (!Platform.isMacOS && !Platform.isIOS) {
      return;
    }
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'play':
          onPlay();
          break;
        case 'pause':
          onPause();
          break;
        case 'toggle':
          onToggle();
          break;
        case 'next':
          onNext();
          break;
        case 'previous':
          onPrevious();
          break;
        case 'seek':
          final args = call.arguments as Map<dynamic, dynamic>? ?? const {};
          final raw = args['position'] as num? ?? 0;
          onSeek(Duration(milliseconds: (raw * 1000).round()));
          break;
        default:
          break;
      }
    });
  }

  /// Updates the system Now Playing metadata.
  Future<void> update({
    required MediaItem track,
    required Duration position,
    required Duration duration,
    required bool isPlaying,
  }) async {
    if (!Platform.isMacOS && !Platform.isIOS) {
      return;
    }
    final artist = track.artists.isNotEmpty
        ? track.artists.join(', ')
        : 'Unknown Artist';
    await _channel.invokeMethod('update', {
      'id': track.id,
      'title': track.title,
      'artist': artist,
      'album': track.album,
      'duration': duration.inMilliseconds / 1000,
      'position': position.inMilliseconds / 1000,
      'isPlaying': isPlaying,
      'imageUrl': track.imageUrl,
    });
  }

  /// Clears the system Now Playing metadata.
  Future<void> clear() async {
    if (!Platform.isMacOS && !Platform.isIOS) {
      return;
    }
    await _channel.invokeMethod('clear');
  }
}
