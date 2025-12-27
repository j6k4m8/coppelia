import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/browse_layout.dart';
import '../../state/library_view.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final layout = state.browseLayoutFor(widget.view);
    final itemCount = widget.items.length;
    final letterIndex = _buildLetterIndex(widget.items);
    final letters = letterIndex.keys.toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: widget.title,
          action: Row(
            children: [
              Text(
                '$itemCount items',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white60),
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
                  state.setBrowseLayout(widget.view, selection.first);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gridMetrics = _GridMetrics.fromWidth(
                width: constraints.maxWidth,
                itemAspectRatio: 1.05,
              );
              return Stack(
                children: [
                  layout == BrowseLayout.grid
                      ? GridView.builder(
                          controller: _controller,
                          itemCount: widget.items.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridMetrics.columns,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: gridMetrics.aspectRatio,
                          ),
                          itemBuilder: (context, index) {
                            final item = widget.items[index];
                            return widget.gridItemBuilder(context, item);
                          },
                        )
                      : ListView.separated(
                          controller: _controller,
                          itemCount: widget.items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final item = widget.items[index];
                            return SizedBox(
                              height: _listItemExtent,
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
                              : targetIndex * _listItemExtent;
                          _controller.animateTo(
                            offset,
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOut,
                          );
                        },
                      ),
                    ),
                  Positioned(
                    right: 24,
                    bottom: 24,
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
    return Container(
      width: 28,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: letters.map((letter) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(letter),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                letter,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.white70),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GridMetrics {
  const _GridMetrics({
    required this.columns,
    required this.itemWidth,
    required this.itemHeight,
    required this.aspectRatio,
  });

  final int columns;
  final double itemWidth;
  final double itemHeight;
  final double aspectRatio;

  static _GridMetrics fromWidth({
    required double width,
    required double itemAspectRatio,
  }) {
    final crossAxisCount = (width / 220).floor().clamp(2, 6);
    final columns = crossAxisCount;
    final spacing = 16 * (columns - 1);
    final itemWidth = (width - spacing) / columns;
    final itemHeight = itemWidth / itemAspectRatio;
    return _GridMetrics(
      columns: columns,
      itemWidth: itemWidth,
      itemHeight: itemHeight,
      aspectRatio: itemAspectRatio,
    );
  }

  double offsetForIndex(int index) {
    final row = (index / columns).floor();
    return row * (itemHeight + 16);
  }
}
