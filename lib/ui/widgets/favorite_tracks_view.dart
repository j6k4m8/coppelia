import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../core/color_tokens.dart';
import 'page_header.dart';
import 'track_row.dart';

/// Displays favorite tracks list.
class FavoriteTracksView extends StatelessWidget {
  /// Creates the favorite tracks view.
  const FavoriteTracksView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final leftGutter =
        (32 * densityScale).clamp(16.0, 40.0).toDouble();
    final rightGutter =
        (24 * densityScale).clamp(12.0, 32.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0),
          child: PageHeader(
            title: 'Favorites / Tracks',
            subtitle: '${state.favoriteTracks.length} tracks',
          ),
        ),
        SizedBox(height: space(16)),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0),
            itemCount: state.favoriteTracks.length,
            separatorBuilder: (_, __) =>
                SizedBox(height: space(6).clamp(4.0, 10.0)),
            itemBuilder: (context, index) {
              final track = state.favoriteTracks[index];
              return TrackRow(
                track: track,
                index: index,
                isActive: state.nowPlaying?.id == track.id,
                onTap: () => state.playFromFavorites(track),
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
