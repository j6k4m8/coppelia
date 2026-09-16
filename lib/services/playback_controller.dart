import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart' as media_kit;

import '../models/media_item.dart';
import 'cache_store.dart';
import 'log_service.dart';

/// Wraps audio playback with queue and state helpers.
///
/// Android/iOS stay on `just_audio` so native mobile playback, notifications,
/// and platform media controls keep working. Desktop uses `media_kit` directly
/// because the `just_audio_media_kit` shim does not reliably seek or report
/// position for some formats.
class PlaybackController {
  PlaybackController({
    AudioPlayer? audioPlayer,
    media_kit.Player? mediaKitPlayer,
    bool? useNativeJustAudio,
  }) : _engine = (useNativeJustAudio ?? _useNativeJustAudioByDefault)
            ? _JustAudioPlaybackEngine(player: audioPlayer)
            : _MediaKitPlaybackEngine(player: mediaKitPlayer);

  final _PlaybackEngine _engine;

  static bool get _useNativeJustAudioByDefault =>
      Platform.isAndroid || Platform.isIOS;

  /// Stream of playback position updates.
  Stream<Duration> get positionStream => _engine.positionStream;

  /// Latest known playback position.
  Duration get position => _engine.position;

  /// Stream of playback duration updates.
  Stream<Duration?> get durationStream => _engine.durationStream;

  /// Latest known duration from the player, if available.
  Duration? get duration => _engine.duration;

  /// Stream of play/pause state updates.
  Stream<PlayerState> get playerStateStream => _engine.playerStateStream;

  /// Stream of the current queue index.
  Stream<int?> get currentIndexStream => _engine.currentIndexStream;

  /// True when playback is active.
  bool get isPlaying => _engine.isPlaying;

  /// Latest playback processing state.
  ProcessingState get processingState => _engine.processingState;

  /// The current media item from the queue.
  MediaItem? get currentMediaItem => _engine.currentMediaItem;

  /// Current queue index, if available.
  int? get currentIndex => _engine.currentIndex;

  /// Sets the playback queue.
  Future<void> setQueue(
    List<MediaItem> items, {
    int startIndex = 0,
    Duration? startPosition,
    CacheStore? cacheStore,
    Map<String, String>? headers,
  }) {
    return _engine.setQueue(
      items,
      startIndex: startIndex,
      startPosition: startPosition,
      cacheStore: cacheStore,
      headers: headers,
    );
  }

  /// Enables or disables gapless playback behavior.
  Future<void> setGaplessPlayback(bool enabled) {
    return _engine.setGaplessPlayback(enabled);
  }

  /// Appends a track to the current queue.
  Future<void> appendToQueue(
    MediaItem item, {
    CacheStore? cacheStore,
    Map<String, String>? headers,
  }) {
    return _engine.appendToQueue(
      item,
      cacheStore: cacheStore,
      headers: headers,
    );
  }

  /// Inserts a track after the current item.
  Future<void> insertNext(
    MediaItem item, {
    CacheStore? cacheStore,
    Map<String, String>? headers,
  }) {
    return _engine.insertNext(
      item,
      cacheStore: cacheStore,
      headers: headers,
    );
  }

  /// Starts playback.
  Future<void> play() => _engine.play();

  /// Pauses playback.
  Future<void> pause() => _engine.pause();

  /// Seeks to a new position in the current track.
  Future<void> seek(Duration position) => _engine.seek(position);

  /// Jumps to a specific index in the queue.
  Future<void> seekToIndex(int index) => _engine.seekToIndex(index);

  /// Skips to the next track in the queue.
  Future<void> skipNext() => _engine.skipNext();

  /// Skips to the previous track in the queue.
  Future<void> skipPrevious() => _engine.skipPrevious();

  /// Sets the playback loop mode.
  Future<void> setLoopMode(LoopMode mode) => _engine.setLoopMode(mode);

  /// Clears upcoming items from the queue.
  Future<void> clearQueue({bool keepCurrent = true}) {
    return _engine.clearQueue(keepCurrent: keepCurrent);
  }

  /// Stops playback and releases resources.
  Future<void> dispose() => _engine.dispose();
}

