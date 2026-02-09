import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/rendering/uniform_mapping.dart';
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
    // R channel modes
    case PaintMode.shuffle:
      r = 0.375;
      writeR = true;
    case PaintMode.move:
      r = 0.625; // 0.5-0.75 → left in shader
      writeR = true;
    case PaintMode.moveLeft:
      r = 0.875; // 0.75+ → right in shader
      writeR = true;

    // G channel modes
    case PaintMode.trickle:
      g = 0.375;
      writeG = true;
    case PaintMode.waterfall:
      g = 0.625; // 0.5-0.75 → down
      writeG = true;
    case PaintMode.waterfallUp:
      g = 0.875; // 0.75+ → up
      writeG = true;

    // B channel modes
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
      break; // handled specially
  }

  return (r: r, g: g, b: b, writeR: writeR, writeG: writeG, writeB: writeB, clearB: clearB);
}

/// Manages drawing state and renders brush strokes to the draw buffer.
class DrawingController {
  PaintMode currentMode = PaintMode.waterfall;
  double brushRadius = 40.0;
  bool squareMode = false;

  /// List of valid brush sizes (powers of 4 from a base).
  late List<double> brushSizeOptions;
  int brushSizeIndex = 4;

  DrawingController() {
    brushSizeOptions = generateBrushSizeOptions(400.0);
    brushSizeIndex = (brushSizeOptions.length * 0.6).floor().clamp(0, brushSizeOptions.length - 1);
    brushRadius = brushSizeOptions[brushSizeIndex];
  }

  /// Generate brush size options matching JS `generateBrushSizeOptions`.
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

  /// Increase brush size by one step.
  void increaseBrushSize() {
    if (brushSizeIndex < brushSizeOptions.length - 1) {
      brushSizeIndex++;
      brushRadius = brushSizeOptions[brushSizeIndex];
    }
  }

  /// Decrease brush size by one step.
  void decreaseBrushSize() {
    if (brushSizeIndex > 0) {
      brushSizeIndex--;
      brushRadius = brushSizeOptions[brushSizeIndex];
    }
  }

  /// Update brush size options when canvas size changes.
  void updateCanvasSize(double shortSide) {
    brushSizeOptions = generateBrushSizeOptions(shortSide);
    brushSizeIndex = brushSizeIndex.clamp(0, brushSizeOptions.length - 1);
    brushRadius = brushSizeOptions[brushSizeIndex];
  }

  /// Render a single brush stroke at ([x], [y]) in pixel coordinates
  /// using the draw shader.
  ///
  /// Paints to the write slot of [state]'s draw buffer ping-pong,
  /// reading from the current read slot.
  void drawAt(
    double x,
    double y,
    ui.FragmentShader drawShader,
    RenderState state,
    double canvasWidth,
    double canvasHeight,
    double pixelRatio,
  ) {
    final pixelW = (canvasWidth * pixelRatio).toInt();
    final pixelH = (canvasHeight * pixelRatio).toInt();

    final encoded = encodePaintMode(currentMode);

    drawShader.setVec3(DrawUniforms.color, encoded.r, encoded.g, encoded.b);
    drawShader.setFloat(DrawUniforms.writeR, encoded.writeR ? 1.0 : 0.0);
    drawShader.setFloat(DrawUniforms.writeG, encoded.writeG ? 1.0 : 0.0);
    drawShader.setFloat(DrawUniforms.writeB, encoded.writeB ? 1.0 : 0.0);
    drawShader.setFloat(DrawUniforms.clearB, encoded.clearB ? 1.0 : 0.0);
    drawShader.setFloat(DrawUniforms.squareMode, squareMode ? 1.0 : 0.0);
    drawShader.setFloat(DrawUniforms.eraseMode, currentMode == PaintMode.erase ? 1.0 : 0.0);
    drawShader.setVec2(DrawUniforms.resolution, pixelW.toDouble(), pixelH.toDouble());
    drawShader.setVec2(DrawUniforms.center, x * pixelRatio, y * pixelRatio);
    drawShader.setVec2(DrawUniforms.radius, brushRadius * pixelRatio, brushRadius * pixelRatio);

    // Bind existing draw buffer as input
    final existing = state.drawBuffer;
    if (existing != null) {
      drawShader.setImageSampler(DrawUniforms.existingTextureSampler, existing);
    } else {
      // Create transparent placeholder
      final placeholder = _createTransparent(pixelW, pixelH);
      drawShader.setImageSampler(DrawUniforms.existingTextureSampler, placeholder);
      state.drawImages[state.drawReadIndex]?.dispose();
      state.drawImages[state.drawReadIndex] = placeholder;
    }

    // Render to offscreen
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
      Paint()..shader = drawShader,
    );
    final picture = recorder.endRecording();
    final newImage = picture.toImageSync(pixelW, pixelH);

    state.drawImages[state.drawWriteIndex]?.dispose();
    state.drawImages[state.drawWriteIndex] = newImage;
    state.swapDrawBuffers();

    picture.dispose();
  }

  /// Draw a line of brush strokes between two points (for smooth drawing).
  void drawLine(
    double x1, double y1,
    double x2, double y2,
    ui.FragmentShader drawShader,
    RenderState state,
    double canvasWidth,
    double canvasHeight,
    double pixelRatio,
  ) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final dist = math.sqrt(dx * dx + dy * dy);
    final spacing = math.max(brushRadius * 0.25, 2.0);
    final steps = (dist / spacing).ceil();

    for (int i = 0; i <= steps; i++) {
      final t = steps == 0 ? 0.0 : i / steps;
      drawAt(
        x1 + dx * t,
        y1 + dy * t,
        drawShader, state, canvasWidth, canvasHeight, pixelRatio,
      );
    }
  }

  ui.Image _createTransparent(int w, int h) {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0x00000000),
    );
    return recorder.endRecording().toImageSync(w, h);
  }
}
