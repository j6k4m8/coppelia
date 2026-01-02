import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Defines the signature look and feel for Coppelia.
class CoppeliaTheme {
  CoppeliaTheme._();

  /// Default accent used when no override is set.
  static const Color defaultAccent = Color(0xFF6F7BFF);

  static const TextTheme _baseTextTheme = TextTheme(
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
    ),
  );

  static TextTheme _scaledTextTheme(double scale) =>
      _baseTextTheme.apply(fontSizeFactor: scale);

  static Color _tint(Color color, Brightness brightness, double amount) {
    final overlay = brightness == Brightness.dark
        ? Colors.black.withValues(alpha: amount)
        : Colors.white.withValues(alpha: amount);
    return Color.alphaBlend(overlay, color);
  }

  static CoppeliaPalette _defaultPalette(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const CoppeliaPalette(
        backgroundGradient: [
          Color(0xFF11131A),
          Color(0xFF151C2D),
          Color(0xFF0B0E14),
        ],
        heroGradient: [
          Color(0xFF1F2433),
          Color(0x0DFFFFFF),
        ],
      );
    }
    return const CoppeliaPalette(
      backgroundGradient: [
        Color(0xFFF7F8FC),
        Color(0xFFF1F3F8),
        Color(0xFFEFF2FA),
      ],
      heroGradient: [
        Color(0xFFFFFFFF),
        Color(0xFFF0F2F9),
      ],
    );
  }

  static CoppeliaPalette _paletteFromSeed(
    Brightness brightness,
    NowPlayingPalette palette,
  ) {
    final primary = palette.primary;
    final secondary = palette.secondary;
    final tertiary = palette.tertiary;
    final backgroundGradient = [
      _tint(primary, brightness, brightness == Brightness.dark ? 0.55 : 0.8),
      _tint(secondary, brightness, brightness == Brightness.dark ? 0.6 : 0.82),
      _tint(tertiary, brightness, brightness == Brightness.dark ? 0.7 : 0.9),
    ];
    final heroGradient = brightness == Brightness.dark
        ? [
            _tint(primary, brightness, 0.35),
            Colors.white.withValues(alpha: 0.04),
          ]
        : [
            Colors.white,
            _tint(primary, brightness, 0.86),
          ];
    return CoppeliaPalette(
      backgroundGradient: backgroundGradient,
      heroGradient: heroGradient,
    );
  }

  /// Dark, glassy theme tuned for macOS surfaces.
  static ThemeData darkTheme({
    String? fontFamily = 'SF Pro Display',
    double fontScale = 1.0,
    Color? accentColor,
    NowPlayingPalette? nowPlayingPalette,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor ?? defaultAccent,
      brightness: Brightness.dark,
      surface: const Color(0xFF15171C),
    );
    final palette = nowPlayingPalette == null
        ? _defaultPalette(Brightness.dark)
        : _paletteFromSeed(Brightness.dark, nowPlayingPalette);
    final textTheme = _scaledTextTheme(fontScale);

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0D0F14),
      fontFamily: fontFamily,
      useMaterial3: true,
      cardTheme: CardThemeData(
        color: const Color(0xFF161920).withValues(alpha: 0.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3.5,
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [palette],
    );
  }

  /// Light theme option with warm neutrals.
  static ThemeData lightTheme({
    String? fontFamily = 'SF Pro Display',
    double fontScale = 1.0,
    Color? accentColor,
    NowPlayingPalette? nowPlayingPalette,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor ?? defaultAccent,
      brightness: Brightness.light,
      surface: const Color(0xFFF5F6FA),
    );
    final palette = nowPlayingPalette == null
        ? _defaultPalette(Brightness.light)
        : _paletteFromSeed(Brightness.light, nowPlayingPalette);
    final textTheme = _scaledTextTheme(fontScale);

    return ThemeData(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      fontFamily: fontFamily,
      useMaterial3: true,
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3.5,
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [palette],
    );
  }
}
