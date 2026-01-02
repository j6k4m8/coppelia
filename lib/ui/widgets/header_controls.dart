import 'package:flutter/material.dart';

import '../../core/color_tokens.dart';

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
    final color = onTap == null
        ? theme.colorScheme.onSurface.withOpacity(0.38)
        : theme.colorScheme.onSurface;
    final background = theme.colorScheme.surfaceVariant;
    return Material(
      type: MaterialType.transparency,
      child: Tooltip(
        message: tooltip ?? 'Back',
        child: InkWell(
          borderRadius: BorderRadius.circular(size),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(size),
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
    return Material(
      type: MaterialType.transparency,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(size),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(size),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
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
