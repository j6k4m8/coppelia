import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../models/album.dart';
import '../../core/formatters.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'app_snack.dart';
import 'context_menu.dart';
import 'collection_detail_view.dart';
import 'collection_header.dart';
import 'library_card.dart';
import 'section_header.dart';

/// Detail view for a single artist.
class ArtistDetailView extends StatefulWidget {
  /// Creates the artist detail view.
  const ArtistDetailView({super.key});

  @override
  State<ArtistDetailView> createState() => _ArtistDetailViewState();
}

class _ArtistDetailViewState extends State<ArtistDetailView> {
  bool _requestedAlbums = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedAlbums) {
      return;
    }
    final state = context.read<AppState>();
    if (state.albums.isEmpty) {
      state.loadAlbums();
    }
    _requestedAlbums = true;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final artist = state.selectedArtist;
    if (artist == null) {
      return const SizedBox.shrink();
    }
    final albums = _albumsForArtist(state.albums, artist.name);
    final hasAlbums = albums.isNotEmpty;
    final tracks = state.artistTracks;
    final pinned = state.pinnedAudio;
    final offlineTracks =
        tracks.where((track) => pinned.contains(track.streamUrl)).toList();
    final displayTracks = state.offlineOnlyFilter ? offlineTracks : tracks;
    final subtitle = formatArtistSubtitle(
      artist,
      fallbackAlbumCount: albums.length,
      fallbackTrackCount: tracks.length,
    );
    final headerImageUrl = artist.imageUrl ??
        (albums.isNotEmpty ? albums.first.imageUrl : null) ??
        (tracks.isNotEmpty ? tracks.first.imageUrl : null);

    return FutureBuilder<bool>(
      future: state.isArtistPinned(artist),
      builder: (context, snapshot) {
        final isPinned = snapshot.data ?? false;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final offlineLabel =
            isPinned ? 'Remove from Offline' : 'Make Available Offline';
        final offlineIcon =
            isPinned ? Icons.download_done_rounded : Icons.download_rounded;
        final offlineOnPressed = tracks.isNotEmpty && !isLoading
            ? () => isPinned
                ? state.unpinArtistOffline(artist)
                : state.makeArtistAvailableOffline(artist)
            : null;

        return CollectionDetailView(
          title: artist.name,
          subtitle: subtitle,
          imageUrl: headerImageUrl,
          tracks: displayTracks,
          nowPlaying: state.nowPlaying,
          onPlayAll: displayTracks.isEmpty
              ? null
              : () => state.playFromList(displayTracks, displayTracks.first),
          onShuffle: displayTracks.isEmpty
              ? null
              : () => state.playShuffledList(displayTracks),
          onTrackTap: (track) => state.playFromList(displayTracks, track),
          onPlayNext: state.playNext,
          onAddToQueue: state.enqueueTrack,
          onAlbumTap: (track) {
            if (track.albumId != null) {
              state.selectAlbumById(track.albumId!);
            }
          },
          onArtistTap: (track) {
            if (track.artistIds.isNotEmpty) {
              state.selectArtistById(track.artistIds.first);
            }
          },
          headerFooter: hasAlbums
              ? _ArtistAlbumsSection(
                  albums: albums,
                  onSelect: state.selectAlbum,
                  state: state,
                )
              : null,
          headerActionSpecs: [
            HeaderActionSpec(
              icon: state.isFavoriteArtist(artist.id)
                  ? Icons.favorite
                  : Icons.favorite_border,
              label:
                  state.isFavoriteArtist(artist.id) ? 'Unfavorite' : 'Favorite',
              tooltip:
                  state.isFavoriteArtist(artist.id) ? 'Unfavorite' : 'Favorite',
              outlined: true,
              onPressed: state.isFavoriteArtistUpdating(artist.id)
                  ? null
                  : () => runWithSnack(
                        context,
                        () => state.setArtistFavorite(
                          artist,
                          !state.isFavoriteArtist(artist.id),
                        ),
                      ),
            ),
            HeaderActionSpec(
              icon: offlineIcon,
              label: offlineLabel,
              tooltip: offlineLabel,
              outlined: true,
              onPressed: offlineOnPressed,
            ),
          ],
          headerActions: [
            OutlinedButton.icon(
              onPressed: state.isFavoriteArtistUpdating(artist.id)
                  ? null
                  : () => runWithSnack(
                        context,
                        () => state.setArtistFavorite(
                          artist,
                          !state.isFavoriteArtist(artist.id),
                        ),
                      ),
              icon: state.isFavoriteArtistUpdating(artist.id)
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Icon(
                      state.isFavoriteArtist(artist.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
              label: Text(
                state.isFavoriteArtist(artist.id) ? 'Unfavorite' : 'Favorite',
              ),
            ),
            OutlinedButton.icon(
              onPressed: offlineOnPressed,
              icon: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Icon(offlineIcon),
              label: Text(offlineLabel),
            ),
          ],
        );
      },
    );
  }
}

List<Album> _albumsForArtist(List<Album> albums, String artistName) {
  final target = artistName.trim().toLowerCase();
  final filtered = albums
      .where(
        (album) => album.artistName.trim().toLowerCase() == target,
      )
      .toList();
  filtered.sort((a, b) => a.name.compareTo(b.name));
  return filtered;
}

Future<void> _showAlbumMenu(
  BuildContext context,
  Offset position,
  Album album,
  AppState state,
) async {
  final canGoToArtist =
      album.artistName.isNotEmpty && album.artistName != 'Unknown Artist';
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
  if (selection == _AlbumAction.play) {
    await state.playAlbum(album);
  }
  if (selection == _AlbumAction.open) {
    await state.selectAlbum(album);
  }
  if (selection == _AlbumAction.goToArtist) {
    await state.selectArtistByName(album.artistName);
  }
  if (selection == _AlbumAction.favorite) {
    if (!context.mounted) {
      return;
    }
    await runWithSnack(
      context,
      () => state.setAlbumFavorite(album, !isFavorite),
    );
  if (!context.mounted) {
    return;
  }
  }
  if (selection == _AlbumAction.makeAvailableOffline) {
    await state.makeAlbumAvailableOffline(album);
  }
  if (selection == _AlbumAction.unpinOffline) {
    await state.unpinAlbumOffline(album);
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

class _ArtistAlbumsSection extends StatelessWidget {
  const _ArtistAlbumsSection({
    required this.albums,
    required this.onSelect,
    required this.state,
  });

  final List<Album> albums;
  final ValueChanged<Album> onSelect;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Albums',
          action: Text(
            '${albums.length} albums',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: ColorTokens.textSecondary(context)),
          ),
        ),
        SizedBox(height: space(16)),
        LayoutBuilder(
          builder: (context, constraints) {
            final targetWidth = space(220).clamp(160.0, 260.0);
            final crossAxisCount = (constraints.maxWidth / targetWidth).floor();
            final columns = crossAxisCount < 1 ? 1 : crossAxisCount;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: space(16),
                mainAxisSpacing: space(16),
                childAspectRatio: 1.1,
              ),
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                return LibraryCard(
                  title: album.name,
                  subtitle: '${album.trackCount} tracks',
                  imageUrl: album.imageUrl,
                  icon: Icons.album,
                  onTap: () => onSelect(album),
                  onContextMenu: (position) => _showAlbumMenu(
                    context,
                    position,
                    album,
                    state,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
