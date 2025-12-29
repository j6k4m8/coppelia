import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/browse_layout.dart';
import '../../state/layout_density.dart';
import '../../state/library_view.dart';
import '../../core/color_tokens.dart';
import 'section_header.dart';

extension BrowseLayoutLabel on BrowseLayout {
  /// Display label for the layout picker.
  String get label => this == BrowseLayout.grid ? 'Grid' : 'List';

  /// Icon for the layout picker.
  IconData get icon =>
      this == BrowseLayout.grid ? Icons.grid_view : Icons.view_list;
}

/// Shared browse view for long album/artist/genre lists.
class LibraryBrowseView<T> extends StatefulWidget {
  /// Creates a library browse view.
  const LibraryBrowseView({
    super.key,
    required this.view,
    required this.title,
    required this.items,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.gridItemBuilder,
    required this.listItemBuilder,
  });

  /// Library view used for state storage.
  final LibraryView view;

  /// Section title.
  final String title;

  /// Items to display.
  final List<T> items;

  /// Returns a display title.
  final String Function(T item) titleBuilder;

  /// Returns a display subtitle.
  final String Function(T item) subtitleBuilder;

  /// Builds grid item tiles.
  final Widget Function(BuildContext context, T item) gridItemBuilder;

  /// Builds list item tiles.
  final Widget Function(BuildContext context, T item) listItemBuilder;

  @override
  State<LibraryBrowseView<T>> createState() => _LibraryBrowseViewState<T>();
}

class _LibraryBrowseViewState<T> extends State<LibraryBrowseView<T>> {
  static const double _listItemExtent = 74;

