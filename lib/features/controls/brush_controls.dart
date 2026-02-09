import 'package:flutter/material.dart';
import '../drawing/drawing_controller.dart';

/// Brush size controls with + / - buttons and size indicator.
class BrushControls extends StatelessWidget {
  final DrawingController controller;
  final VoidCallback onChanged;

  const BrushControls({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconButton(Icons.remove, () {
          controller.decreaseBrushSize();
          onChanged();
        }),
        const SizedBox(width: 8),
        Text(
          '${controller.brushRadius.toInt()}px',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 8),
        _iconButton(Icons.add, () {
          controller.increaseBrushSize();
          onChanged();
        }),
        const SizedBox(width: 16),
        _iconButton(
          controller.squareMode ? Icons.crop_square : Icons.circle_outlined,
          () {
            controller.squareMode = !controller.squareMode;
            onChanged();
          },
        ),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white38),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }
}
