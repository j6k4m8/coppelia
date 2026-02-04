import 'dart:convert';
import 'dart:io' show Platform, Process;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../core/formatters.dart';
import '../../models/download_task.dart';
import '../../state/app_state.dart';
import '../../state/accent_color_source.dart';
import '../../state/home_section.dart';
import '../../state/home_shelf_layout.dart';
import '../../state/keyboard_shortcut.dart';
import '../../state/layout_density.dart';
import '../../state/corner_radius_style.dart';
import '../../state/now_playing_layout.dart';
import '../../state/sidebar_item.dart';
import '../../state/theme_palette_source.dart';
import '../../state/track_list_style.dart';
import '../../core/color_tokens.dart';
import '../../core/app_info.dart';
import '../../services/log_service.dart';
import 'compact_switch.dart';
import 'corner_radius.dart';
import 'glass_container.dart';

/// Settings view for Coppelia preferences.
class SettingsView extends StatelessWidget {
  /// Creates the settings view.
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final leftGutter = (32 * densityScale).clamp(16.0, 40.0).toDouble();
    final rightGutter = (24 * densityScale).clamp(12.0, 32.0).toDouble();
    return Padding(
      padding: EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0),
      child: DefaultTabController(
        length: 7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    child: _PlaybackSettings(state: state),
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
                  _SettingsTab(
                    child: _AppSettings(),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Container(
      padding: EdgeInsets.all(space(4).clamp(2.0, 6.0)),
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.08),
        borderRadius: BorderRadius.circular(context.scaledRadius(16)),
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
          borderRadius: BorderRadius.circular(context.scaledRadius(12)),
        ),
        tabs: const [
          _SettingsTabLabel(text: 'Appearance'),
          _SettingsTabLabel(text: 'Layout'),
          _SettingsTabLabel(text: 'Keyboard'),
          _SettingsTabLabel(text: 'Playback'),
          _SettingsTabLabel(text: 'Cache'),
          _SettingsTabLabel(text: 'Account'),
          _SettingsTabLabel(text: 'App'),
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
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
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
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    final padding = EdgeInsets.all((20 * densityScale).clamp(12.0, 28.0));
    final pagePadding =
        EdgeInsets.symmetric(horizontal: (10 * densityScale).clamp(6.0, 14.0));
    return SingleChildScrollView(
      padding: pagePadding,
      child: GlassContainer(padding: padding, child: child),
    );
  }
}

class _AppearanceSettings extends StatefulWidget {
  const _AppearanceSettings({required this.state});

  final AppState state;

