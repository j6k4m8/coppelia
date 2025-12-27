import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/home_section.dart';
import '../../state/now_playing_layout.dart';
import '../../state/sidebar_item.dart';
import '../../core/color_tokens.dart';
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
                  title: 'Theme',
                  subtitle: 'Follow system appearance or set manually.',
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                      ),
                    ],
                    selected: {state.themeMode},
                    onSelectionChanged: (selection) {
                      final mode = selection.first;
                      state.setThemeMode(mode);
                    },
                  ),
                ),
                Divider(height: 32, color: ColorTokens.border(context, 0.12)),
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
                Divider(height: 32, color: ColorTokens.border(context, 0.12)),
                Text('Home', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ...HomeSection.values.map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SettingRow(
                      title: section.label,
                      subtitle: section.description,
                      trailing: Switch(
                        value: state.isHomeSectionVisible(section),
                        onChanged: (value) =>
                            state.setHomeSectionVisible(section, value),
                      ),
                    ),
                  ),
                ),
                Divider(height: 32, color: ColorTokens.border(context, 0.12)),
                Text('Sidebar', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _SettingsSubheader(title: 'Main'),
                const SizedBox(height: 8),
                _SettingRow(
                  title: SidebarItem.home.label,
                  subtitle: 'Show Home in the sidebar.',
                  trailing: Switch(
                    value: state.isSidebarItemVisible(SidebarItem.home),
                    onChanged: (value) =>
                        state.setSidebarItemVisible(SidebarItem.home, value),
                  ),
                ),
                const SizedBox(height: 12),
                _SettingRow(
                  title: SidebarItem.settings.label,
                  subtitle: 'Show Settings in the sidebar.',
                  trailing: Switch(
                    value: state.isSidebarItemVisible(SidebarItem.settings),
                    onChanged: (value) =>
                        state.setSidebarItemVisible(SidebarItem.settings, value),
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsSubheader(title: 'Favorites'),
                const SizedBox(height: 8),
                _SettingRow(
                  title: SidebarItem.favoritesAlbums.label,
                  subtitle: 'Show favorite albums.',
                  trailing: Switch(
                    value: state.isSidebarItemVisible(
                      SidebarItem.favoritesAlbums,
                    ),
                    onChanged: (value) => state.setSidebarItemVisible(
                      SidebarItem.favoritesAlbums,
                      value,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SettingRow(
                  title: SidebarItem.favoritesSongs.label,
                  subtitle: 'Show favorite songs.',
                  trailing: Switch(
                    value: state.isSidebarItemVisible(
                      SidebarItem.favoritesSongs,
                    ),
                    onChanged: (value) => state.setSidebarItemVisible(
                      SidebarItem.favoritesSongs,
                      value,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SettingRow(
                  title: SidebarItem.favoritesArtists.label,
                  subtitle: 'Show favorite artists.',
                  trailing: Switch(
                    value: state.isSidebarItemVisible(
                      SidebarItem.favoritesArtists,
                    ),
                    onChanged: (value) => state.setSidebarItemVisible(
                      SidebarItem.favoritesArtists,
                      value,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsSubheader(title: 'Browse'),
                const SizedBox(height: 8),
                _SettingRow(
                  title: SidebarItem.browseAlbums.label,
                  subtitle: 'Show albums in Browse.',
                  trailing: Switch(
                    value: state.isSidebarItemVisible(
                      SidebarItem.browseAlbums,
                    ),
                    onChanged: (value) => state.setSidebarItemVisible(
                      SidebarItem.browseAlbums,
                      value,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SettingRow(
                  title: SidebarItem.browseArtists.label,
                  subtitle: 'Show artists in Browse.',
                  trailing: Switch(
                    value: state.isSidebarItemVisible(
                      SidebarItem.browseArtists,
                    ),
                    onChanged: (value) => state.setSidebarItemVisible(
                      SidebarItem.browseArtists,
                      value,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SettingRow(
                  title: SidebarItem.browseGenres.label,
                  subtitle: 'Show genres in Browse.',
                  trailing: Switch(
                    value: state.isSidebarItemVisible(
                      SidebarItem.browseGenres,
                    ),
                    onChanged: (value) => state.setSidebarItemVisible(
                      SidebarItem.browseGenres,
                      value,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsSubheader(title: 'Playback'),
                const SizedBox(height: 8),
                _SettingRow(
                  title: SidebarItem.history.label,
                  subtitle: 'Show playback history.',
                  trailing: Switch(
                    value: state.isSidebarItemVisible(SidebarItem.history),
                    onChanged: (value) =>
                        state.setSidebarItemVisible(SidebarItem.history, value),
                  ),
                ),
                const SizedBox(height: 12),
                _SettingRow(
                  title: SidebarItem.queue.label,
                  subtitle: 'Show the play queue.',
                  trailing: Switch(
                    value: state.isSidebarItemVisible(SidebarItem.queue),
                    onChanged: (value) =>
                        state.setSidebarItemVisible(SidebarItem.queue, value),
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsSubheader(title: 'Playlists'),
                const SizedBox(height: 8),
                _SettingRow(
                  title: SidebarItem.playlists.label,
                  subtitle: 'Show playlist list in the sidebar.',
                  trailing: Switch(
                    value: state.isSidebarItemVisible(SidebarItem.playlists),
                    onChanged: (value) => state.setSidebarItemVisible(
                      SidebarItem.playlists,
                      value,
                    ),
                  ),
                ),
                Divider(height: 32, color: ColorTokens.border(context, 0.12)),
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
                Divider(height: 32, color: ColorTokens.border(context, 0.12)),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;
        final textBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: ColorTokens.textSecondary(context)),
            ),
          ],
        );
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              textBlock,
              const SizedBox(height: 12),
              trailing,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: textBlock),
            const SizedBox(width: 16),
            trailing,
          ],
        );
      },
    );
  }
}

class _SettingsSubheader extends StatelessWidget {
  const _SettingsSubheader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(color: ColorTokens.textSecondary(context, 0.75)),
    );
  }
}
