import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../models/album.dart';
import '../../state/app_state.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: trackStartIndex + tracks.length,
            separatorBuilder: (_, index) {
              if (index == 0 || (hasAlbums && index == 1)) {
                return const SizedBox(height: 24);
              }
              return const SizedBox(height: 6);
            },
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ArtistHeader(
                  title: artist.name,
                  subtitle: subtitle,
                  imageUrl: artist.imageUrl,
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
    await state.selectArtistByName(album.artistName);
  }
}

enum _AlbumAction { play, open, goToArtist }

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ColorTokens.heroGradient(context),
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: ColorTokens.border(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;
          Widget buildArtworkFallback() => Container(
                width: isNarrow ? 160 : 140,
                height: isNarrow ? 160 : 140,
                color: ColorTokens.cardFillStrong(context),
                child: const Icon(Icons.person, size: 36),
              );
          final artwork = ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: imageUrl == null
                ? buildArtworkFallback()
                : CachedNetworkImage(
                    imageUrl: imageUrl!,
                    width: isNarrow ? 160 : 140,
                    height: isNarrow ? 160 : 140,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => buildArtworkFallback(),
                    errorWidget: (_, __, ___) => buildArtworkFallback(),
                  ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: ColorTokens.textSecondary(context)),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
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
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                artwork,
                const SizedBox(height: 20),
                details,
              ],
            );
          }
          return Row(
            children: [
              artwork,
              const SizedBox(width: 24),
              Expanded(child: details),
            ],
          );
        },
      ),
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
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = (constraints.maxWidth / 220).floor();
            final columns = crossAxisCount < 1 ? 1 : crossAxisCount;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
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
