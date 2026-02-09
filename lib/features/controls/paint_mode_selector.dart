import 'package:flutter/material.dart';
import '../drawing/drawing_controller.dart';

/// A horizontal row of paint mode buttons with terminal-style aesthetics.
class PaintModeSelector extends StatelessWidget {
  final PaintMode currentMode;
  final ValueChanged<PaintMode> onModeChanged;

  const PaintModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _modeChip('waterfall', PaintMode.waterfall),
        _modeChip('waterfall-up', PaintMode.waterfallUp),
        _modeChip('trickle', PaintMode.trickle),
        _modeChip('move', PaintMode.move),
        _modeChip('move-left', PaintMode.moveLeft),
        _modeChip('shuffle', PaintMode.shuffle),
        _modeChip('freeze', PaintMode.freeze),
        _modeChip('reset', PaintMode.reset),
        _modeChip('reset-empty', PaintMode.resetEmpty),
        _modeChip('reset-static', PaintMode.resetStatic),
        _modeChip('reset-gem', PaintMode.resetGem),
        _modeChip('erase', PaintMode.erase),
      ],
    );
  }

  Widget _modeChip(String label, PaintMode mode) {
    final selected = currentMode == mode;
    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          border: Border.all(
            color: selected ? Colors.white : Colors.white38,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
