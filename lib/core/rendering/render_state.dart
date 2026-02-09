import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the mutable rendering state for the generative animation loop.
class RenderState {
  double time;
  int frameCount;
  double fps;
  bool isPaused;
  double seed;

  /// Ping-pong frame images — the painter reads from [readIndex]
  /// and writes to the other slot.
  final List<ui.Image?> frameImages = [null, null];
  int readIndex = 0;

  /// Draw-buffer ping-pong images.
  final List<ui.Image?> drawImages = [null, null];
  int drawReadIndex = 0;

  RenderState({
    this.time = 0,
    this.frameCount = 0,
    this.fps = 0,
    this.isPaused = false,
    this.seed = 0,
  });

  int get writeIndex => (readIndex + 1) % 2;
  int get drawWriteIndex => (drawReadIndex + 1) % 2;

  ui.Image? get currentFrame => frameImages[readIndex];
  ui.Image? get drawBuffer => drawImages[drawReadIndex];

  /// Swap ping-pong after writing a new frame.
  void swapFrames() {
    readIndex = writeIndex;
  }

  /// Swap draw-buffer ping-pong after a draw operation.
  void swapDrawBuffers() {
    drawReadIndex = drawWriteIndex;
  }

  /// Dispose all retained images.
  void dispose() {
    for (final img in frameImages) {
      img?.dispose();
    }
    for (final img in drawImages) {
      img?.dispose();
    }
    frameImages[0] = null;
    frameImages[1] = null;
    drawImages[0] = null;
    drawImages[1] = null;
  }
}

/// Provides the shared [RenderState] instance.
final renderStateProvider = Provider<RenderState>((ref) {
  final state = RenderState();
  ref.onDispose(() => state.dispose());
  return state;
});