  late final ScrollController _controller;
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final offset = state.loadScrollOffset(_scrollKey);
    _controller = ScrollController(initialScrollOffset: offset);
    _controller.addListener(_handleScroll);
  }

  @override
  void dispose() {
    final state = context.read<AppState>();
    state.saveScrollOffset(_scrollKey, _controller.offset);
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  String get _scrollKey => '${widget.view.name}-layout';

  void _handleScroll() {
    final shouldShow = _controller.offset > 280;
    if (_showBackToTop != shouldShow) {
      setState(() {
        _showBackToTop = shouldShow;
      });
    }
  }

  double _textHeight(TextStyle? style) {
    final fontSize = style?.fontSize ?? 14;
    final height = style?.height ?? 1.2;
    return fontSize * height;
  }

  @override
  Widget build(BuildContext context) {
    final density =
        context.select((AppState state) => state.layoutDensity);
    final densityScale = density.scaleDouble;
    final layout = context
        .select((AppState state) => state.browseLayoutFor(widget.view));
    double space(double value) => value * densityScale;
    final leftGutter =
        (32 * densityScale).clamp(16.0, 40.0).toDouble();
    final rightGutter =
        (24 * densityScale).clamp(12.0, 32.0).toDouble();
    final itemCount = widget.items.length;
    final letterIndex = _buildLetterIndex(widget.items);
    final letters = letterIndex.keys.toList(growable: false);
    final contentRightPadding =
        letters.isNotEmpty ? space(48).clamp(32.0, 64.0) : 0.0;
    final titleStyle = density == LayoutDensity.sardine
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.titleMedium;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    final titleHeight = _textHeight(titleStyle);
    final subtitleHeight = _textHeight(subtitleStyle);
    final subtitleGap = density == LayoutDensity.sardine
        ? space(2).clamp(0.0, 3.0)
        : space(4).clamp(2.0, 6.0);
    final verticalPadding = density == LayoutDensity.sardine
        ? space(6).clamp(2.0, 8.0)
        : space(10).clamp(4.0, 12.0);
    final artSize = (48 * densityScale).clamp(24.0, 56.0);
    final textBlock = titleHeight + subtitleHeight + subtitleGap;
    final contentHeight = math.max(artSize, textBlock);
    final listItemExtent =
        math.max(contentHeight + verticalPadding * 2, 28).toDouble();

    final contentPadding =
        EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0);
    final listPadding = EdgeInsets.fromLTRB(
      leftGutter,
      0,
      rightGutter + contentRightPadding,
      0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: contentPadding,
          child: SectionHeader(
            title: widget.title,
            action: Row(
              children: [
                Text(
                  '$itemCount items',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: ColorTokens.textSecondary(context)),
                ),
                const SizedBox(width: 16),
                SegmentedButton<BrowseLayout>(
                  segments: BrowseLayout.values
                      .map(
                        (mode) => ButtonSegment(
                          value: mode,
                          label: Text(mode.label),
                          icon: Icon(mode.icon, size: 16),
                        ),
                      )
                      .toList(),
                  selected: {layout},
                  onSelectionChanged: (selection) {
                    context
                        .read<AppState>()
                        .setBrowseLayout(widget.view, selection.first);
                  },
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: space(16)),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gridMetrics = _GridMetrics.fromWidth(
                width: constraints.maxWidth,
                itemAspectRatio: 1.05,
                itemMinWidth: space(220).clamp(160.0, 260.0),
                spacing: space(16),
              );
              return Stack(
                children: [
                  layout == BrowseLayout.grid
                      ? GridView.builder(
                          controller: _controller,
                          padding: listPadding,
                          itemCount: widget.items.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridMetrics.columns,
                            crossAxisSpacing: gridMetrics.spacing,
                            mainAxisSpacing: gridMetrics.spacing,
                            childAspectRatio: gridMetrics.aspectRatio,
                          ),
                          itemBuilder: (context, index) {
                            final item = widget.items[index];
                            return widget.gridItemBuilder(context, item);
                          },
                        )
                      : ListView.separated(
                          controller: _controller,
                          padding: listPadding,
                          itemCount: widget.items.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: space(6).clamp(4.0, 10.0)),
                          itemBuilder: (context, index) {
                            final item = widget.items[index];
                            return SizedBox(
                              height: listItemExtent,
                              child: widget.listItemBuilder(context, item),
                            );
                          },
                        ),
                  if (letters.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 12,
                      bottom: 12,
                      child: _AlphabetScroller(
                        letters: letters,
                        onSelected: (letter) {
                          final targetIndex = letterIndex[letter];
                          if (targetIndex == null) {
                            return;
                          }
                          final offset = layout == BrowseLayout.grid
                              ? gridMetrics.offsetForIndex(targetIndex)
                              : (targetIndex * listItemExtent).toDouble();
                          _controller.animateTo(
                            offset,
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOut,
                          );
                        },
                      ),
                    ),
                  Positioned(
                    right: space(24),
                    bottom: space(24),
                    child: AnimatedOpacity(
                      opacity: _showBackToTop ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !_showBackToTop,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _controller.animateTo(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                          icon: const Icon(Icons.arrow_upward, size: 16),
                          label: const Text('Back to top'),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Map<String, int> _buildLetterIndex(List<T> items) {
    final index = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      final raw = widget.titleBuilder(items[i]).trim();
      if (raw.isEmpty) {
        continue;
      }
      final letter = raw.substring(0, 1).toUpperCase();
      index.putIfAbsent(letter, () => i);
    }
    return index;
  }
}

class _AlphabetScroller extends StatelessWidget {
  const _AlphabetScroller({
    required this.letters,
    required this.onSelected,
  });

  final List<String> letters;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final densityScale =
        context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotHeight = space(18).clamp(14.0, 22.0);
        final maxSlots = ((constraints.maxHeight - space(16)) / slotHeight)
            .floor()
            .clamp(1, letters.length);
        final displayLetters = _subsampleLetters(letters, maxSlots);
        return Container(
          width: space(28).clamp(22.0, 36.0),
          padding: EdgeInsets.symmetric(vertical: space(8)),
          decoration: BoxDecoration(
            color: ColorTokens.cardFill(context, 0.04),
            borderRadius: BorderRadius.circular(
              space(20).clamp(14.0, 24.0),
            ),
            border: Border.all(color: ColorTokens.border(context)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: displayLetters.map((letter) {
              return SizedBox(
                height: slotHeight,
                child: _AlphabetLetter(
                  letter: letter,
                  onTap: () => onSelected(letter),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  List<String> _subsampleLetters(List<String> items, int maxSlots) {
    if (items.length <= maxSlots) {
      return items;
    }
    if (maxSlots <= 1) {
      return [items.first];
    }
    final sampled = <String>[];
    final step = (items.length - 1) / (maxSlots - 1);
    for (var i = 0; i < maxSlots; i++) {
      final index = (i * step).round().clamp(0, items.length - 1);
      final letter = items[index];
      if (sampled.isEmpty || sampled.last != letter) {
        sampled.add(letter);
      }
    }
    return sampled;
  }
}

class _AlphabetLetter extends StatelessWidget {
  const _AlphabetLetter({
    required this.letter,
    required this.onTap,
  });

  final String letter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final densityScale =
        context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final baseStyle = Theme.of(context).textTheme.labelSmall;
    return TextButton(
      onPressed: onTap,
      style: ButtonStyle(
        padding: MaterialStateProperty.all(EdgeInsets.zero),
        minimumSize:
            MaterialStateProperty.all(Size(space(20), space(20))),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.hovered)) {
            return ColorTokens.textPrimary(context);
          }
          return ColorTokens.textSecondary(context, 0.7);
        }),
        textStyle: MaterialStateProperty.all(baseStyle),
        overlayColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.hovered)) {
            return ColorTokens.cardFill(context, 0.08);
          }
          return Colors.transparent;
        }),
      ),
      child: Text(letter),
    );
  }
}

class _GridMetrics {
  const _GridMetrics({
    required this.columns,
    required this.itemWidth,
    required this.itemHeight,
    required this.aspectRatio,
    required this.spacing,
  });

  final int columns;
  final double itemWidth;
  final double itemHeight;
  final double aspectRatio;
  final double spacing;

  static _GridMetrics fromWidth({
    required double width,
    required double itemAspectRatio,
    required double itemMinWidth,
    required double spacing,
  }) {
    final crossAxisCount = (width / itemMinWidth).floor();
    final columns = crossAxisCount < 1 ? 1 : crossAxisCount;
    final totalSpacing = spacing * (columns - 1);
    final itemWidth = (width - totalSpacing) / columns;
    final itemHeight = itemWidth / itemAspectRatio;
    return _GridMetrics(
      columns: columns,
      itemWidth: itemWidth,
      itemHeight: itemHeight,
      aspectRatio: itemAspectRatio,
      spacing: spacing,
    );
  }

  double offsetForIndex(int index) {
    final row = (index / columns).floor();
    return row * (itemHeight + spacing);
  }
}
