import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../state/app_state.dart';
import 'section_header.dart';
import 'track_row.dart';

/// Displays the full library track list with pagination.
class TracksView extends StatefulWidget {
  /// Creates the tracks view.
  const TracksView({super.key});

  @override
  State<TracksView> createState() => _TracksViewState();
}

class _TracksViewState extends State<TracksView> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _controller.addListener(_handleScroll);
    final state = context.read<AppState>();
    if (state.libraryTracks.isEmpty && !state.isLoadingTracks) {
      unawaited(state.loadLibraryTracks(reset: true));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final state = context.read<AppState>();
    if (state.isLoadingTracks || !state.hasMoreTracks) {
      return;
    }
    final max = _controller.position.maxScrollExtent;
    if (max <= 0) {
      return;
    }
    if (_controller.position.pixels >= max - 320) {
      unawaited(state.loadLibraryTracks());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final total = state.libraryStats?.trackCount ?? 0;
    final count = state.libraryTracks.length;
    final label = total > 0 ? '$count of $total tracks' : '$count tracks';

    if (count == 0 && state.isLoadingTracks) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Tracks',
          action: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: ColorTokens.textSecondary(context)),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            controller: _controller,
            itemCount: count + (state.hasMoreTracks ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              if (index >= count) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: state.isLoadingTracks
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton.icon(
                            onPressed: () =>
                                state.loadLibraryTracks(),
                            icon: const Icon(Icons.expand_more),
                            label: const Text('Load more'),
                          ),
                  ),
                );
              }
              final track = state.libraryTracks[index];
              return TrackRow(
                track: track,
                index: index,
                isActive: state.nowPlaying?.id == track.id,
                onTap: () => state.playFromList(state.libraryTracks, track),
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
