import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';

/// Vertical navigation rail for playlists and actions.
class SidebarNavigation extends StatefulWidget {
  /// Creates the sidebar navigation.
  const SidebarNavigation({super.key});

  @override
  State<SidebarNavigation> createState() => _SidebarNavigationState();
}

class _SidebarNavigationState extends State<SidebarNavigation> {
  bool _favoritesExpanded = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1218),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF6F7BFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.queue_music, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Copellia',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 32),
          _NavTile(
            icon: Icons.home_filled,
            label: 'Home',
            selected: state.selectedPlaylist == null &&
                state.selectedView == LibraryView.home,
            onTap: () => state.selectLibraryView(LibraryView.home),
          ),
          const SizedBox(height: 20),
          _SectionHeader(
            title: 'Favorites',
            isExpanded: _favoritesExpanded,
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
                      const SizedBox(height: 8),
                      _NavTile(
                        icon: Icons.album,
                        label: 'Albums',
                        selected: state.selectedPlaylist == null &&
                            state.selectedView == LibraryView.favoritesAlbums,
                        onTap: () =>
                            state.selectLibraryView(LibraryView.favoritesAlbums),
                      ),
                      _NavTile(
                        icon: Icons.music_note,
                        label: 'Songs',
                        selected: state.selectedPlaylist == null &&
                            state.selectedView == LibraryView.favoritesSongs,
                        onTap: () =>
                            state.selectLibraryView(LibraryView.favoritesSongs),
                      ),
                      _NavTile(
                        icon: Icons.people_alt,
                        label: 'Artists',
                        selected: state.selectedPlaylist == null &&
                            state.selectedView == LibraryView.favoritesArtists,
                        onTap: () => state
                            .selectLibraryView(LibraryView.favoritesArtists),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          Text(
            'Browse',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          _NavTile(
            icon: Icons.album,
            label: 'Albums',
            selected: state.selectedPlaylist == null &&
                state.selectedView == LibraryView.albums,
            onTap: () => state.selectLibraryView(LibraryView.albums),
          ),
          _NavTile(
            icon: Icons.people_alt,
            label: 'Artists',
            selected: state.selectedPlaylist == null &&
                state.selectedView == LibraryView.artists,
            onTap: () => state.selectLibraryView(LibraryView.artists),
          ),
          _NavTile(
            icon: Icons.auto_awesome_motion,
            label: 'Genres',
            selected: state.selectedPlaylist == null &&
                state.selectedView == LibraryView.genres,
            onTap: () => state.selectLibraryView(LibraryView.genres),
          ),
          const SizedBox(height: 16),
          Text(
            'Playback',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          _NavTile(
            icon: Icons.history,
            label: 'History',
            selected: state.selectedPlaylist == null &&
                state.selectedView == LibraryView.history,
            onTap: () => state.selectLibraryView(LibraryView.history),
          ),
          _NavTile(
            icon: Icons.queue_music,
            label: 'Queue',
            selected: state.selectedPlaylist == null &&
                state.selectedView == LibraryView.queue,
            onTap: () => state.selectLibraryView(LibraryView.queue),
          ),
          const SizedBox(height: 16),
          Text(
            'Playlists',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          ...state.playlists.map(
            (playlist) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _PlaylistTile(
                playlist: playlist,
                selected: state.selectedPlaylist?.id == playlist.id,
                onTap: () => state.selectPlaylist(playlist),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => state.selectLibraryView(LibraryView.settings),
            child: const Text('Settings'),
          ),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 12),
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
    required this.isExpanded,
    required this.onTap,
  });

  final String title;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: Colors.white70),
            ),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.expand_more, size: 18),
            ),
          ],
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.queue_music, size: 16),
            const SizedBox(width: 10),
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
