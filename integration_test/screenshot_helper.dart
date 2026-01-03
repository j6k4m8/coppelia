import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Captures a screenshot by rendering the provided [RepaintBoundary].
Future<Uint8List> captureScreenshot(
  GlobalKey rootKey, {
  required double pixelRatio,
}) async {
  final boundary =
      rootKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) {
    throw StateError('Unable to locate the screenshot boundary.');
  }
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    throw StateError('Failed to encode screenshot.');
  }
  return bytes.buffer.asUint8List();
}
