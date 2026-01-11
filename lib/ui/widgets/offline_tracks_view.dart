import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import 'offline_section_loader.dart';
import 'track_list_view.dart';

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
        return TrackListView(
          title: 'Offline / Tracks',
          subtitle: '${tracks.length} cached tracks',
          listBottomPadding: 32,
          tracks: tracks,
          onTapTrack: (track, _) => state.playFromList(tracks, track),
          enableAlbumArtistNav: false,
          enableGoToActions: false,
        );
      },
    );
  }
}
