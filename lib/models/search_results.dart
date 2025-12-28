import 'album.dart';
import 'artist.dart';
import 'genre.dart';
import 'media_item.dart';
import 'playlist.dart';

/// Container for search results.
class SearchResults {
  /// Creates search results.
  const SearchResults({
    this.tracks = const [],
    this.albums = const [],
    this.artists = const [],
    this.genres = const [],
    this.playlists = const [],
  });

  /// Matching tracks.
  final List<MediaItem> tracks;

  /// Matching albums.
  final List<Album> albums;

  /// Matching artists.
  final List<Artist> artists;

  /// Matching genres.
  final List<Genre> genres;

  /// Matching playlists.
  final List<Playlist> playlists;

  /// True when all result lists are empty.
  bool get isEmpty =>
      tracks.isEmpty &&
      albums.isEmpty &&
      artists.isEmpty &&
      genres.isEmpty &&
      playlists.isEmpty;
}