abstract class _PlaybackEngine {
  Stream<Duration> get positionStream;
  Duration get position;
  Stream<Duration?> get durationStream;
  Duration? get duration;
  Stream<PlayerState> get playerStateStream;
  Stream<int?> get currentIndexStream;
  bool get isPlaying;
  ProcessingState get processingState;
  MediaItem? get currentMediaItem;
  int? get currentIndex;

  Future<void> setQueue(
    List<MediaItem> items, {
    int startIndex = 0,
    Duration? startPosition,
    CacheStore? cacheStore,
    Map<String, String>? headers,
  });

  Future<void> setGaplessPlayback(bool enabled);

  Future<void> appendToQueue(
    MediaItem item, {
    CacheStore? cacheStore,
    Map<String, String>? headers,
  });

  Future<void> insertNext(
    MediaItem item, {
    CacheStore? cacheStore,
    Map<String, String>? headers,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> seekToIndex(int index);
  Future<void> skipNext();
  Future<void> skipPrevious();
  Future<void> setLoopMode(LoopMode mode);
  Future<void> clearQueue({bool keepCurrent = true});
  Future<void> dispose();
}

class _JustAudioPlaybackEngine implements _PlaybackEngine {
  _JustAudioPlaybackEngine({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  int _queueRevision = 0;
  bool _gaplessPlayback = true;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Duration get position => _player.position;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Duration? get duration => _player.duration;

  @override
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  @override
  bool get isPlaying => _player.playing;

  @override
  ProcessingState get processingState => _player.processingState;

  @override
  MediaItem? get currentMediaItem {
    final tag = _player.sequenceState.currentSource?.tag;
    if (tag is MediaItem) {
      return tag;
    }
    if (tag is audio_service.MediaItem) {
      final extras = tag.extras;
      final raw = extras?['coppelia'];
      if (raw is Map) {
        return MediaItem.fromJson(raw.cast<String, dynamic>());
      }
    }
    return null;
  }

  @override
  int? get currentIndex => _player.currentIndex;

  @override
  Future<void> setQueue(
    List<MediaItem> items, {
    int startIndex = 0,
    Duration? startPosition,
    CacheStore? cacheStore,
    Map<String, String>? headers,
  }) async {
    final revision = ++_queueRevision;
    final logService = await LogService.instance;
    if (revision != _queueRevision) return;
    const batchSize = 20;
    final sources = <AudioSource>[];
    final startTime = DateTime.now();

    for (var i = 0; i < items.length; i += batchSize) {
      if (revision != _queueRevision) return;
      final batchStart = DateTime.now();
      final end = (i + batchSize).clamp(0, items.length);
      final batch = items.sublist(i, end);
      final batchSources = await Future.wait(
        batch.map((item) => _buildSource(item, cacheStore, headers)),
      );
      if (revision != _queueRevision) return;
      sources.addAll(batchSources);
      final batchTime = DateTime.now().difference(batchStart).inMilliseconds;
      await logService.info(
        'Queue batch ${i ~/ batchSize + 1}: '
        '${batch.length} tracks in ${batchTime}ms',
      );
      if (revision != _queueRevision) return;
    }

    final totalTime = DateTime.now().difference(startTime).inMilliseconds;
    await logService.info(
      'Total queue build: ${items.length} tracks in ${totalTime}ms',
    );
    if (revision != _queueRevision) return;

    if (sources.isEmpty) {
      await _player.stop();
      if (revision != _queueRevision) return;
      await _player.clearAudioSources();
      return;
    }

    final targetIndex = startIndex.clamp(0, sources.length - 1);
    await _player.setAudioSources(
      sources,
      initialIndex: targetIndex,
      initialPosition: startPosition,
      preload: _gaplessPlayback,
    );
  }

  @override
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

  @override
  Future<void> appendToQueue(
    MediaItem item, {
    CacheStore? cacheStore,
    Map<String, String>? headers,
  }) async {
    final revision = _queueRevision;
    final source = await _buildSource(item, cacheStore, headers);
    if (revision != _queueRevision) return;
    await _player.addAudioSource(source);
  }

  @override
  Future<void> insertNext(
    MediaItem item, {
    CacheStore? cacheStore,
    Map<String, String>? headers,
  }) async {
    final revision = _queueRevision;
    final source = await _buildSource(item, cacheStore, headers);
    if (revision != _queueRevision) return;
    final insertIndex = (_player.currentIndex ?? -1) + 1;
    final queueLength = _player.audioSources.length;
    final targetIndex = insertIndex.clamp(0, queueLength);
    await _player.insertAudioSource(targetIndex, source);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> seekToIndex(int index) {
    return _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> skipNext() => _player.seekToNext();

  @override
  Future<void> skipPrevious() => _player.seekToPrevious();

  @override
  Future<void> setLoopMode(LoopMode mode) => _player.setLoopMode(mode);

  @override
  Future<void> clearQueue({bool keepCurrent = true}) async {
    final revision = ++_queueRevision;
    final sources = _player.audioSources;
    if (sources.isEmpty) {
      await _player.stop();
      return;
    }
    final index = _player.currentIndex ?? -1;
    if (keepCurrent && index >= 0) {
      if (index + 1 < sources.length) {
        await _player.removeAudioSourceRange(index + 1, sources.length);
      }
      return;
    }
    await _player.stop();
    if (revision != _queueRevision) return;
    await _player.clearAudioSources();
  }

  @override
  Future<void> dispose() => _player.dispose();

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
      extras: <String, dynamic>{'coppelia': item.toJson()},
    );
    final file = cacheStore == null
        ? null
        : await cacheStore.getCachedAudio(item, touch: false);
    final logService = await LogService.instance;
    if (file != null) {
      await logService.info('_buildSource: FILE "${item.title}" ${file.path}');
      return AudioSource.file(file.path, tag: tag);
    }
    await logService
        .info('_buildSource: URI "${item.title}" ${item.streamUrl}');
    return AudioSource.uri(
      Uri.parse(item.streamUrl),
      headers: headers,
      tag: tag,
    );
  }
}

class _MediaKitPlaybackEngine implements _PlaybackEngine {
  _MediaKitPlaybackEngine({media_kit.Player? player})
      : _player = player ?? _createPlayer() {
    _setPositionAnchor(_player.state.position, index: _currentBackendIndex);
    _subscriptions.addAll([
      _player.stream.position.listen(_handleBackendPosition),
      _player.stream.duration.listen((_) => _emitDuration()),
      _player.stream.playing.listen((_) => _emitPlayerState()),
      _player.stream.buffering.listen((_) => _emitPlayerState()),
      _player.stream.completed.listen(_handleCompleted),
      _player.stream.playlist.listen(_handleBackendPlaylist),
      _player.stream.error.listen((error) async {
        final log = await LogService.instance;
        await log.warning('media_kit playback error: $error');
      }),
    ]);
  }

  final media_kit.Player _player;
  int _queueRevision = 0;
  final Stopwatch _positionClock = Stopwatch()..start();
  final List<MediaItem> _queueItems = [];
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<PlayerState> _playerStateController =
      StreamController<PlayerState>.broadcast();
  final StreamController<int?> _currentIndexController =
      StreamController<int?>.broadcast();

  CacheStore? _cacheStore;
  Map<String, String>? _headers;
  LoopMode _loopMode = LoopMode.off;
  Duration _positionAnchor = Duration.zero;
  Duration _positionAnchorClock = Duration.zero;
  int? _positionAnchorIndex;
  bool _isLoading = false;
  bool _isDisposed = false;
  bool _completed = false;

  static const _autoAdvanceGrace = Duration(milliseconds: 500);

  static media_kit.Player _createPlayer() {
    media_kit.MediaKit.ensureInitialized();
    return media_kit.Player();
  }

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Duration get position => _projectedPosition(_positionClock.elapsed);

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Duration? get duration => _durationForIndex(currentIndex);

  @override
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  @override
  Stream<int?> get currentIndexStream => _currentIndexController.stream;

  @override
  bool get isPlaying => _player.state.playing;

  @override
  ProcessingState get processingState => _processingState;

  @override
  MediaItem? get currentMediaItem {
    final index = currentIndex;
    if (index == null || index < 0 || index >= _queueItems.length) {
      return null;
    }
    return _queueItems[index];
  }

  @override
  int? get currentIndex => _positionAnchorIndex ?? _currentBackendIndex;

  int? get _currentBackendIndex {
    final playlist = _player.state.playlist;
    if (playlist.medias.isEmpty || playlist.index < 0) {
      return null;
    }
    return playlist.index;
  }

  @override
  Future<void> setQueue(
    List<MediaItem> items, {
    int startIndex = 0,
    Duration? startPosition,
    CacheStore? cacheStore,
    Map<String, String>? headers,
  }) async {
    final revision = ++_queueRevision;
    _cacheStore = cacheStore;
    _headers = headers == null ? null : Map<String, String>.from(headers);
    _queueItems
      ..clear()
      ..addAll(items);

    if (items.isEmpty) {
      await _player.stop();
      if (revision != _queueRevision) return;
      await _player.open(const media_kit.Playlist([]), play: false);
      if (revision != _queueRevision) return;
      _setPositionAnchor(Duration.zero, index: null);
      _emitAll();
      return;
    }

    final targetIndex = startIndex.clamp(0, items.length - 1);
    final targetPosition = _clampPosition(
      startPosition ?? Duration.zero,
      index: targetIndex,
    );
    final playlist = media_kit.Playlist(
      await _buildMediaList(items),
      index: targetIndex,
    );
    if (revision != _queueRevision) return;
    _isLoading = true;
    _completed = false;
    _setPositionAnchor(targetPosition, index: targetIndex);
    _emitAll();
    await _player.open(playlist, play: false);
    if (revision != _queueRevision) return;
    if (targetPosition > Duration.zero) {
      await _player.seek(targetPosition);
      if (revision != _queueRevision) return;
    }
    _isLoading = false;
    _setPositionAnchor(targetPosition, index: targetIndex);
    _emitAll();
  }

  @override
  Future<void> setGaplessPlayback(bool enabled) async {
    // media_kit does not expose just_audio's preload flag. Keep the method so
    // existing settings remain harmless on desktop.
  }

  @override
  Future<void> appendToQueue(
    MediaItem item, {
    CacheStore? cacheStore,
    Map<String, String>? headers,
  }) async {
    final revision = _queueRevision;
    if (cacheStore != null) {
      _cacheStore = cacheStore;
    }
    if (headers != null) {
      _headers = Map<String, String>.from(headers);
    }
    final media = await _buildMedia(item, _cacheStore, _headers);
    if (revision != _queueRevision) return;
    _queueItems.add(item);
    await _player.add(media);
    if (revision != _queueRevision) return;
    _emitAll();
  }

  @override
  Future<void> insertNext(
    MediaItem item, {
    CacheStore? cacheStore,
    Map<String, String>? headers,
  }) async {
    final revision = _queueRevision;
    if (cacheStore != null) {
      _cacheStore = cacheStore;
    }
    if (headers != null) {
      _headers = Map<String, String>.from(headers);
    }
    final insertIndex = ((currentIndex ?? -1) + 1).clamp(0, _queueItems.length);
    final media = await _buildMedia(item, _cacheStore, _headers);
    if (revision != _queueRevision) return;
    _queueItems.insert(insertIndex, item);
    await _player.add(media);
    if (revision != _queueRevision) return;
    final lastIndex = _player.state.playlist.medias.length - 1;
    if (lastIndex >= 0 && insertIndex < lastIndex) {
      await _player.move(lastIndex, insertIndex);
      if (revision != _queueRevision) return;
    }
    _emitAll();
  }

  @override
  Future<void> play() async {
    final currentPosition = position;
    if (currentPosition > Duration.zero) {
      await _player.seek(currentPosition);
    }
    await _player.play();
    _completed = false;
    _setPositionAnchor(currentPosition, index: currentIndex);
    _emitAll();
  }

  @override
  Future<void> pause() async {
    final currentPosition = position;
    await _player.pause();
    _setPositionAnchor(currentPosition, index: currentIndex);
    _emitAll();
  }

  @override
  Future<void> seek(Duration position) async {
    final index = currentIndex;
    final targetPosition = _clampPosition(position, index: index);
    _completed = false;
    _setPositionAnchor(targetPosition, index: index);
    _emitPosition();
    await _player.seek(targetPosition);
    _setPositionAnchor(targetPosition, index: index);
    _emitAll();
  }

  @override
  Future<void> seekToIndex(int index) async {
    if (index < 0 || index >= _queueItems.length) {
      return;
    }
    _completed = false;
    _setPositionAnchor(Duration.zero, index: index);
    _emitAll();
    await _player.jump(index);
    await _player.seek(Duration.zero);
    _setPositionAnchor(Duration.zero, index: index);
    _emitAll();
  }

  @override
  Future<void> skipNext() async {
    final targetIndex = _nextProjectedIndex(currentIndex);
    if (targetIndex == null) {
      return;
    }
    await seekToIndex(targetIndex);
  }

  @override
  Future<void> skipPrevious() async {
    final targetIndex = _previousProjectedIndex(currentIndex);
    if (targetIndex == null) {
      return;
    }
    await seekToIndex(targetIndex);
  }

  @override
  Future<void> setLoopMode(LoopMode mode) async {
    _loopMode = mode;
    await _player.setPlaylistMode(_toMediaKitLoopMode(mode));
  }

  @override
  Future<void> clearQueue({bool keepCurrent = true}) async {
    final revision = ++_queueRevision;
    if (_queueItems.isEmpty) {
      await _player.stop();
      if (revision != _queueRevision) return;
      _setPositionAnchor(Duration.zero, index: null);
      _emitAll();
      return;
    }

    final index = currentIndex ?? -1;
    if (keepCurrent && index >= 0 && index < _queueItems.length) {
      final position = this.position;
      final current = _queueItems[index];
      _queueItems
        ..clear()
        ..add(current);
      final media = await _buildMedia(current, _cacheStore, _headers);
      if (revision != _queueRevision) return;
      await _player.open(
        media_kit.Playlist([media]),
        play: isPlaying,
      );
      if (revision != _queueRevision) return;
      if (position > Duration.zero) {
        await _player.seek(position);
        if (revision != _queueRevision) return;
      }
      _setPositionAnchor(position, index: 0);
      _emitAll();
      return;
    }

    await _player.stop();
    if (revision != _queueRevision) return;
    await _player.open(const media_kit.Playlist([]), play: false);
    if (revision != _queueRevision) return;
    _queueItems.clear();
    _setPositionAnchor(Duration.zero, index: null);
    _emitAll();
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _positionController.close();
    await _durationController.close();
    await _playerStateController.close();
    await _currentIndexController.close();
    await _player.dispose();
  }

  void _handleBackendPosition(Duration rawPosition) {
    final index = currentIndex;
    final projected = _projectedPosition(_positionClock.elapsed);
    final clampedRaw = _clampPosition(rawPosition, index: index);
    if (clampedRaw >= projected || !_isProjectingPosition) {
      _setPositionAnchor(clampedRaw, index: index);
    } else {
      _setPositionAnchor(projected, index: index);
    }
    _emitPosition();
  }

  void _handleCompleted(bool completed) {
    _completed = completed;
    if (completed) {
      final index = currentIndex;
      final duration = _durationForIndex(index);
      if (duration != null && duration > Duration.zero) {
        _setPositionAnchor(duration, index: index);
      }
    }
    _emitAll();
  }

  void _handleBackendPlaylist(media_kit.Playlist playlist) {
    final index =
        playlist.medias.isEmpty || playlist.index < 0 ? null : playlist.index;
    if (index != _positionAnchorIndex) {
      _completed = false;
      _setPositionAnchor(_player.state.position, index: index);
    }
    _emitAll();
  }

  Duration _projectedPosition(Duration now) {
    var projected = _positionAnchor;
    if (_isProjectingPosition) {
      final elapsed = now - _positionAnchorClock;
      if (elapsed > Duration.zero) {
        projected += elapsed * _player.state.rate;
      }
    }
    final index = _positionAnchorIndex;
    final duration = _durationForIndex(index);
    if (_isProjectingPosition &&
        duration != null &&
        duration > Duration.zero &&
        projected >= duration + _autoAdvanceGrace) {
      final overflow = projected - duration;
      final nextIndex = _nextProjectedIndex(index);
      if (nextIndex != null) {
        _completed = false;
        _setPositionAnchor(overflow, index: nextIndex, clock: now);
        _emitAll();
        unawaited(_player.jump(nextIndex).then((_) => _player.seek(overflow)));
        return _clampPosition(_positionAnchor, index: nextIndex);
      }
    }
    return _clampPosition(projected, index: index);
  }

  void _setPositionAnchor(
    Duration position, {
    required int? index,
    Duration? clock,
  }) {
    _positionAnchor = _clampPosition(position, index: index);
    _positionAnchorClock = clock ?? _positionClock.elapsed;
    _positionAnchorIndex = index;
  }

  Duration _clampPosition(Duration position, {int? index}) {
    if (position < Duration.zero) {
      return Duration.zero;
    }
    final duration = _durationForIndex(index ?? _positionAnchorIndex);
    if (duration != null && duration > Duration.zero && position > duration) {
      return duration;
    }
    return position;
  }

  Duration? _durationForIndex(int? index) {
    if (index != null && index >= 0 && index < _queueItems.length) {
      final duration = _queueItems[index].duration;
      if (duration > Duration.zero) {
        return duration;
      }
    }
    final playerDuration = _player.state.duration;
    return playerDuration > Duration.zero ? playerDuration : null;
  }

  Future<List<media_kit.Media>> _buildMediaList(List<MediaItem> items) {
    return Future.wait(
      items.map((item) => _buildMedia(item, _cacheStore, _headers)),
    );
  }

  Future<media_kit.Media> _buildMedia(
    MediaItem item,
    CacheStore? cacheStore,
    Map<String, String>? headers,
  ) async {
    final file = cacheStore == null
        ? null
        : await cacheStore.getCachedAudio(item, touch: false);
    final logService = await LogService.instance;
    if (file != null) {
      await logService.info('_buildMedia: FILE "${item.title}" ${file.path}');
      return media_kit.Media(Uri.file(file.path).toString());
    }
    await logService.info('_buildMedia: URI "${item.title}" ${item.streamUrl}');
    return media_kit.Media(item.streamUrl, httpHeaders: headers);
  }

  int? _nextProjectedIndex(int? index) {
    if (index == null || _queueItems.isEmpty) {
      return null;
    }
    if (_loopMode == LoopMode.one) {
      return index;
    }
    if (index + 1 < _queueItems.length) {
      return index + 1;
    }
    return _loopMode == LoopMode.all ? 0 : null;
  }

  int? _previousProjectedIndex(int? index) {
    if (index == null || _queueItems.isEmpty) {
      return null;
    }
    if (index > 0) {
      return index - 1;
    }
    return _loopMode == LoopMode.all ? _queueItems.length - 1 : null;
  }

  media_kit.PlaylistMode _toMediaKitLoopMode(LoopMode mode) {
    return switch (mode) {
      LoopMode.off => media_kit.PlaylistMode.none,
      LoopMode.one => media_kit.PlaylistMode.single,
      LoopMode.all => media_kit.PlaylistMode.loop,
    };
  }

  ProcessingState get _processingState {
    if (_completed) {
      return ProcessingState.completed;
    }
    if (_isLoading) {
      return ProcessingState.loading;
    }
    if (_player.state.buffering) {
      return ProcessingState.buffering;
    }
    if (_queueItems.isEmpty) {
      return ProcessingState.idle;
    }
    return ProcessingState.ready;
  }

  bool get _isProjectingPosition =>
      _player.state.playing && _processingState == ProcessingState.ready;

  void _emitAll() {
    _emitPosition();
    _emitDuration();
    _emitCurrentIndex();
    _emitPlayerState();
  }

  void _emitPosition() {
    if (!_positionController.isClosed) {
      _positionController.add(position);
    }
  }

  void _emitDuration() {
    if (!_durationController.isClosed) {
      _durationController.add(duration);
    }
  }

  void _emitCurrentIndex() {
    if (!_currentIndexController.isClosed) {
      _currentIndexController.add(currentIndex);
    }
  }

  void _emitPlayerState() {
    if (!_playerStateController.isClosed) {
      _playerStateController.add(
        PlayerState(_player.state.playing, _processingState),
      );
    }
  }
}
