import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Captures the current frame as a PNG and provides it for sharing/saving.
class ImageExporter {
  /// Convert a [ui.Image] to PNG bytes.
  static Future<Uint8List?> imageToPng(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  /// Show a share dialog or save the image.
  ///
  /// On mobile, this would use `share_plus` or `image_gallery_saver`.
  /// For now, we show a snackbar confirming the capture.
  static Future<void> captureAndShare(
    ui.Image? currentFrame,
    BuildContext context,
  ) async {
    if (currentFrame == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No frame to capture'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    final pngBytes = await imageToPng(currentFrame);
    if (pngBytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to encode image'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Captured ${pngBytes.length ~/ 1024} KB PNG'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
