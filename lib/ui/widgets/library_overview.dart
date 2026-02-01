import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/home_section.dart';
import '../../state/home_shelf_layout.dart';
import '../../state/layout_density.dart';
import '../../state/library_view.dart';
import '../../core/color_tokens.dart';
import '../../core/formatters.dart';
import '../../models/media_item.dart';
import 'featured_track_card.dart';
import 'media_card.dart';
import 'playlist_tile.dart';
import 'section_header.dart';
import 'smart_list_card.dart';
import 'header_controls.dart';
import 'header_action.dart';
import 'adaptive_grid.dart';
import 'grid_metrics.dart';

/// Displays featured content and playlists.
class LibraryOverview extends StatelessWidget {
  /// Creates the library overview widget.
  const LibraryOverview({super.key});

  /// Computes a responsive grid column count.
  ///
  /// - Uses the available content width (constraints).
  /// - Forces at least [minColumnsOnPhone] columns for phone-sized screens,
  ///   unless the content width is too small to feasibly fit them.
  int _homeGridColumns(
    BuildContext context, {
    required double maxWidth,
    required double targetWidth,
    int maxColumns = 3,
    int minColumnsOnPhone = 2,
    double phoneWidthBreakpoint = 420,
    double absoluteMinItemWidth = 120,
  }) {
    final computed = (maxWidth / targetWidth).floor();
    final clamped = computed.clamp(1, maxColumns);

    final isPhoneWidth =
        MediaQuery.of(context).size.width < phoneWidthBreakpoint;
    if (!isPhoneWidth) {
      return clamped;
    }

    // If we can't realistically fit N columns at all, fall back to 1.
    final canFitMinColumns =
        maxWidth >= (absoluteMinItemWidth * minColumnsOnPhone);
    if (!canFitMinColumns) {
      return 1;
    }

    return clamped < minColumnsOnPhone ? minColumnsOnPhone : clamped;
  }

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
    final stats = state.libraryStats;
    final trackCount = stats?.trackCount ?? state.libraryTracks.length;
    final albumCount = stats?.albumCount ?? state.albums.length;
    final artistCount = stats?.artistCount ?? state.artists.length;
    final playlistCount = stats?.playlistCount ?? state.playlists.length;
    children.addAll([
      Padding(
        padding: sectionPadding(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, $userName',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: space(4)),
                  Text(
                    '${formatCount(trackCount)} tracks • '
                    '${formatCount(albumCount)} albums • '
                    '${formatCount(artistCount)} artists • '
                    '${formatCount(playlistCount)} playlists',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ColorTokens.textSecondary(context, 0.7),
                        ),
                  ),
                ],
              ),
            ),
            SearchCircleButton(
              onTap: state.requestSearchFocus,
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

    Widget buildShelf({
      required List<MediaItem> tracks,
      required void Function(MediaItem track) onTap,
      VoidCallback? Function(MediaItem track)? onArtistTap,
    }) {
      if (state.homeShelfLayout == HomeShelfLayout.grid) {
        return Padding(
          padding: sectionPadding(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final targetWidth = space(180).clamp(130.0, 220.0);
              const aspectRatio = 1.35;
              final columns = math.max(
                2,
                GridMetrics.fromWidth(
                  width: constraints.maxWidth,
                  itemAspectRatio: aspectRatio,
                  itemMinWidth: targetWidth,
                  spacing: space(12),
                ).columns,
              );
              final rows = state.homeShelfGridRows;
              final maxItems = math.min(tracks.length, columns * rows);
              final displayTracks = tracks.take(maxItems).toList();
              return AdaptiveGrid(
                itemCount: displayTracks.length,
                aspectRatio: aspectRatio,
                spacing: space(12),
                targetMinWidth: targetWidth,
                columns: columns,
                itemBuilder: (context, index) {
                  final track = displayTracks[index];
                  return FeaturedTrackCard(
                    track: track,
                    onTap: () => onTap(track),
                    onArtistTap: onArtistTap?.call(track),
                    expand: true,
                    layout: MediaCardLayout.vertical,
                    artAspectRatio: 2.6,
                  );
                },
              );
            },
          ),
        );
      }

      return Padding(
        padding: leftPadding(),
        child: SizedBox(
          height: space(110).clamp(86.0, 140.0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: tracks.length,
            separatorBuilder: (_, __) => SizedBox(width: space(16)),
            itemBuilder: (context, index) {
              final track = tracks[index];
              return FeaturedTrackCard(
                track: track,
                onTap: () => onTap(track),
                onArtistTap: onArtistTap?.call(track),
              );
            },
          ),
        ),
      );
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
                  HeaderAction(
                    label: 'View all',
                    onTap: () =>
                        state.selectLibraryView(LibraryView.homeFeatured),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: space(16)),
          buildShelf(
            tracks: state.featuredTracks,
            onTap: state.playFeatured,
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
                  HeaderAction(
                    label: 'View all',
                    onTap: () =>
                        state.selectLibraryView(LibraryView.homeRecent),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: space(16)),
          buildShelf(
            tracks: recent,
            onTap: (track) => state.playFromList(recent, track),
            onArtistTap: (track) => track.artistIds.isEmpty
                ? null
                : () => state.selectArtistById(track.artistIds.first),
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
                  HeaderAction(
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
                  final columns = _homeGridColumns(
                    context,
                    maxWidth: constraints.maxWidth,
                    targetWidth: targetWidth,
                    maxColumns: 3,
                    minColumnsOnPhone: 2,
                    absoluteMinItemWidth: space(140).clamp(120.0, 170.0),
                  );
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
            child: AdaptiveGrid(
              itemCount: smartLists.length,
              aspectRatio: 1.1,
              spacing: space(16),
              targetMinWidth: space(170).clamp(140.0, 220.0),
              itemBuilder: (context, index) {
                final list = smartLists[index];
                return SmartListCard(
                  smartList: list,
                  onTap: () => state.selectSmartList(list),
                  onPlay: () => state.playSmartList(list),
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
              action: HeaderAction(
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
                // Phones often end up with a content width that makes the
                // naive floor division yield 1 column. Force 2 columns for
                // compact widths to avoid giant, single-row playlist cards.
                final targetWidth = space(170).clamp(140.0, 220.0);
                final columns = _homeGridColumns(
                  context,
                  maxWidth: constraints.maxWidth,
                  targetWidth: targetWidth,
                  maxColumns: 4,
                  minColumnsOnPhone: 2,
                  absoluteMinItemWidth: space(150).clamp(120.0, 180.0),
                );
                return AdaptiveGrid(
                  itemCount: state.playlists.length,
                  aspectRatio: 1.1,
                  spacing: space(16),
                  targetMinWidth: targetWidth,
                  columns: columns,
                  itemBuilder: (context, index) {
                    final playlist = state.playlists[index];
                    return PlaylistTile(
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
