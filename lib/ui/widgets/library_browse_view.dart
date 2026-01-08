import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/browse_layout.dart';
import '../../state/layout_density.dart';
import '../../state/library_view.dart';
import '../../core/color_tokens.dart';
import 'alphabet_scroller.dart';
import 'page_header.dart';

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
  late final ScrollController _controller;
  late final AppState _state;
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    final offset = _state.loadScrollOffset(_scrollKey);
    _controller = ScrollController(initialScrollOffset: offset);
    _controller.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _state.saveScrollOffset(_scrollKey, _controller.offset);
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
    final density = context.select((AppState state) => state.layoutDensity);
    final densityScale = density.scaleDouble;
    final layout =
        context.select((AppState state) => state.browseLayoutFor(widget.view));
    double space(double value) => value * densityScale;
    final isCompactWidth = MediaQuery.of(context).size.width < 420;
    final leftGutter = isCompactWidth
        ? (20 * densityScale).clamp(12.0, 24.0).toDouble()
        : (32 * densityScale).clamp(16.0, 40.0).toDouble();
    final rightGutter = isCompactWidth
        ? (18 * densityScale).clamp(10.0, 22.0).toDouble()
        : (24 * densityScale).clamp(12.0, 32.0).toDouble();
    final itemCount = widget.items.length;
    final letterIndex = _buildLetterIndex(widget.items);
    final letters = letterIndex.keys.toList(growable: false);
    final alphaWidth = space(26).clamp(20.0, 32.0).toDouble();
    final alphaGap = space(6).clamp(4.0, 10.0).toDouble();
    final contentRightPadding =
        letters.isNotEmpty ? alphaWidth + alphaGap : 0.0;
    final titleStyle = density == LayoutDensity.sardine
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.titleMedium;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    final titleHeight = _textHeight(titleStyle);
    final subtitleHeight = _textHeight(subtitleStyle);
    // Keep these in sync with `LibraryListTile` to avoid sub-pixel overflow
    // when we size list rows via `SizedBox(height: listItemExtent)`.
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

    final contentPadding = EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: widget.title,
                subtitle: '$itemCount items',
              ),
              SizedBox(height: space(12)),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gridMetrics = _GridMetrics.fromWidth(
                width: constraints.maxWidth,
                itemAspectRatio: 1.05,
                itemMinWidth: space(190).clamp(150.0, 240.0),
                spacing: space(16),
              );
              final gap = space(6).clamp(4.0, 10.0);
              return Stack(
                children: [
                  CustomScrollView(
                    controller: _controller,
                    slivers: [
                      SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          leftGutter,
                          0,
                          rightGutter,
                          space(12),
                        ),
                        child: SegmentedButton<BrowseLayout>(
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
                                .setBrowseLayout(
                                  widget.view,
                                  selection.first,
                                );
                          },
                        ),
                      ),
                      ),
                      layout == BrowseLayout.grid
                          ? SliverPadding(
                              padding: listPadding,
                              sliver: SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => widget.gridItemBuilder(
                                    context,
                                    widget.items[index],
                                  ),
                                  childCount: widget.items.length,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: gridMetrics.columns,
                                  crossAxisSpacing: gridMetrics.spacing,
                                  mainAxisSpacing: gridMetrics.spacing,
                                  childAspectRatio: gridMetrics.aspectRatio,
                                ),
                              ),
                            )
                          : SliverPadding(
                              padding: listPadding,
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final item = widget.items[index];
                                    final child =
                                        widget.listItemBuilder(context, item);
                                    return Column(
                                      children: [
                                        child,
                                        if (index + 1 < widget.items.length)
                                          SizedBox(height: gap),
                                      ],
                                    );
                                  },
                                  childCount: widget.items.length,
                                ),
                              ),
                            ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: space(16)),
                      ),
                    ],
                  ),
                  if (letters.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 12,
                      bottom: 12,
                      child: AlphabetScroller(
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
                        useSubsampling: true,
                        baseWidth: 26,
                        minWidth: 20,
                        maxWidth: 32,
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
