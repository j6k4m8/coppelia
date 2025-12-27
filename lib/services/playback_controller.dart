import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../models/media_item.dart';
import 'cache_store.dart';

/// Wraps audio playback with queue and state helpers.
class PlaybackController {
  /// Creates a playback controller.
  PlaybackController({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  /// Stream of playback position updates.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Stream of playback duration updates.
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Stream of play/pause state updates.
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Stream of the current queue index.
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  /// True when playback is active.
  bool get isPlaying => _player.playing;

  /// The current media item from the queue.
  MediaItem? get currentMediaItem {
    final tag = _player.sequenceState?.currentSource?.tag;
    return tag is MediaItem ? tag : null;
  }

  /// Sets the playback queue.
  Future<void> setQueue(
    List<MediaItem> items, {
    int startIndex = 0,
    CacheStore? cacheStore,
  }) async {
    final sources = <AudioSource>[];
    for (final item in items) {
      final file =
          cacheStore == null ? null : await cacheStore.getCachedAudio(item);
      if (file != null) {
        sources.add(AudioSource.file(file.path, tag: item));
      } else {
        sources.add(AudioSource.uri(Uri.parse(item.streamUrl), tag: item));
        unawaited(cacheStore?.prefetchAudio(item));
      }
    }
    final queue = ConcatenatingAudioSource(children: sources);
    await _player.setAudioSource(queue, initialIndex: startIndex);
  }

  /// Starts playback.
  Future<void> play() async {
    await _player.play();
  }

  /// Pauses playback.
  Future<void> pause() async {
    await _player.pause();
  }

  /// Seeks to a new position in the current track.
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Skips to the next track in the queue.
  Future<void> skipNext() async {
    await _player.seekToNext();
  }

  /// Skips to the previous track in the queue.
  Future<void> skipPrevious() async {
    await _player.seekToPrevious();
  }

  /// Stops playback and releases resources.
  Future<void> dispose() async {
    await _player.dispose();
  }
}
