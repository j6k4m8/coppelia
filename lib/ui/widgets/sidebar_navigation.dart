import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../models/smart_list.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import '../../state/layout_density.dart';
import '../../state/sidebar_item.dart';
import '../../core/color_tokens.dart';
import 'compact_switch.dart';
import 'corner_radius.dart';
import 'playlist_dialogs.dart';
import 'smart_list_dialogs.dart';

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
  bool _offlineExpanded = true;
  bool _browseExpanded = true;
  bool _playbackExpanded = true;
  bool _playlistsExpanded = true;
  bool _smartListsExpanded = true;

  void _handleNavigate(VoidCallback action) {
    action();
    widget.onNavigate?.call();
  }

  Future<void> _renameSmartList(
    BuildContext context,
    SmartList smartList,
  ) async {
    final controller = TextEditingController(text: smartList.name);
    final appState = context.read<AppState>();
    String value = controller.text;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rename smart list'),
          content: TextField(
            controller: controller,
            autofocus: true,
            onChanged: (text) => setState(() {
              value = text;
            }),
            onSubmitted: (_) => Navigator.of(context).pop(value),
            decoration: const InputDecoration(hintText: 'Smart list name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: value.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(value),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    final trimmed = result?.trim();
    if (!mounted || trimmed == null || trimmed.isEmpty) {
      return;
    }
    await appState.updateSmartList(smartList.copyWith(name: trimmed));
  }

  Future<void> _duplicateSmartList(
    BuildContext context,
    SmartList smartList,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final copy = smartList.copyWith(
      id: 'smart-$now',
      name: '${smartList.name} Copy',
    );
    final appState = context.read<AppState>();
    final created = await appState.createSmartList(copy);
    if (mounted) {
      await appState.selectSmartList(created);
    }
  }

  Future<void> _deleteSmartList(
    BuildContext context,
    SmartList smartList,
  ) async {
    final appState = context.read<AppState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Smart List?'),
        content: Text('“${smartList.name}” will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      await appState.deleteSmartList(smartList);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layoutDensity = context.select(
      (AppState s) => s.layoutDensity.scaleDouble,
    );
    final homeVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.home),
    );
    final settingsVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.settings),
    );
    final searchVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.search),
    );
    final favoritesAlbumsVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.favoritesAlbums),
    );
    final favoritesArtistsVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.favoritesArtists),
    );
    final favoritesTracksVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.favoritesSongs),
    );
    final offlineAlbumsVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.offlineAlbums),
    );
    final offlineArtistsVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.offlineArtists),
    );
    final offlinePlaylistsVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.offlinePlaylists),
    );
    final offlineTracksVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.offlineTracks),
    );
    final browseAlbumsVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.browseAlbums),
    );
    final browseArtistsVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.browseArtists),
    );
    final browseGenresVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.browseGenres),
    );
    final browsePlaylistsVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.browsePlaylists),
    );
    final browseTracksVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.browseTracks),
    );
    final playbackHistoryVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.history),
    );
    final playbackQueueVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.queue),
    );
    final playlistsVisible = context.select(
      (AppState s) => s.isSidebarItemVisible(SidebarItem.playlists),
    );
    final offlineMode = context.select((AppState s) => s.offlineMode);
    final sessionPresent = context.select((AppState s) => s.session != null);
    final smartLists = context.select((AppState s) => s.smartLists);
    final playlists = context.select((AppState s) => s.playlists);
    final selectedView = context.select((AppState s) => s.selectedView);
    final selectedPlaylistId = context.select(
      (AppState s) => s.selectedPlaylist?.id,
    );
    final selectedSmartListId = context.select(
      (AppState s) => s.selectedSmartList?.id,
    );
    final topInset = MediaQuery.of(context).padding.top +
        (14 * layoutDensity).clamp(12.0, 20.0).toDouble();
    final horizontalPadding = 20 * layoutDensity;
    final verticalPadding = 24 * layoutDensity;
    double space(double value) => value * layoutDensity;
    final showFavoritesSection = favoritesAlbumsVisible ||
        favoritesArtistsVisible ||
        favoritesTracksVisible;
    final showOfflineSection = offlineAlbumsVisible ||
        offlineArtistsVisible ||
        offlinePlaylistsVisible ||
        offlineTracksVisible;
    final showBrowseSection = browseAlbumsVisible ||
        browseArtistsVisible ||
        browseGenresVisible ||
        browsePlaylistsVisible ||
        browseTracksVisible;
    final showPlaybackSection = playbackHistoryVisible || playbackQueueVisible;
    final showSmartListsSection = smartLists.isNotEmpty || sessionPresent;
    final showPlaylistsSection = playlistsVisible;
    final appState = context.read<AppState>();
    final effectiveHorizontalPadding =
        (horizontalPadding * 0.6).clamp(10.0, horizontalPadding);
    return Container(
      padding: EdgeInsets.fromLTRB(
        effectiveHorizontalPadding,
        verticalPadding + topInset,
        0,
        0,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.panelBackground(context),
        border: Border(
          right: BorderSide(
            color: ColorTokens.border(context),
          ),
        ),
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          0,
          0,
          effectiveHorizontalPadding,
          0,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: homeVisible
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: homeVisible
                        ? () => _handleNavigate(
                              () => appState.selectLibraryView(
                                LibraryView.home,
                              ),
                            )
                        : null,
                    child: Row(
                      children: [
                        // SizedBox(
                        //   width: space(36).clamp(28.0, 42.0),
                        //   height: space(36).clamp(28.0, 42.0),
                        //   child: Image.asset(
                        //     'assets/logo.png',
                        //     width: space(36).clamp(28.0, 42.0),
                        //     height: space(36).clamp(28.0, 42.0),
                        //     fit: BoxFit.contain,
                        //   ),
                        // ),
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
          if (settingsVisible) ...[
            _NavTile(
              icon: Icons.menu,
              label: 'Settings',
              selected: selectedPlaylistId == null &&
                  selectedView == LibraryView.settings,
              onTap: () => _handleNavigate(
                () => appState.selectLibraryView(LibraryView.settings),
              ),
            ),
            SizedBox(height: space(8)),
            if (searchVisible) ...[
              _NavTile(
                icon: Icons.search,
                label: 'Search',
                selected: selectedPlaylistId == null &&
                    (appState.searchQuery.isNotEmpty || appState.isSearching),
                onTap: () => _handleNavigate(appState.requestSearchFocus),
              ),
              SizedBox(height: space(8)),
            ],
            _ToggleTile(
              icon: Icons.cloud_off,
              label: 'Offline mode',
              value: offlineMode,
              onChanged: (value) => appState.setOfflineMode(value),
            ),
          ],
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
                        if (favoritesAlbumsVisible)
                          _NavTile(
                            icon: Icons.album,
                            label: 'Albums',
                            selected: selectedPlaylistId == null &&
                                selectedView == LibraryView.favoritesAlbums,
                            onTap: () => _handleNavigate(
                              () => appState.selectLibraryView(
                                LibraryView.favoritesAlbums,
                              ),
                            ),
                          ),
                        if (favoritesArtistsVisible)
                          _NavTile(
                            icon: Icons.people_alt,
                            label: 'Artists',
                            selected: selectedPlaylistId == null &&
                                selectedView == LibraryView.favoritesArtists,
                            onTap: () => _handleNavigate(
                              () => appState.selectLibraryView(
                                LibraryView.favoritesArtists,
                              ),
                            ),
                          ),
                        if (favoritesTracksVisible)
                          _NavTile(
                            icon: Icons.music_note,
                            label: 'Tracks',
                            selected: selectedPlaylistId == null &&
                                selectedView == LibraryView.favoritesSongs,
                            onTap: () => _handleNavigate(
                              () => appState.selectLibraryView(
                                LibraryView.favoritesSongs,
                              ),
                            ),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
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
                        if (browseAlbumsVisible)
                          _NavTile(
                            icon: Icons.album,
                            label: 'Albums',
                            selected: selectedPlaylistId == null &&
                                selectedView == LibraryView.albums,
                            onTap: () => _handleNavigate(
                              () => appState.selectLibraryView(
                                LibraryView.albums,
                              ),
                            ),
                          ),
                        if (browseArtistsVisible)
                          _NavTile(
                            icon: Icons.people_alt,
                            label: 'Artists',
                            selected: selectedPlaylistId == null &&
                                selectedView == LibraryView.artists,
                            onTap: () => _handleNavigate(
                              () => appState.selectLibraryView(
                                LibraryView.artists,
                              ),
                            ),
                          ),
                        if (browseGenresVisible)
                          _NavTile(
                            icon: Icons.auto_awesome_motion,
                            label: 'Genres',
                            selected: selectedPlaylistId == null &&
                                selectedView == LibraryView.genres,
                            onTap: () => _handleNavigate(
                              () => appState.selectLibraryView(
                                LibraryView.genres,
                              ),
                            ),
                          ),
                        if (browsePlaylistsVisible)
                          _NavTile(
                            icon: Icons.queue_music,
                            label: 'Playlists',
                            selected: selectedPlaylistId == null &&
                                selectedView == LibraryView.homePlaylists,
                            onTap: () => _handleNavigate(
                              () => appState.selectLibraryView(
                                LibraryView.homePlaylists,
                              ),
                            ),
                          ),
                        if (browseTracksVisible)
                          _NavTile(
                            icon: Icons.music_note,
                            label: 'Tracks',
                            selected: selectedPlaylistId == null &&
                                selectedView == LibraryView.tracks,
                            onTap: () => _handleNavigate(
                              () => appState.selectLibraryView(
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
                        if (playbackHistoryVisible)
                          _NavTile(
                            icon: Icons.history,
                            label: 'History',
                            selected: selectedPlaylistId == null &&
                                selectedView == LibraryView.history,
                            onTap: () => _handleNavigate(
                              () => appState.selectLibraryView(
                                LibraryView.history,
                              ),
                            ),
                          ),
                        if (playbackQueueVisible)
                          _NavTile(
                            icon: Icons.queue_music,
                            label: 'Queue',
                            selected: selectedPlaylistId == null &&
                                selectedView == LibraryView.queue,
                            onTap: () => _handleNavigate(
                              () => appState.selectLibraryView(
                                LibraryView.queue,
                              ),
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
                        _PlaylistActionTile(
                          label: 'New playlist',
                          enabled: sessionPresent && !offlineMode,
                          onTap: () async {
                            final created =
                                await showCreatePlaylistDialog(context);
                            if (created != null) {
                              appState.selectPlaylist(created);
                            }
                          },
                        ),
                        SizedBox(height: space(6)),
                        ...playlists.map(
                          (playlist) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _PlaylistTile(
                              playlist: playlist,
                              selected: selectedPlaylistId == playlist.id,
                              onTap: () => _handleNavigate(
                                () => appState.selectPlaylist(
                                  playlist,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
          if (showSmartListsSection) ...[
            SizedBox(height: space(16)),
            _SectionHeader(
              title: 'Smart Lists',
              onTap: () => setState(() {
                _smartListsExpanded = !_smartListsExpanded;
              }),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: _smartListsExpanded
                  ? Column(
                      children: [
                        SizedBox(height: space(12)),
                        _PlaylistActionTile(
                          label: 'New smart list',
                          enabled: sessionPresent && !offlineMode,
                          onTap: () async {
                            final created =
                                await showSmartListEditorDialog(context);
                            if (created != null) {
                              final stored =
                                  await appState.createSmartList(created);
                              await appState.selectSmartList(stored);
                            }
                          },
                        ),
                        SizedBox(height: space(6)),
                        if (smartLists.isEmpty)
                          Padding(
                            padding: EdgeInsets.only(
                              left: space(12).clamp(8.0, 16.0),
                              right: space(12).clamp(8.0, 16.0),
                              bottom: space(8),
                            ),
                            child: Text(
                              'Build playlists that update themselves.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        ColorTokens.textSecondary(context, 0.6),
                                  ),
                            ),
                          )
                        else
                          ...smartLists.map(
                            (smartList) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: _SmartListTile(
                                smartList: smartList,
                                selected: selectedSmartListId == smartList.id,
                                onTap: () => _handleNavigate(
                                  () => appState.selectSmartList(smartList),
                                ),
                                onRename: () =>
                                    _renameSmartList(context, smartList),
                                onDuplicate: () =>
                                    _duplicateSmartList(context, smartList),
                                onToggleHome: () {
                                  final updated = smartList.copyWith(
                                    showOnHome: !smartList.showOnHome,
                                  );
                                  appState.updateSmartList(updated);
                                },
                                onDelete: () =>
                                    _deleteSmartList(context, smartList),
                              ),
                            ),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
          SizedBox(height: space(20)),
          if (showOfflineSection) ...[
            _SectionHeader(
              title: 'Available Offline',
              onTap: () => setState(() {
                _offlineExpanded = !_offlineExpanded;
              }),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: _offlineExpanded
                  ? Column(
                      children: [
                        SizedBox(height: space(8)),
                        if (offlineAlbumsVisible)
                          _NavTile(
                            icon: Icons.album,
                            label: 'Albums',
                            selected: selectedPlaylistId == null &&
                                selectedView == LibraryView.offlineAlbums,
                            onTap: () => _handleNavigate(
                              () => appState.selectLibraryView(
                                LibraryView.offlineAlbums,
                              ),
                            ),
                          ),
                        if (offlineArtistsVisible)
                          _NavTile(
                            icon: Icons.people_alt,
                            label: 'Artists',
                            selected: selectedPlaylistId == null &&
                                selectedView == LibraryView.offlineArtists,
                            onTap: () => _handleNavigate(
                              () => appState.selectLibraryView(
                                LibraryView.offlineArtists,
                              ),
                            ),
                          ),
                        if (offlinePlaylistsVisible)
                          _NavTile(
                            icon: Icons.playlist_play,
                            label: 'Playlists',
                            selected: selectedPlaylistId == null &&
                                selectedView == LibraryView.offlinePlaylists,
                            onTap: () => _handleNavigate(
                              () => appState.selectLibraryView(
                                LibraryView.offlinePlaylists,
                              ),
                            ),
                          ),
                        if (offlineTracksVisible)
                          _NavTile(
                            icon: Icons.music_note,
                            label: 'Tracks',
                            selected: selectedPlaylistId == null &&
                                selectedView == LibraryView.offlineTracks,
                            onTap: () => _handleNavigate(
                              () => appState.selectLibraryView(
                                LibraryView.offlineTracks,
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
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
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
            context.scaledRadius(clamped(16, min: 10, max: 20)),
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

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: space(12).clamp(8.0, 16.0),
          vertical: space(10).clamp(6.0, 14.0),
        ),
        decoration: BoxDecoration(
          color: value ? ColorTokens.activeRow(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(
            context.scaledRadius(clamped(16, min: 10, max: 20)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: clamped(18, min: 14, max: 20)),
            SizedBox(width: space(12).clamp(8.0, 16.0)),
            Expanded(child: Text(label)),
            CompactSwitch(
              value: value,
              onChanged: onChanged,
            ),
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
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
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
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
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
            context.scaledRadius(clamped(14, min: 10, max: 18)),
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

class _SmartListTile extends StatelessWidget {
  const _SmartListTile({
    required this.smartList,
    required this.onTap,
    required this.selected,
    required this.onRename,
    required this.onDuplicate,
    required this.onToggleHome,
    required this.onDelete,
  });

  final SmartList smartList;
  final VoidCallback onTap;
  final bool selected;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onToggleHome;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onSecondaryTapDown: (details) {
        showMenu<_SmartListContextAction>(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            details.globalPosition.dx,
            details.globalPosition.dy,
          ),
          items: [
            const PopupMenuItem(
              value: _SmartListContextAction.open,
              child: Text('Open'),
            ),
            const PopupMenuItem(
              value: _SmartListContextAction.rename,
              child: Text('Rename'),
            ),
            const PopupMenuItem(
              value: _SmartListContextAction.duplicate,
              child: Text('Duplicate'),
            ),
            PopupMenuItem(
              value: _SmartListContextAction.toggleHome,
              child: Text(
                smartList.showOnHome ? 'Remove from Home' : 'Add to Home',
              ),
            ),
            const PopupMenuItem(
              value: _SmartListContextAction.delete,
              child: Text('Delete'),
            ),
          ],
        ).then((value) {
          switch (value) {
            case _SmartListContextAction.open:
              onTap();
              break;
            case _SmartListContextAction.rename:
              onRename();
              break;
            case _SmartListContextAction.duplicate:
              onDuplicate();
              break;
            case _SmartListContextAction.toggleHome:
              onToggleHome();
              break;
            case _SmartListContextAction.delete:
              onDelete();
              break;
            case null:
              break;
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: space(12).clamp(8.0, 16.0),
          vertical: space(10).clamp(6.0, 14.0),
        ),
        decoration: BoxDecoration(
          color: selected ? ColorTokens.activeRow(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(
            context.scaledRadius(clamped(14, min: 10, max: 18)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome,
              size: clamped(16, min: 12, max: 18),
            ),
            SizedBox(width: space(10).clamp(6.0, 14.0)),
            Expanded(
              child: Text(
                smartList.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SmartListContextAction {
  open,
  rename,
  duplicate,
  toggleHome,
  delete,
}

class _PlaylistActionTile extends StatelessWidget {
  const _PlaylistActionTile({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: enabled
              ? ColorTokens.textSecondary(context, 0.9)
              : ColorTokens.textSecondary(context, 0.4),
        );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: space(12).clamp(8.0, 16.0),
          vertical: space(8).clamp(6.0, 12.0),
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(
            context.scaledRadius(clamped(12, min: 8, max: 16)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.add,
              size: clamped(16, min: 12, max: 18),
              color: enabled
                  ? ColorTokens.textSecondary(context, 0.9)
                  : ColorTokens.textSecondary(context, 0.4),
            ),
            SizedBox(width: space(10).clamp(6.0, 14.0)),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