  @override
  State<_AppearanceSettings> createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<_AppearanceSettings> {
  late final TextEditingController _accentController;
  final FocusNode _accentFocusNode = FocusNode();
  String? _accentError;

  @override
  void initState() {
    super.initState();
    _accentController = TextEditingController(
      text: _formatHex(widget.state.accentColorValue),
    );
  }

  @override
  void didUpdateWidget(covariant _AppearanceSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextHex = _formatHex(widget.state.accentColorValue);
    if (!_accentFocusNode.hasFocus &&
        _accentController.text.toUpperCase() != nextHex) {
      _accentController.text = nextHex;
    }
  }

  @override
  void dispose() {
    _accentController.dispose();
    _accentFocusNode.dispose();
    super.dispose();
  }

  String _formatHex(int value) {
    final hex = value.toRadixString(16).padLeft(8, '0');
    return hex.substring(2).toUpperCase();
  }

  Color? _parseHex(String input) {
    final raw = input.replaceAll('#', '').trim();
    if (raw.length != 6) {
      return null;
    }
    final valid = RegExp(r'^[0-9a-fA-F]{6}$');
    if (!valid.hasMatch(raw)) {
      return null;
    }
    final value = int.parse(raw, radix: 16);
    return Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final fontChoice = _fontChoices.firstWhere(
      (choice) => choice.family == state.fontFamily,
      orElse: () => _fontChoices.first,
    );
    final fontScale =
        _fontScaleChoices.any((choice) => choice.scale == state.fontScale)
            ? state.fontScale
            : 1.0;
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final accentSource = state.accentColorSource;
    final segmentedStyle = ButtonStyle(
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.bodySmall,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Theme',
          subtitle: 'Follow system appearance or set manually.',
          trailing: SegmentedButton<ThemeMode>(
            style: segmentedStyle,
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
          title: 'Accent color',
          subtitle: 'Pick a brand accent or sync to the now playing artwork.',
          trailing: SegmentedButton<AccentColorSource>(
            style: segmentedStyle,
            segments: AccentColorSource.values
                .map(
                  (source) => ButtonSegment(
                    value: source,
                    label: Text(source.label),
                  ),
                )
                .toList(),
            selected: {accentSource},
            onSelectionChanged: (selection) {
              state.setAccentColorSource(selection.first);
              setState(() {
                _accentError = null;
              });
            },
          ),
        ),
        SizedBox(height: space(12)),
        if (accentSource == AccentColorSource.preset)
          Wrap(
            spacing: space(12),
            runSpacing: space(8),
            children: _accentPresets
                .map(
                  (preset) => _AccentSwatch(
                    label: preset.label,
                    color: preset.color,
                    selected:
                        state.accentColorValue == preset.color.toARGB32() &&
                            accentSource == AccentColorSource.preset,
                    onTap: () {
                      state.setAccentColor(preset.color);
                    },
                  ),
                )
                .toList(),
          )
        else if (accentSource == AccentColorSource.custom)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _accentController,
                  focusNode: _accentFocusNode,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9a-fA-F#]'),
                    ),
                    LengthLimitingTextInputFormatter(7),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Hex color',
                    prefixText: '#',
                    errorText: _accentError,
                  ),
                  onChanged: (value) {
                    final color = _parseHex(value);
                    if (color == null) {
                      if (value.replaceAll('#', '').length < 6) {
                        setState(() {
                          _accentError = null;
                        });
                        return;
                      }
                      setState(() {
                        _accentError = 'Invalid hex';
                      });
                      return;
                    }
                    setState(() {
                      _accentError = null;
                    });
                    state.setAccentColor(color);
                  },
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              _AccentPreview(color: state.accentColor),
              SizedBox(width: space(12)),
              Expanded(
                child: Text(
                  'Uses the dominant artwork color in Now Playing.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColorTokens.textSecondary(context),
                      ),
                ),
              ),
            ],
          ),
        SizedBox(height: space(16)),
        _SettingRow(
          title: 'Theme palette',
          subtitle: 'Tint gradients and hero cards using Now Playing artwork.',
          trailing: SegmentedButton<ThemePaletteSource>(
            style: segmentedStyle,
            segments: ThemePaletteSource.values
                .map(
                  (source) => ButtonSegment(
                    value: source,
                    label: Text(source.label),
                  ),
                )
                .toList(),
            selected: {state.themePaletteSource},
            onSelectionChanged: (selection) {
              state.setThemePaletteSource(selection.first);
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
                borderRadius: BorderRadius.circular(context.scaledRadius(12)),
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
            style: segmentedStyle,
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
            style: segmentedStyle,
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
        SizedBox(height: space(16)),
        _SettingRow(
          title: 'Corner radius',
          subtitle: 'Dial in how rounded the UI feels.',
          trailing: SizedBox(
            width: 320,
            child: Row(
              children: [
                for (final style in const [
                  CornerRadiusStyle.pointy,
                  CornerRadiusStyle.traditional,
                  CornerRadiusStyle.babyProofed,
                ])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: space(4)),
                      child: _CornerRadiusOption(
                        label: style.label,
                        radius: space(18).clamp(10.0, 20.0) * style.scale,
                        selected: state.cornerRadiusStyle == style,
                        onTap: () => state.setCornerRadiusStyle(style),
                      ),
                    ),
                  ),
              ],
            ),
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
    List<Widget> buildSidebarSection(
      String title,
      List<_SidebarToggleSpec> items,
    ) {
      return [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _SettingsSubheader(title: title),
        ),
        SizedBox(height: space(8)),
        ...items.expand(
          (spec) => [
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _SettingRow(
                title: spec.item.label,
                subtitle: spec.subtitle,
                forceInline: true,
                trailing: CompactSwitch(
                  value: state.isSidebarItemVisible(spec.item),
                  onChanged: (value) =>
                      state.setSidebarItemVisible(spec.item, value),
                ),
              ),
            ),
            SizedBox(height: space(12)),
          ],
        ),
      ];
    }

    final sidebarSections = <_SidebarToggleSection>[
      const _SidebarToggleSection(
        title: 'Main',
        items: [
          _SidebarToggleSpec(
            item: SidebarItem.home,
            subtitle: 'Show Home in the sidebar.',
          ),
          _SidebarToggleSpec(
            item: SidebarItem.settings,
            subtitle: 'Show Settings in the sidebar.',
          ),
        ],
      ),
      const _SidebarToggleSection(
        title: 'Favorites',
        items: [
          _SidebarToggleSpec(
            item: SidebarItem.favoritesAlbums,
            subtitle: 'Show favorite albums.',
          ),
          _SidebarToggleSpec(
            item: SidebarItem.favoritesArtists,
            subtitle: 'Show favorite artists.',
          ),
          _SidebarToggleSpec(
            item: SidebarItem.favoritesSongs,
            subtitle: 'Show favorite tracks.',
          ),
        ],
      ),
      const _SidebarToggleSection(
        title: 'Available Offline',
        items: [
          _SidebarToggleSpec(
            item: SidebarItem.offlineAlbums,
            subtitle: 'Show offline albums.',
          ),
          _SidebarToggleSpec(
            item: SidebarItem.offlineArtists,
            subtitle: 'Show offline artists.',
          ),
          _SidebarToggleSpec(
            item: SidebarItem.offlinePlaylists,
            subtitle: 'Show offline playlists.',
          ),
          _SidebarToggleSpec(
            item: SidebarItem.offlineTracks,
            subtitle: 'Show offline tracks.',
          ),
        ],
      ),
      const _SidebarToggleSection(
        title: 'Browse',
        items: [
          _SidebarToggleSpec(
            item: SidebarItem.browseAlbums,
            subtitle: 'Show albums in Browse.',
          ),
          _SidebarToggleSpec(
            item: SidebarItem.browseArtists,
            subtitle: 'Show artists in Browse.',
          ),
          _SidebarToggleSpec(
            item: SidebarItem.browseGenres,
            subtitle: 'Show genres in Browse.',
          ),
          _SidebarToggleSpec(
            item: SidebarItem.browsePlaylists,
            subtitle: 'Show playlists in Browse.',
          ),
          _SidebarToggleSpec(
            item: SidebarItem.browseTracks,
            subtitle: 'Show tracks in Browse.',
          ),
        ],
      ),
      const _SidebarToggleSection(
        title: 'Playback',
        items: [
          _SidebarToggleSpec(
            item: SidebarItem.history,
            subtitle: 'Show playback history.',
          ),
          _SidebarToggleSpec(
            item: SidebarItem.queue,
            subtitle: 'Show the play queue.',
          ),
        ],
      ),
      const _SidebarToggleSection(
        title: 'Playlists',
        items: [
          _SidebarToggleSpec(
            item: SidebarItem.playlists,
            subtitle: 'Show playlist list in the sidebar.',
          ),
        ],
      ),
    ];
    final segmentedStyle = ButtonStyle(
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.bodySmall,
      ),
    );
    Widget sectionHeader(String title) => Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        );
    Widget segmentedRow<T>({
      required String title,
      required String subtitle,
      required Set<T> selected,
      required List<ButtonSegment<T>> segments,
      required ValueChanged<Set<T>> onSelectionChanged,
    }) {
      return _SettingRow(
        title: title,
        subtitle: subtitle,
        forceInline: true,
        trailing: SegmentedButton<T>(
          style: segmentedStyle,
          segments: segments,
          selected: selected,
          onSelectionChanged: onSelectionChanged,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Layout'),
        SizedBox(height: space(12)),
        segmentedRow<NowPlayingLayout>(
          title: 'Now playing layout',
          subtitle: 'Choose where the player is docked.',
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
        Divider(height: space(32), color: ColorTokens.border(context, 0.12)),
        sectionHeader('Track Lists'),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Default track lists to',
          subtitle: 'Choose how track lists are displayed.',
          trailing: SizedBox(
            width: 200,
            child: Row(
              children: [
                for (final style in TrackListStyle.values)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: space(4)),
                      child: _StyleButton(
                        label: style.label,
                        selected: state.trackListStyle == style,
                        onTap: () => state.setTrackListStyle(style),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: space(16)),
        _TrackListStyleDemo(),
        Divider(height: space(32), color: ColorTokens.border(context, 0.12)),
        sectionHeader('Home'),
        SizedBox(height: space(12)),
        segmentedRow<HomeShelfLayout>(
          title: 'Featured & recent layout',
          subtitle: 'Switch between the scroller and a compact grid.',
          segments: HomeShelfLayout.values
              .map(
                (layout) => ButtonSegment(
                  value: layout,
                  label: Text(layout.label),
                ),
              )
              .toList(),
          selected: {state.homeShelfLayout},
          onSelectionChanged: (selection) {
            state.setHomeShelfLayout(selection.first);
          },
        ),
        if (state.homeShelfLayout == HomeShelfLayout.grid) ...[
          SizedBox(height: space(12)),
          _SettingRow(
            title: 'Grid rows',
            subtitle: 'Limit how many rows appear on the home shelves.',
            forceInline: true,
            trailing: SegmentedButton<int>(
              style: segmentedStyle,
              segments: const [
                ButtonSegment(value: 1, label: Text('1')),
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
              ],
              selected: {state.homeShelfGridRows},
              onSelectionChanged: (selection) {
                state.setHomeShelfGridRows(selection.first);
              },
            ),
          ),
        ],
        SizedBox(height: space(20)),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: state.homeSectionOrder.length,
          onReorder: (oldIndex, newIndex) =>
              state.reorderHomeSections(oldIndex, newIndex),
          itemBuilder: (context, index) {
            final section = state.homeSectionOrder[index];
            return _HomeSectionRow(
              key: ValueKey(section.storageKey),
              section: section,
              index: index,
              enabled: state.isHomeSectionVisible(section),
              onToggle: (value) => state.setHomeSectionVisible(section, value),
            );
          },
        ),
        Divider(height: space(32), color: ColorTokens.border(context, 0.12)),
        Text('Sidebar', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: space(12)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...sidebarSections.expand(
              (section) => buildSidebarSection(section.title, section.items),
            ),
          ],
        ),
      ],
    );
  }
}

