import 'package:flutter/material.dart';

/// Shows a contextual menu at the given pointer location.
Future<T?> showContextMenu<T>(
  BuildContext context,
  Offset position,
  List<PopupMenuEntry<T>> items,
) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  final bounds = overlay?.size ?? const Size(1000, 1000);
  return showMenu<T>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(position, position),
      Offset.zero & bounds,
    ),
    items: items,
  );
}
