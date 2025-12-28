import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../state/app_state.dart';
import '../../state/home_section.dart';
import '../../state/keyboard_shortcut.dart';
import '../../state/layout_density.dart';
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
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return DefaultTabController(
      length: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Settings'),
          SizedBox(height: space(12)),
          _SettingsTabBar(),
          SizedBox(height: space(16)),
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
                  child: _KeyboardSettings(state: state),
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
    final densityScale =
        context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Container(
      padding: EdgeInsets.all(space(4).clamp(2.0, 6.0)),
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorTokens.border(context)),
      ),
      child: TabBar(
        isScrollable: true,
        labelPadding:
            EdgeInsets.symmetric(horizontal: space(6).clamp(4.0, 10.0)),
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
          _SettingsTabLabel(text: 'Keyboard'),
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
    final densityScale =
        context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Tab(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: space(18).clamp(12.0, 22.0),
          vertical: space(6).clamp(4.0, 10.0),
        ),
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
    final densityScale =
        context.watch<AppState>().layoutDensity.scaleDouble;
    final padding = EdgeInsets.all((20 * densityScale).clamp(12.0, 28.0));
    return SingleChildScrollView(
      child: GlassContainer(
        padding: padding,
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
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: space(12)),
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
        SizedBox(height: space(16)),
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
        SizedBox(height: space(16)),
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
        SizedBox(height: space(16)),
        _SettingRow(
          title: 'Layout density',
          subtitle: 'Adjust padding and spacing throughout the UI.',
          trailing: SegmentedButton<LayoutDensity>(
            segments: LayoutDensity.values
                .map(
                  (density) => ButtonSegment(
                    value: density,
                    label: Text(density.label),
                  ),
                )
                .toList(),
            selected: {state.layoutDensity},
            onSelectionChanged: (selection) {
              state.setLayoutDensity(selection.first);
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
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Layout', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: space(12)),
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
        Divider(height: space(32), color: ColorTokens.border(context, 0.12)),
        Text('Home', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: space(12)),
        ...HomeSection.values.map(
          (section) => Padding(
            padding: EdgeInsets.only(bottom: space(12)),
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
        Divider(height: space(32), color: ColorTokens.border(context, 0.12)),
        Text('Sidebar', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: space(12)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: _SettingsSubheader(title: 'Main'),
            ),
            SizedBox(height: space(8)),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
                title: SidebarItem.home.label,
                subtitle: 'Show Home in the sidebar.',
                forceInline: true,
                trailing: Switch(
                  value: state.isSidebarItemVisible(SidebarItem.home),
                  onChanged: (value) =>
                      state.setSidebarItemVisible(SidebarItem.home, value),
                ),
              ),
            ),
            SizedBox(height: space(12)),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
                title: SidebarItem.settings.label,
                subtitle: 'Show Settings in the sidebar.',
                forceInline: true,
                trailing: Switch(
                  value: state.isSidebarItemVisible(SidebarItem.settings),
                  onChanged: (value) =>
                      state.setSidebarItemVisible(SidebarItem.settings, value),
                ),
              ),
            ),
            SizedBox(height: space(16)),
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: _SettingsSubheader(title: 'Favorites'),
            ),
            SizedBox(height: space(8)),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
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
            ),
            SizedBox(height: space(12)),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
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
            ),
            SizedBox(height: space(12)),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
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
            ),
            SizedBox(height: space(16)),
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: _SettingsSubheader(title: 'Available Offline'),
            ),
            SizedBox(height: space(8)),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
                title: SidebarItem.offlineAlbums.label,
                subtitle: 'Show offline albums.',
                forceInline: true,
                trailing: Switch(
                  value: state.isSidebarItemVisible(
                    SidebarItem.offlineAlbums,
                  ),
                  onChanged: (value) => state.setSidebarItemVisible(
                    SidebarItem.offlineAlbums,
                    value,
                  ),
                ),
              ),
            ),
            SizedBox(height: space(12)),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
                title: SidebarItem.offlineArtists.label,
                subtitle: 'Show offline artists.',
                forceInline: true,
                trailing: Switch(
                  value: state.isSidebarItemVisible(
                    SidebarItem.offlineArtists,
                  ),
                  onChanged: (value) => state.setSidebarItemVisible(
                    SidebarItem.offlineArtists,
                    value,
                  ),
                ),
              ),
            ),
            SizedBox(height: space(12)),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
                title: SidebarItem.offlinePlaylists.label,
                subtitle: 'Show offline playlists.',
                forceInline: true,
                trailing: Switch(
                  value: state.isSidebarItemVisible(
                    SidebarItem.offlinePlaylists,
                  ),
                  onChanged: (value) => state.setSidebarItemVisible(
                    SidebarItem.offlinePlaylists,
                    value,
                  ),
                ),
              ),
            ),
            SizedBox(height: space(12)),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
                title: SidebarItem.offlineTracks.label,
                subtitle: 'Show offline tracks.',
                forceInline: true,
                trailing: Switch(
                  value: state.isSidebarItemVisible(
                    SidebarItem.offlineTracks,
                  ),
                  onChanged: (value) => state.setSidebarItemVisible(
                    SidebarItem.offlineTracks,
                    value,
                  ),
                ),
              ),
            ),
            SizedBox(height: space(16)),
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: _SettingsSubheader(title: 'Browse'),
            ),
            SizedBox(height: space(8)),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
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
            ),
            SizedBox(height: space(12)),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
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
            ),
            SizedBox(height: space(12)),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
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
            ),
            SizedBox(height: space(12)),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
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
            ),
            SizedBox(height: space(16)),
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: _SettingsSubheader(title: 'Playback'),
            ),
            SizedBox(height: space(8)),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
                title: SidebarItem.history.label,
                subtitle: 'Show playback history.',
                forceInline: true,
                trailing: Switch(
                  value: state.isSidebarItemVisible(SidebarItem.history),
                  onChanged: (value) =>
                      state.setSidebarItemVisible(SidebarItem.history, value),
                ),
              ),
            ),
            SizedBox(height: space(12)),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
                title: SidebarItem.queue.label,
                subtitle: 'Show the play queue.',
                forceInline: true,
                trailing: Switch(
                  value: state.isSidebarItemVisible(SidebarItem.queue),
                  onChanged: (value) =>
                      state.setSidebarItemVisible(SidebarItem.queue, value),
                ),
              ),
            ),
            SizedBox(height: space(16)),
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: _SettingsSubheader(title: 'Playlists'),
            ),
            SizedBox(height: space(8)),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
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
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyboardSettings extends StatelessWidget {
  const _KeyboardSettings({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Keyboard', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: space(12)),
        Text(
          'Open settings',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: space(4)),
        Text(
          'Use a global shortcut to jump to Settings.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColorTokens.textSecondary(context),
              ),
        ),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Enabled',
          subtitle: 'Allow the shortcut to open Settings.',
          forceInline: true,
          trailing: Switch(
            value: state.settingsShortcutEnabled,
            onChanged: (value) => state.setSettingsShortcutEnabled(value),
          ),
        ),
        SizedBox(height: space(8)),
        _SettingRow(
          title: 'Shortcut',
          subtitle: 'Include Cmd/Ctrl/Alt plus a key.',
          forceInline: true,
          trailing: _ShortcutRecorder(
            shortcut: state.settingsShortcut,
            enabled: state.settingsShortcutEnabled,
            onChanged: (shortcut) => state.setSettingsShortcut(shortcut),
          ),
        ),
        Divider(height: space(24), color: ColorTokens.border(context, 0.12)),
        Text(
          'Focus search',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: space(4)),
        Text(
          'Jump straight to the search field from anywhere.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColorTokens.textSecondary(context),
              ),
        ),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Enabled',
          subtitle: 'Allow the shortcut to focus Search.',
          forceInline: true,
          trailing: Switch(
            value: state.searchShortcutEnabled,
            onChanged: (value) => state.setSearchShortcutEnabled(value),
          ),
        ),
        SizedBox(height: space(8)),
        _SettingRow(
          title: 'Shortcut',
          subtitle: 'Include Cmd/Ctrl/Alt plus a key.',
          forceInline: true,
          trailing: _ShortcutRecorder(
            shortcut: state.searchShortcut,
            enabled: state.searchShortcutEnabled,
            onChanged: (shortcut) => state.setSearchShortcut(shortcut),
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
  static const List<int> _cacheLimitOptions = [
    50 * 1024 * 1024,
    500 * 1024 * 1024,
    1024 * 1024 * 1024,
    2 * 1024 * 1024 * 1024,
    4 * 1024 * 1024 * 1024,
    32 * 1024 * 1024 * 1024,
    64 * 1024 * 1024 * 1024,
    100 * 1024 * 1024 * 1024,
    0,
  ];

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

  Future<bool> _confirmCacheTrim({
    required int currentBytes,
    required int targetBytes,
  }) async {
    if (targetBytes == 0 || currentBytes <= targetBytes) {
      return true;
    }
    final formattedCurrent = formatBytes(currentBytes);
    final formattedTarget = formatBytes(targetBytes);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trim cache?'),
        content: Text(
          'Your cache uses $formattedCurrent. Reducing the limit to '
          '$formattedTarget will evict older downloads.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Trim cache'),
          ),
        ],
      ),
    );
    return result ?? false;
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
    final densityScale = widget.state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cache', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: space(12)),
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
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Cache limit',
          subtitle: 'Maximum disk space for cached audio.',
          trailing: _CacheLimitPicker(
            currentBytes: widget.state.cacheMaxBytes,
            options: _cacheLimitOptions,
            onChanged: (bytes) async {
              final currentBytes = await widget.state.getMediaCacheBytes();
              final shouldTrim = await _confirmCacheTrim(
                currentBytes: currentBytes,
                targetBytes: bytes,
              );
              if (!shouldTrim) {
                return;
              }
              await widget.state.setCacheMaxBytes(bytes);
              _refreshCacheUsage();
              if (context.mounted) {
                widget.onSnack('Cache limit updated.');
              }
            },
          ),
        ),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Cache location',
          subtitle: 'Open cached media in your file manager.',
          trailing: OutlinedButton(
            onPressed: widget.state.showMediaCacheLocation,
            child: Text(_fileManagerLabel()),
          ),
        ),
        SizedBox(height: space(12)),
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
        SizedBox(height: space(12)),
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

