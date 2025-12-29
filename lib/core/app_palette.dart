import 'package:flutter/material.dart';

/// Base colors extracted from now playing artwork.
@immutable
class NowPlayingPalette {
  /// Creates a palette from dominant artwork colors.
  const NowPlayingPalette({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  /// Dominant artwork color.
  final Color primary;

  /// Supporting artwork color.
  final Color secondary;

  /// Additional artwork color for gradients.
  final Color tertiary;
}

/// Theme extension that carries gradient colors.
@immutable
class CoppeliaPalette extends ThemeExtension<CoppeliaPalette> {
  /// Creates a palette extension.
  const CoppeliaPalette({
    required this.backgroundGradient,
    required this.heroGradient,
  });

  /// Background gradient colors.
  final List<Color> backgroundGradient;

  /// Hero/header gradient colors.
  final List<Color> heroGradient;

  @override
  CoppeliaPalette copyWith({
    List<Color>? backgroundGradient,
    List<Color>? heroGradient,
  }) {
    return CoppeliaPalette(
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      heroGradient: heroGradient ?? this.heroGradient,
    );
  }

  @override
  CoppeliaPalette lerp(ThemeExtension<CoppeliaPalette>? other, double t) {
    if (other is! CoppeliaPalette) {
      return this;
    }
    Color lerpColor(int index, List<Color> colors) {
      final otherColor = other.backgroundGradient.length > index
          ? other.backgroundGradient[index]
          : other.backgroundGradient.last;
      return Color.lerp(colors[index], otherColor, t) ?? colors[index];
    }

    Color lerpHero(int index, List<Color> colors) {
      final otherColor = other.heroGradient.length > index
          ? other.heroGradient[index]
          : other.heroGradient.last;
      return Color.lerp(colors[index], otherColor, t) ?? colors[index];
    }

    final bg = backgroundGradient
        .asMap()
        .entries
        .map((entry) => lerpColor(entry.key, backgroundGradient))
        .toList();
    final hero = heroGradient
        .asMap()
        .entries
        .map((entry) => lerpHero(entry.key, heroGradient))
        .toList();
    return CoppeliaPalette(
      backgroundGradient: bg,
      heroGradient: hero,
    );
  }
}
