import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../state/app_state.dart';
import '../../state/home_section.dart';
import '../../state/now_playing_layout.dart';
import '../../state/sidebar_item.dart';
import '../../core/color_tokens.dart';
import 'glass_container.dart';
import 'section_header.dart';

/// Settings view for Coppelia preferences.
class SettingsView extends StatelessWidget {
  /// Creates the settings view.
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Settings'),
          const SizedBox(height: 12),
          _SettingsTabBar(),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              children: [
                _SettingsTab(
                  child: _AppearanceSettings(state: state),
                ),
                _SettingsTab(
                  child: _LayoutSettings(state: state),
                ),
                _SettingsTab(
                  child: _CacheSettings(
                    state: state,
                    onSnack: (message) => _showSnack(context, message),
                  ),
                ),
                _SettingsTab(
                  child: _AccountSettings(state: state),
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

class _SettingsTabBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorTokens.border(context)),
      ),
      child: TabBar(
        isScrollable: true,
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        labelColor: Theme.of(context).colorScheme.onSurface,
        unselectedLabelColor: ColorTokens.textSecondary(context),
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: ColorTokens.cardFill(context, 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        tabs: const [
          _SettingsTabLabel(text: 'Appearance'),
          _SettingsTabLabel(text: 'Layout'),
          _SettingsTabLabel(text: 'Cache'),
          _SettingsTabLabel(text: 'Account'),
        ],
      ),
    );
  }
}

class _SettingsTabLabel extends StatelessWidget {
  const _SettingsTabLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Text(text),
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: GlassContainer(
        child: child,
      ),
    );
  }
}

