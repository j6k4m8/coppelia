import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'playback_controller.dart';

/// Wraps the [PlaybackController] to provide MPRIS support on Linux.
class LinuxAudioHandler extends BaseAudioHandler with SeekHandler {
  LinuxAudioHandler(this._playback) {
    _init();
  }

  final PlaybackController _playback;

  void _init() {
    _playback.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[playerState.processingState]!;

      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: processingState,
        playing: isPlaying,
        updatePosition: _playback.position,
        bufferedPosition: _playback.duration ?? Duration.zero,
        speed: 1.0,
      ));
    });

    _playback.currentIndexStream.listen((_) {
      _updateMediaItem();
    });
    _playback.durationStream.listen((_) {
      _updateMediaItem();
    });
  }

  void _updateMediaItem() {
    final item = _playback.currentMediaItem;
    if (item != null) {
      mediaItem.add(MediaItem(
        id: item.id,
        title: item.title,
        album: item.album,
        artist: item.artists.isNotEmpty ? item.artists.join(', ') : 'Unknown Artist',
        duration: item.duration,
        artUri: item.imageUrl == null ? null : Uri.parse(item.imageUrl!),
      ));
    } else {
      mediaItem.add(null);
    }
  }

  @override
  Future<void> play() => _playback.play();

  @override
  Future<void> pause() => _playback.pause();

  @override
  Future<void> seek(Duration position) => _playback.seek(position);

  @override
  Future<void> stop() => _playback.pause();

  @override
  Future<void> skipToNext() => _playback.skipNext();

  @override
  Future<void> skipToPrevious() => _playback.skipPrevious();
}
