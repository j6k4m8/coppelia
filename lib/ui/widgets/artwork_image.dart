import 'package:flutter/material.dart';

/// Lightweight artwork loader with a simple error fallback.
class ArtworkImage extends StatelessWidget {
  /// Creates an artwork image.
  const ArtworkImage({
    super.key,
    required this.imageUrl,
    required this.placeholder,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  /// Remote image URL.
  final String? imageUrl;

  /// Widget displayed when loading fails or URL is missing.
  final Widget placeholder;

  /// Optional width.
  final double? width;

  /// Optional height.
  final double? height;

  /// How to inscribe the image into the space.
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return placeholder;
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}
