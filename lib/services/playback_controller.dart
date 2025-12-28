import 'package:just_audio/just_audio.dart';

import '../models/media_item.dart';
import 'cache_store.dart';

/// Wraps audio playback with queue and state helpers.
class PlaybackController {
  /// Creates a playback controller.
  PlaybackController({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  ConcatenatingAudioSource? _queueSource;

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

  /// Current queue index, if available.
  int? get currentIndex => _player.currentIndex;

  /// Sets the playback queue.
  Future<void> setQueue(
    List<MediaItem> items, {
    int startIndex = 0,
    CacheStore? cacheStore,
    Map<String, String>? headers,
  }) async {
    final sources = <AudioSource>[];
    for (final item in items) {
      sources.add(await _buildSource(item, cacheStore, headers));
    }
    _queueSource = ConcatenatingAudioSource(children: sources);
    await _player.setAudioSource(_queueSource!, initialIndex: startIndex);
  }

  /// Appends a track to the current queue.
  Future<void> appendToQueue(
    MediaItem item, {
    CacheStore? cacheStore,
    Map<String, String>? headers,
  }) async {
    final source = await _buildSource(item, cacheStore, headers);
    await _queueSource?.add(source);
  }

  /// Inserts a track after the current item.
  Future<void> insertNext(
    MediaItem item, {
    CacheStore? cacheStore,
    Map<String, String>? headers,
  }) async {
    final source = await _buildSource(item, cacheStore, headers);
    final insertIndex = (currentIndex ?? -1) + 1;
    final queueLength = _queueSource?.length ?? 0;
    final targetIndex = insertIndex.clamp(0, queueLength);
    await _queueSource?.insert(targetIndex, source);
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

  /// Jumps to a specific index in the queue.
  Future<void> seekToIndex(int index) async {
    await _player.seek(Duration.zero, index: index);
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

  /// Clears upcoming items from the queue.
  Future<void> clearQueue({bool keepCurrent = true}) async {
    final source = _queueSource;
    if (source == null || source.length == 0) {
      await _player.stop();
      final emptyQueue = ConcatenatingAudioSource(children: []);
      await _player.setAudioSource(emptyQueue);
      _queueSource = emptyQueue;
      return;
    }
    final index = currentIndex ?? -1;
    if (keepCurrent && index >= 0) {
      if (index + 1 < source.length) {
        await source.removeRange(index + 1, source.length);
      }
      return;
    }
    await _player.stop();
    final emptyQueue = ConcatenatingAudioSource(children: []);
    await _player.setAudioSource(emptyQueue);
    _queueSource = emptyQueue;
  }

  Future<AudioSource> _buildSource(
    MediaItem item,
    CacheStore? cacheStore,
    Map<String, String>? headers,
  ) async {
    final file = cacheStore == null
        ? null
        : await cacheStore.getCachedAudio(item, touch: false);
    if (file != null) {
      return AudioSource.file(file.path, tag: item);
    }
    return AudioSource.uri(
      Uri.parse(item.streamUrl),
      headers: headers,
      tag: item,
    );
  }
}
