import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'uniform_mapping.dart';
import 'render_state.dart';

// NOTE: All shader parameters are now hard-coded in shaders/generative.frag
// to stay under Metal's 31 buffer limit. Only runtime-dynamic values are
// passed as uniforms (resolution, time, pixelDensity, frameCount, seed,
// globalFreeze, forceReset, manualMode).

/// [CustomPainter] that executes the generative fragment shader with
/// ping-pong frame feedback.
///
/// Each paint cycle:
///  1. Sets all float uniforms via [_setUniforms]
///  2. Binds the previous frame image (sampler 0) and draw buffer (sampler 1)
///  3. Draws a full-screen rect with the shader
///  4. Captures the result into an offscreen image for the next frame
///  5. Paints the result to the visible canvas
class GenerativePainter extends CustomPainter {
  final ui.FragmentShader shader;
  final RenderState state;
  final Size size;

  /// Shader parameters (will be set from ParameterState in Phase 4).
  /// For now we use reasonable defaults.
  final Map<String, double> params;

  GenerativePainter({
    required this.shader,
    required this.state,
    required this.size,
    this.params = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final pixelRatio = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final pixelW = (w * pixelRatio).toInt();
    final pixelH = (h * pixelRatio).toInt();

    // Set all uniforms
    _setUniforms(w, h, pixelRatio);

    // Bind previous frame as sampler 0
    final prevFrame = state.currentFrame;
    if (prevFrame != null) {
      shader.setImageSampler(GenerativeUniforms.textureSampler, prevFrame);
    } else {
      // First frame — create a transparent 1x1 placeholder
      final placeholder = _createPlaceholder(pixelW, pixelH);
      shader.setImageSampler(GenerativeUniforms.textureSampler, placeholder);
      // Store it so it can be disposed later
      state.frameImages[state.readIndex]?.dispose();
      state.frameImages[state.readIndex] = placeholder;
    }

    // Bind draw buffer as sampler 1
    final drawBuf = state.drawBuffer;
    if (drawBuf != null) {
      shader.setImageSampler(GenerativeUniforms.drawTextureSampler, drawBuf);
    } else {
      final placeholder = _createPlaceholder(pixelW, pixelH);
      shader.setImageSampler(GenerativeUniforms.drawTextureSampler, placeholder);
      state.drawImages[state.drawReadIndex]?.dispose();
      state.drawImages[state.drawReadIndex] = placeholder;
    }

    // Draw to an offscreen recorder for ping-pong capture
    final recorder = ui.PictureRecorder();
    final offCanvas = Canvas(recorder);
    final paint = Paint()..shader = shader;
    offCanvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
    final picture = recorder.endRecording();

    // Capture as image for the next frame
    final newFrame = picture.toImageSync(pixelW, pixelH);

    // Dispose the old frame in the write slot, then store the new one
    state.frameImages[state.writeIndex]?.dispose();
    state.frameImages[state.writeIndex] = newFrame;
    state.swapFrames();

    // Paint the captured frame to the visible canvas
    canvas.drawImageRect(
      newFrame,
      Rect.fromLTWH(0, 0, pixelW.toDouble(), pixelH.toDouble()),
      Rect.fromLTWH(0, 0, w, h),
      Paint(),
    );

    picture.dispose();
  }

  void _setUniforms(double w, double h, double pixelRatio) {
    final s = shader;
    final p = params;

    // Minimal uniforms: only 8 float values (all other params hard-coded in shader)
    s.setVec2(GenerativeUniforms.resolution, w * pixelRatio, h * pixelRatio);
    s.setFloat(GenerativeUniforms.time, state.time);
    s.setFloat(GenerativeUniforms.pixelDensity, pixelRatio);
    s.setFloat(GenerativeUniforms.frameCount, state.frameCount.toDouble());
    s.setFloat(GenerativeUniforms.seed, state.seed);
    s.setBool(GenerativeUniforms.globalFreeze, state.isPaused);
    s.setBool(GenerativeUniforms.forceReset, (p['forceReset'] ?? 0.0) > 0.5);
    s.setBool(GenerativeUniforms.manualMode, (p['manualMode'] ?? 0.0) > 0.5);
  }

  /// Creates a transparent placeholder image for initial frames.
  ui.Image _createPlaceholder(int w, int h) {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0x00000000),
    );
    return recorder.endRecording().toImageSync(w, h);
  }

  @override
  bool shouldRepaint(covariant GenerativePainter oldDelegate) => true;
}
