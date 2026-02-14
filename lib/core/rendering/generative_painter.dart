import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'uniform_mapping.dart';
import 'render_state.dart';

/// Renders the generative fragment shader directly to the canvas.
///
/// Feedback loop is achieved by binding the previous frame (captured via
/// RenderRepaintBoundary.toImage after each paint) as a sampler uniform.
class GenerativePainter extends CustomPainter {
  final ui.FragmentShader shader;
  final RenderState state;
  final ui.Image previousFrame;
  final ui.Image drawBuffer;
  final Map<String, double> params;

  GenerativePainter({
    required this.shader,
    required this.state,
    required this.previousFrame,
    required this.drawBuffer,
    this.params = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // Set uniforms
    // FlutterFragCoord() returns logical pixels, so pass logical size
    shader.setVec2(GenerativeUniforms.resolution, w, h);
    shader.setFloat(GenerativeUniforms.time, state.time);
    // Pixel density = 1.0 since we're in logical pixel space
    shader.setFloat(GenerativeUniforms.pixelDensity, 1.0);
    shader.setFloat(GenerativeUniforms.frameCount, state.frameCount.toDouble());
    shader.setFloat(GenerativeUniforms.seed, state.seed);
    shader.setBool(GenerativeUniforms.globalFreeze, state.isPaused);
    shader.setBool(GenerativeUniforms.forceReset, (params['forceReset'] ?? 0.0) > 0.5);
    shader.setBool(GenerativeUniforms.manualMode, (params['manualMode'] ?? 0.0) > 0.5);

    // Bind previous frame and draw buffer as samplers
    shader.setImageSampler(GenerativeUniforms.textureSampler, previousFrame);
    shader.setImageSampler(GenerativeUniforms.drawTextureSampler, drawBuffer);

    // Draw shader to canvas
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant GenerativePainter oldDelegate) => true;
}