class _HomeSectionRow extends StatelessWidget {
  const _HomeSectionRow({
    super.key,
    required this.section,
    required this.index,
    required this.enabled,
    required this.onToggle,
  });

  final HomeSection section;
  final int index;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Padding(
      padding: EdgeInsets.only(bottom: space(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: EdgeInsets.only(
                top: space(6),
                right: space(10).clamp(6.0, 14.0),
              ),
              child: Icon(
                Icons.drag_handle,
                size: space(18).clamp(14.0, 22.0),
                color: ColorTokens.textSecondary(context, 0.7),
              ),
            ),
          ),
          Expanded(
            child: _SettingRow(
              title: section.label,
              subtitle: section.description,
              forceInline: true,
              trailing: CompactSwitch(
                value: enabled,
                onChanged: onToggle,
              ),
            ),
          ),
        ],
      ),
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
    List<Widget> shortcutSection({
      required String title,
      required String description,
      required bool enabled,
      required ValueChanged<bool> onEnabled,
      required KeyboardShortcut shortcut,
      required ValueChanged<KeyboardShortcut> onChanged,
    }) {
      return [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: space(4)),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColorTokens.textSecondary(context),
              ),
        ),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Enabled',
          subtitle: 'Allow the shortcut to ${title.toLowerCase()}.',
          forceInline: true,
          trailing: CompactSwitch(
            value: enabled,
            onChanged: onEnabled,
          ),
        ),
        SizedBox(height: space(8)),
        _SettingRow(
          title: 'Shortcut',
          subtitle: 'Include Cmd/Ctrl/Alt plus a key.',
          forceInline: true,
          trailing: _ShortcutRecorder(
            shortcut: shortcut,
            enabled: enabled,
            onChanged: onChanged,
          ),
        ),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Keyboard', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: space(12)),
        ...shortcutSection(
          title: 'Open settings',
          description: 'Use a global shortcut to jump to Settings.',
          enabled: state.settingsShortcutEnabled,
          onEnabled: (value) => state.setSettingsShortcutEnabled(value),
          shortcut: state.settingsShortcut,
          onChanged: (shortcut) => state.setSettingsShortcut(shortcut),
        ),
        Divider(height: space(24), color: ColorTokens.border(context, 0.12)),
        ...shortcutSection(
          title: 'Focus search',
          description: 'Jump straight to the search field from anywhere.',
          enabled: state.searchShortcutEnabled,
          onEnabled: (value) => state.setSearchShortcutEnabled(value),
          shortcut: state.searchShortcut,
          onChanged: (shortcut) => state.setSearchShortcut(shortcut),
        ),
      ],
    );
  }
}

