import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'artwork_image.dart';

/// Shared hero header for playlist-like detail views.
class CollectionHeader extends StatelessWidget {
  /// Creates a collection header.
  const CollectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.fallbackIcon,
    required this.actions,
  });

  /// Title text.
  final String title;

  /// Subtitle text.
  final String subtitle;

  /// Optional artwork image URL.
  final String? imageUrl;

  /// Icon for the artwork fallback block.
  final IconData fallbackIcon;

  /// Action widgets displayed under the subtitle.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final densityScale =
        context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    Widget buildArtworkFallback(bool isNarrow) => Container(
          width: clamped(isNarrow ? 160 : 140, min: 110, max: 190),
          height: clamped(isNarrow ? 160 : 140, min: 110, max: 190),
          color: ColorTokens.cardFillStrong(context),
          child: Icon(
            fallbackIcon,
            size: clamped(36, min: 26, max: 42),
          ),
        );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(space(24).clamp(14.0, 32.0)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ColorTokens.heroGradient(context),
        ),
        borderRadius: BorderRadius.circular(
          clamped(26, min: 16, max: 30),
        ),
        border: Border.all(color: ColorTokens.border(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;
          final artworkSize =
              clamped(isNarrow ? 160 : 140, min: 110, max: 190);
          final artwork = ClipRRect(
            borderRadius: BorderRadius.circular(
              clamped(20, min: 12, max: 24),
            ),
            child: ArtworkImage(
              imageUrl: imageUrl,
              width: artworkSize,
              height: artworkSize,
              fit: BoxFit.cover,
              placeholder: buildArtworkFallback(isNarrow),
            ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: space(8)),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: ColorTokens.textSecondary(context)),
              ),
              SizedBox(height: space(16)),
              Wrap(
                spacing: space(12),
                runSpacing: space(8),
                children: actions,
              ),
            ],
          );
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                artwork,
                SizedBox(height: space(20)),
                details,
              ],
            );
          }
          return Row(
            children: [
              artwork,
              SizedBox(width: space(24)),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}
