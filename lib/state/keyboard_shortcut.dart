import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Serializable keyboard shortcut definition.
class KeyboardShortcut {
  /// Creates a keyboard shortcut.
  const KeyboardShortcut({
    required this.key,
    this.meta = false,
    this.control = false,
    this.alt = false,
    this.shift = false,
  });

  /// Primary key for the shortcut.
  final LogicalKeyboardKey key;

  /// True when the Meta/Cmd key is required.
  final bool meta;

  /// True when the Control key is required.
  final bool control;

  /// True when the Alt/Option key is required.
  final bool alt;

  /// True when the Shift key is required.
  final bool shift;

  /// Default shortcut: Cmd/Ctrl + comma.
  factory KeyboardShortcut.defaultForPlatform() {
    final isApple = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return KeyboardShortcut(
      key: LogicalKeyboardKey.comma,
      meta: isApple,
      control: !isApple,
    );
  }

  /// Serializes this shortcut for persistence.
  String serialize() {
    return [
      meta ? '1' : '0',
      control ? '1' : '0',
      alt ? '1' : '0',
      shift ? '1' : '0',
      key.keyId.toString(),
    ].join(',');
  }

  /// Parses a shortcut from storage.
  static KeyboardShortcut? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final parts = raw.split(',');
    if (parts.length != 5) {
      return null;
    }
    final meta = parts[0] == '1';
    final control = parts[1] == '1';
    final alt = parts[2] == '1';
    final shift = parts[3] == '1';
    final keyId = int.tryParse(parts[4]);
    if (keyId == null) {
      return null;
    }
    final key =
        LogicalKeyboardKey.findKeyByKeyId(keyId) ?? LogicalKeyboardKey(keyId);
    return KeyboardShortcut(
      key: key,
      meta: meta,
      control: control,
      alt: alt,
      shift: shift,
    );
  }

  /// Returns true when a primary modifier is present.
  bool get hasPrimaryModifier => meta || control || alt;

  /// Converts this shortcut into a Flutter key set.
  LogicalKeySet toKeySet() {
    final keys = <LogicalKeyboardKey>{
      key,
      if (meta) LogicalKeyboardKey.meta,
      if (control) LogicalKeyboardKey.control,
      if (alt) LogicalKeyboardKey.alt,
      if (shift) LogicalKeyboardKey.shift,
    };
    return LogicalKeySet.fromSet(keys);
  }

  /// Human-readable label for UI.
  String label() {
    final parts = <String>[];
    if (meta) {
      parts.add(
        defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.iOS
            ? 'Cmd'
            : 'Meta',
      );
    }
    if (control) {
      parts.add('Ctrl');
    }
    if (alt) {
      parts.add('Alt');
    }
    if (shift) {
      parts.add('Shift');
    }
    parts.add(_keyLabel());
    return parts.join(' + ');
  }

  String _keyLabel() {
    if (key == LogicalKeyboardKey.comma) {
      return ',';
    }
    if (key == LogicalKeyboardKey.period) {
      return '.';
    }
    final label = key.keyLabel;
    if (label.isNotEmpty) {
      if (label.trim().isEmpty) {
        return 'Space';
      }
      if (label.length == 1) {
        return label.toUpperCase();
      }
      return label;
    }
    final debugName = key.debugName ?? 'Key';
    return debugName.replaceAll('Left', '').replaceAll('Right', '').trim();
  }
}
