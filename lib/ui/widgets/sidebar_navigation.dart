import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import '../../state/layout_density.dart';
import '../../state/sidebar_item.dart';
import '../../core/color_tokens.dart';

/// Vertical navigation rail for playlists and actions.
class SidebarNavigation extends StatefulWidget {
  /// Creates the sidebar navigation.
  const SidebarNavigation({super.key, this.onCollapse, this.onNavigate});

  /// Optional handler to collapse the sidebar.
  final VoidCallback? onCollapse;

  /// Optional handler when a nav item is selected.
  final VoidCallback? onNavigate;

  @override
  State<SidebarNavigation> createState() => _SidebarNavigationState();
}

class _SidebarNavigationState extends State<SidebarNavigation> {
  bool _favoritesExpanded = true;
  bool _browseExpanded = true;
  bool _playbackExpanded = true;
  bool _playlistsExpanded = true;

  void _handleNavigate(VoidCallback action) {
    action();
    widget.onNavigate?.call();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final showFavoritesSection = state.isSidebarItemVisible(
          SidebarItem.favoritesAlbums,
        ) ||
        state.isSidebarItemVisible(SidebarItem.favoritesSongs) ||
        state.isSidebarItemVisible(SidebarItem.favoritesArtists);
    final showBrowseSection = state.isSidebarItemVisible(
          SidebarItem.browseAlbums,
        ) ||
        state.isSidebarItemVisible(SidebarItem.browseArtists) ||
        state.isSidebarItemVisible(SidebarItem.browseGenres) ||
        state.isSidebarItemVisible(SidebarItem.browseTracks);
    final showPlaybackSection =
        state.isSidebarItemVisible(SidebarItem.history) ||
            state.isSidebarItemVisible(SidebarItem.queue);
    final showPlaylistsSection =
        state.isSidebarItemVisible(SidebarItem.playlists);
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24)
          .scale(densityScale),
      decoration: BoxDecoration(
        color: ColorTokens.panelBackground(context),
        border: Border(
          right: BorderSide(
            color: ColorTokens.border(context),
          ),
        ),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Row(
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: state.isSidebarItemVisible(SidebarItem.home)
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: state.isSidebarItemVisible(SidebarItem.home)
                        ? () => _handleNavigate(
                              () => state.selectLibraryView(
                                LibraryView.home,
                              ),
                            )
                        : null,
                    child: Row(
                      children: [
                        SizedBox(
                          width: space(36).clamp(28.0, 42.0),
                          height: space(36).clamp(28.0, 42.0),
                          child: SvgPicture.asset(
                            'assets/logo.svg',
                            width: space(36).clamp(28.0, 42.0),
                            height: space(36).clamp(28.0, 42.0),
                          ),
                        ),
                        SizedBox(width: space(12).clamp(8.0, 16.0)),
                        Text(
                          'Coppelia',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.onCollapse != null)
                IconButton(
                  onPressed: widget.onCollapse,
                  icon: const Icon(Icons.chevron_left, size: 18),
                  tooltip: 'Collapse sidebar',
                ),
            ],
          ),
          SizedBox(height: space(32)),
          if (state.isSidebarItemVisible(SidebarItem.settings))
            _NavTile(
              icon: Icons.menu,
              label: 'Settings',
              selected: state.selectedPlaylist == null &&
                  state.selectedView == LibraryView.settings,
              onTap: () => _handleNavigate(
                () => state.selectLibraryView(LibraryView.settings),
              ),
            ),
          SizedBox(height: space(20)),
          if (showFavoritesSection) ...[
            _SectionHeader(
              title: 'Favorites',
              onTap: () => setState(() {
                _favoritesExpanded = !_favoritesExpanded;
              }),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: _favoritesExpanded
                  ? Column(
                      children: [
                        SizedBox(height: space(8)),
                        if (state.isSidebarItemVisible(
                          SidebarItem.favoritesAlbums,
                        ))
                          _NavTile(
                            icon: Icons.album,
                            label: 'Albums',
                            selected: state.selectedPlaylist == null &&
                                state.selectedView ==
                                    LibraryView.favoritesAlbums,
                            onTap: () => _handleNavigate(
                              () => state.selectLibraryView(
                                LibraryView.favoritesAlbums,
                              ),
                            ),
                          ),
                        if (state.isSidebarItemVisible(
                          SidebarItem.favoritesSongs,
                        ))
                          _NavTile(
                            icon: Icons.music_note,
                            label: 'Songs',
                            selected: state.selectedPlaylist == null &&
                                state.selectedView ==
                                    LibraryView.favoritesSongs,
                            onTap: () => _handleNavigate(
                              () => state.selectLibraryView(
                                LibraryView.favoritesSongs,
                              ),
                            ),
                          ),
                        if (state.isSidebarItemVisible(
                          SidebarItem.favoritesArtists,
                        ))
                          _NavTile(
                            icon: Icons.people_alt,
                            label: 'Artists',
                            selected: state.selectedPlaylist == null &&
                                state.selectedView ==
                                    LibraryView.favoritesArtists,
                            onTap: () => _handleNavigate(
                              () => state.selectLibraryView(
                                LibraryView.favoritesArtists,
                              ),
                            ),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
          SizedBox(height: space(20)),
          if (showBrowseSection) ...[
            _SectionHeader(
              title: 'Browse',
              onTap: () => setState(() {
                _browseExpanded = !_browseExpanded;
              }),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: _browseExpanded
                  ? Column(
                      children: [
                        SizedBox(height: space(8)),
                        if (state.isSidebarItemVisible(
                          SidebarItem.browseAlbums,
                        ))
                          _NavTile(
                            icon: Icons.album,
                            label: 'Albums',
                            selected: state.selectedPlaylist == null &&
                                state.selectedView == LibraryView.albums,
                            onTap: () => _handleNavigate(
                              () =>
                                  state.selectLibraryView(LibraryView.albums),
                            ),
                          ),
                        if (state.isSidebarItemVisible(
                          SidebarItem.browseArtists,
                        ))
                          _NavTile(
                            icon: Icons.people_alt,
                            label: 'Artists',
                            selected: state.selectedPlaylist == null &&
                                state.selectedView == LibraryView.artists,
                            onTap: () => _handleNavigate(
                              () =>
                                  state.selectLibraryView(LibraryView.artists),
                            ),
                          ),
                        if (state.isSidebarItemVisible(
                          SidebarItem.browseGenres,
                        ))
                          _NavTile(
                            icon: Icons.auto_awesome_motion,
                            label: 'Genres',
                            selected: state.selectedPlaylist == null &&
                                state.selectedView == LibraryView.genres,
                            onTap: () => _handleNavigate(
                              () =>
                                  state.selectLibraryView(LibraryView.genres),
                            ),
                          ),
                        if (state.isSidebarItemVisible(
                          SidebarItem.browseTracks,
                        ))
                          _NavTile(
                            icon: Icons.music_note,
                            label: 'Tracks',
                            selected: state.selectedPlaylist == null &&
                                state.selectedView == LibraryView.tracks,
                            onTap: () => _handleNavigate(
                              () => state.selectLibraryView(
                                LibraryView.tracks,
                              ),
                            ),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
          SizedBox(height: space(16)),
          if (showPlaybackSection) ...[
            _SectionHeader(
              title: 'Playback',
              onTap: () => setState(() {
                _playbackExpanded = !_playbackExpanded;
              }),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: _playbackExpanded
                  ? Column(
                      children: [
                        SizedBox(height: space(8)),
                        if (state.isSidebarItemVisible(SidebarItem.history))
                          _NavTile(
                            icon: Icons.history,
                            label: 'History',
                            selected: state.selectedPlaylist == null &&
                                state.selectedView == LibraryView.history,
                            onTap: () => _handleNavigate(
                              () =>
                                  state.selectLibraryView(LibraryView.history),
                            ),
                          ),
                        if (state.isSidebarItemVisible(SidebarItem.queue))
                          _NavTile(
                            icon: Icons.queue_music,
                            label: 'Queue',
                            selected: state.selectedPlaylist == null &&
                                state.selectedView == LibraryView.queue,
                            onTap: () => _handleNavigate(
                              () =>
                                  state.selectLibraryView(LibraryView.queue),
                            ),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
          SizedBox(height: space(16)),
          if (showPlaylistsSection) ...[
            _SectionHeader(
              title: 'Playlists',
              onTap: () => setState(() {
                _playlistsExpanded = !_playlistsExpanded;
              }),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: _playlistsExpanded
                  ? Column(
                      children: [
                        SizedBox(height: space(12)),
                        ...state.playlists.map(
                          (playlist) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _PlaylistTile(
                              playlist: playlist,
                              selected:
                                  state.selectedPlaylist?.id == playlist.id,
                              onTap: () =>
                                  _handleNavigate(() => state.selectPlaylist(
                                        playlist,
                                      )),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
          SizedBox(height: space(16)),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final densityScale =
        context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: space(12).clamp(8.0, 16.0),
          vertical: space(10).clamp(6.0, 14.0),
        ),
        decoration: BoxDecoration(
          color: selected ? ColorTokens.activeRow(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(
            clamped(16, min: 10, max: 20),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: clamped(18, min: 14, max: 20)),
            SizedBox(width: space(12).clamp(8.0, 16.0)),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final densityScale =
        context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: space(6).clamp(4.0, 8.0),
          vertical: space(6).clamp(4.0, 8.0),
        ),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: ColorTokens.textSecondary(context, 0.7)),
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.onTap,
    required this.selected,
  });

  final Playlist playlist;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final densityScale =
        context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: space(12).clamp(8.0, 16.0),
          vertical: space(10).clamp(6.0, 14.0),
        ),
        decoration: BoxDecoration(
          color: selected ? ColorTokens.activeRow(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(
            clamped(14, min: 10, max: 18),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.queue_music, size: clamped(16, min: 12, max: 18)),
            SizedBox(width: space(10).clamp(6.0, 14.0)),
            Expanded(
              child: Text(
                playlist.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
