import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/rendering/render_state.dart';
import 'drawing_controller.dart';

/// Transparent overlay that captures touch input and feeds it to the
/// [DrawingController] to render brush strokes to the draw buffer.
class DrawingOverlay extends StatefulWidget {
  final DrawingController controller;
  final RenderState renderState;
  final ui.FragmentShader drawShader;

  const DrawingOverlay({
    super.key,
    required this.controller,
    required this.renderState,
    required this.drawShader,
  });

  @override
  State<DrawingOverlay> createState() => _DrawingOverlayState();
}

class _DrawingOverlayState extends State<DrawingOverlay> {
  Offset? _lastPosition;

  void _onPanStart(DragStartDetails details) {
    final pos = details.localPosition;
    _lastPosition = pos;
    final size = context.size;
    if (size == null) return;

    final pixelRatio =
        ui.PlatformDispatcher.instance.views.first.devicePixelRatio;

    widget.controller.drawAt(
      pos.dx, pos.dy,
      widget.drawShader, widget.renderState,
      size.width, size.height, pixelRatio,
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final pos = details.localPosition;
    final prev = _lastPosition ?? pos;
    _lastPosition = pos;
    final size = context.size;
    if (size == null) return;

    final pixelRatio =
        ui.PlatformDispatcher.instance.views.first.devicePixelRatio;

    widget.controller.drawLine(
      prev.dx, prev.dy, pos.dx, pos.dy,
      widget.drawShader, widget.renderState,
      size.width, size.height, pixelRatio,
    );
  }

  void _onPanEnd(DragEndDetails details) {
    _lastPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: const SizedBox.expand(),
    );
  }
}
