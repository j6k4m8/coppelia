/// Corner radius styles for rounded UI elements.
enum CornerRadiusStyle {
  babyProofed,
  traditional,
  pointy,
}

extension CornerRadiusStyleX on CornerRadiusStyle {
  String get label {
    switch (this) {
      case CornerRadiusStyle.babyProofed:
        return 'Baby-proofed';
      case CornerRadiusStyle.traditional:
        return 'Traditional';
      case CornerRadiusStyle.pointy:
        return 'Pointy';
    }
  }

  double get scale {
    switch (this) {
      case CornerRadiusStyle.babyProofed:
        return 1.0;
      case CornerRadiusStyle.traditional:
        return 0.45;
      case CornerRadiusStyle.pointy:
        return 0.0;
    }
  }

  String get storageKey => name;

  static CornerRadiusStyle? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    for (final value in CornerRadiusStyle.values) {
      if (value.storageKey == raw) {
        return value;
      }
    }
    return null;
  }
}
