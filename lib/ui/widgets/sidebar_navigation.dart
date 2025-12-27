import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../state/app_state.dart';

/// Vertical navigation rail for playlists and actions.
class SidebarNavigation extends StatelessWidget {
  /// Creates the sidebar navigation.
  const SidebarNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1218),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            selected: state.selectedPlaylist == null,
            onTap: state.clearPlaylistSelection,
          ),
          const SizedBox(height: 24),
          Text(
            'Playlists',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Scrollbar(
              child: ListView.separated(
                itemCount: state.playlists.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final playlist = state.playlists[index];
                  return _PlaylistTile(
                    playlist: playlist,
                    selected: state.selectedPlaylist?.id == playlist.id,
                    onTap: () => state.selectPlaylist(playlist),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: state.signOut,
            child: const Text('Sign out'),
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
    return InkWell(
      borderRadius: BorderRadius.circular(16),
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
    return InkWell(
      borderRadius: BorderRadius.circular(14),
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
