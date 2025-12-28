import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../models/album.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'artwork_image.dart';
import 'context_menu.dart';
import 'library_card.dart';
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
    final artist = state.selectedArtist;
    if (artist == null) {
      return const SizedBox.shrink();
    }
    final subtitle = artist.albumCount > 0
        ? '${artist.albumCount} albums • ${artist.trackCount} tracks'
        : '${artist.trackCount} tracks';
    final albums = _albumsForArtist(state.albums, artist.name);
    final hasAlbums = albums.isNotEmpty;
    final tracks = state.artistTracks;
    final trackStartIndex = hasAlbums ? 2 : 1;
    final headerImageUrl = artist.imageUrl ??
        (albums.isNotEmpty ? albums.first.imageUrl : null) ??
        (tracks.isNotEmpty ? tracks.first.imageUrl : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: trackStartIndex + tracks.length,
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
                  onPlayAll: tracks.isEmpty
                      ? null
                      : () => state.playFromArtist(tracks.first),
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
              final track = tracks[trackIndex];
              return TrackRow(
                track: track,
                index: trackIndex,
                isActive: state.nowPlaying?.id == track.id,
                onTap: () => state.playFromArtist(track),
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
        child: Text(isFavorite ? 'Unfavorite' : 'Favorite'),
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
}

enum _AlbumAction { play, open, favorite, goToArtist }

class _ArtistHeader extends StatelessWidget {
  const _ArtistHeader({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onPlayAll,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback? onPlayAll;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        final theme = Theme.of(context);
        Widget buildArtworkFallback({double? size}) => Container(
              width: size,
              height: size,
              color: ColorTokens.cardFillStrong(context),
              child: Icon(
                Icons.person,
                size: size == null
                    ? clamped(42, min: 32, max: 48)
                    : clamped(36, min: 26, max: 42),
              ),
            );
        final artworkSize = clamped(isNarrow ? 160 : 140, min: 110, max: 190);
        final artwork = ClipRRect(
          borderRadius: BorderRadius.circular(
            clamped(20, min: 12, max: 24),
          ),
          child: ArtworkImage(
            imageUrl: imageUrl,
            width: artworkSize,
            height: artworkSize,
            fit: BoxFit.cover,
            placeholder: buildArtworkFallback(size: artworkSize),
          ),
        );
        Widget details({
          TextStyle? titleStyle,
          TextStyle? subtitleStyle,
        }) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: titleStyle ?? theme.textTheme.headlineMedium,
              ),
              SizedBox(height: space(8)),
              Text(
                subtitle,
                style: subtitleStyle ??
                    theme.textTheme.bodyMedium?.copyWith(
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
                ],
              ),
            ],
          );
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(space(24).clamp(14.0, 32.0)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: ColorTokens.heroGradient(context),
            ),
            borderRadius: BorderRadius.circular(
              clamped(26, min: 16, max: 30),
            ),
            border: Border.all(color: ColorTokens.border(context)),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    artwork,
                    SizedBox(height: space(20)),
                    details(),
                  ],
                )
              : Row(
                  children: [
                    artwork,
                    SizedBox(width: space(24)),
                    Expanded(child: details()),
                  ],
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
