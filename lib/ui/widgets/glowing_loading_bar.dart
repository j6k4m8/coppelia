import 'package:flutter/material.dart';

/// A subtle glowing bar that indicates background buffering.
class GlowingLoadingBar extends StatefulWidget {
  /// Creates the loading bar.
  const GlowingLoadingBar({super.key, required this.isVisible});

  /// Whether the bar should be shown.
  final bool isVisible;

  @override
  State<GlowingLoadingBar> createState() => _GlowingLoadingBarState();
}

class _GlowingLoadingBarState extends State<GlowingLoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: SizedBox(
        height: widget.isVisible ? 6 : 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TickerMode(
            enabled: widget.isVisible,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final shimmerPosition = _controller.value * 2 - 1;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1 + shimmerPosition, 0),
                      end: Alignment(1 + shimmerPosition, 0),
                      colors: [
                        Colors.transparent,
                        Theme.of(context).colorScheme.primary.withOpacity(0.4),
                        Theme.of(context).colorScheme.primary.withOpacity(0.8),
                        Theme.of(context).colorScheme.primary.withOpacity(0.4),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.35),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
