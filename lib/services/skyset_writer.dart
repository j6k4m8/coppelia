import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_palette.dart';

class SkysetPayload {
  const SkysetPayload({
    required this.path,
    required this.origin,
    required this.updatedAt,
    required this.message,
    required this.submessage,
    required this.sourceWillUpdate,
    required this.themeMode,
    required this.brightness,
    required this.accentColor,
    required this.palette,
    required this.backgroundGradient,
    required this.heroGradient,
  });

  final String path;
  final String origin;
  final DateTime updatedAt;
  final String message;
  final String submessage;
  final bool sourceWillUpdate;
  final ThemeMode themeMode;
  final Brightness brightness;
  final Color accentColor;
  final NowPlayingPalette palette;
  final List<Color> backgroundGradient;
  final List<Color> heroGradient;
}

class SkysetWriter {
  static const int schemaVersion = 1;

  Future<void> write(SkysetPayload payload) async {
    final resolvedPath = _resolveSkysetPath(_expandPath(payload.path));
    if (resolvedPath.isEmpty) {
      return;
    }
    final file = File(resolvedPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(_serialize(payload));
  }

  static SkysetPalette buildPalette({
    required Brightness brightness,
    required NowPlayingPalette palette,
  }) {
    final backgroundGradient = [
      _tint(
        palette.primary,
        brightness,
        brightness == Brightness.dark ? 0.55 : 0.8,
      ),
      _tint(
        palette.secondary,
        brightness,
        brightness == Brightness.dark ? 0.6 : 0.82,
      ),
      _tint(
        palette.tertiary,
        brightness,
        brightness == Brightness.dark ? 0.7 : 0.9,
      ),
    ];
    final heroGradient = brightness == Brightness.dark
        ? [
            _tint(palette.primary, brightness, 0.35),
            Colors.white.withValues(alpha: 0.04),
          ]
        : [
            Colors.white,
            _tint(palette.primary, brightness, 0.86),
          ];
    return SkysetPalette(
      backgroundGradient: backgroundGradient,
      heroGradient: heroGradient,
    );
  }

  String _serialize(SkysetPayload payload) {
    final lines = <String>[
      '_version: $schemaVersion',
      'origin: ${_yamlString(payload.origin)}',
      'updated_at: ${_yamlString(payload.updatedAt.toUtc().toIso8601String())}',
      'message: ${_yamlString(payload.message)}',
      'submessage: ${_yamlString(payload.submessage)}',
      'source_will_update: ${payload.sourceWillUpdate ? 'true' : 'false'}',
      'theme:',
      '  mode: ${_yamlString(_themeModeLabel(payload.themeMode))}',
      '  brightness: ${_yamlString(_brightnessLabel(payload.brightness))}',
      '  accent: ${_yamlString(_hex(payload.accentColor))}',
      'palette:',
      '  primary: ${_yamlString(_hex(payload.palette.primary))}',
      '  secondary: ${_yamlString(_hex(payload.palette.secondary))}',
      '  tertiary: ${_yamlString(_hex(payload.palette.tertiary))}',
      'gradients:',
      '  background:',
      for (final color in payload.backgroundGradient)
        '    - ${_yamlString(_hex(color))}',
      '  hero:',
      for (final color in payload.heroGradient)
        '    - ${_yamlString(_hex(color))}',
    ];
    return lines.join('\n');
  }

  String _expandPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (!trimmed.startsWith('~')) {
      return trimmed;
    }
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (home.isEmpty) {
      return trimmed;
    }
    if (trimmed == '~') {
      return home;
    }
    if (trimmed.startsWith('~/')) {
      return '$home/${trimmed.substring(2)}';
    }
    return trimmed.replaceFirst('~', home);
  }

  String _resolveSkysetPath(String path) {
    if (path.isEmpty) {
      return '';
    }
    final separator = Platform.pathSeparator;
    final trimmed = path.endsWith(separator)
        ? path.substring(0, path.length - 1)
        : path;
    final lower = trimmed.toLowerCase();
    if (lower.endsWith('.yml') || lower.endsWith('.yaml')) {
      return trimmed;
    }
    return '$trimmed${separator}latest.yml';
  }

  static Color _tint(Color color, Brightness brightness, double amount) {
    final overlay = brightness == Brightness.dark
        ? Colors.black.withValues(alpha: amount)
        : Colors.white.withValues(alpha: amount);
    return Color.alphaBlend(overlay, color);
  }

  String _hex(Color color) {
    final value = color.value.toRadixString(16).padLeft(8, '0');
    return '#${value.substring(2).toUpperCase()}';
  }

  String _yamlString(String value) => jsonEncode(value);

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }

  String _brightnessLabel(Brightness brightness) {
    return brightness == Brightness.dark ? 'dark' : 'light';
  }
}

class SkysetPalette {
  const SkysetPalette({
    required this.backgroundGradient,
    required this.heroGradient,
  });

  final List<Color> backgroundGradient;
  final List<Color> heroGradient;
}
