import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/rendering/render_controller.dart';
import '../../core/rendering/render_state.dart';
import '../../core/rendering/generative_painter.dart';
import '../parameters/parameter_provider.dart';
import '../drawing/drawing_controller.dart';
import '../drawing/drawing_overlay.dart';

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
  late final DrawingController _drawingController;

  ui.FragmentShader? _generativeShader;
  ui.FragmentShader? _drawShader;
  bool _shadersReady = false;

  @override
  void initState() {
    super.initState();
    _renderState = RenderState(seed: DateTime.now().millisecondsSinceEpoch % 1000);
    _renderController = RenderController(onTick: _onTick);
    _drawingController = DrawingController();
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
    _drawShader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final genShaderAsync = ref.watch(generativeShaderProvider);
    final drawShaderAsync = ref.watch(drawShaderProvider);
    final paramState = ref.watch(parameterProvider);
    final shaderParams = paramState.toShaderParams();

    return genShaderAsync.when(
      loading: () => const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white24)),
      ),
      error: (err, stack) => ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text('Shader error: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
      data: (genProgram) {
        return drawShaderAsync.when(
          loading: () => const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator(color: Colors.white24)),
          ),
          error: (err, stack) => ColoredBox(
            color: Colors.black,
            child: Center(
              child: Text('Draw shader error: $err', style: const TextStyle(color: Colors.red)),
            ),
          ),
          data: (drawProgram) {
            _generativeShader ??= genProgram.fragmentShader();
            _drawShader ??= drawProgram.fragmentShader();
            _shadersReady = true;

            return LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                _drawingController.updateCanvasSize(
                  size.shortestSide,
                );

                return Stack(
                  children: [
                    // Generative canvas
                    SizedBox.expand(
                      child: CustomPaint(
                        painter: GenerativePainter(
                          shader: _generativeShader!,
                          state: _renderState,
                          size: size,
                          params: shaderParams,
                        ),
                      ),
                    ),
                    // Drawing overlay (captures touch)
                    DrawingOverlay(
                      controller: _drawingController,
                      renderState: _renderState,
                      drawShader: _drawShader!,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
