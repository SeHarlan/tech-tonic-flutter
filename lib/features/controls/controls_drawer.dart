import 'package:flutter/material.dart';
import '../drawing/drawing_controller.dart';
import 'paint_mode_selector.dart';
import 'brush_controls.dart';

/// Bottom sheet-style controls drawer with terminal aesthetics.
///
/// Slides up from the bottom of the screen. Contains mode selection,
/// brush controls, and action buttons.
class ControlsDrawer extends StatelessWidget {
  final DrawingController drawingController;
  final VoidCallback onNewSeed;
  final VoidCallback onClear;
  final VoidCallback onToggleManual;
  final VoidCallback onToggleFreeze;
  final bool isManualMode;
  final bool isFrozen;
  final VoidCallback onChanged;

  const ControlsDrawer({
    super.key,
    required this.drawingController,
    required this.onNewSeed,
    required this.onClear,
    required this.onToggleManual,
    required this.onToggleFreeze,
    required this.isManualMode,
    required this.isFrozen,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(230),
        border: const Border(
          top: BorderSide(color: Colors.white24, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Section: Paint Mode
          const _SectionLabel('MODE'),
          const SizedBox(height: 6),
          PaintModeSelector(
            currentMode: drawingController.currentMode,
            onModeChanged: (mode) {
              drawingController.currentMode = mode;
              onChanged();
            },
          ),

          const SizedBox(height: 16),

          // Section: Brush
          const _SectionLabel('BRUSH'),
          const SizedBox(height: 6),
          BrushControls(
            controller: drawingController,
            onChanged: onChanged,
          ),

          const SizedBox(height: 16),

          // Section: Actions
          const _SectionLabel('ACTIONS'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton('NEW SEED', onNewSeed),
              _actionButton('CLEAR', onClear),
              _toggleButton('MANUAL', isManualMode, onToggleManual),
              _toggleButton('FREEZE', isFrozen, onToggleFreeze),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white38),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _toggleButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          border: Border.all(
            color: active ? Colors.white : Colors.white38,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white70,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10,
        fontFamily: 'monospace',
        letterSpacing: 2,
      ),
    );
  }
}
