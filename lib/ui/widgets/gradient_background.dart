import 'package:flutter/material.dart';

/// Branded gradient backdrop for immersive surfaces.
class GradientBackground extends StatelessWidget {
  /// Creates a gradient wrapper.
  const GradientBackground({super.key, required this.child});

  /// Widget layered above the gradient.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF11131A),
            Color(0xFF151C2D),
            Color(0xFF0B0E14),
          ],
        ),
      ),
      child: child,
    );
  }
}
