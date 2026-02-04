import 'package:fuzzywuzzy/fuzzywuzzy.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/genre.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';
import '../models/search_results.dart';

/// Performs local search across cached library data.
class SearchService {
  /// Searches across all provided library data using fuzzy matching.
  static SearchResults searchLocal({
    required String query,
    required List<MediaItem> allTracks,
    required List<Album> albums,
    required List<Artist> artists,
    required List<Genre> genres,
    required List<Playlist> playlists,
  }) {
    const threshold = 30; // Minimum score to include in results

    // Fuzzy search for tracks
    final matchedTracks = allTracks
        .map((track) {
          final titleScore = ratio(query, track.title);
          final albumScore = ratio(query, track.album);
          final artistScore = track.artists.isEmpty
              ? 0
              : track.artists
                  .map((artist) => ratio(query, artist))
                  .reduce((a, b) => a > b ? a : b);
          final maxScore = [titleScore, albumScore, artistScore]
              .reduce((a, b) => a > b ? a : b);
          return (track: track, score: maxScore);
        })
        .where((result) => result.score >= threshold)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Fuzzy search for albums
    final matchedAlbums = albums
        .map((album) {
          final nameScore = ratio(query, album.name);
          final artistScore = ratio(query, album.artistName);
          final maxScore = nameScore > artistScore ? nameScore : artistScore;
          return (album: album, score: maxScore);
        })
        .where((result) => result.score >= threshold)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Fuzzy search for artists
    final matchedArtists = artists
        .map((artist) {
          final score = ratio(query, artist.name);
          return (artist: artist, score: score);
        })
        .where((result) => result.score >= threshold)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Fuzzy search for genres
    final matchedGenres = genres
        .map((genre) {
          final score = ratio(query, genre.name);
          return (genre: genre, score: score);
        })
        .where((result) => result.score >= threshold)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Fuzzy search for playlists
    final matchedPlaylists = playlists
        .map((playlist) {
          final score = ratio(query, playlist.name);
          return (playlist: playlist, score: score);
        })
        .where((result) => result.score >= threshold)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return SearchResults(
      tracks: matchedTracks.map((r) => r.track).toList(),
      albums: matchedAlbums.map((r) => r.album).toList(),
      artists: matchedArtists.map((r) => r.artist).toList(),
      genres: matchedGenres.map((r) => r.genre).toList(),
      playlists: matchedPlaylists.map((r) => r.playlist).toList(),
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
