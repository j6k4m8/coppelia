import 'package:flutter/material.dart';

import '../../core/color_tokens.dart';

/// Draggable handle to resize the sidebar width.
class SidebarResizeHandle extends StatelessWidget {
  /// Creates the resize handle.
  const SidebarResizeHandle({
    super.key,
    required this.onDragUpdate,
    this.onDragEnd,
  });

  /// Callback with horizontal drag delta.
  final ValueChanged<double> onDragUpdate;

  /// Callback when the drag ends.
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) => onDragUpdate(details.delta.dx),
      onHorizontalDragEnd: (_) => onDragEnd?.call(),
      child: Container(
        width: 4,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              ColorTokens.border(context, 0.12),
            ],
          ),
        ),
      ),
    );
  }
}
