import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/library_view.dart';
import '../widgets/gradient_background.dart';
import '../widgets/library_overview.dart';
import '../widgets/library_placeholder_view.dart';
import '../widgets/now_playing_panel.dart';
import '../widgets/playlist_detail_view.dart';
import '../widgets/sidebar_navigation.dart';

/// Main shell for authenticated users.
class HomeScreen extends StatelessWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Row(
            children: [
              const SidebarNavigation(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(
                        userName: state.session?.userName ?? 'Listener',
                        playlistCount: state.playlists.length,
                        trackCount: state.playlists.fold(
                          0,
                          (total, playlist) => total + playlist.trackCount,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (state.isLoadingLibrary)
                        const LinearProgressIndicator(minHeight: 2),
                      const SizedBox(height: 12),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: _LibraryContent(state: state),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const NowPlayingPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.userName,
    required this.playlistCount,
    required this.trackCount,
  });

  final String userName;
  final int playlistCount;
  final int trackCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Good evening, $userName', style: theme.textTheme.headlineLarge),
            const SizedBox(height: 4),
            Text(
              '$playlistCount playlists • $trackCount tracks',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              const Icon(Icons.music_note, size: 18),
              const SizedBox(width: 8),
              Text(
                'Copellia • macOS',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LibraryContent extends StatelessWidget {
  const _LibraryContent({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.selectedPlaylist != null) {
      return const PlaylistDetailView();
    }
    if (state.selectedView == LibraryView.home) {
      return const LibraryOverview();
    }
    return LibraryPlaceholderView(view: state.selectedView);
  }
}
