import 'package:fuzzywuzzy/fuzzywuzzy.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/genre.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';
import '../models/search_results.dart';

class _SearchField {
  const _SearchField(this.value, {this.priorityBonus = 0});

  final String value;
  final int priorityBonus;
}

/// Performs local search across cached library data.
class SearchService {
  static const _defaultLocalThreshold = 30;
  static const _exactMatchBonus = 120;
  static const _prefixMatchBonus = 80;
  static const _wordMatchBonus = 45;
  static const _containsMatchBonus = 25;

  /// Searches across all provided library data using fuzzy matching.
  static SearchResults searchLocal({
    required String query,
    required List<MediaItem> allTracks,
    required List<Album> albums,
    required List<Artist> artists,
    required List<Genre> genres,
    required List<Playlist> playlists,
  }) {
    return SearchResults(
      tracks: rankTracks(
        query: query,
        tracks: allTracks,
        minScore: _defaultLocalThreshold,
      ),
      albums: rankAlbums(
        query: query,
        albums: albums,
        minScore: _defaultLocalThreshold,
      ),
      artists: rankArtists(
        query: query,
        artists: artists,
        minScore: _defaultLocalThreshold,
      ),
      genres: rankGenres(
        query: query,
        genres: genres,
        minScore: _defaultLocalThreshold,
      ),
      playlists: rankPlaylists(
        query: query,
        playlists: playlists,
        minScore: _defaultLocalThreshold,
      ),
    );
  }

  /// Ranks tracks for a query, optionally filtering out low-score results.
  static List<MediaItem> rankTracks({
    required String query,
    required List<MediaItem> tracks,
    int? minScore,
  }) {
    return _rankItems(
      query: query,
      items: tracks,
      minScore: minScore,
      fieldsOf: (track) => [
        _SearchField(track.title, priorityBonus: 12),
        _SearchField(track.album, priorityBonus: 4),
        ...track.artists.map((artist) => _SearchField(artist, priorityBonus: 8))
      ],
    );
  }

  /// Ranks albums for a query, optionally filtering out low-score results.
  static List<Album> rankAlbums({
    required String query,
    required List<Album> albums,
    int? minScore,
  }) {
    return _rankItems(
      query: query,
      items: albums,
      minScore: minScore,
      fieldsOf: (album) => [
        _SearchField(album.name, priorityBonus: 12),
        _SearchField(album.artistName, priorityBonus: 8),
      ],
    );
  }

  /// Ranks artists for a query, optionally filtering out low-score results.
  static List<Artist> rankArtists({
    required String query,
    required List<Artist> artists,
    int? minScore,
  }) {
    return _rankItems(
      query: query,
      items: artists,
      minScore: minScore,
      fieldsOf: (artist) => [_SearchField(artist.name, priorityBonus: 12)],
    );
  }

  /// Ranks genres for a query, optionally filtering out low-score results.
  static List<Genre> rankGenres({
    required String query,
    required List<Genre> genres,
    int? minScore,
  }) {
    return _rankItems(
      query: query,
      items: genres,
      minScore: minScore,
      fieldsOf: (genre) => [_SearchField(genre.name, priorityBonus: 12)],
    );
  }

  /// Ranks playlists for a query, optionally filtering out low-score results.
  static List<Playlist> rankPlaylists({
    required String query,
    required List<Playlist> playlists,
    int? minScore,
  }) {
    return _rankItems(
      query: query,
      items: playlists,
      minScore: minScore,
      fieldsOf: (playlist) => [_SearchField(playlist.name, priorityBonus: 12)],
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

  static List<T> _rankItems<T>({
    required String query,
    required List<T> items,
    required List<_SearchField> Function(T item) fieldsOf,
    int? minScore,
  }) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty || items.isEmpty) {
      return List<T>.from(items);
    }

    final ranked = items.asMap().entries.map((entry) {
      final item = entry.value;
      final score = _scoreItem(
        query: normalizedQuery,
        fields: fieldsOf(item),
      );
      return (item: item, score: score, index: entry.key);
    }).where((result) => minScore == null || result.score >= minScore).toList()
      ..sort((a, b) {
        final scoreCompare = b.score.compareTo(a.score);
        if (scoreCompare != 0) {
          return scoreCompare;
        }
        return a.index.compareTo(b.index);
      });

    return ranked.map((result) => result.item).toList();
  }

  static int _scoreItem({
    required String query,
    required List<_SearchField> fields,
  }) {
    var best = 0;
    for (final field in fields) {
      final score = _scoreField(
        query: query,
        field: _normalize(field.value),
        priorityBonus: field.priorityBonus,
      );
      if (score > best) {
        best = score;
      }
    }
    return best;
  }

  static int _scoreField({
    required String query,
    required String field,
    required int priorityBonus,
  }) {
    if (field.isEmpty) {
      return 0;
    }

    final fuzzyScore = ratio(query, field);
    var matchBonus = 0;
    if (field == query) {
      matchBonus = _exactMatchBonus;
    } else if (field.startsWith(query)) {
      matchBonus = _prefixMatchBonus;
    } else if (_containsWord(field, query)) {
      matchBonus = _wordMatchBonus;
    } else if (field.contains(query)) {
      matchBonus = _containsMatchBonus;
    }

    final effectivePriorityBonus = matchBonus > 0 ? priorityBonus : 0;
    return fuzzyScore + matchBonus + effectivePriorityBonus;
  }

  static bool _containsWord(String field, String query) {
    final pattern =
        '(^|[^a-z0-9])${RegExp.escape(query)}([^a-z0-9]|\$)';
    return RegExp(pattern).hasMatch(field);
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
