import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:just_audio/just_audio.dart';

import '../models/media_item.dart';
import 'cache_store.dart';

/// Wraps audio playback with queue and state helpers.
class PlaybackController {
  PlaybackController({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool _gaplessPlayback = true;

  /// Stream of playback position updates.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Latest known playback position.
  Duration get position => _player.position;

  /// Stream of playback duration updates.
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Latest known duration from the player, if available.
  Duration? get duration => _player.duration;

  /// Stream of play/pause state updates.
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Stream of the current queue index.
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  /// True when playback is active.
  bool get isPlaying => _player.playing;

  /// The current media item from the queue.
  MediaItem? get currentMediaItem {
    final tag = _player.sequenceState.currentSource?.tag;
    if (tag is MediaItem) {
      return tag;
    }
    if (tag is audio_service.MediaItem) {
      final extras = tag.extras;
      if (extras == null) {
        return null;
      }
      final raw = extras['coppelia'];
      if (raw is Map) {
        return MediaItem.fromJson(
          raw.cast<String, dynamic>(),
        );
      }
    }
    return null;
  }

  /// Current queue index, if available.
  int? get currentIndex => _player.currentIndex;

  /// Sets the playback queue.
  Future<void> setQueue(
    List<MediaItem> items, {
    int startIndex = 0,
    Duration? startPosition,
    CacheStore? cacheStore,
    Map<String, String>? headers,
  }) async {
    if (items.isEmpty) {
      await _player.stop();
      await _player.clearAudioSources();
      return;
    }

    final targetIndex = startIndex.clamp(0, items.length - 1);

    // Build initial sources for immediate playback (current + next 2)
    final immediateCount = (targetIndex + 3).clamp(0, items.length);
    final immediateSources = <AudioSource>[];
    for (var i = 0; i < immediateCount; i++) {
      immediateSources.add(await _buildSource(items[i], cacheStore, headers));
    }

    // Start playback immediately with initial batch
    await _player.setAudioSources(
      immediateSources,
      initialIndex: targetIndex,
      initialPosition: startPosition,
      preload: _gaplessPlayback,
    );

    // Build and append remaining tracks in background batches
    if (immediateCount < items.length) {
      _buildRemainingQueue(
        items.sublist(immediateCount),
        cacheStore,
        headers,
      );
    }
  }

  Future<void> _buildRemainingQueue(
    List<MediaItem> remaining,
    CacheStore? cacheStore,
    Map<String, String>? headers,
  ) async {
    const batchSize = 20;
    for (var i = 0; i < remaining.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, remaining.length);
      final batch = remaining.sublist(i, end);
      final batchSources = await Future.wait(
        batch.map((item) => _buildSource(item, cacheStore, headers)),
      );
      for (final source in batchSources) {
        await _player.addAudioSource(source);
      }
    }
  }

  /// Enables or disables gapless playback behavior.
  Future<void> setGaplessPlayback(bool enabled) async {
    _gaplessPlayback = enabled;
    final sources = List<AudioSource>.from(_player.audioSources);
    if (sources.isEmpty) {
      return;
    }
    final currentIndex = _player.currentIndex;
    if (currentIndex == null) {
      return;
    }
    final position = _player.position;
    final wasPlaying = _player.playing;
    await _player.setAudioSources(
      sources,
      initialIndex: currentIndex,
      initialPosition: position,
      preload: _gaplessPlayback,
    );
    if (wasPlaying) {
      await _player.play();
    }
  }

  /// Appends a track to the current queue.
  Future<void> appendToQueue(
    MediaItem item, {
    CacheStore? cacheStore,
    Map<String, String>? headers,
  }) async {
    final source = await _buildSource(item, cacheStore, headers);
    await _player.addAudioSource(source);
  }

  /// Inserts a track after the current item.
  Future<void> insertNext(
    MediaItem item, {
    CacheStore? cacheStore,
    Map<String, String>? headers,
  }) async {
    final source = await _buildSource(item, cacheStore, headers);
    final insertIndex = (currentIndex ?? -1) + 1;
    final queueLength = _player.audioSources.length;
    final targetIndex = insertIndex.clamp(0, queueLength);
    await _player.insertAudioSource(targetIndex, source);
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

  /// Sets the playback loop mode.
  Future<void> setLoopMode(LoopMode mode) async {
    await _player.setLoopMode(mode);
  }

  /// Stops playback and releases resources.
  Future<void> dispose() async {
    await _player.dispose();
  }

  /// Clears upcoming items from the queue.
  Future<void> clearQueue({bool keepCurrent = true}) async {
    final sources = _player.audioSources;
    if (sources.isEmpty) {
      await _player.stop();
      return;
    }
    final index = currentIndex ?? -1;
    if (keepCurrent && index >= 0) {
      if (index + 1 < sources.length) {
        await _player.removeAudioSourceRange(index + 1, sources.length);
      }
      return;
    }
    await _player.stop();
    await _player.clearAudioSources();
  }

  Future<AudioSource> _buildSource(
    MediaItem item,
    CacheStore? cacheStore,
    Map<String, String>? headers,
  ) async {
    final tag = audio_service.MediaItem(
      id: item.id,
      title: item.title,
      album: item.album,
      artist:
          item.artists.isNotEmpty ? item.artists.join(', ') : 'Unknown Artist',
      duration: item.duration,
      artUri: item.imageUrl == null ? null : Uri.parse(item.imageUrl!),
      extras: <String, dynamic>{
        'coppelia': item.toJson(),
      },
    );
    final file = cacheStore == null
        ? null
        : await cacheStore.getCachedAudio(item, touch: false);
    if (file != null) {
      return AudioSource.file(file.path, tag: tag);
    }
    return AudioSource.uri(
      Uri.parse(item.streamUrl),
      headers: headers,
      tag: tag,
    );
  }
}
