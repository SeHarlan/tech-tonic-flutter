import 'package:flutter/material.dart';
import '../../core/rendering/render_state.dart';
import 'drawing_controller.dart';

/// Transparent overlay that captures touch input and queues brush strokes
/// in the [DrawingController]. Strokes are rendered to the draw buffer
/// each frame by [DrawingController.processPendingStrokes].
class DrawingOverlay extends StatefulWidget {
  final DrawingController controller;
  final RenderState renderState;

  const DrawingOverlay({
    super.key,
    required this.controller,
    required this.renderState,
  });

  @override
  State<DrawingOverlay> createState() => _DrawingOverlayState();
}

class _DrawingOverlayState extends State<DrawingOverlay> {
  Offset? _lastPosition;

  void _onPanStart(DragStartDetails details) {
    final pos = details.localPosition;
    _lastPosition = pos;
    widget.controller.addStroke(pos.dx, pos.dy);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final pos = details.localPosition;
    final prev = _lastPosition ?? pos;
    _lastPosition = pos;
    widget.controller.addLine(prev.dx, prev.dy, pos.dx, pos.dy);
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
