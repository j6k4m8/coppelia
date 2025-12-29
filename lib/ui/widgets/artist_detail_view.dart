import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../models/album.dart';
import '../../core/formatters.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'artwork_image.dart';
import 'context_menu.dart';
import 'library_cover_card.dart';
import 'section_header.dart';
import 'track_row.dart';

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
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final leftGutter =
        (32 * densityScale).clamp(16.0, 40.0).toDouble();
    final rightGutter =
        (24 * densityScale).clamp(12.0, 32.0).toDouble();
    final artist = state.selectedArtist;
    if (artist == null) {
      return const SizedBox.shrink();
    }
    final albums = _albumsForArtist(state.albums, artist.name);
    final hasAlbums = albums.isNotEmpty;
    final tracks = state.artistTracks;
    final pinned = state.pinnedAudio;
    final offlineTracks = tracks
        .where((track) => pinned.contains(track.streamUrl))
        .toList();
    final displayTracks =
        state.offlineOnlyFilter ? offlineTracks : tracks;
    final subtitle = formatArtistSubtitle(
      artist,
      fallbackAlbumCount: albums.length,
      fallbackTrackCount: tracks.length,
    );
    final trackStartIndex = hasAlbums ? 2 : 1;
    final headerImageUrl = artist.imageUrl ??
        (albums.isNotEmpty ? albums.first.imageUrl : null) ??
        (tracks.isNotEmpty ? tracks.first.imageUrl : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: trackStartIndex + displayTracks.length,
            padding: EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0),
            separatorBuilder: (_, index) {
              if (index == 0 || (hasAlbums && index == 1)) {
                return SizedBox(height: space(24));
              }
              return SizedBox(height: space(6).clamp(4.0, 10.0));
            },
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ArtistHeader(
                  title: artist.name,
                  subtitle: subtitle,
                  imageUrl: headerImageUrl,
                  onPlayAll: displayTracks.isEmpty
                      ? null
                      : () => state.playFromList(
                            displayTracks,
                            displayTracks.first,
                          ),
                  onShuffle: displayTracks.isEmpty
                      ? null
                      : () => state.playShuffledList(displayTracks),
                  actions: [
                    OutlinedButton.icon(
                      onPressed: state.isFavoriteArtistUpdating(artist.id)
                          ? null
                          : () => state.setArtistFavorite(
                                artist,
                                !state.isFavoriteArtist(artist.id),
                              ),
                      icon: state.isFavoriteArtistUpdating(artist.id)
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : Icon(
                              state.isFavoriteArtist(artist.id)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                            ),
                      label: Text(
                        state.isFavoriteArtist(artist.id)
                            ? 'Unfavorite'
                            : 'Favorite',
                      ),
                    ),
                    FutureBuilder<bool>(
                      future: state.isArtistPinned(artist),
                      builder: (context, snapshot) {
                        final isPinned = snapshot.data ?? false;
                        final isLoading =
                            snapshot.connectionState ==
                                ConnectionState.waiting;
                        return OutlinedButton.icon(
                          onPressed: tracks.isNotEmpty && !isLoading
                              ? () => isPinned
                                  ? state.unpinArtistOffline(artist)
                                  : state.makeArtistAvailableOffline(artist)
                              : null,
                          icon: isLoading
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                )
                              : Icon(
                                  isPinned
                                      ? Icons.download_done_rounded
                                      : Icons.download_rounded,
                                ),
                          label: Text(
                            isPinned
                                ? 'Remove from Offline'
                                : 'Make Available Offline',
                          ),
                        );
                      },
                    ),
                  ],
                );
              }
              if (hasAlbums && index == 1) {
                return _ArtistAlbumsSection(
                  albums: albums,
                  onSelect: state.selectAlbum,
                  state: state,
                );
              }
              final trackIndex = index - trackStartIndex;
              final track = displayTracks[trackIndex];
              return TrackRow(
                track: track,
                index: trackIndex,
                isActive: state.nowPlaying?.id == track.id,
                onTap: () => state.playFromList(displayTracks, track),
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
        ),
      ],
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
    await state.setAlbumFavorite(album, !isFavorite);
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

class _ArtistHeader extends StatelessWidget {
  const _ArtistHeader({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onPlayAll,
    this.onShuffle,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    final cardRadius = clamped(26, min: 16, max: 30);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        final theme = Theme.of(context);
        Widget buildArtworkFallback() => Container(
              color: ColorTokens.cardFillStrong(context),
              child: Center(
                child: Icon(
                  Icons.person,
                  size: clamped(42, min: 30, max: 48),
                ),
              ),
            );
        final artworkExtent = clamped(isNarrow ? 240 : 200, min: 160, max: 260);
        Widget details() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineMedium,
              ),
              SizedBox(height: space(8)),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ColorTokens.textSecondary(context),
                ),
              ),
              SizedBox(height: space(16)),
              Wrap(
                spacing: space(12),
                runSpacing: space(8),
                children: [
                  FilledButton.icon(
                    onPressed: onPlayAll,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                  ),
                  if (onShuffle != null)
                    FilledButton.tonalIcon(
                      onPressed: onShuffle,
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Shuffle'),
                    ),
                  ...actions,
                ],
              ),
            ],
          );
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: ColorTokens.heroGradient(context),
            ),
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: ColorTokens.border(context)),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(cardRadius),
                        topRight: Radius.circular(cardRadius),
                      ),
                      child: SizedBox(
                        height: artworkExtent,
                        child: imageUrl == null
                            ? buildArtworkFallback()
                            : ArtworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: buildArtworkFallback(),
                              ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        space(22).clamp(14.0, 28.0),
                        space(18).clamp(12.0, 24.0),
                        space(22).clamp(14.0, 28.0),
                        space(22).clamp(14.0, 28.0),
                      ),
                      child: details(),
                    ),
                  ],
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(cardRadius),
                          bottomLeft: Radius.circular(cardRadius),
                        ),
                        child: SizedBox(
                          width: artworkExtent,
                          child: imageUrl == null
                              ? buildArtworkFallback()
                              : ArtworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: buildArtworkFallback(),
                                ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            space(24).clamp(16.0, 30.0),
                            space(20).clamp(12.0, 26.0),
                            space(24).clamp(16.0, 30.0),
                            space(20).clamp(12.0, 26.0),
                          ),
                          child: details(),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
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
            final crossAxisCount =
                (constraints.maxWidth / targetWidth).floor();
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
                return LibraryCoverCard(
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