class _CacheLimitPicker extends StatelessWidget {
  const _CacheLimitPicker({
    required this.currentBytes,
    required this.options,
    required this.onChanged,
  });

  final int currentBytes;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final resolvedOptions = options.contains(currentBytes)
        ? List<int>.from(options)
        : [...options, currentBytes];
    resolvedOptions.sort((a, b) {
      if (a == 0 && b == 0) {
        return 0;
      }
      if (a == 0) {
        return 1;
      }
      if (b == 0) {
        return -1;
      }
      return a.compareTo(b);
    });
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: currentBytes,
        onChanged: (value) {
          if (value == null) {
            return;
          }
          onChanged(value);
        },
        items: resolvedOptions
            .map(
              (bytes) => DropdownMenuItem(
                value: bytes,
                child: Text(bytes == 0 ? 'Unlimited' : formatBytes(bytes)),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ShortcutRecorder extends StatefulWidget {
  const _ShortcutRecorder({
    required this.shortcut,
    required this.onChanged,
    required this.enabled,
  });

  final KeyboardShortcut shortcut;
  final ValueChanged<KeyboardShortcut> onChanged;
  final bool enabled;

  @override
  State<_ShortcutRecorder> createState() => _ShortcutRecorderState();
}

class _ShortcutRecorderState extends State<_ShortcutRecorder> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'ShortcutRecorder');
  bool _isRecording = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ShortcutRecorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _isRecording) {
      _stopRecording();
    }
  }

  void _startRecording() {
    if (!widget.enabled) {
      return;
    }
    setState(() {
      _isRecording = true;
    });
    _focusNode.requestFocus();
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });
    _focusNode.unfocus();
  }

  void _handleKey(RawKeyEvent event) {
    if (!_isRecording || event is! RawKeyDownEvent) {
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _stopRecording();
      return;
    }
    if (_isModifierKey(event.logicalKey)) {
      return;
    }
    final shortcut = KeyboardShortcut(
      key: event.logicalKey,
      meta: event.isMetaPressed,
      control: event.isControlPressed,
      alt: event.isAltPressed,
      shift: event.isShiftPressed,
    );
    if (!shortcut.hasPrimaryModifier) {
      return;
    }
    widget.onChanged(shortcut);
    _stopRecording();
  }

  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.meta;
  }

  @override
  Widget build(BuildContext context) {
    final label =
        _isRecording ? 'Press shortcut...' : widget.shortcut.label();
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKey,
      child: OutlinedButton(
        onPressed: widget.enabled
            ? (_isRecording ? _stopRecording : _startRecording)
            : null,
        child: Text(label),
      ),
    );
  }
}

