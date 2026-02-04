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
import 'track_row.dart';

/// Displays search results for the library.
class SearchResultsView extends StatefulWidget {
  /// Creates the search results view.
  const SearchResultsView({super.key});

  @override
  State<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends State<SearchResultsView> {
  bool _showAllTracks = false;
  String _lastSearchQuery = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Reset show all when search query changes
    if (state.searchQuery != _lastSearchQuery) {
      _lastSearchQuery = state.searchQuery;
      _showAllTracks = false;
    }

    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final leftGutter = (32 * densityScale).clamp(16.0, 40.0).toDouble();
    final rightGutter = (24 * densityScale).clamp(12.0, 32.0).toDouble();
    if (state.isSearching && state.searchResults == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final results = state.searchResults;
    if (results == null || results.isEmpty) {
      return Center(
        child: Text(
          'No results for "${state.searchQuery}"',
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
          SizedBox(height: space(16)),
          if (results.tracks.isNotEmpty) ...[
            const SectionHeader(title: 'Tracks'),
            SizedBox(height: space(12)),
            Builder(
              builder: (context) {
                const maxInitialTracks = 20;
                final displayedTracks = _showAllTracks
                    ? results.tracks
                    : results.tracks.take(maxInitialTracks).toList();
                final hasMore = results.tracks.length > maxInitialTracks;

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
                        return TrackRow(
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
                            'Show ${results.tracks.length - maxInitialTracks} more tracks',
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
            AdaptiveGrid(
              itemCount: results.albums.length,
              aspectRatio: 1.05,
              spacing: space(16),
              targetMinWidth: space(190).clamp(150.0, 240.0),
              itemBuilder: (context, index) {
                final album = results.albums[index];
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
            SizedBox(height: space(24)),
          ],
          if (results.artists.isNotEmpty) ...[
            const SectionHeader(title: 'Artists'),
            SizedBox(height: space(12)),
            AdaptiveGrid(
              itemCount: results.artists.length,
              aspectRatio: 1.05,
              spacing: space(16),
              targetMinWidth: space(190).clamp(150.0, 240.0),
              itemBuilder: (context, index) {
                final artist = results.artists[index];
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
            SizedBox(height: space(24)),
          ],
          if (results.genres.isNotEmpty) ...[
            const SectionHeader(title: 'Genres'),
            SizedBox(height: space(12)),
            AdaptiveGrid(
              itemCount: results.genres.length,
              aspectRatio: 1.05,
              spacing: space(16),
              targetMinWidth: space(190).clamp(150.0, 240.0),
              itemBuilder: (context, index) {
                final genre = results.genres[index];
                return LibraryCard(
                  title: genre.name,
                  subtitle: '${genre.trackCount} tracks',
                  imageUrl: genre.imageUrl,
                  icon: Icons.auto_awesome_motion,
                  onTap: () => state.selectGenre(genre),
                );
              },
            ),
            SizedBox(height: space(24)),
          ],
          if (results.playlists.isNotEmpty) ...[
            const SectionHeader(title: 'Playlists'),
            SizedBox(height: space(12)),
            AdaptiveGrid(
              itemCount: results.playlists.length,
              aspectRatio: 1.05,
              spacing: space(16),
              targetMinWidth: space(190).clamp(150.0, 240.0),
              itemBuilder: (context, index) {
                final playlist = results.playlists[index];
                return PlaylistTile(
                  playlist: playlist,
                  onTap: () => state.selectPlaylist(playlist),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
