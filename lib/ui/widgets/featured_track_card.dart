import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../core/color_tokens.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'media_card.dart';

/// Prominent card for spotlight tracks.
class FeaturedTrackCard extends StatelessWidget {
  /// Creates a featured track card.
  const FeaturedTrackCard({
    super.key,
    required this.track,
    required this.onTap,
    this.onArtistTap,
    this.layout = MediaCardLayout.horizontal,
    this.artAspectRatio,
    this.expand = false,
  });

  /// Track to display.
  final MediaItem track;

  /// Tap handler.
  final VoidCallback onTap;

  /// Optional handler for tapping the artist label.
  final VoidCallback? onArtistTap;

  /// Card layout style.
  final MediaCardLayout layout;

  /// Optional artwork aspect ratio for vertical layouts.
  final double? artAspectRatio;

  /// When true, allow the card to fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final useSingleTap = !kIsWeb &&
        (Platform.isIOS || Platform.isAndroid || Platform.isFuchsia);
    final densityScale =
        context.select((AppState state) => state.layoutDensity.scaleDouble);
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    final cardWidth = expand || layout == MediaCardLayout.vertical
        ? null
        : clamped(260, min: 170, max: 300);
    return MediaCard(
      layout: layout,
      title: track.title,
      subtitle: track.subtitle,
      imageUrl: track.imageUrl,
      fallbackIcon: Icons.music_note,
      onTap: useSingleTap ? onTap : null,
      onDoubleTap: useSingleTap ? null : onTap,
      onSubtitleTap: onArtistTap,
      width: cardWidth,
      artAspectRatio:
          layout == MediaCardLayout.vertical ? artAspectRatio : null,
      backgroundGradient: LinearGradient(
        colors: [
          ColorTokens.cardFill(context, 0.1),
          ColorTokens.cardFill(context, 0.04),
        ],
      ),
      borderRadius: clamped(24, min: 14, max: 28),
    );
  }
}
