import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Creates placeholder images using decodeImageFromPixels.
///
/// This avoids Picture.toImage/toImageSync entirely, which have
/// Impeller compatibility issues on iOS physical devices.
class ImageHelper {
  /// Create a transparent placeholder image from raw pixel data.
  /// No Picture/PictureRecorder involved — works with Impeller.
  static Future<ui.Image> createPlaceholder(int w, int h) {
    final completer = Completer<ui.Image>();
    final bytes = Uint8List(w * h * 4); // RGBA, all zeros = transparent black
    ui.decodeImageFromPixels(
      bytes,
      w,
      h,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}
