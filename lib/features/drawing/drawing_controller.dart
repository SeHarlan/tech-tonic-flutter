import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/rendering/render_state.dart';

/// Paint modes matching the JS mode encoding.
///
/// R channel: move/shuffle
/// G channel: waterfall/trickle
/// B channel: freeze/reset
enum PaintMode {
  waterfall,
  waterfallUp,
  trickle,
  move,
  moveLeft,
  shuffle,
  freeze,
  reset,
  resetEmpty,
  resetStatic,
  resetGem,
  erase,
}

/// Encodes a [PaintMode] into RGB channel values matching the GLSL
/// draw-buffer decoding.
({double r, double g, double b, bool writeR, bool writeG, bool writeB, bool clearB}) encodePaintMode(PaintMode mode) {
  double r = 0, g = 0, b = 0;
  bool writeR = false, writeG = false, writeB = false, clearB = false;

  switch (mode) {
    case PaintMode.shuffle:
      r = 0.375;
      writeR = true;
    case PaintMode.move:
      r = 0.625;
      writeR = true;
    case PaintMode.moveLeft:
      r = 0.875;
      writeR = true;
    case PaintMode.trickle:
      g = 0.375;
      writeG = true;
    case PaintMode.waterfall:
      g = 0.625;
      writeG = true;
    case PaintMode.waterfallUp:
      g = 0.875;
      writeG = true;
    case PaintMode.freeze:
      b = 0.375;
      writeB = true;
    case PaintMode.reset:
      b = 0.53125;
      writeB = true;
      clearB = false;
    case PaintMode.resetEmpty:
      b = 0.59375;
      writeB = true;
    case PaintMode.resetStatic:
      b = 0.65625;
      writeB = true;
    case PaintMode.resetGem:
      b = 0.71875;
      writeB = true;
    case PaintMode.erase:
      break;
  }

  return (r: r, g: g, b: b, writeR: writeR, writeG: writeG, writeB: writeB, clearB: clearB);
}

/// Manages drawing state and renders brush strokes to the draw buffer.
///
/// Uses Flutter Canvas API (not the draw shader) to composite brush strokes
/// onto the draw buffer. This avoids Impeller compatibility issues with
/// Picture.toImage when custom shader samplers are involved.
class DrawingController {
  PaintMode currentMode = PaintMode.waterfall;
  double brushRadius = 40.0;
  bool squareMode = false;

  late List<double> brushSizeOptions;
  int brushSizeIndex = 4;

  /// Pending stroke points queued by touch events, rendered on next frame.
  final List<Offset> _pendingPoints = [];
  bool _isRendering = false;

  DrawingController() {
    brushSizeOptions = generateBrushSizeOptions(400.0);
    brushSizeIndex = (brushSizeOptions.length * 0.6).floor().clamp(0, brushSizeOptions.length - 1);
    brushRadius = brushSizeOptions[brushSizeIndex];
  }

  bool get hasPendingStrokes => _pendingPoints.isNotEmpty;

  static List<double> generateBrushSizeOptions(double canvasShortSide) {
    final maxRadius = canvasShortSide / 2;
    final sizes = <double>[];
    double size = 4.0;
    while (size <= maxRadius) {
      sizes.add(size);
      size *= 2;
    }
    if (sizes.isEmpty) sizes.add(4.0);
    return sizes;
  }

  void increaseBrushSize() {
    if (brushSizeIndex < brushSizeOptions.length - 1) {
      brushSizeIndex++;
      brushRadius = brushSizeOptions[brushSizeIndex];
    }
  }

  void decreaseBrushSize() {
    if (brushSizeIndex > 0) {
      brushSizeIndex--;
      brushRadius = brushSizeOptions[brushSizeIndex];
    }
  }

  void updateCanvasSize(double shortSide) {
    brushSizeOptions = generateBrushSizeOptions(shortSide);
    brushSizeIndex = brushSizeIndex.clamp(0, brushSizeOptions.length - 1);
    brushRadius = brushSizeOptions[brushSizeIndex];
  }

  /// Queue a single brush stroke at ([x], [y]).
  void addStroke(double x, double y) {
    _pendingPoints.add(Offset(x, y));
  }

  /// Queue a line of brush strokes between two points, interpolated
  /// at half-radius spacing to avoid gaps.
  void addLine(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final dist = math.sqrt(dx * dx + dy * dy);
    final steps = (dist / (brushRadius * 0.5)).ceil().clamp(1, 200);
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      _pendingPoints.add(Offset(x1 + dx * t, y1 + dy * t));
    }
  }

  /// Process all pending strokes and render them to the draw buffer.
  ///
  /// Uses Flutter Canvas API to composite brush strokes onto the existing
  /// draw buffer, then captures via [Picture.toImage]. No custom shader
  /// samplers are used, so this is Impeller-safe.
  Future<void> processPendingStrokes(
    RenderState state,
    double canvasWidth,
    double canvasHeight,
  ) async {
    if (_pendingPoints.isEmpty || _isRendering) return;
    _isRendering = true;

    final points = List<Offset>.from(_pendingPoints);
    _pendingPoints.clear();

    try {
      final w = canvasWidth.ceil();
      final h = canvasHeight.ceil();
      if (w <= 0 || h <= 0) return;

      final encoding = encodePaintMode(currentMode);
      final isErase = currentMode == PaintMode.erase;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

      // Draw existing draw buffer as base layer
      final existing = state.drawBuffer;
      if (existing != null) {
        canvas.drawImageRect(
          existing,
          Rect.fromLTWH(0, 0, existing.width.toDouble(), existing.height.toDouble()),
          Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          Paint(),
        );
      }

      // Render each stroke point
      final brushPaint = Paint();
      if (isErase) {
        brushPaint.blendMode = BlendMode.clear;
      } else {
        brushPaint.color = Color.fromRGBO(
          (encoding.r * 255).round(),
          (encoding.g * 255).round(),
          (encoding.b * 255).round(),
          1.0,
        );
      }

      for (final point in points) {
        if (squareMode) {
          canvas.drawRect(
            Rect.fromCenter(
              center: point,
              width: brushRadius * 2,
              height: brushRadius * 2,
            ),
            brushPaint,
          );
        } else {
          canvas.drawCircle(point, brushRadius, brushPaint);
        }
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(w, h);
      picture.dispose();

      state.drawImages[state.drawWriteIndex]?.dispose();
      state.drawImages[state.drawWriteIndex] = image;
      state.swapDrawBuffers();
    } catch (e) {
      debugPrint('DrawingController: error rendering strokes: $e');
    } finally {
      _isRendering = false;
    }
  }
}
