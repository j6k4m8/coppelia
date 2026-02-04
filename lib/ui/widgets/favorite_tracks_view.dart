import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import 'track_list_view.dart';

/// Displays favorite tracks list.
class FavoriteTracksView extends StatelessWidget {
  /// Creates the favorite tracks view.
  const FavoriteTracksView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final favorites = state.favoriteTracks;
    return TrackListView(
      title: 'Favorite Tracks',
      subtitle: '${favorites.length} tracks',
      tracks: favorites,
      onTapTrack: (track, _) => state.playFromFavorites(track),
    );
  }
}
