import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coppelia/models/media_item.dart';
import 'package:coppelia/models/playlist.dart';
import 'package:coppelia/services/cache_store.dart';

void main() {
  test('cache store saves and restores playlists', () async {
    SharedPreferences.setMockInitialValues({});
    final cacheStore = CacheStore();
    final playlists = [
      const Playlist(
        id: 'playlist-1',
        name: 'Late Night',
        trackCount: 8,
        imageUrl: null,
      ),
    ];

    await cacheStore.savePlaylists(playlists);
    final restored = await cacheStore.loadPlaylists();

    expect(restored, hasLength(1));
    expect(restored.first.name, 'Late Night');
  });

  test('cache store saves playlist tracks', () async {
    SharedPreferences.setMockInitialValues({});
    final cacheStore = CacheStore();
    final tracks = [
      const MediaItem(
        id: 'track-1',
        title: 'Evergreen',
        album: 'Solstice',
        artists: ['Studio Band'],
        duration: Duration(minutes: 3, seconds: 12),
        imageUrl: null,
        streamUrl: 'https://demo.jellyfin.org/Audio/track-1/stream',
      ),
    ];

    await cacheStore.savePlaylistTracks('playlist-1', tracks);
    final restored = await cacheStore.loadPlaylistTracks('playlist-1');

    expect(restored, hasLength(1));
    expect(restored.first.title, 'Evergreen');
  });
}
