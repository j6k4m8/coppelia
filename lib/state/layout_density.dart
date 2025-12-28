import 'package:flutter/material.dart';

/// Density options for spacing and padding.
enum LayoutDensity {
  /// Tight, compact spacing.
  sardine,

  /// Default spacing.
  comfortable,

  /// Relaxed, spacious spacing.
  spacious,
}

extension LayoutDensityMeta on LayoutDensity {
  /// Label for UI.
  String get label {
    switch (this) {
      case LayoutDensity.sardine:
        return 'Sardinemode';
      case LayoutDensity.comfortable:
        return 'Comfortable';
      case LayoutDensity.spacious:
        return 'Spacious';
    }
  }

  /// Scale factor for padding/spacing.
  double get scale {
    switch (this) {
      case LayoutDensity.sardine:
        return 0.5;
      case LayoutDensity.comfortable:
        return 1.0;
      case LayoutDensity.spacious:
        return 1.4;
    }
  }

  /// Scale factor as a double for layout sizing.
  double get scaleDouble => scale;
}

extension EdgeInsetsScale on EdgeInsets {
  /// Returns a scaled copy of this padding.
  EdgeInsets scale(double factor) {
    return EdgeInsets.fromLTRB(
      left * factor,
      top * factor,
      right * factor,
      bottom * factor,
    );
  }
}
