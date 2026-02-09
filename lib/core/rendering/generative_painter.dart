import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'uniform_mapping.dart';
import 'render_state.dart';

/// Default shader parameter values matching the JS constants.
const double _baseChunkSize = 160.0;
const double _blockTimeMult = 0.05;
const double _structuralTimeMult = 0.01;
const double _moveSpeed = 0.0033;
const double _cycleColorHueBaseSpeed = 0.0025;
const double _targetFps = 60.0;
const double _resetEdgeThreshold = 0.33;
const double _ribbonDirtThreshold = 0.9;
const double _useRibbonThreshold = 0.25;
const double _blankStaticThreshold = 0.33;
const double _blankStaticTimeMult = 2.0;

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

    s.setVec2(GenerativeUniforms.resolution, w * pixelRatio, h * pixelRatio);
    s.setFloat(GenerativeUniforms.time, state.time);
    s.setFloat(GenerativeUniforms.pixelDensity, pixelRatio);
    s.setFloat(GenerativeUniforms.frameCount, state.frameCount.toDouble());
    s.setFloat(GenerativeUniforms.displayFps, state.fps);
    s.setFloat(GenerativeUniforms.seed, state.seed);
    s.setFloat(GenerativeUniforms.targetFps, p['targetFps'] ?? _targetFps);
    s.setFloat(GenerativeUniforms.baseChunkSize, p['baseChunkSize'] ?? _baseChunkSize);

    // Movement thresholds — manual mode zeroes them out (handled in Phase 4)
    s.setFloat(GenerativeUniforms.shouldMoveThreshold, p['shouldMoveThreshold'] ?? 0.2);
    s.setFloat(GenerativeUniforms.moveSpeed, p['moveSpeed'] ?? _moveSpeed);
    s.setVec2(GenerativeUniforms.moveShapeScale,
        p['moveShapeScaleX'] ?? 0.5, p['moveShapeScaleY'] ?? 5.0);
    s.setFloat(GenerativeUniforms.moveShapeSpeed, p['moveShapeSpeed'] ?? 0.025);
    s.setFloat(GenerativeUniforms.resetThreshold, p['resetThreshold'] ?? 0.5);
    s.setFloat(GenerativeUniforms.resetEdgeThreshold, p['resetEdgeThreshold'] ?? _resetEdgeThreshold);
    s.setVec2(GenerativeUniforms.resetNoiseScale,
        p['resetNoiseScaleX'] ?? 0.0625, p['resetNoiseScaleY'] ?? 0.0625);
    s.setFloat(GenerativeUniforms.shouldFallThreshold, p['shouldFallThreshold'] ?? 0.2);
    s.setVec2(GenerativeUniforms.shouldFallScale,
        p['shouldFallScaleX'] ?? 10.0, p['shouldFallScaleY'] ?? 0.5);
    s.setFloat(GenerativeUniforms.fallShapeSpeed, p['fallShapeSpeed'] ?? 0.044);
    s.setBool(GenerativeUniforms.fxWithBlocking, (p['fxWithBlocking'] ?? 0.0) > 0.5);
    s.setFloat(GenerativeUniforms.blockTimeMult, p['blockTimeMult'] ?? _blockTimeMult);
    s.setFloat(GenerativeUniforms.structuralTimeMult, p['structuralTimeMult'] ?? _structuralTimeMult);
    s.setFloat(GenerativeUniforms.extraMoveShapeThreshold, p['extraMoveShapeThreshold'] ?? 0.2);
    s.setVec2(GenerativeUniforms.extraMoveStutterScale,
        p['extraMoveStutterScaleX'] ?? 500.0, p['extraMoveStutterScaleY'] ?? 50.01);
    s.setFloat(GenerativeUniforms.extraMoveStutterThreshold, p['extraMoveStutterThreshold'] ?? 0.1);
    s.setFloat(GenerativeUniforms.extraFallShapeThreshold, p['extraFallShapeThreshold'] ?? 0.2);
    s.setVec2(GenerativeUniforms.extraFallStutterScale,
        p['extraFallStutterScaleX'] ?? 50.0, p['extraFallStutterScaleY'] ?? 500.01);
    s.setFloat(GenerativeUniforms.extraFallStutterThreshold, p['extraFallStutterThreshold'] ?? 0.1);
    s.setFloat(GenerativeUniforms.fallWaterfallMult, p['fallWaterfallMult'] ?? 2.0);
    s.setVec2(GenerativeUniforms.extraFallShapeScale,
        p['extraFallShapeScaleX'] ?? 30.0, p['extraFallShapeScaleY'] ?? 1.0);
    s.setFloat(GenerativeUniforms.extraFallShapeTimeMult, p['extraFallShapeTimeMult'] ?? 0.025);

    // Blocking
    final blocking = (p['fxWithBlocking'] ?? 0.0) > 0.5
        ? (p['blockingScale'] ?? 128.0)
        : 0.0;
    s.setFloat(GenerativeUniforms.blocking, blocking);

    s.setVec2(GenerativeUniforms.blackNoiseScale,
        p['blackNoiseScaleX'] ?? 0.0625, p['blackNoiseScaleY'] ?? 0.0625);
    s.setFloat(GenerativeUniforms.blackNoiseEdgeMult, p['blackNoiseEdgeMult'] ?? 0.02);
    s.setFloat(GenerativeUniforms.blackNoiseThreshold, p['blackNoiseThreshold'] ?? 0.5);
    s.setFloat(GenerativeUniforms.useRibbonThreshold, p['useRibbonThreshold'] ?? _useRibbonThreshold);
    s.setVec2(GenerativeUniforms.dirtNoiseScale,
        p['dirtNoiseScaleX'] ?? 2500.1, p['dirtNoiseScaleY'] ?? 2490.9);
    s.setFloat(GenerativeUniforms.ribbonDirtThreshold, p['ribbonDirtThreshold'] ?? _ribbonDirtThreshold);
    s.setVec2(GenerativeUniforms.blankStaticScale,
        p['blankStaticScaleX'] ?? 100.0, p['blankStaticScaleY'] ?? 0.01);
    s.setFloat(GenerativeUniforms.blankStaticThreshold, p['blankStaticThreshold'] ?? _blankStaticThreshold);
    s.setFloat(GenerativeUniforms.blankStaticTimeMult, p['blankStaticTimeMult'] ?? _blankStaticTimeMult);

    // Colors
    s.setVec3(GenerativeUniforms.blankColor,
        p['blankColorR'] ?? 0.0, p['blankColorG'] ?? 0.0, p['blankColorB'] ?? 0.0);
    s.setBool(GenerativeUniforms.useGrayscale, (p['useGrayscale'] ?? 0.0) > 0.5);
    s.setVec3(GenerativeUniforms.staticColor1,
        p['staticColor1R'] ?? 1.0, p['staticColor1G'] ?? 0.0, p['staticColor1B'] ?? 0.0);
    s.setVec3(GenerativeUniforms.staticColor2,
        p['staticColor2R'] ?? 0.0, p['staticColor2G'] ?? 1.0, p['staticColor2B'] ?? 0.0);
    s.setVec3(GenerativeUniforms.staticColor3,
        p['staticColor3R'] ?? 0.0, p['staticColor3G'] ?? 0.0, p['staticColor3B'] ?? 1.0);
    s.setVec2(GenerativeUniforms.extraMoveShapeScale,
        p['extraMoveShapeScaleX'] ?? 1.0, p['extraMoveShapeScaleY'] ?? 10.0);

    final cycleSpeed = (p['cycleColorHueSpeed'] ?? _cycleColorHueBaseSpeed) *
        (60.0 / (p['targetFps'] ?? _targetFps));
    s.setFloat(GenerativeUniforms.cycleColorHueSpeed, cycleSpeed);
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
