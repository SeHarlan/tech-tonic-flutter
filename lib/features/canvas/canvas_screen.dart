import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/rendering/render_controller.dart';
import '../../core/rendering/render_state.dart';
import '../../core/rendering/generative_painter.dart';
import '../../core/rendering/shader_renderer.dart';
import '../parameters/parameter_provider.dart';
import '../drawing/drawing_controller.dart';
import '../drawing/drawing_overlay.dart';
import '../controls/controls_drawer.dart';
import '../export/image_exporter.dart';

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

  final GlobalKey _boundaryKey = GlobalKey();
  ui.FragmentShader? _generativeShader;
  ui.FragmentShader? _drawShader;
  bool _shadersReady = false;
  bool _showControls = false;
  bool _capturing = false;
  ui.Image? _placeholder;

  @override
  void initState() {
    super.initState();
    _renderState = RenderState(seed: DateTime.now().millisecondsSinceEpoch % 1000);
    _renderController = RenderController(onTick: _onTick);
    _drawingController = DrawingController();
    _initPlaceholder();
    _renderController.start(this);
  }

  Future<void> _initPlaceholder() async {
    _placeholder = await ImageHelper.createPlaceholder(2, 2);
    if (mounted) setState(() {});
  }

  void _onTick(double elapsedSeconds) {
    if (!_shadersReady || _placeholder == null || _capturing) return;

    _renderState.time = elapsedSeconds;
    _renderState.frameCount = _renderController.frameCount;
    _renderState.fps = _renderController.fps;
    _renderState.isPaused = _renderController.isPaused;

    // Process any pending draw strokes (fire-and-forget async)
    if (_drawingController.hasPendingStrokes) {
      final size = _boundaryKey.currentContext?.size;
      if (size != null) {
        _drawingController.processPendingStrokes(
          _renderState, size.width, size.height,
        );
      }
    }

    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_capturing) {
          _captureFrame();
        }
      });
    }
  }

  Future<void> _captureFrame() async {
    _capturing = true;
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 1.0);

      _renderState.frameImages[_renderState.writeIndex]?.dispose();
      _renderState.frameImages[_renderState.writeIndex] = image;
      _renderState.swapFrames();
    } catch (e) {
      // Silently handle capture errors
    } finally {
      _capturing = false;
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _newSeed() {
    final newSeed = DateTime.now().millisecondsSinceEpoch % 10000;
    ref.read(seedProvider.notifier).state = newSeed;
    _renderState.seed = newSeed.toDouble();
  }

  void _clearCanvas() {
    final paramNotifier = ref.read(parameterProvider.notifier);
    paramNotifier.setForceReset(true);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        paramNotifier.setForceReset(false);
      }
    });
  }

  @override
  void dispose() {
    _renderController.dispose();
    _renderState.dispose();
    _placeholder?.dispose();
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
          child: Text('Shader error: $err',
              style: const TextStyle(color: Colors.red)),
        ),
      ),
      data: (genProgram) {
        return drawShaderAsync.when(
          loading: () => const ColoredBox(
            color: Colors.black,
            child: Center(
                child: CircularProgressIndicator(color: Colors.white24)),
          ),
          error: (err, stack) => ColoredBox(
            color: Colors.black,
            child: Center(
              child: Text('Draw shader error: $err',
                  style: const TextStyle(color: Colors.red)),
            ),
          ),
          data: (drawProgram) {
            _generativeShader ??= genProgram.fragmentShader();
            _drawShader ??= drawProgram.fragmentShader();
            _shadersReady = true;

            final placeholder = _placeholder;
            if (placeholder == null) {
              return const ColoredBox(color: Colors.black);
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final size =
                    Size(constraints.maxWidth, constraints.maxHeight);
                _drawingController.updateCanvasSize(size.shortestSide);

                return Stack(
                  children: [
                    RepaintBoundary(
                      key: _boundaryKey,
                      child: SizedBox.expand(
                        child: CustomPaint(
                          painter: GenerativePainter(
                            shader: _generativeShader!,
                            state: _renderState,
                            previousFrame:
                                _renderState.currentFrame ?? placeholder,
                            drawBuffer:
                                _renderState.drawBuffer ?? placeholder,
                            params: shaderParams,
                          ),
                        ),
                      ),
                    ),

                    if (!_showControls)
                      DrawingOverlay(
                        controller: _drawingController,
                        renderState: _renderState,
                      ),

                    Positioned(
                      bottom: _showControls ? null : 16,
                      right: 16,
                      top: _showControls ? 16 : null,
                      child: GestureDetector(
                        onTap: _toggleControls,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Icon(
                            _showControls ? Icons.close : Icons.tune,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    if (_showControls)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ControlsDrawer(
                          drawingController: _drawingController,
                          onNewSeed: _newSeed,
                          onClear: _clearCanvas,
                          onCapture: () {
                            ImageExporter.captureAndShare(
                              _renderState.currentFrame,
                              context,
                            );
                          },
                          onToggleManual: () {
                            ref
                                .read(parameterProvider.notifier)
                                .toggleManualMode();
                          },
                          onToggleFreeze: () {
                            ref
                                .read(parameterProvider.notifier)
                                .toggleGlobalFreeze();
                          },
                          isManualMode: paramState.manualMode,
                          isFrozen: paramState.globalFreeze,
                          onChanged: () => setState(() {}),
                        ),
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
