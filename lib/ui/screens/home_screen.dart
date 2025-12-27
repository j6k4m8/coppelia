import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/gradient_background.dart';
import '../widgets/library_overview.dart';
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
                      _Header(userName: state.session?.userName ?? 'Listener'),
                      const SizedBox(height: 24),
                      if (state.isLoadingLibrary)
                        const LinearProgressIndicator(minHeight: 2),
                      const SizedBox(height: 12),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: state.selectedPlaylist == null
                              ? const LibraryOverview()
                              : const PlaylistDetailView(),
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
  const _Header({required this.userName});

  final String userName;

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
              'Your Jellyfin library, reimagined.',
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
