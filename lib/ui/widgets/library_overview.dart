import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../core/color_tokens.dart';
import 'featured_track_card.dart';
import 'playlist_card.dart';
import 'section_header.dart';

/// Displays featured content and playlists.
class LibraryOverview extends StatelessWidget {
  /// Creates the library overview widget.
  const LibraryOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final recent = state.playHistory.isNotEmpty
        ? state.playHistory.take(12).toList()
        : state.recentTracks;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Featured',
            action: Text(
              '${state.featuredTracks.length} tracks',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: ColorTokens.textSecondary(context)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.featuredTracks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final track = state.featuredTracks[index];
                return FeaturedTrackCard(
                  track: track,
                  onTap: () => state.playFeatured(track),
                );
              },
            ),
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 32),
            SectionHeader(
              title: 'Recently played',
              action: Text(
                '${recent.length} tracks',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: ColorTokens.textSecondary(context)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final track = recent[index];
                  return FeaturedTrackCard(
                    track: track,
                    onTap: () => state.playFromList(recent, track),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 32),
          const SectionHeader(title: 'Playlists'),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = (constraints.maxWidth / 220).floor();
              final columns = crossAxisCount.clamp(2, 4);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: state.playlists.length,
                itemBuilder: (context, index) {
                  final playlist = state.playlists[index];
                  return PlaylistCard(
                    playlist: playlist,
                    onTap: () => state.selectPlaylist(playlist),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
