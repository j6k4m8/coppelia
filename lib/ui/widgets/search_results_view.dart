import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/album.dart';
import '../../state/app_state.dart';
import '../../core/color_tokens.dart';
import 'context_menu.dart';
import 'library_card.dart';
import 'section_header.dart';
import 'track_row.dart';

/// Displays search results for the library.
class SearchResultsView extends StatelessWidget {
  /// Creates the search results view.
  const SearchResultsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
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
          const SizedBox(height: 16),
          if (results.tracks.isNotEmpty) ...[
            SectionHeader(title: 'Tracks'),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: results.tracks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final track = results.tracks[index];
                return TrackRow(
                  track: track,
                  index: index,
                  isActive: state.nowPlaying?.id == track.id,
                  onTap: () => state.playFromSearch(track),
                  onPlayNext: () => state.playNext(track),
                  onAddToQueue: () => state.enqueueTrack(track),
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
            const SizedBox(height: 24),
          ],
          if (results.albums.isNotEmpty) ...[
            SectionHeader(title: 'Albums'),
            const SizedBox(height: 12),
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
                  onContextMenu: (position) => _showAlbumMenu(
                    context,
                    position,
                    album,
                    state,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
          if (results.artists.isNotEmpty) ...[
            SectionHeader(title: 'Artists'),
            const SizedBox(height: 12),
            _CardGrid(
              itemCount: results.artists.length,
              itemBuilder: (context, index) {
                final artist = results.artists[index];
                return LibraryCard(
                  title: artist.name,
                  subtitle: '${artist.trackCount} tracks',
                  imageUrl: artist.imageUrl,
                  icon: Icons.people_alt,
                  onTap: () => state.selectArtist(artist),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
          if (results.genres.isNotEmpty) ...[
            SectionHeader(title: 'Genres'),
            const SizedBox(height: 12),
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
          ],
        ],
      ),
    );
  }

  Future<void> _showAlbumMenu(
    BuildContext context,
    Offset position,
    Album album,
    AppState state,
  ) async {
    final albumArtist = album.artistName;
    final canGoToArtist =
        albumArtist.isNotEmpty && albumArtist != 'Unknown Artist';
    final selection = await showContextMenu<_AlbumAction>(
      context,
      position,
      [
        const PopupMenuItem(
          value: _AlbumAction.play,
          child: Text('Play'),
        ),
        const PopupMenuItem(
          value: _AlbumAction.open,
          child: Text('Open'),
        ),
        if (canGoToArtist)
          const PopupMenuItem(
            value: _AlbumAction.goToArtist,
            child: Text('Go to Artist'),
          ),
      ],
    );
    if (selection == _AlbumAction.play) {
      await state.playAlbum(album);
    }
    if (selection == _AlbumAction.open) {
      await state.selectAlbum(album);
    }
    if (selection == _AlbumAction.goToArtist) {
      await state.selectArtistByName(albumArtist);
    }
  }
}

enum _AlbumAction { play, open, goToArtist }

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 220).floor();
        final columns = crossAxisCount < 1 ? 1 : crossAxisCount;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.05,
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
