import '../models/album.dart';
import '../models/artist.dart';
import '../models/genre.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';
import '../models/search_results.dart';

/// Performs local search across cached library data.
class SearchService {
  /// Searches across all provided library data using local string matching.
  static SearchResults searchLocal({
    required String query,
    required List<MediaItem> allTracks,
    required List<Album> albums,
    required List<Artist> artists,
    required List<Genre> genres,
    required List<Playlist> playlists,
  }) {
    final needle = query.toLowerCase();
    bool matches(String value) => value.toLowerCase().contains(needle);

    final matchedTracks = allTracks
        .where(
          (track) =>
              matches(track.title) ||
              matches(track.album) ||
              track.artists.any(matches),
        )
        .toList();

    final matchedAlbums = albums
        .where(
          (album) => matches(album.name) || matches(album.artistName),
        )
        .toList();

    final matchedArtists =
        artists.where((artist) => matches(artist.name)).toList();

    final matchedGenres = genres.where((genre) => matches(genre.name)).toList();

    final matchedPlaylists =
        playlists.where((playlist) => matches(playlist.name)).toList();

    return SearchResults(
      tracks: matchedTracks,
      albums: matchedAlbums,
      artists: matchedArtists,
      genres: matchedGenres,
      playlists: matchedPlaylists,
    );
  }

  /// Collects unique tracks from multiple sources into a single list.
  static List<MediaItem> collectUniqueTracks(
    List<List<MediaItem>> trackLists,
  ) {
    final uniqueTracks = <String, MediaItem>{};
    for (final trackList in trackLists) {
      for (final track in trackList) {
        uniqueTracks[track.id] = track;
      }
    }
    return uniqueTracks.values.toList();
  }
}