class _AppearanceSettings extends StatelessWidget {
  const _AppearanceSettings({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final fontChoice = _fontChoices.firstWhere(
      (choice) => choice.family == state.fontFamily,
      orElse: () => _fontChoices.first,
    );
    final fontScale = _fontScaleChoices
            .any((choice) => choice.scale == state.fontScale)
        ? state.fontScale
        : 1.0;
    return Column(
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
        const SizedBox(height: 16),
        _SettingRow(
          title: 'Font family',
          subtitle: 'Choose a display font for the app.',
          trailing: SizedBox(
            width: 220,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: fontChoice.value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(12),
                items: _fontChoices
                    .map(
                      (choice) => DropdownMenuItem<String>(
                        value: choice.value,
                        child: Text(
                          choice.label,
                          style: choice.family == null
                              ? null
                              : TextStyle(fontFamily: choice.family),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  final selected = _fontChoices.firstWhere(
                    (choice) => choice.value == value,
                    orElse: () => _fontChoices.first,
                  );
                  state.setFontFamily(selected.family);
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SettingRow(
          title: 'Font size',
          subtitle: 'Scale typography across the interface.',
          trailing: SegmentedButton<double>(
            segments: _fontScaleChoices
                .map(
                  (choice) => ButtonSegment(
                    value: choice.scale,
                    label: Text(
                      choice.label,
                      style: TextStyle(fontSize: 12 * choice.scale),
                    ),
                  ),
                )
                .toList(),
            selected: {fontScale},
            onSelectionChanged: (selection) {
              state.setFontScale(selection.first);
            },
          ),
        ),
      ],
    );
  }
}

class _LayoutSettings extends StatelessWidget {
  const _LayoutSettings({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Layout', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _SettingRow(
          title: 'Now playing layout',
          subtitle: 'Choose where the player is docked.',
          forceInline: true,
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
              forceInline: true,
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
          forceInline: true,
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
          forceInline: true,
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
          forceInline: true,
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
          forceInline: true,
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
          forceInline: true,
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
          forceInline: true,
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
          forceInline: true,
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
          forceInline: true,
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
        const SizedBox(height: 12),
        _SettingRow(
          title: SidebarItem.browseTracks.label,
          subtitle: 'Show tracks in Browse.',
          forceInline: true,
          trailing: Switch(
            value: state.isSidebarItemVisible(
              SidebarItem.browseTracks,
            ),
            onChanged: (value) => state.setSidebarItemVisible(
              SidebarItem.browseTracks,
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
          forceInline: true,
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
          forceInline: true,
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
          forceInline: true,
          trailing: Switch(
            value: state.isSidebarItemVisible(SidebarItem.playlists),
            onChanged: (value) => state.setSidebarItemVisible(
              SidebarItem.playlists,
              value,
            ),
          ),
        ),
      ],
    );
  }
}

class _CacheSettings extends StatefulWidget {
  const _CacheSettings({
    required this.state,
    required this.onSnack,
  });

  final AppState state;
  final ValueChanged<String> onSnack;

  @override
  State<_CacheSettings> createState() => _CacheSettingsState();
}

class _CacheSettingsState extends State<_CacheSettings> {
  late Future<int> _cacheFuture;

  @override
  void initState() {
    super.initState();
    _cacheFuture = widget.state.getMediaCacheBytes();
  }

  void _refreshCacheUsage() {
    setState(() {
      _cacheFuture = widget.state.getMediaCacheBytes();
    });
  }

  String _fileManagerLabel() {
    if (Platform.isMacOS) {
      return 'Show in Finder';
    }
    if (Platform.isWindows) {
      return 'Show in File Explorer';
    }
    if (Platform.isLinux) {
      return 'Show in Files';
    }
    return 'Show in folder';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cache', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _SettingRow(
          title: 'Media cache',
          subtitle: 'Downloaded artwork and audio stored on disk.',
          trailing: FutureBuilder<int>(
            future: _cacheFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text(
                  'Calculating...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColorTokens.textSecondary(context),
                      ),
                );
              }
              final bytes = snapshot.data ?? 0;
              return Text(
                formatBytes(bytes),
                style: Theme.of(context).textTheme.bodyLarge,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _SettingRow(
          title: 'Cache location',
          subtitle: 'Open cached media in your file manager.',
          trailing: OutlinedButton(
            onPressed: widget.state.showMediaCacheLocation,
            child: Text(_fileManagerLabel()),
          ),
        ),
        const SizedBox(height: 12),
        _SettingRow(
          title: 'Cached metadata',
          subtitle: 'Refresh playlists, albums, and recent tracks.',
          trailing: OutlinedButton(
            onPressed: () async {
              await widget.state.clearMetadataCache();
              _refreshCacheUsage();
              if (context.mounted) {
                widget.onSnack('Metadata cache cleared.');
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
              await widget.state.clearAudioCache();
              _refreshCacheUsage();
              if (context.mounted) {
                widget.onSnack('Audio cache cleared.');
              }
            },
            child: const Text('Clear'),
          ),
        ),
      ],
    );
  }
}

class _AccountSettings extends StatelessWidget {
  const _AccountSettings({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final session = state.session;
    final stats = state.libraryStats;
    final trackCount = stats?.trackCount ??
        state.playlists.fold<int>(
          0,
          (total, playlist) => total + playlist.trackCount,
        );
    final albumCount = stats?.albumCount ?? state.albums.length;
    final artistCount = stats?.artistCount ?? state.artists.length;
    final playlistCount = stats?.playlistCount ?? state.playlists.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Account', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (session == null)
          Text(
            'No active session.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: ColorTokens.textSecondary(context)),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ColorTokens.cardFill(context, 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ColorTokens.border(context, 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Signed in as',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: ColorTokens.textSecondary(context)),
                ),
                const SizedBox(height: 6),
                Text(
                  session.userName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _AccountMetaRow(label: 'Server', value: session.serverUrl),
                const SizedBox(height: 8),
                _AccountMetaRow(label: 'User ID', value: session.userId),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AccountStatChip(
                      label: 'Tracks',
                      value: formatCount(trackCount),
                    ),
                    _AccountStatChip(
                      label: 'Albums',
                      value: formatCount(albumCount),
                    ),
                    _AccountStatChip(
                      label: 'Artists',
                      value: formatCount(artistCount),
                    ),
                    _AccountStatChip(
                      label: 'Playlists',
                      value: formatCount(playlistCount),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Text('Telemetry', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _SettingRow(
          title: 'Playback reporting',
          subtitle: 'Send now playing and pause/resume state to Jellyfin.',
          forceInline: true,
          trailing: Switch(
            value: state.telemetryPlaybackEnabled,
            onChanged: state.setTelemetryPlayback,
          ),
        ),
        const SizedBox(height: 12),
        _SettingRow(
          title: 'Progress updates',
          subtitle: 'Report playback progress while a track is playing.',
          forceInline: true,
          trailing: Switch(
            value: state.telemetryProgressEnabled,
            onChanged: state.setTelemetryProgress,
          ),
        ),
        const SizedBox(height: 12),
        _SettingRow(
          title: 'Play history',
          subtitle: 'Send play completion events for library history.',
          forceInline: true,
          trailing: Switch(
            value: state.telemetryHistoryEnabled,
            onChanged: state.setTelemetryHistory,
          ),
        ),
        const SizedBox(height: 16),
        _SettingRow(
          title: 'Sign out',
          subtitle: 'Disconnect from this Jellyfin account.',
          trailing: OutlinedButton(
            onPressed: state.signOut,
            child: const Text('Sign out'),
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.forceInline = false,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final bool forceInline;

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
        if (isNarrow && !forceInline) {
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

class _AccountMetaRow extends StatelessWidget {
  const _AccountMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: ColorTokens.textSecondary(context)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _AccountStatChip extends StatelessWidget {
  const _AccountStatChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ColorTokens.border(context, 0.12)),
      ),
      child: Text(
        '$value $label',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}


class _FontChoice {
  const _FontChoice(this.label, this.family);

  final String label;
  final String? family;

  String get value => family ?? 'system';
}

class _FontScaleChoice {
  const _FontScaleChoice(this.label, this.scale);

  final String label;
  final double scale;
}

const List<_FontChoice> _fontChoices = [
  _FontChoice('SF Pro Display', 'SF Pro Display'),
  _FontChoice('System', null),
  _FontChoice('SF Pro Text', 'SF Pro Text'),
  _FontChoice('Avenir Next', 'Avenir Next'),
  _FontChoice('Helvetica Neue', 'Helvetica Neue'),
  _FontChoice('Georgia', 'Georgia'),
];

const List<_FontScaleChoice> _fontScaleChoices = [
  _FontScaleChoice('XS', 0.8),
  _FontScaleChoice('S', 0.9),
  _FontScaleChoice('M', 1.0),
  _FontScaleChoice('L', 1.12),
  _FontScaleChoice('XL', 1.3),
];
