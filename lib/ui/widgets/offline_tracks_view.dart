import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import '../../state/layout_density.dart';
import 'offline_empty_view.dart';
import 'page_header.dart';
import 'track_row.dart';

/// Displays offline-ready tracks.
class OfflineTracksView extends StatelessWidget {
  /// Creates the offline tracks view.
  const OfflineTracksView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    final leftGutter =
        (32 * densityScale).clamp(16.0, 40.0).toDouble();
    final rightGutter =
        (24 * densityScale).clamp(12.0, 32.0).toDouble();
    return FutureBuilder<List<MediaItem>>(
      future: state.loadOfflineTracks(),
      builder: (context, snapshot) {
        final tracks = snapshot.data ?? const <MediaItem>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            tracks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (tracks.isEmpty) {
          return OfflineEmptyView(
            title: LibraryView.offlineTracks.title,
            subtitle: LibraryView.offlineTracks.subtitle,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0),
              child: PageHeader(
                title: 'Offline / Tracks',
                subtitle: '${tracks.length} cached tracks',
              ),
            ),
            SizedBox(height: 16 * densityScale),
            Expanded(
              child: ListView.separated(
                itemCount: tracks.length,
                padding: EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 32),
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  final isFavorite = state.isFavoriteTrack(track.id);
                  final isActive = state.nowPlaying?.id == track.id;
                  return TrackRow(
                    track: track,
                    index: index,
                    isActive: isActive,
                    onTap: () => state.playFromList(tracks, track),
                    onPlayNext: () => state.playNext(track),
                    onAddToQueue: () => state.enqueueTrack(track),
                    isFavorite: isFavorite,
                    isFavoriteUpdating: state.isFavoriteTrackUpdating(track.id),
                    onToggleFavorite: () =>
                        state.setTrackFavorite(track, !isFavorite),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
