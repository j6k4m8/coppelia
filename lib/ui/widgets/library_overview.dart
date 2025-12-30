import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/home_section.dart';
import '../../state/layout_density.dart';
import '../../state/library_view.dart';
import '../../core/color_tokens.dart';
import '../../core/formatters.dart';
import 'featured_track_card.dart';
import 'media_card.dart';
import 'playlist_card.dart';
import 'section_header.dart';
import 'smart_list_card.dart';

/// Displays featured content and playlists.
class LibraryOverview extends StatelessWidget {
  /// Creates the library overview widget.
  const LibraryOverview({super.key});

  String _greetingFor(DateTime time) {
    final hour = time.hour;
    if (hour >= 4 && hour < 6) {
      return 'Some early bird tunes';
    }
    if (hour >= 22 || hour < 4) {
      return 'Late night vibes';
    }
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    }
    if (hour >= 12 && hour < 18) {
      return 'Good afternoon';
    }
    return 'Welcome back';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final leftGutter = (32 * densityScale).clamp(16.0, 40.0).toDouble();
    final rightGutter = (24 * densityScale).clamp(12.0, 32.0).toDouble();
    EdgeInsets sectionPadding() =>
        EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0);
    EdgeInsets leftPadding() => EdgeInsets.only(left: leftGutter);
    final recent = state.playHistory.isNotEmpty
        ? state.playHistory.take(12).toList()
        : state.recentTracks;
    final smartLists = state.smartListsOnHome;
    final children = <Widget>[];

    final greeting = _greetingFor(DateTime.now());
    final userName = state.session?.userName ?? 'Listener';
    children.addAll([
      Padding(
        padding: sectionPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting, $userName',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: space(4)),
            Text(
              '${state.libraryTracks.length} tracks • '
              '${state.albums.length} albums • '
              '${state.artists.length} artists • '
              '${state.playlists.length} playlists',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ColorTokens.textSecondary(context, 0.7),
                  ),
            ),
          ],
        ),
      ),
      SizedBox(height: space(28)),
    ]);

    void addSection(List<Widget> section) {
      if (children.isNotEmpty) {
        children.add(SizedBox(height: space(32)));
      }
      children.addAll(section);
    }

    final builders = <HomeSection, void Function()>{
      HomeSection.featured: () {
        if (!state.isHomeSectionVisible(HomeSection.featured)) {
          return;
        }
        addSection([
          Padding(
            padding: sectionPadding(),
            child: SectionHeader(
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
          ),
          SizedBox(height: space(16)),
          Padding(
            padding: leftPadding(),
            child: SizedBox(
              height: space(110).clamp(86.0, 140.0),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
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
          ),
        ]);
      },
      HomeSection.recent: () {
        if (!state.isHomeSectionVisible(HomeSection.recent) || recent.isEmpty) {
          return;
        }
        addSection([
          Padding(
            padding: sectionPadding(),
            child: SectionHeader(
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
          ),
          SizedBox(height: space(16)),
          Padding(
            padding: leftPadding(),
            child: SizedBox(
              height: space(110).clamp(86.0, 140.0),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
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
          ),
        ]);
      },
      HomeSection.jumpIn: () {
        if (!state.isHomeSectionVisible(HomeSection.jumpIn)) {
          return;
        }
        final track = state.jumpInTrack;
        final album = state.jumpInAlbum;
        final artist = state.jumpInArtist;
        if (!state.isLoadingJumpIn && state.shouldRefreshJumpIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              state.loadJumpIn(force: true);
            }
          });
        }
        final entries = <_JumpInEntry>[];
        if (track != null) {
          entries.add(
            _JumpInEntry(
              label: 'Track',
              title: track.title,
              subtitle: track.artists.isNotEmpty
                  ? track.artists.join(', ')
                  : track.album,
              imageUrl: track.imageUrl,
              icon: Icons.music_note,
              onTap: () => state.playFromList([track], track),
            ),
          );
        }
        if (album != null) {
          entries.add(
            _JumpInEntry(
              label: 'Album',
              title: album.name,
              subtitle: album.artistName,
              imageUrl: album.imageUrl,
              icon: Icons.album,
              onTap: () => state.selectAlbum(album),
            ),
          );
        }
        if (artist != null) {
          entries.add(
            _JumpInEntry(
              label: 'Artist',
              title: artist.name,
              subtitle: formatArtistSubtitle(artist),
              imageUrl: artist.imageUrl,
              icon: Icons.person,
              onTap: () => state.selectArtist(artist),
            ),
          );
        }
        if (!state.isLoadingJumpIn &&
            (track == null || album == null || artist == null)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              state.loadJumpIn();
            }
          });
        }
        addSection([
          Padding(
            padding: sectionPadding(),
            child: SectionHeader(
              title: 'Jump in',
              action: Row(
                children: [
                  if (state.isLoadingJumpIn)
                    Text(
                      'Refreshing...',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: ColorTokens.textSecondary(context)),
                    )
                  else
                    Text(
                      '${entries.length} picks',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: ColorTokens.textSecondary(context)),
                    ),
                  SizedBox(width: space(12)),
                  _HeaderAction(
                    label: 'Refresh',
                    onTap: () => state.loadJumpIn(force: true),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: space(16)),
          if (entries.isEmpty)
            Padding(
              padding: sectionPadding(),
              child: SizedBox(
                height: space(120).clamp(96.0, 150.0),
                child: const Center(child: CircularProgressIndicator()),
              ),
            )
          else
            Padding(
              padding: sectionPadding(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final targetWidth = space(190).clamp(150.0, 240.0);
                  final columns =
                      (constraints.maxWidth / targetWidth).floor().clamp(1, 3);
                  final spacing = space(16);
                  final width =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: entries
                        .map(
                          (entry) => SizedBox(
                            width: width,
                            child: _JumpInCard(entry: entry),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
        ]);
      },
      HomeSection.smartLists: () {
        if (!state.isHomeSectionVisible(HomeSection.smartLists) ||
            smartLists.isEmpty) {
          return;
        }
        addSection([
          Padding(
            padding: sectionPadding(),
            child: SectionHeader(
              title: 'Smart Lists',
              action: Row(
                children: [
                  Text(
                    '${smartLists.length} lists',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: ColorTokens.textSecondary(context)),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: space(16)),
          Padding(
            padding: sectionPadding(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final targetWidth = space(190).clamp(150.0, 240.0);
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
                  itemCount: smartLists.length,
                  itemBuilder: (context, index) {
                    final list = smartLists[index];
                    return SmartListCard(
                      smartList: list,
                      onTap: () => state.selectSmartList(list),
                      onPlay: () => state.playSmartList(list),
                    );
                  },
                );
              },
            ),
          ),
        ]);
      },
      HomeSection.playlists: () {
        if (!state.isHomeSectionVisible(HomeSection.playlists)) {
          return;
        }
        addSection([
          Padding(
            padding: sectionPadding(),
            child: SectionHeader(
              title: 'Playlists',
              action: _HeaderAction(
                label: 'View all',
                onTap: () => state.selectLibraryView(LibraryView.homePlaylists),
              ),
            ),
          ),
          SizedBox(height: space(16)),
          Padding(
            padding: sectionPadding(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final targetWidth = space(190).clamp(150.0, 240.0);
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
          ),
        ]);
      },
    };

    for (final section in state.homeSectionOrder) {
      final builder = builders[section];
      if (builder != null) {
        builder();
      }
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
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

class _JumpInEntry {
  const _JumpInEntry({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.imageUrl,
    this.icon = Icons.music_note,
  });

  final String label;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final IconData icon;
  final VoidCallback onTap;
}

class _JumpInCard extends StatelessWidget {
  const _JumpInCard({required this.entry});

  final _JumpInEntry entry;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ColorTokens.textSecondary(context),
                letterSpacing: 0.6,
              ),
        ),
        SizedBox(height: space(8).clamp(6.0, 12.0)),
        AspectRatio(
          aspectRatio: 1.05,
          child: MediaCard(
            layout: MediaCardLayout.vertical,
            title: entry.title,
            subtitle: entry.subtitle,
            imageUrl: entry.imageUrl,
            fallbackIcon: entry.icon,
            onTap: entry.onTap,
          ),
        ),
      ],
    );
  }
}