class _PlaybackSettings extends StatelessWidget {
  const _PlaybackSettings({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Playback', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Gapless playback',
          subtitle: 'Preload the next track to remove silence between songs.',
          trailing: CompactSwitch(
            value: state.gaplessPlaybackEnabled,
            onChanged: state.setGaplessPlayback,
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
    widget.state.refreshMediaCacheBytes();
  }

  void _refreshCacheUsage() {
    widget.state.refreshMediaCacheBytes();
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
          trailing: ValueListenableBuilder<int>(
            valueListenable: widget.state.mediaCacheBytesListenable,
            builder: (context, bytes, _) => Text(
              formatBytes(bytes),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
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
        SizedBox(height: space(6)),
        ValueListenableBuilder<int>(
          valueListenable: widget.state.pinnedCacheBytesListenable,
          builder: (context, pinnedBytes, _) {
            if (widget.state.cacheMaxBytes <= 0 ||
                pinnedBytes <= widget.state.cacheMaxBytes) {
              return const SizedBox.shrink();
            }
            return Text(
              'Pinned downloads use ${formatBytes(pinnedBytes)} and may exceed '
              'the cache limit; unpinned tracks are evicted first.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColorTokens.textSecondary(context, 0.7),
                  ),
            );
          },
        ),
        SizedBox(height: space(20)),
        const _SettingsSubheader(title: 'Offline favorites'),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Automatically download favorites',
          subtitle: 'Keep favorited items available offline.',
          forceInline: true,
          trailing: CompactSwitch(
            value: widget.state.autoDownloadFavoritesEnabled,
            onChanged: widget.state.setAutoDownloadFavoritesEnabled,
          ),
        ),
        SizedBox(height: space(12)),
        _AutoDownloadOption(
          enabled: widget.state.autoDownloadFavoritesEnabled,
          child: _SettingRow(
            title: 'Albums',
            subtitle: 'Download favorited albums.',
            forceInline: true,
            trailing: CompactSwitch(
              value: widget.state.autoDownloadFavoriteAlbums,
              onChanged: widget.state.setAutoDownloadFavoriteAlbums,
            ),
          ),
        ),
        SizedBox(height: space(12)),
        _AutoDownloadOption(
          enabled: widget.state.autoDownloadFavoritesEnabled,
          child: _SettingRow(
            title: 'Artists',
            subtitle: 'Download favorited artists.',
            forceInline: true,
            trailing: CompactSwitch(
              value: widget.state.autoDownloadFavoriteArtists,
              onChanged: widget.state.setAutoDownloadFavoriteArtists,
            ),
          ),
        ),
        SizedBox(height: space(12)),
        _AutoDownloadOption(
          enabled: widget.state.autoDownloadFavoritesEnabled,
          child: _SettingRow(
            title: 'Tracks',
            subtitle: 'Download favorited tracks.',
            forceInline: true,
            trailing: CompactSwitch(
              value: widget.state.autoDownloadFavoriteTracks,
              onChanged: widget.state.setAutoDownloadFavoriteTracks,
            ),
          ),
        ),
        SizedBox(height: space(12)),
        _AutoDownloadOption(
          enabled: widget.state.autoDownloadFavoritesEnabled,
          child: _SettingRow(
            title: 'Only on Wi-Fi',
            subtitle: 'Avoid cellular downloads for favorites.',
            forceInline: true,
            trailing: CompactSwitch(
              value: widget.state.autoDownloadFavoritesWifiOnly,
              onChanged: widget.state.setAutoDownloadFavoritesWifiOnly,
            ),
          ),
        ),
        SizedBox(height: space(20)),
        const _SettingsSubheader(title: 'Downloads'),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Only on Wi-Fi',
          subtitle: 'Avoid cellular downloads for pinned media.',
          forceInline: true,
          trailing: CompactSwitch(
            value: widget.state.downloadsWifiOnly,
            onChanged: widget.state.setDownloadsWifiOnly,
          ),
        ),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Pause downloads',
          subtitle: 'Stop downloading until you resume.',
          forceInline: true,
          trailing: CompactSwitch(
            value: widget.state.downloadsPaused,
            onChanged: widget.state.setDownloadsPaused,
          ),
        ),
        SizedBox(height: space(12)),
        _DownloadQueueList(
          tasks: widget.state.downloadQueue,
          isPaused: widget.state.downloadsPaused,
          onReorder: widget.state.reorderDownloadQueue,
          onRetry: widget.state.retryDownload,
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

class _AutoDownloadOption extends StatelessWidget {
  const _AutoDownloadOption({
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Padding(
          padding: EdgeInsets.only(left: space(16).clamp(12.0, 24.0)),
          child: child,
        ),
      ),
    );
  }
}

class _DownloadQueueList extends StatelessWidget {
  const _DownloadQueueList({
    required this.tasks,
    required this.isPaused,
    required this.onReorder,
    required this.onRetry,
  });

  final List<DownloadTask> tasks;
  final bool isPaused;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<DownloadTask> onRetry;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    if (tasks.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(left: space(8)),
        child: Text(
          'No downloads queued.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColorTokens.textSecondary(context),
              ),
        ),
      );
    }
    var downloading = 0;
    var queued = 0;
    var waiting = 0;
    var failed = 0;
    for (final task in tasks) {
      switch (task.status) {
        case DownloadStatus.downloading:
          downloading += 1;
          break;
        case DownloadStatus.queued:
          queued += 1;
          break;
        case DownloadStatus.waitingForWifi:
          waiting += 1;
          break;
        case DownloadStatus.failed:
          failed += 1;
          break;
      }
    }
    final summaryParts = <String>[];
    summaryParts.add('${tasks.length} downloads');
    if (isPaused) {
      summaryParts.add('Paused');
    }
    if (downloading > 0) {
      summaryParts.add('$downloading downloading');
    }
    if (waiting > 0) {
      summaryParts.add('$waiting waiting');
    }
    if (queued > 0) {
      summaryParts.add('$queued queued');
    }
    if (failed > 0) {
      summaryParts.add('$failed failed');
    }
    final rowHeight = space(38).clamp(32.0, 44.0).toDouble();
    final visibleRows = tasks.length.clamp(1, 4);
    final listHeight = rowHeight * visibleRows;
    return Container(
      padding: EdgeInsets.all(space(12).clamp(10.0, 16.0)),
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.04),
        borderRadius: BorderRadius.circular(
          context.scaledRadius(space(16).clamp(12.0, 20.0)),
        ),
        border: Border.all(color: ColorTokens.border(context, 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summaryParts.join(' • '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ColorTokens.textSecondary(context),
                ),
          ),
          SizedBox(height: space(6)),
          SizedBox(
            height: listHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                context.scaledRadius(space(12).clamp(10.0, 16.0)),
              ),
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: tasks.length,
                onReorder: (oldIndex, newIndex) {
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    onReorder(oldIndex, newIndex);
                  });
                },
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return _DownloadQueueRow(
                    key: ValueKey(task.track.streamUrl),
                    task: task,
                    isPaused: isPaused,
                    index: index,
                    onRetry: () => onRetry(task),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadQueueRow extends StatelessWidget {
  const _DownloadQueueRow({
    super.key,
    required this.task,
    required this.isPaused,
    required this.index,
    required this.onRetry,
  });

  final DownloadTask task;
  final bool isPaused;
  final int index;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final progressPrefix = () {
      if (task.status == DownloadStatus.downloading && task.progress != null) {
        final percent = (task.progress! * 100).clamp(0, 100).round();
        return '[$percent%] ';
      }
      return '';
    }();
    final statusLabel = _statusLabel(task, isPaused);
    final artistLabel = task.track.artists.isEmpty
        ? 'Unknown Artist'
        : task.track.artists.join(', ');
    final albumLabel =
        task.track.album.isEmpty ? 'Unknown Album' : task.track.album;
    final line =
        '$progressPrefix$statusLabel • ${task.track.title} – $artistLabel / $albumLabel';
    return Padding(
      padding: EdgeInsets.only(bottom: space(6)),
      child: Container(
        height: space(40).clamp(32.0, 44.0),
        padding: EdgeInsets.symmetric(
          horizontal: space(10).clamp(8.0, 14.0),
        ),
        decoration: BoxDecoration(
          color: ColorTokens.cardFill(context, 0.06),
          borderRadius: BorderRadius.circular(
            context.scaledRadius(space(12).clamp(8.0, 16.0)),
          ),
          border: Border.all(
            color: ColorTokens.border(context, 0.12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: EdgeInsets.only(right: space(10)),
                child: Icon(
                  Icons.drag_handle,
                  size: space(16).clamp(12.0, 20.0),
                  color: ColorTokens.textSecondary(context, 0.7),
                ),
              ),
            ),
            Expanded(
              child: Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (task.status == DownloadStatus.failed) ...[
              const SizedBox(width: 6),
              IconButton(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Retry',
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(DownloadTask task, bool isPaused) {
    if (isPaused &&
        task.status != DownloadStatus.downloading &&
        task.status != DownloadStatus.failed) {
      return 'Paused';
    }
    if (task.status == DownloadStatus.downloading) {
      return 'Downloading';
    }
    if (task.status == DownloadStatus.waitingForWifi) {
      return 'Waiting for Wi-Fi';
    }
    if (task.status == DownloadStatus.failed) {
      return 'Failed';
    }
    return 'Queued';
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

  void _handleKey(KeyEvent event) {
    if (!_isRecording || event is! KeyDownEvent) {
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _stopRecording();
      return;
    }
    if (_isModifierKey(event.logicalKey)) {
      return;
    }
    final keyboard = HardwareKeyboard.instance;
    final shortcut = KeyboardShortcut(
      key: event.logicalKey,
      meta: keyboard.isMetaPressed,
      control: keyboard.isControlPressed,
      alt: keyboard.isAltPressed,
      shift: keyboard.isShiftPressed,
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
    final label = _isRecording ? 'Press shortcut...' : widget.shortcut.label();
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
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
                context.scaledRadius(clamped(18, min: 12, max: 22)),
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
        SizedBox(height: space(6)),
        Text(
          'These updates are sent to your Jellyfin server to report your playback. They are all optional. None of these settings send any data to third parties like Coppelia or other analytics services.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColorTokens.textSecondary(context),
              ),
        ),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Playback reporting',
          subtitle: 'Send now playing and pause/resume state to Jellyfin.',
          forceInline: true,
          trailing: CompactSwitch(
            value: state.telemetryPlaybackEnabled,
            onChanged: state.setTelemetryPlayback,
          ),
        ),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Progress updates',
          subtitle: 'Report playback progress while a track is playing.',
          forceInline: true,
          trailing: CompactSwitch(
            value: state.telemetryProgressEnabled,
            onChanged: state.setTelemetryProgress,
          ),
        ),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Play history',
          subtitle: 'Send play completion events for library history.',
          forceInline: true,
          trailing: CompactSwitch(
            value: state.telemetryHistoryEnabled,
            onChanged: state.setTelemetryHistory,
          ),
        ),
        SizedBox(height: space(32)),
        Text('Search', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Use local search even when online',
          subtitle: 'Search cached library data instead of using server.',
          forceInline: true,
          trailing: CompactSwitch(
            value: state.preferLocalSearch,
            onChanged: state.setPreferLocalSearch,
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

class _LogsDialog extends StatelessWidget {
  const _LogsDialog({
    required this.logContent,
    required this.logPath,
    required this.onClear,
  });

  final String logContent;
  final String? logPath;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;

    return AlertDialog(
      title: const Text('App Logs'),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (logPath != null) ...[
              Text(
                'Log file location:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColorTokens.textSecondary(context),
                    ),
              ),
              SizedBox(height: space(4)),
              SelectableText(
                logPath!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: ColorTokens.textSecondary(context, 0.7),
                    ),
              ),
              SizedBox(height: space(16)),
            ],
            Text(
              'Recent logs:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColorTokens.textSecondary(context),
                  ),
            ),
            SizedBox(height: space(8)),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(space(12)),
                decoration: BoxDecoration(
                  color: ColorTokens.cardFill(context, 0.08),
                  borderRadius: BorderRadius.circular(
                    context.scaledRadius(12),
                  ),
                  border: Border.all(
                    color: ColorTokens.border(context, 0.12),
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    logContent,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (logPath != null && Platform.isMacOS)
          TextButton(
            onPressed: () async {
              // Extract directory from file path
              final dir = logPath!.substring(0, logPath!.lastIndexOf('/'));
              // Use 'open' command to reveal in Finder
              await Process.run('open', [dir]);
            },
            child: const Text('Show in Finder'),
          ),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: logContent));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard')),
              );
            }
          },
          child: const Text('Copy'),
        ),
        if (logPath != null)
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: logPath!));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Path copied to clipboard')),
                );
              }
            },
            child: const Text('Copy path'),
          ),
        TextButton(
          onPressed: onClear,
          child: const Text('Clear logs'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _AppSettings extends StatefulWidget {
  @override
  State<_AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<_AppSettings> {
  bool _isChecking = false;
  String? _latestTag;
  String? _error;

  Future<void> _checkLatestVersion() async {
    setState(() {
      _isChecking = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.github.com/repos/j6k4m8/coppelia/releases/latest'),
      );
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = payload['tag_name']?.toString();
      setState(() {
        _latestTag = tag;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  bool get _isUpToDate {
    final tag = _latestTag;
    if (tag == null) return false;
    final normalized = tag.startsWith('v') ? tag.substring(1) : tag;
    return normalized == AppInfo.version;
  }

  String? _downloadUrlForPlatform() {
    final tag = _latestTag;
    if (tag == null) return null;
    final base = 'https://github.com/j6k4m8/coppelia/releases/download/$tag';
    if (Platform.isMacOS) {
      return '$base/Coppelia-macos.zip';
    }
    if (Platform.isLinux) {
      return '$base/Coppelia-linux.tar.gz';
    }
    if (Platform.isAndroid) {
      return '$base/Coppelia-android.apk';
    }
    if (Platform.isIOS) {
      return '$base/Coppelia-ios-simulator.zip';
    }
    return base;
  }

  Future<void> _showLogsDialog(BuildContext context) async {
    final logService = await LogService.instance;
    final logContent = await logService.getLogContent();
    final logPath = await logService.getLogFilePath();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => _LogsDialog(
        logContent: logContent,
        logPath: logPath,
        onClear: () async {
          await logService.clearLogs();
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final statusText = _error != null
        ? 'Update check failed: $_error'
        : _latestTag == null
            ? 'Latest release: unknown'
            : _isUpToDate
                ? 'Up to date (latest: $_latestTag)'
                : 'Update available (latest: $_latestTag)';
    final downloadUrl = !_isUpToDate ? _downloadUrlForPlatform() : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('App', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Version',
          subtitle: 'Installed app version.',
          trailing: Text(AppInfo.displayVersion),
        ),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'Check for updates',
          subtitle: statusText,
          trailing: OutlinedButton(
            onPressed: _isChecking ? null : _checkLatestVersion,
            child: Text(_isChecking ? 'Checking…' : 'Check'),
          ),
        ),
        if (downloadUrl != null && _latestTag != null) ...[
          SizedBox(height: space(8)),
          _SettingRow(
            title: 'Download update',
            subtitle: 'Grab the latest release for this platform.',
            trailing: OutlinedButton(
              onPressed: () => launchUrlString(downloadUrl),
              child: const Text('Download'),
            ),
          ),
        ],
        SizedBox(height: space(24)),
        Text('Diagnostics', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: space(12)),
        _SettingRow(
          title: 'App logs',
          subtitle:
              'View and share diagnostic logs to help troubleshoot issues.',
          trailing: OutlinedButton(
            onPressed: () => _showLogsDialog(context),
            child: const Text('View logs'),
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
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
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

class _SidebarToggleSpec {
  const _SidebarToggleSpec({required this.item, required this.subtitle});

  final SidebarItem item;
  final String subtitle;
}

class _SidebarToggleSection {
  const _SidebarToggleSection({required this.title, required this.items});

  final String title;
  final List<_SidebarToggleSpec> items;
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
        borderRadius: BorderRadius.circular(context.scaledRadius(999)),
        border: Border.all(color: ColorTokens.border(context, 0.12)),
      ),
      child: Text(
        '$value $label',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final ringColor =
        selected ? Theme.of(context).colorScheme.primary : Colors.transparent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: space(24).clamp(18.0, 30.0),
              height: space(24).clamp(18.0, 30.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: ringColor,
                  width: 2,
                ),
              ),
            ),
            SizedBox(width: space(8)),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentPreview extends StatelessWidget {
  const _AccentPreview({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: ColorTokens.border(context, 0.2)),
      ),
    );
  }
}

class _CornerRadiusOption extends StatelessWidget {
  const _CornerRadiusOption({
    required this.label,
    required this.radius,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double radius;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : ColorTokens.border(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: space(52).clamp(42.0, 60.0),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(radius),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      selected ? Theme.of(context).colorScheme.primary : null,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
          ),
        ),
      ),
    );
  }
}

class _AccentPreset {
  const _AccentPreset(this.label, this.color);

  final String label;
  final Color color;
}

const List<_AccentPreset> _accentPresets = [
  _AccentPreset('Indigo', Color(0xFF6F7BFF)),
  _AccentPreset('Mint', Color(0xFF45D6B4)),
  _AccentPreset('Coral', Color(0xFFFF7A59)),
  _AccentPreset('Amber', Color(0xFFFFB347)),
  _AccentPreset('Teal', Color(0xFF35B7C3)),
  _AccentPreset('Rose', Color(0xFFF06292)),
];

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

/// Simple style toggle button.
class _StyleButton extends StatelessWidget {
  const _StyleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
              : ColorTokens.cardFill(context, 0.05),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : ColorTokens.border(context, 0.12),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? Theme.of(context).colorScheme.primary : null,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ),
    );
  }
}

/// Demo showing card vs table track list styles.
class _TrackListStyleDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;

    // Mock track data for demo
    final demoTrack1 = {
      'title': 'Carnegie Hall: 4\'33',
      'artist': 'John Cage',
      'album': 'Cage Plays Carnegie Hall',
      'duration': '4:33',
    };
    final demoTrack2 = {
      'title': 'Four-Thirty-Three (DUBSTEP REMIX) - Radio Edit',
      'artist': 'DJ Tuchas',
      'album': 'The Sound of Silence',
      'duration': '4:32',
    };

    return Container(
      padding: EdgeInsets.all(space(16)),
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ColorTokens.border(context, 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ColorTokens.textSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(height: space(12)),
          if (state.trackListStyle == TrackListStyle.card) ...[
            _DemoTrackCard(track: demoTrack1),
            SizedBox(height: space(6)),
            _DemoTrackCard(track: demoTrack2),
          ] else ...[
            // Table header
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      '#',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ColorTokens.textSecondary(context, 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Title',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ColorTokens.textSecondary(context, 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Artist',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ColorTokens.textSecondary(context, 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Album',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ColorTokens.textSecondary(context, 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      'Time',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ColorTokens.textSecondary(context, 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            _DemoTrackTableRow(index: 1, track: demoTrack1),
            _DemoTrackTableRow(index: 2, track: demoTrack2),
          ],
        ],
      ),
    );
  }
}

class _DemoTrackCard extends StatelessWidget {
  const _DemoTrackCard({required this.track});

  final Map<String, String> track;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;

    return Container(
      height: space(56).clamp(48.0, 64.0),
      padding: EdgeInsets.symmetric(horizontal: space(12)),
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: space(40).clamp(32.0, 48.0),
            height: space(40).clamp(32.0, 48.0),
            decoration: BoxDecoration(
              color: ColorTokens.cardFillStrong(context),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.music_note,
              size: space(20).clamp(16.0, 24.0),
              color: ColorTokens.textSecondary(context, 0.5),
            ),
          ),
          SizedBox(width: space(12)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track['title']!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: space(2)),
                Text(
                  track['artist']!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColorTokens.textSecondary(context),
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            track['duration']!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ColorTokens.textSecondary(context),
                ),
          ),
        ],
      ),
    );
  }
}

class _DemoTrackTableRow extends StatelessWidget {
  const _DemoTrackTableRow({required this.index, required this.track});

  final int index;
  final Map<String, String> track;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '$index',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColorTokens.textSecondary(context),
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              track['title']!,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              track['artist']!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColorTokens.textSecondary(context),
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              track['album']!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColorTokens.textSecondary(context),
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              track['duration']!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColorTokens.textSecondary(context),
                  ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
