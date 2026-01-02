import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../core/formatters.dart';
import '../../models/album.dart';
import '../../models/artist.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../models/playlist.dart';
import 'app_snack.dart';
import 'context_menu.dart';
import 'library_card.dart';
import 'library_cover_card.dart';
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
                return LibraryCoverCard(
                  title: album.name,
                  subtitle: album.artistName,
                  imageUrl: album.imageUrl,
                  icon: Icons.album,
                  onTap: () => state.selectAlbum(album),
                  onSubtitleTap: _canLinkArtist(album)
                      ? () => state.selectArtistByName(album.artistName)
                      : null,
                  onContextMenu: (position) => _showAlbumMenu(
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
                return LibraryCoverCard(
                  title: artist.name,
                  subtitle: formatArtistSubtitle(artist),
                  imageUrl: artist.imageUrl,
                  icon: Icons.people_alt,
                  onTap: () => state.selectArtist(artist),
                  onContextMenu: (position) => _showArtistMenu(
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

  Future<void> _showAlbumMenu(
    BuildContext context,
    Offset position,
    Album album,
    AppState state,
  ) async {
    final albumArtist = album.artistName;
    final canGoToArtist = _canLinkArtist(album);
    final isFavorite = state.isFavoriteAlbum(album.id);
    final isPinned = await state.isAlbumPinned(album);
    if (!context.mounted) {
      return;
    }
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
        PopupMenuItem(
          value: _AlbumAction.favorite,
          child: isFavorite
              ? const Row(
                  children: [
                    Icon(Icons.favorite, size: 16),
                    SizedBox(width: 8),
                    Text('Unfavorite'),
                  ],
                )
              : const Text('Favorite'),
        ),
        PopupMenuItem(
          value: isPinned
              ? _AlbumAction.unpinOffline
              : _AlbumAction.makeAvailableOffline,
          child: isPinned
              ? const Row(
                  children: [
                    Icon(Icons.download_done_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Unpin from Offline'),
                  ],
                )
              : const Text('Make Available Offline'),
        ),
        if (canGoToArtist)
          const PopupMenuItem(
            value: _AlbumAction.goToArtist,
            child: Text('Go to Artist'),
          ),
      ],
    );
    if (!context.mounted) {
      return;
    }
    if (selection == _AlbumAction.play) {
      await state.playAlbum(album);
    }
    if (selection == _AlbumAction.open) {
      await state.selectAlbum(album);
    }
    if (selection == _AlbumAction.goToArtist) {
      await state.selectArtistByName(albumArtist);
    }
    if (selection == _AlbumAction.favorite) {
      if (!context.mounted) {
        return;
      }
      await runWithSnack(
        context,
        () => state.setAlbumFavorite(album, !isFavorite),
      );
    }
    if (selection == _AlbumAction.makeAvailableOffline) {
      await state.makeAlbumAvailableOffline(album);
    }
    if (selection == _AlbumAction.unpinOffline) {
      await state.unpinAlbumOffline(album);
    }
  }

  Future<void> _showArtistMenu(
    BuildContext context,
    Offset position,
    Artist artist,
    AppState state,
  ) async {
    final isFavorite = state.isFavoriteArtist(artist.id);
    final isPinned = await state.isArtistPinned(artist);
    if (!context.mounted) {
      return;
    }
    final selection = await showContextMenu<_ArtistAction>(
      context,
      position,
      [
        const PopupMenuItem(
          value: _ArtistAction.play,
          child: Text('Play'),
        ),
        const PopupMenuItem(
          value: _ArtistAction.open,
          child: Text('Open'),
        ),
        PopupMenuItem(
          value: _ArtistAction.favorite,
          child: isFavorite
              ? const Row(
                  children: [
                    Icon(Icons.favorite, size: 16),
                    SizedBox(width: 8),
                    Text('Unfavorite'),
                  ],
                )
              : const Text('Favorite'),
        ),
        PopupMenuItem(
          value: isPinned
              ? _ArtistAction.unpinOffline
              : _ArtistAction.makeAvailableOffline,
          child: isPinned
              ? const Row(
                  children: [
                    Icon(Icons.download_done_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Unpin from Offline'),
                  ],
                )
              : const Text('Make Available Offline'),
        ),
      ],
    );
    if (!context.mounted) {
      return;
    }
    if (selection == _ArtistAction.play) {
      await state.playArtist(artist);
    }
    if (selection == _ArtistAction.open) {
      await state.selectArtist(artist);
    }
    if (selection == _ArtistAction.favorite) {
      if (!context.mounted) {
        return;
      }
      await runWithSnack(
        context,
        () => state.setArtistFavorite(artist, !isFavorite),
      );
    }
    if (selection == _ArtistAction.makeAvailableOffline) {
      await state.makeArtistAvailableOffline(artist);
    }
    if (selection == _ArtistAction.unpinOffline) {
      await state.unpinArtistOffline(artist);
    }
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

enum _AlbumAction {
  play,
  open,
  favorite,
  makeAvailableOffline,
  unpinOffline,
  goToArtist
}

enum _ArtistAction { play, open, favorite, makeAvailableOffline, unpinOffline }

bool _canLinkArtist(Album album) {
  final artist = album.artistName;
  return artist.isNotEmpty && artist != 'Unknown Artist';
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
        final targetWidth = space(190).clamp(150.0, 240.0);
        final crossAxisCount = (constraints.maxWidth / targetWidth).floor();
        final columns = crossAxisCount < 1 ? 1 : crossAxisCount;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: space(16),
            mainAxisSpacing: space(16),
            childAspectRatio: 1.05,
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
