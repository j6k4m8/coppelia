import 'package:flutter/material.dart';

/// Slightly tightened switch used across settings toggles.
class CompactSwitch extends StatelessWidget {
  /// Creates a compact switch.
  const CompactSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Current switch value.
  final bool value;

  /// Callback when the value changes.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.82,
      child: Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
