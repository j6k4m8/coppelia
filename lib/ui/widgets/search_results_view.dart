import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../core/formatters.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../models/playlist.dart';
import 'album_context_menu.dart';
import 'artist_context_menu.dart';
import 'grid_metrics.dart';
import 'library_card.dart';
import 'media_card.dart';
import 'section_header.dart';
import 'track_row.dart';

/// Displays search results for the library.
class SearchResultsView extends StatelessWidget {
  /// Creates the search results view.
  const SearchResultsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
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
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: results.tracks.length,
              separatorBuilder: (_, __) =>
                  SizedBox(height: space(6).clamp(4.0, 10.0)),
              itemBuilder: (context, index) {
                final track = results.tracks[index];
                return TrackRow(
                  track: track,
                  index: index,
                  isActive: state.nowPlaying?.id == track.id,
                  onTap: () => state.playFromSearch(track),
                  onPlayNext: () => state.playNext(track),
                  onAddToQueue: () => state.enqueueTrack(track),
                  isFavorite: state.isFavoriteTrack(track.id),
                  isFavoriteUpdating: state.isFavoriteTrackUpdating(track.id),
                  onToggleFavorite: () => state.setTrackFavorite(
                    track,
                    !state.isFavoriteTrack(track.id),
                  ),
                  onAlbumTap: track.albumId == null
                      ? null
                      : () => state.selectAlbumById(track.albumId!),
                  onArtistTap: track.artistIds.isEmpty
                      ? null
                      : () => state.selectArtistById(track.artistIds.first),
                  onGoToAlbum: track.albumId == null
                      ? null
                      : () => state.selectAlbumById(track.albumId!),
                  onGoToArtist: track.artistIds.isEmpty
                      ? null
                      : () => state.selectArtistById(track.artistIds.first),
                );
              },
            ),
            SizedBox(height: space(24)),
          ],
          if (results.albums.isNotEmpty) ...[
            const SectionHeader(title: 'Albums'),
            SizedBox(height: space(12)),
            _CardGrid(
              itemCount: results.albums.length,
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
            _CardGrid(
              itemCount: results.artists.length,
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
            _CardGrid(
              itemCount: results.genres.length,
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
            _CardGrid(
              itemCount: results.playlists.length,
              itemBuilder: (context, index) {
                final playlist = results.playlists[index];
                return _PlaylistResultCard(
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

class _PlaylistResultCard extends StatelessWidget {
  const _PlaylistResultCard({
    required this.playlist,
    required this.onTap,
  });

  final Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MediaCard(
      layout: MediaCardLayout.vertical,
      title: playlist.name,
      subtitle: '${playlist.trackCount} tracks',
      imageUrl: playlist.imageUrl,
      fallbackIcon: Icons.queue_music,
      onTap: onTap,
    );
  }
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridMetrics = GridMetrics.fromWidth(
          width: constraints.maxWidth,
          itemAspectRatio: 1.05,
          itemMinWidth: space(190).clamp(150.0, 240.0),
          spacing: space(16),
        );
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridMetrics.columns,
            crossAxisSpacing: gridMetrics.spacing,
            mainAxisSpacing: gridMetrics.spacing,
            childAspectRatio: gridMetrics.aspectRatio,
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
