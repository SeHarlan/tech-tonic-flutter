import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/rendering/render_controller.dart';
import '../../core/rendering/render_state.dart';
import '../../core/rendering/generative_painter.dart';

/// Providers for the loaded shader programs.
final generativeShaderProvider = FutureProvider<ui.FragmentProgram>((ref) {
  return ui.FragmentProgram.fromAsset('shaders/generative.frag');
});

final drawShaderProvider = FutureProvider<ui.FragmentProgram>((ref) {
  return ui.FragmentProgram.fromAsset('shaders/draw.frag');
});

/// Full-screen canvas that renders the generative art animation.
class CanvasScreen extends ConsumerStatefulWidget {
  const CanvasScreen({super.key});

  @override
  ConsumerState<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends ConsumerState<CanvasScreen>
    with SingleTickerProviderStateMixin {
  late final RenderController _renderController;
  late final RenderState _renderState;

  ui.FragmentShader? _generativeShader;
  bool _shadersReady = false;

  @override
  void initState() {
    super.initState();
    _renderState = RenderState(seed: DateTime.now().millisecondsSinceEpoch % 1000);
    _renderController = RenderController(onTick: _onTick);
    _renderController.start(this);
  }

  void _onTick(double elapsedSeconds) {
    if (!_shadersReady) return;
    _renderState.time = elapsedSeconds;
    _renderState.frameCount = _renderController.frameCount;
    _renderState.fps = _renderController.fps;
    _renderState.isPaused = _renderController.isPaused;
    if (mounted) {
      setState(() {}); // trigger repaint
    }
  }

  @override
  void dispose() {
    _renderController.dispose();
    _renderState.dispose();
    _generativeShader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shaderAsync = ref.watch(generativeShaderProvider);

    return shaderAsync.when(
      loading: () => const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white24)),
      ),
      error: (err, stack) => ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Shader error: $err',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
      data: (program) {
        _generativeShader ??= program.fragmentShader();
        _shadersReady = true;

        return LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              // Double tap → new seed
              onDoubleTap: () {
                setState(() {
                  _renderState.seed =
                      DateTime.now().millisecondsSinceEpoch % 1000;
                });
              },
              // Long press → toggle pause
              onLongPress: () {
                _renderController.togglePause();
              },
              child: SizedBox.expand(
                child: CustomPaint(
                  painter: GenerativePainter(
                    shader: _generativeShader!,
                    state: _renderState,
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