class _AccountSettings extends StatelessWidget {
  const _AccountSettings({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final session = state.session;
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
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
        SizedBox(height: space(12)),
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
            padding: EdgeInsets.all(space(16).clamp(10.0, 20.0)),
            decoration: BoxDecoration(
              color: ColorTokens.cardFill(context, 0.08),
              borderRadius: BorderRadius.circular(
                clamped(18, min: 12, max: 22),
              ),
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
                SizedBox(height: space(6).clamp(4.0, 10.0)),
                Text(
                  session.userName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: space(16)),
                _AccountMetaRow(label: 'Server', value: session.serverUrl),
                SizedBox(height: space(8)),
                _AccountMetaRow(label: 'User ID', value: session.userId),
                SizedBox(height: space(16)),
                Wrap(
                  spacing: space(8),
                  runSpacing: space(8),
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
        SizedBox(height: space(24)),
        Text('Telemetry', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Playback reporting',
          subtitle: 'Send now playing and pause/resume state to Jellyfin.',
          forceInline: true,
          trailing: Switch(
            value: state.telemetryPlaybackEnabled,
            onChanged: state.setTelemetryPlayback,
          ),
        ),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Progress updates',
          subtitle: 'Report playback progress while a track is playing.',
          forceInline: true,
          trailing: Switch(
            value: state.telemetryProgressEnabled,
            onChanged: state.setTelemetryProgress,
          ),
        ),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Play history',
          subtitle: 'Send play completion events for library history.',
          forceInline: true,
          trailing: Switch(
            value: state.telemetryHistoryEnabled,
            onChanged: state.setTelemetryHistory,
          ),
        ),
        SizedBox(height: space(16)),
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
    final densityScale =
        context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;
        final textBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyLarge),
            SizedBox(height: space(4).clamp(2.0, 6.0)),
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
              SizedBox(height: space(12)),
              trailing,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: textBlock),
            SizedBox(width: space(16).clamp(10.0, 20.0)),
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
