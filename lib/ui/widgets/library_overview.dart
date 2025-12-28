import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/home_section.dart';
import '../../state/layout_density.dart';
import '../../state/library_view.dart';
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
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final recent = state.playHistory.isNotEmpty
        ? state.playHistory.take(12).toList()
        : state.recentTracks;
    final children = <Widget>[];

    void addSection(List<Widget> section) {
      if (children.isNotEmpty) {
        children.add(SizedBox(height: space(32)));
      }
      children.addAll(section);
    }

    if (state.isHomeSectionVisible(HomeSection.featured)) {
      addSection([
        SectionHeader(
          title: 'Featured',
          action: Row(
            children: [
              Text(
                '${state.featuredTracks.length} tracks',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: ColorTokens.textSecondary(context)),
              ),
              SizedBox(width: space(8)),
              _HeaderAction(
                label: 'View all',
                onTap: () =>
                    state.selectLibraryView(LibraryView.homeFeatured),
              ),
            ],
          ),
        ),
        SizedBox(height: space(16)),
        SizedBox(
          height: space(110).clamp(86.0, 140.0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.featuredTracks.length,
            separatorBuilder: (_, __) => SizedBox(width: space(16)),
            itemBuilder: (context, index) {
              final track = state.featuredTracks[index];
              return FeaturedTrackCard(
                track: track,
                onTap: () => state.playFeatured(track),
              );
            },
          ),
        ),
      ]);
    }

    if (state.isHomeSectionVisible(HomeSection.recent) && recent.isNotEmpty) {
      addSection([
        SectionHeader(
          title: 'Recently played',
          action: Row(
            children: [
              Text(
                '${recent.length} tracks',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: ColorTokens.textSecondary(context)),
              ),
              SizedBox(width: space(8)),
              _HeaderAction(
                label: 'View all',
                onTap: () =>
                    state.selectLibraryView(LibraryView.homeRecent),
              ),
            ],
          ),
        ),
        SizedBox(height: space(16)),
        SizedBox(
          height: space(110).clamp(86.0, 140.0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (_, __) => SizedBox(width: space(16)),
            itemBuilder: (context, index) {
              final track = recent[index];
              return FeaturedTrackCard(
                track: track,
                onTap: () => state.playFromList(recent, track),
                onArtistTap: track.artistIds.isEmpty
                    ? null
                    : () => state.selectArtistById(track.artistIds.first),
              );
            },
          ),
        ),
      ]);
    }

    if (state.isHomeSectionVisible(HomeSection.playlists)) {
      addSection([
        SectionHeader(
          title: 'Playlists',
          action: _HeaderAction(
            label: 'View all',
            onTap: () => state.selectLibraryView(LibraryView.homePlaylists),
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
              itemCount: state.playlists.length,
              itemBuilder: (context, index) {
                final playlist = state.playlists[index];
                return PlaylistCard(
                  playlist: playlist,
                  onTap: () => state.selectPlaylist(playlist),
                  onPlay: () => state.playPlaylist(playlist),
                );
              },
            );
          },
        ),
      ]);
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...children,
          SizedBox(height: space(24)),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
