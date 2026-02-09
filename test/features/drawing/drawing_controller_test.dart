import 'package:flutter_test/flutter_test.dart';
import 'package:tech_tonic/features/drawing/drawing_controller.dart';

void main() {
  group('encodePaintMode()', () {
    test('waterfall encodes G channel 0.625', () {
      final e = encodePaintMode(PaintMode.waterfall);
      expect(e.g, closeTo(0.625, 0.01));
      expect(e.writeG, isTrue);
      expect(e.writeR, isFalse);
      expect(e.writeB, isFalse);
    });

    test('waterfallUp encodes G channel 0.875', () {
      final e = encodePaintMode(PaintMode.waterfallUp);
      expect(e.g, closeTo(0.875, 0.01));
      expect(e.writeG, isTrue);
    });

    test('shuffle encodes R channel 0.375', () {
      final e = encodePaintMode(PaintMode.shuffle);
      expect(e.r, closeTo(0.375, 0.01));
      expect(e.writeR, isTrue);
    });

    test('freeze encodes B channel 0.375', () {
      final e = encodePaintMode(PaintMode.freeze);
      expect(e.b, closeTo(0.375, 0.01));
      expect(e.writeB, isTrue);
    });

    test('reset encodes B channel 0.53125', () {
      final e = encodePaintMode(PaintMode.reset);
      expect(e.b, closeTo(0.53125, 0.001));
      expect(e.writeB, isTrue);
    });

    test('resetGem encodes B channel 0.71875', () {
      final e = encodePaintMode(PaintMode.resetGem);
      expect(e.b, closeTo(0.71875, 0.001));
      expect(e.writeB, isTrue);
    });

    test('erase sets no write flags', () {
      final e = encodePaintMode(PaintMode.erase);
      expect(e.writeR, isFalse);
      expect(e.writeG, isFalse);
      expect(e.writeB, isFalse);
    });
  });

  group('DrawingController', () {
    test('generates brush size options', () {
      final sizes = DrawingController.generateBrushSizeOptions(400.0);
      expect(sizes.isNotEmpty, isTrue);
      expect(sizes.first, equals(4.0));
      // Should have powers of 2: 4, 8, 16, 32, 64, 128
      expect(sizes, contains(4.0));
      expect(sizes, contains(8.0));
      expect(sizes, contains(128.0));
    });

    test('increase/decrease brush size', () {
      final ctrl = DrawingController();
      ctrl.brushSizeOptions = [4.0, 8.0, 16.0, 32.0];
      ctrl.brushSizeIndex = 1;
      ctrl.brushRadius = ctrl.brushSizeOptions[1];

      ctrl.increaseBrushSize();
      expect(ctrl.brushRadius, equals(16.0));
      expect(ctrl.brushSizeIndex, equals(2));

      ctrl.decreaseBrushSize();
      expect(ctrl.brushRadius, equals(8.0));
      expect(ctrl.brushSizeIndex, equals(1));
    });

    test('decrease clamps at 0', () {
      final ctrl = DrawingController();
      ctrl.brushSizeOptions = [4.0, 8.0];
      ctrl.brushSizeIndex = 0;
      ctrl.brushRadius = 4.0;

      ctrl.decreaseBrushSize();
      expect(ctrl.brushSizeIndex, equals(0));
      expect(ctrl.brushRadius, equals(4.0));
    });

    test('increase clamps at max', () {
      final ctrl = DrawingController();
      ctrl.brushSizeOptions = [4.0, 8.0];
      ctrl.brushSizeIndex = 1;
      ctrl.brushRadius = 8.0;

      ctrl.increaseBrushSize();
      expect(ctrl.brushSizeIndex, equals(1));
      expect(ctrl.brushRadius, equals(8.0));
    });
  });
}
