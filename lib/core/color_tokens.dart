import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Shared color helpers for light/dark surfaces.
class ColorTokens {
  /// Gradient colors for the app background.
  static List<Color> backgroundGradient(BuildContext context) {
    final palette = Theme.of(context).extension<CoppeliaPalette>();
    if (palette != null) {
      return palette.backgroundGradient;
    }
    if (Theme.of(context).brightness == Brightness.dark) {
      return const [
        Color(0xFF11131A),
        Color(0xFF151C2D),
        Color(0xFF0B0E14),
      ];
    }
    return const [
      Color(0xFFF7F8FC),
      Color(0xFFF1F3F8),
      Color(0xFFEFF2FA),
    ];
  }

  /// Background for app side panels.
  static Color panelBackground(BuildContext context) {
    final palette = Theme.of(context).extension<CoppeliaPalette>();
    if (palette != null && palette.backgroundGradient.isNotEmpty) {
      final gradient = palette.backgroundGradient;
      return gradient.length > 1 ? gradient[1] : gradient.first;
    }
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0F1218)
        : const Color(0xFFF4F5FA);
  }

  /// Divider/border tone.
  static Color border(BuildContext context, [double opacity = 0.08]) {
    return Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: opacity);
  }

  /// Card fill for tiles.
  static Color cardFill(BuildContext context, [double opacity = 0.05]) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.white.withValues(alpha: opacity)
        : Colors.black.withValues(alpha: opacity * 0.9);
  }

  /// Stronger card fill for artwork placeholders.
  static Color cardFillStrong(BuildContext context, [double opacity = 0.08]) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.white.withValues(alpha: opacity)
        : Colors.black.withValues(alpha: opacity * 0.9);
  }

  /// Primary text tone.
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  /// Secondary text tone.
  static Color textSecondary(BuildContext context, [double opacity = 0.6]) {
    return Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: opacity);
  }

  /// Active row highlight.
  static Color activeRow(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
  }

  /// Hover row highlight.
  static Color hoverRow(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
  }

  /// Section header background gradient.
  static List<Color> heroGradient(BuildContext context) {
    final palette = Theme.of(context).extension<CoppeliaPalette>();
    if (palette != null) {
      return palette.heroGradient;
    }
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      return [
        const Color(0xFF1F2433),
        Colors.white.withValues(alpha: 0.03),
      ];
    }
    return const [
      Color(0xFFFFFFFF),
      Color(0xFFF0F2F9),
    ];
  }
}
