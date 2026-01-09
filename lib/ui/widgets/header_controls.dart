import 'package:flutter/material.dart';

import '../../core/color_tokens.dart';
import 'corner_radius.dart';

/// Circular button used in headers for navigation controls and search.
class HeaderControlButton extends StatelessWidget {
  const HeaderControlButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 36,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = context.scaledRadius(size);
    final color = onTap == null
        ? theme
            .colorScheme
            .onSurface
            .withValues(alpha: 0.38)
        : theme.colorScheme.onSurface;
    final background = theme.colorScheme.surfaceContainerHighest;
    return Material(
      type: MaterialType.transparency,
      child: Tooltip(
        message: tooltip ?? 'Back',
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: ColorTokens.border(context, 0.08),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Search button that sits in header rows.
class SearchCircleButton extends StatelessWidget {
  const SearchCircleButton({
    super.key,
    required this.onTap,
    this.tooltip = 'Search',
    this.size = 38,
  });

  final VoidCallback onTap;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = context.scaledRadius(size);
    return Material(
      type: MaterialType.transparency,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color:
                      theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              Icons.search,
              size: 18,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
