import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import 'offline_section_loader.dart';
import 'track_list_section.dart';
import 'track_row.dart';

/// Displays offline-ready tracks.
class OfflineTracksView extends StatelessWidget {
  /// Creates the offline tracks view.
  const OfflineTracksView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return OfflineSectionLoader<MediaItem>(
      future: state.loadOfflineTracks(),
      emptyTitle: LibraryView.offlineTracks.title,
      emptySubtitle: LibraryView.offlineTracks.subtitle,
      builder: (context, tracks) {
        return TrackListSection(
          title: 'Offline / Tracks',
          subtitle: '${tracks.length} cached tracks',
          listBottomPadding: 32,
          itemCount: tracks.length,
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
        );
      },
    );
  }
}
