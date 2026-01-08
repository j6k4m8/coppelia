import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';

class AlphabetScroller extends StatelessWidget {
  const AlphabetScroller({
    super.key,
    required this.letters,
    required this.onSelected,
    this.selected,
    this.useSubsampling = false,
    this.scrollable = false,
    this.baseWidth = 26,
    this.minWidth = 20,
    this.maxWidth = 32,
  });

  final List<String> letters;
  final ValueChanged<String> onSelected;
  final String? selected;
  final bool useSubsampling;
  final bool scrollable;
  final double baseWidth;
  final double minWidth;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final slotHeight = space(18).clamp(14.0, 22.0);

    Widget buildColumn(List<String> displayLetters) {
      final children = displayLetters
          .map(
            (letter) => SizedBox(
              height: slotHeight,
              child: _AlphabetLetter(
                letter: letter,
                selected: selected == letter,
                onTap: () => onSelected(letter),
              ),
            ),
          )
          .toList();
      if (scrollable && !useSubsampling) {
        return SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
        );
      }
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      );
    }

    Widget buildContainer(Widget child) {
      return Container(
        width: space(baseWidth).clamp(minWidth, maxWidth),
        padding: EdgeInsets.symmetric(vertical: space(8)),
        decoration: BoxDecoration(
          color: ColorTokens.cardFill(context, 0.04),
          borderRadius: BorderRadius.circular(
            space(20).clamp(14.0, 24.0),
          ),
          border: Border.all(color: ColorTokens.border(context)),
        ),
        child: child,
      );
    }

    if (useSubsampling) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final maxSlots = ((constraints.maxHeight - space(16)) / slotHeight)
              .floor()
              .clamp(1, letters.length);
          final displayLetters = _subsampleLetters(letters, maxSlots);
          return buildContainer(buildColumn(displayLetters));
        },
      );
    }

    return buildContainer(buildColumn(letters));
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
    required this.selected,
  });

  final String letter;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final baseStyle = Theme.of(context).textTheme.labelSmall;
    return TextButton(
      onPressed: onTap,
      style: ButtonStyle(
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        minimumSize: WidgetStateProperty.all(Size(space(20), space(20))),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (selected) {
            return Theme.of(context).colorScheme.primary;
          }
          if (states.contains(WidgetState.hovered)) {
            return ColorTokens.textPrimary(context);
          }
          return ColorTokens.textSecondary(context, 0.7);
        }),
        textStyle: WidgetStateProperty.all(baseStyle),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return ColorTokens.cardFill(context, 0.08);
          }
          return Colors.transparent;
        }),
      ),
      child: Text(letter),
    );
  }
}
