import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:media_kit/media_kit.dart' as media_kit;

import 'package:coppelia/models/media_item.dart';
import 'package:coppelia/services/cache_store.dart';
import 'package:coppelia/services/playback_controller.dart';

class _Player extends Mock implements AudioPlayer {}

class _Cache extends Mock implements CacheStore {}

class _DesktopPlayer extends Mock implements media_kit.Player {}

class _DesktopStreams extends Mock implements media_kit.PlayerStream {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const track = MediaItem(
      id: 'old',
      title: 'Old',
      album: '',
      artists: [],
      duration: Duration(seconds: 1),
      imageUrl: null,
      streamUrl: 'https://old.example.com/Audio/old/universal');
  setUpAll(() {
    registerFallbackValue(track);
    registerFallbackValue(<AudioSource>[]);
    registerFallbackValue(const media_kit.Playlist([]));
  });

  for (final operation in ['replace', 'append', 'insert']) {
    test('clearing playback cancels a pending $operation source lookup',
        () async {
      final player = _Player();
      final cache = _Cache();
      final started = Completer<void>();
      final lookup = Completer<File?>();
      when(() => cache.getCachedAudio(any(), touch: false)).thenAnswer((_) {
        started.complete();
        return lookup.future;
      });
      when(() => player.audioSources).thenReturn([]);
      when(() => player.stop()).thenAnswer((_) async {});
      final playback =
          PlaybackController(audioPlayer: player, useNativeJustAudio: true);
      final Future<void> pending;
      switch (operation) {
        case 'append':
          pending = playback.appendToQueue(track, cacheStore: cache);
        case 'insert':
          pending = playback.insertNext(track, cacheStore: cache);
        default:
          pending = playback.setQueue([track], cacheStore: cache);
      }
      await started.future;
      await playback.clearQueue(keepCurrent: false);
      lookup.complete(null);
      await pending;
      // No source mutation may follow the clear, regardless of entry point.
      verify(() => player.stop()).called(1);
      verify(() => player.audioSources).called(1);
      verifyNoMoreInteractions(player);
    });
  }
  test(
      'desktop queue preparation cannot revive a cleared queue and a fresh queue still works',
      () async {
    final player = _DesktopPlayer();
    final streams = _DesktopStreams();
    when(() => player.state).thenReturn(const media_kit.PlayerState());
    when(() => player.stream).thenReturn(streams);
    when(() => streams.position).thenAnswer((_) => const Stream.empty());
    when(() => streams.duration).thenAnswer((_) => const Stream.empty());
    when(() => streams.playing).thenAnswer((_) => const Stream.empty());
    when(() => streams.buffering).thenAnswer((_) => const Stream.empty());
    when(() => streams.completed).thenAnswer((_) => const Stream.empty());
    when(() => streams.playlist).thenAnswer((_) => const Stream.empty());
    when(() => streams.error).thenAnswer((_) => const Stream.empty());
    when(() => player.stop()).thenAnswer((_) async {});
    when(() => player.dispose()).thenAnswer((_) async {});
    final opened = <media_kit.Playlist>[];
    when(() => player.open(any(), play: false)).thenAnswer((call) async {
      opened.add(call.positionalArguments.single as media_kit.Playlist);
    });
    final cache = _Cache();
    final started = Completer<void>();
    final lookup = Completer<File?>();
    when(() => cache.getCachedAudio(any(), touch: false)).thenAnswer((_) {
      started.complete();
      return lookup.future;
    });
    final playback =
        PlaybackController(mediaKitPlayer: player, useNativeJustAudio: false);
    addTearDown(playback.dispose);
    final pending = playback.setQueue([track],
        cacheStore: cache, headers: {'Authorization': 'old-token'});
    await started.future;
    await playback.clearQueue(keepCurrent: false);
    lookup.complete(null);
    await pending;
    expect(opened, hasLength(1));
    expect(opened.single.medias, isEmpty);
    expect(playback.currentMediaItem, isNull);
    when(() => cache.getCachedAudio(any(), touch: false))
        .thenAnswer((_) async => null);
    await playback.setQueue([track],
        cacheStore: cache, headers: {'Authorization': 'new-token'});
    expect(opened, hasLength(2));
    expect(
        opened.last.medias.single.httpHeaders!['Authorization'], 'new-token');
    expect(playback.currentMediaItem?.id, track.id);
  });
}
