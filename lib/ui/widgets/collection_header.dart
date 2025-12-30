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
    this.actions = const [],
    this.actionSpecs = const [],
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

  /// Preferred action model for consistent responsive rendering.
  ///
  /// When provided, these actions will be rendered instead of [actions].
  /// This avoids brittle widget introspection (which can lead to wrong icons
  /// like the ellipsis fallback).
  final List<HeaderActionSpec> actionSpecs;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
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
          final iconOnlyActions = constraints.maxWidth < 420;

          List<Widget> effectiveActions(List<Widget> raw) {
            if (!iconOnlyActions) {
              return raw;
            }

            // Important: don't attempt to "guess" icons from arbitrary widgets.
            // If we can't confidently extract an icon, keep the widget as-is.
            return raw.map(
              (widget) {
                final converted = _iconOnlyFromButtonOrNull(widget);
                if (converted == null) {
                  return widget;
                }
                return Tooltip(
                  message: _tooltipForAction(widget),
                  child: converted,
                );
              },
            ).toList(growable: false);
          }

          final resolvedActions = actionSpecs.isNotEmpty
              ? buildActionsFromSpecs(
                  context,
                  actionSpecs,
                  iconOnly: iconOnlyActions,
                  densityScale: densityScale,
                )
              : effectiveActions(actions);

          final artworkSize = clamped(isNarrow ? 160 : 140, min: 110, max: 190);
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
                children: resolvedActions,
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

  static String _tooltipForAction(Widget widget) {
    if (widget is OutlinedButton) {
      return _tooltipTextFromChild(widget.child) ?? 'Action';
    }
    if (widget is FilledButton) {
      return _tooltipTextFromChild(widget.child) ?? 'Action';
    }
    if (widget is IconButton) {
      return widget.tooltip ?? 'Action';
    }
    return 'Action';
  }

  static String? _tooltipTextFromChild(Widget? child) {
    final resolved = _unwrap(child);
    if (resolved is Text) {
      return resolved.data;
    }
    if (resolved is Row) {
      for (final entry in resolved.children) {
        final unwrapped = _unwrap(entry);
        if (unwrapped is Text) {
          return unwrapped.data;
        }
      }
    }
    return null;
  }

  static Widget? _iconOnlyFromButtonOrNull(Widget widget) {
    if (widget is OutlinedButton) {
      final icon = _iconFromButtonChild(widget.child);
      if (icon == null) return null;
      return IconButton.outlined(
        onPressed: widget.onPressed,
        icon: icon,
      );
    }
    if (widget is FilledButton) {
      final icon = _iconFromButtonChild(widget.child);
      if (icon == null) return null;
      return IconButton.filledTonal(
        onPressed: widget.onPressed,
        icon: icon,
      );
    }
    return null;
  }

  static Widget? _iconFromButtonChild(Widget? child) {
    final resolved = _unwrap(child);
    if (resolved is Icon) {
      return resolved;
    }
    if (resolved is Row) {
      for (final entry in resolved.children) {
        final unwrapped = _unwrap(entry);
        if (unwrapped is Icon) {
          return unwrapped;
        }
      }
    }
    return null;
  }

  static Widget? _unwrap(Widget? widget) {
    Widget? current = widget;
    for (var i = 0; i < 6; i++) {
      if (current is SizedBox) {
        current = current.child;
        continue;
      }
      if (current is Padding) {
        current = current.child;
        continue;
      }
      if (current is Center) {
        current = current.child;
        continue;
      }
      if (current is IconTheme) {
        current = current.child;
        continue;
      }
      break;
    }
    return current;
  }

  static List<Widget> buildActionsFromSpecs(
    BuildContext context,
    List<HeaderActionSpec> specs, {
    required bool iconOnly,
    required double densityScale,
  }) {
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);

    Widget iconOnlyButton(HeaderActionSpec spec) {
      final iconWidget = Icon(spec.icon);
      final button = spec.outlined
          ? IconButton.outlined(
              key: spec.iconKey,
              onPressed: spec.onPressed,
              icon: iconWidget,
              iconSize: clamped(22, min: 18, max: 24),
              padding: EdgeInsets.all(space(10).clamp(8.0, 12.0)),
            )
          : spec.tonal
              ? IconButton.filledTonal(
                  key: spec.iconKey,
                  onPressed: spec.onPressed,
                  icon: iconWidget,
                  iconSize: clamped(22, min: 18, max: 24),
                  padding: EdgeInsets.all(space(10).clamp(8.0, 12.0)),
                )
              : IconButton.filled(
                  key: spec.iconKey,
                  onPressed: spec.onPressed,
                  icon: iconWidget,
                  iconSize: clamped(22, min: 18, max: 24),
                  padding: EdgeInsets.all(space(10).clamp(8.0, 12.0)),
                );

      final tooltip = spec.tooltip ?? spec.label;
      return Tooltip(message: tooltip, child: button);
    }

    Widget expandedButton(HeaderActionSpec spec) {
      if (spec.outlined) {
        return OutlinedButton.icon(
          onPressed: spec.onPressed,
          icon: Icon(spec.icon),
          label: Text(spec.label),
        );
      }
      if (spec.tonal) {
        return FilledButton.tonalIcon(
          onPressed: spec.onPressed,
          icon: Icon(spec.icon),
          label: Text(spec.label),
        );
      }
      return FilledButton.icon(
        onPressed: spec.onPressed,
        icon: Icon(spec.icon),
        label: Text(spec.label),
      );
    }

    return specs
        .map((spec) => iconOnly ? iconOnlyButton(spec) : expandedButton(spec))
        .toList(growable: false);
  }
}

/// Explicit header action description for consistent icon-only rendering.
class HeaderActionSpec {
  const HeaderActionSpec({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.iconKey,
    this.tonal = false,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Key? iconKey;
  final bool tonal;
  final bool outlined;
}
