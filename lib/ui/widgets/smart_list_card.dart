import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/smart_list.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'media_card.dart';
import 'play_overlay_button.dart';

/// Artwork tile for a Smart List.
class SmartListCard extends StatelessWidget {
  /// Creates a Smart List card.
  const SmartListCard({
    super.key,
    required this.smartList,
    required this.onTap,
    this.onPlay,
  });

  /// Smart List metadata.
  final SmartList smartList;

  /// Tap handler.
  final VoidCallback onTap;

  /// Optional handler to play the list.
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final densityScale =
        context.select((AppState state) => state.layoutDensity.scaleDouble);
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    return MediaCard(
      layout: MediaCardLayout.vertical,
      title: smartList.name,
      subtitle: 'Smart list',
      imageUrl: null,
      fallbackIcon: Icons.auto_awesome,
      onTap: onTap,
      width: clamped(200, min: 130, max: 240),
      artOverlay: onPlay == null ? null : PlayOverlayButton(onTap: onPlay!),
    );
  }
}
