import 'package:flutter/material.dart';

import '../../core/color_tokens.dart';

/// Standardized artwork placeholder for missing images.
class ArtworkFallback extends StatelessWidget {
  const ArtworkFallback({
    super.key,
    required this.icon,
    this.iconSize,
    this.width,
    this.height,
    this.backgroundColor,
  });

  final IconData icon;
  final double? iconSize;
  final double? width;
  final double? height;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? ColorTokens.cardFillStrong(context),
      child: Center(
        child: Icon(icon, size: iconSize),
      ),
    );
  }
}
