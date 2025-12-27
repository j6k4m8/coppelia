import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/now_playing_layout.dart';
import 'glass_container.dart';
import 'section_header.dart';

/// Settings view for Copellia preferences.
class SettingsView extends StatelessWidget {
  /// Creates the settings view.
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Settings'),
          const SizedBox(height: 16),
          GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _SettingRow(
                  title: 'Dark mode',
                  subtitle: 'Toggle between light and dark themes.',
                  trailing: Switch(
                    value: state.themeMode == ThemeMode.dark,
                    onChanged: (value) => state.setThemeMode(
                      value ? ThemeMode.dark : ThemeMode.light,
                    ),
                  ),
                ),
                const Divider(height: 32, color: Colors.white12),
                Text('Now Playing', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _SettingRow(
                  title: 'Layout',
                  subtitle: 'Choose where the player is docked.',
                  trailing: SegmentedButton<NowPlayingLayout>(
                    segments: NowPlayingLayout.values
                        .map(
                          (layout) => ButtonSegment(
                            value: layout,
                            label: Text(layout.label),
                          ),
                        )
                        .toList(),
                    selected: {state.nowPlayingLayout},
                    onSelectionChanged: (selection) {
                      final layout = selection.first;
                      state.setNowPlayingLayout(layout);
                    },
                  ),
                ),
                const Divider(height: 32, color: Colors.white12),
                Text('Cache', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _SettingRow(
                  title: 'Cached metadata',
                  subtitle: 'Refresh playlists, albums, and recent tracks.',
                  trailing: OutlinedButton(
                    onPressed: () async {
                      await state.clearMetadataCache();
                      if (context.mounted) {
                        _showSnack(context, 'Metadata cache cleared.');
                      }
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(height: 12),
                _SettingRow(
                  title: 'Cached audio',
                  subtitle: 'Remove downloaded audio files.',
                  trailing: OutlinedButton(
                    onPressed: () async {
                      await state.clearAudioCache();
                      if (context.mounted) {
                        _showSnack(context, 'Audio cache cleared.');
                      }
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const Divider(height: 32, color: Colors.white12),
                Text('Account', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _SettingRow(
                  title: 'Sign out',
                  subtitle: 'Disconnect from this Jellyfin account.',
                  trailing: OutlinedButton(
                    onPressed: state.signOut,
                    child: const Text('Sign out'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white60),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        trailing,
      ],
    );
  }
}
