import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../core/formatters.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'album_context_menu.dart';
import 'artist_context_menu.dart';
import 'adaptive_grid.dart';
import 'library_card.dart';
import 'playlist_tile.dart';
import 'section_header.dart';
import 'track_list_item.dart';
import 'track_table_header.dart';
import '../../state/track_list_style.dart';

/// Displays search results for the library.
class SearchResultsView extends StatefulWidget {
  /// Creates the search results view.
  const SearchResultsView({super.key});

  @override
  State<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends State<SearchResultsView> {
  static const _maxInitialTracks = 20;
  static const _maxInitialGridItems = 24;

  bool _showAllTracks = false;
  bool _showAllAlbums = false;
  bool _showAllArtists = false;
  bool _showAllGenres = false;
  bool _showAllPlaylists = false;
  String _lastSearchQuery = '';
  Set<String> _visibleColumns = {
    'title',
    'artist',
    'album',
    'duration',
    'favorite',
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Reset show all when search query changes
    if (state.searchQuery != _lastSearchQuery) {
      _lastSearchQuery = state.searchQuery;
      _showAllTracks = false;
      _showAllAlbums = false;
      _showAllArtists = false;
      _showAllGenres = false;
      _showAllPlaylists = false;
    }

    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final leftGutter = (32 * densityScale).clamp(16.0, 40.0).toDouble();
    final rightGutter = (24 * densityScale).clamp(12.0, 32.0).toDouble();
    final results = state.searchResults;
    final isLoading = state.isSearchLoading;
    if (isLoading && results == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.searchQuery.trim().isEmpty && !isLoading) {
      return Center(
        child: Text(
          'Search your library',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: ColorTokens.textSecondary(context)),
        ),
      );
    }
    if (results == null || results.isEmpty) {
      return Center(
        child: Text(
          isLoading
              ? 'Searching for "${state.searchQuery}"...'
              : 'No results for "${state.searchQuery}"',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: ColorTokens.textSecondary(context)),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Search results',
            action: Text(
              state.searchQuery,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: ColorTokens.textSecondary(context)),
            ),
          ),
          if (isLoading) ...[
            SizedBox(height: space(8)),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: space(8)),
                Text(
                  'Loading full library results...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColorTokens.textSecondary(context),
                      ),
                ),
              ],
            ),
          ],
          SizedBox(height: space(16)),
          if (results.tracks.isNotEmpty) ...[
            const SectionHeader(title: 'Tracks'),
            SizedBox(height: space(12)),
            if (state.trackListStyle == TrackListStyle.table)
              TrackTableHeader(
                onVisibleColumnsChanged: (columns) {
                  setState(() {
                    _visibleColumns = columns;
                  });
                },
              ),
            Builder(
              builder: (context) {
                final displayedTracks = _showAllTracks
                    ? results.tracks
                    : results.tracks.take(_maxInitialTracks).toList();
                final hasMore = results.tracks.length > _maxInitialTracks;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedTracks.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(height: space(6).clamp(4.0, 10.0)),
                      itemBuilder: (context, index) {
                        final track = displayedTracks[index];
                        return TrackListItem(
                          track: track,
                          index: index,
                          isActive: state.nowPlaying?.id == track.id,
                          onTap: () => state.playFromSearch(track),
                          onPlayNext: () => state.playNext(track),
                          onAddToQueue: () => state.enqueueTrack(track),
                          isFavorite: state.isFavoriteTrack(track.id),
                          isFavoriteUpdating:
                              state.isFavoriteTrackUpdating(track.id),
                          onToggleFavorite: () => state.setTrackFavorite(
                            track,
                            !state.isFavoriteTrack(track.id),
                          ),
                          onAlbumTap: track.albumId == null
                              ? null
                              : () => state.selectAlbumById(track.albumId!),
                          onArtistTap: track.artistIds.isEmpty
                              ? null
                              : () =>
                                  state.selectArtistById(track.artistIds.first),
                          visibleColumns: _visibleColumns,
                          onGoToAlbum: track.albumId == null
                              ? null
                              : () => state.selectAlbumById(track.albumId!),
                          onGoToArtist: track.artistIds.isEmpty
                              ? null
                              : () =>
                                  state.selectArtistById(track.artistIds.first),
                        );
                      },
                    ),
                    if (hasMore && !_showAllTracks) ...[
                      SizedBox(height: space(12)),
                      Center(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _showAllTracks = true;
                            });
                          },
                          child: Text(
                            'Show ${results.tracks.length - _maxInitialTracks} more tracks',
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            SizedBox(height: space(24)),
          ],
          if (results.albums.isNotEmpty) ...[
            const SectionHeader(title: 'Albums'),
            SizedBox(height: space(12)),
            Builder(
              builder: (context) {
                final displayedAlbums = _showAllAlbums
                    ? results.albums
                    : results.albums.take(_maxInitialGridItems).toList();
                final hasMore = results.albums.length > _maxInitialGridItems;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdaptiveGrid(
                      itemCount: displayedAlbums.length,
                      aspectRatio: 1.05,
                      spacing: space(16),
                      targetMinWidth: space(190).clamp(150.0, 240.0),
                      itemBuilder: (context, index) {
                        final album = displayedAlbums[index];
                        return LibraryCard(
                          title: album.name,
                          subtitle: album.artistName,
                          imageUrl: album.imageUrl,
                          icon: Icons.album,
                          onTap: () => state.selectAlbum(album),
                          onSubtitleTap: canLinkArtist(album)
                              ? () => state.selectArtistByName(album.artistName)
                              : null,
                          onContextMenu: (position) => showAlbumContextMenu(
                            context,
                            position,
                            album,
                            state,
                          ),
                        );
                      },
                    ),
                    if (hasMore && !_showAllAlbums) ...[
                      SizedBox(height: space(12)),
                      Center(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _showAllAlbums = true;
                            });
                          },
                          child: Text(
                            'Show ${results.albums.length - _maxInitialGridItems} more albums',
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            SizedBox(height: space(24)),
          ],
          if (results.artists.isNotEmpty) ...[
            const SectionHeader(title: 'Artists'),
            SizedBox(height: space(12)),
            Builder(
              builder: (context) {
                final displayedArtists = _showAllArtists
                    ? results.artists
                    : results.artists.take(_maxInitialGridItems).toList();
                final hasMore = results.artists.length > _maxInitialGridItems;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdaptiveGrid(
                      itemCount: displayedArtists.length,
                      aspectRatio: 1.05,
                      spacing: space(16),
                      targetMinWidth: space(190).clamp(150.0, 240.0),
                      itemBuilder: (context, index) {
                        final artist = displayedArtists[index];
                        return LibraryCard(
                          title: artist.name,
                          subtitle: formatArtistSubtitle(artist),
                          imageUrl: artist.imageUrl,
                          icon: Icons.people_alt,
                          onTap: () => state.selectArtist(artist),
                          onContextMenu: (position) => showArtistContextMenu(
                            context,
                            position,
                            artist,
                            state,
                          ),
                        );
                      },
                    ),
                    if (hasMore && !_showAllArtists) ...[
                      SizedBox(height: space(12)),
                      Center(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _showAllArtists = true;
                            });
                          },
                          child: Text(
                            'Show ${results.artists.length - _maxInitialGridItems} more artists',
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            SizedBox(height: space(24)),
          ],
          if (results.genres.isNotEmpty) ...[
            const SectionHeader(title: 'Genres'),
            SizedBox(height: space(12)),
            Builder(
              builder: (context) {
                final displayedGenres = _showAllGenres
                    ? results.genres
                    : results.genres.take(_maxInitialGridItems).toList();
                final hasMore = results.genres.length > _maxInitialGridItems;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdaptiveGrid(
                      itemCount: displayedGenres.length,
                      aspectRatio: 1.05,
                      spacing: space(16),
                      targetMinWidth: space(190).clamp(150.0, 240.0),
                      itemBuilder: (context, index) {
                        final genre = displayedGenres[index];
                        return LibraryCard(
                          title: genre.name,
                          subtitle: '${genre.trackCount} tracks',
                          imageUrl: genre.imageUrl,
                          icon: Icons.auto_awesome_motion,
                          onTap: () => state.selectGenre(genre),
                        );
                      },
                    ),
                    if (hasMore && !_showAllGenres) ...[
                      SizedBox(height: space(12)),
                      Center(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _showAllGenres = true;
                            });
                          },
                          child: Text(
                            'Show ${results.genres.length - _maxInitialGridItems} more genres',
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            SizedBox(height: space(24)),
          ],
          if (results.playlists.isNotEmpty) ...[
            const SectionHeader(title: 'Playlists'),
            SizedBox(height: space(12)),
            Builder(
              builder: (context) {
                final displayedPlaylists = _showAllPlaylists
                    ? results.playlists
                    : results.playlists.take(_maxInitialGridItems).toList();
                final hasMore =
                    results.playlists.length > _maxInitialGridItems;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdaptiveGrid(
                      itemCount: displayedPlaylists.length,
                      aspectRatio: 1.05,
                      spacing: space(16),
                      targetMinWidth: space(190).clamp(150.0, 240.0),
                      itemBuilder: (context, index) {
                        final playlist = displayedPlaylists[index];
                        return PlaylistTile(
                          playlist: playlist,
                          onTap: () => state.selectPlaylist(playlist),
                        );
                      },
                    ),
                    if (hasMore && !_showAllPlaylists) ...[
                      SizedBox(height: space(12)),
                      Center(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _showAllPlaylists = true;
                            });
                          },
                          child: Text(
                            'Show ${results.playlists.length - _maxInitialGridItems} more playlists',
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
