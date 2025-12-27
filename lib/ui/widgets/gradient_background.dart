import 'package:flutter/material.dart';

import '../../core/color_tokens.dart';

/// Branded gradient backdrop for immersive surfaces.
class GradientBackground extends StatelessWidget {
  /// Creates a gradient wrapper.
  const GradientBackground({super.key, required this.child});

  /// Widget layered above the gradient.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ColorTokens.backgroundGradient(context),
        ),
      ),
      child: child,
    );
  }
}
