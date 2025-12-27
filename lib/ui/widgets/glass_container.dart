import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/color_tokens.dart';

/// Frosted glass container for elevated panels.
class GlassContainer extends StatelessWidget {
  /// Creates a glass container.
  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
  });

  /// Panel content.
  final Widget child;

  /// Interior padding.
  final EdgeInsets padding;

  /// Corner radius.
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: ColorTokens.cardFill(context, 0.08),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: ColorTokens.border(context),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
