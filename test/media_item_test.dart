import 'package:flutter_test/flutter_test.dart';

import 'package:coppelia/models/media_item.dart';

void main() {
  test('MediaItem subtitle prefers artists when available', () {
    const track = MediaItem(
      id: '1',
      title: 'Track',
      album: 'Album',
      artists: ['Artist One', 'Artist Two'],
      duration: Duration(seconds: 120),
      imageUrl: null,
      streamUrl: 'https://example.com/stream',
    );

    expect(track.subtitle, 'Artist One, Artist Two');
  });

  test('MediaItem subtitle falls back to album', () {
    const track = MediaItem(
      id: '2',
      title: 'Track',
      album: 'Album',
      artists: [],
      duration: Duration(seconds: 90),
      imageUrl: null,
      streamUrl: 'https://example.com/stream',
    );

    expect(track.subtitle, 'Album');
  });
}
