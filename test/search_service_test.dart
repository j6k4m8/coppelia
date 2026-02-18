import 'package:flutter_test/flutter_test.dart';

import 'package:coppelia/models/album.dart';
import 'package:coppelia/models/artist.dart';
import 'package:coppelia/models/genre.dart';
import 'package:coppelia/models/media_item.dart';
import 'package:coppelia/models/playlist.dart';
import 'package:coppelia/services/search_service.dart';

void main() {
  test('rankTracks prefers title matches over album-only matches', () {
    const tracks = [
      MediaItem(
        id: 'album-match',
        title: 'Unrelated Title',
        album: 'Halo',
        artists: ['Other Artist'],
        duration: Duration(minutes: 3),
        imageUrl: null,
        streamUrl: 'https://example.com/album-match',
      ),
      MediaItem(
        id: 'title-match',
        title: 'Halo',
        album: 'Unrelated Album',
        artists: ['Other Artist'],
        duration: Duration(minutes: 3),
        imageUrl: null,
        streamUrl: 'https://example.com/title-match',
      ),
    ];

    final ranked = SearchService.rankTracks(query: 'halo', tracks: tracks);

    expect(ranked.first.id, 'title-match');
  });

  test('rankArtists orders exact, prefix, then contains-style matches', () {
    const artists = [
      Artist(
        id: 'word',
        name: 'The Best Band',
        albumCount: 0,
        trackCount: 0,
        imageUrl: null,
      ),
      Artist(
        id: 'prefix',
        name: 'Best Friends',
        albumCount: 0,
        trackCount: 0,
        imageUrl: null,
      ),
      Artist(
        id: 'exact',
        name: 'Best',
        albumCount: 0,
        trackCount: 0,
        imageUrl: null,
      ),
      Artist(
        id: 'contains',
        name: 'Alphabest',
        albumCount: 0,
        trackCount: 0,
        imageUrl: null,
      ),
    ];

    final ranked = SearchService.rankArtists(query: 'best', artists: artists);

    expect(
      ranked.take(4).map((artist) => artist.id).toList(),
      ['exact', 'prefix', 'word', 'contains'],
    );
  });

  test('searchLocal keeps threshold filtering for weak matches', () {
    const tracks = [
      MediaItem(
        id: 'relevant',
        title: 'Smells Like Teen Spirit',
        album: 'Nevermind',
        artists: ['Nirvana'],
        duration: Duration(minutes: 5),
        imageUrl: null,
        streamUrl: 'https://example.com/relevant',
      ),
      MediaItem(
        id: 'weak',
        title: 'Completely Different Song',
        album: 'Other Album',
        artists: ['Other Artist'],
        duration: Duration(minutes: 3),
        imageUrl: null,
        streamUrl: 'https://example.com/weak',
      ),
    ];

    final results = SearchService.searchLocal(
      query: 'nirvana',
      allTracks: tracks,
      albums: const <Album>[],
      artists: const <Artist>[],
      genres: const <Genre>[],
      playlists: const <Playlist>[],
    );

    expect(results.tracks, hasLength(1));
    expect(results.tracks.first.id, 'relevant');
  });
}
