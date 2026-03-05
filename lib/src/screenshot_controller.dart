import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Controls screenshot capture for the wrapped widget tree.
///
/// Uses a [RepaintBoundary] with a [GlobalKey] to capture the current
/// rendered frame as a PNG image.
///
/// This controller is used internally by [ScreenshotServer], but can also
/// be used standalone:
///
/// ```dart
/// final controller = ScreenshotController();
///
/// // Wrap your widget
/// RepaintBoundary(
///   key: controller.boundaryKey,
///   child: MyApp(),
/// );
///
/// // Capture screenshot
/// final pngBytes = await controller.capture();
/// ```
class ScreenshotController {
  /// The [GlobalKey] to attach to a [RepaintBoundary] widget.
  final GlobalKey boundaryKey = GlobalKey();

  /// Captures the current state of the widget tree wrapped by the
  /// [RepaintBoundary] identified by [boundaryKey].
  ///
  /// [pixelRatio] controls the resolution of the captured image.
  /// Defaults to 1.0. Use higher values (e.g. 2.0, 3.0) for
  /// higher resolution screenshots.
  ///
  /// Returns PNG-encoded bytes of the screenshot, or `null` if the
  /// boundary is not yet rendered.
  Future<Uint8List?> capture({double pixelRatio = 1.0}) async {
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;

    if (boundary == null) {
      return null;
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      return null;
    }

    return byteData.buffer.asUint8List();
  }
}
