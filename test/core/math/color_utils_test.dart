import 'package:flutter_test/flutter_test.dart';
import 'package:tech_tonic/core/math/color_utils.dart';

void main() {
  group('rgb2hsl()', () {
    test('black → (0, 0, 0)', () {
      final (h, s, l) = rgb2hsl(0, 0, 0);
      expect(h, equals(0.0));
      expect(s, equals(0.0));
      expect(l, equals(0.0));
    });

    test('white → (0, 0, 1)', () {
      final (h, s, l) = rgb2hsl(1, 1, 1);
      expect(h, equals(0.0));
      expect(s, equals(0.0));
      expect(l, equals(1.0));
    });

    test('pure red → (0, 1, 0.5)', () {
      final (h, s, l) = rgb2hsl(1, 0, 0);
      expect(h, closeTo(0.0, 1e-10));
      expect(s, closeTo(1.0, 1e-10));
      expect(l, closeTo(0.5, 1e-10));
    });

    test('pure green → (1/3, 1, 0.5)', () {
      final (h, s, l) = rgb2hsl(0, 1, 0);
      expect(h, closeTo(1.0 / 3.0, 1e-10));
      expect(s, closeTo(1.0, 1e-10));
      expect(l, closeTo(0.5, 1e-10));
    });

    test('pure blue → (2/3, 1, 0.5)', () {
      final (h, s, l) = rgb2hsl(0, 0, 1);
      expect(h, closeTo(2.0 / 3.0, 1e-10));
      expect(s, closeTo(1.0, 1e-10));
      expect(l, closeTo(0.5, 1e-10));
    });

    test('mid-grey → (0, 0, 0.5)', () {
      final (h, s, l) = rgb2hsl(0.5, 0.5, 0.5);
      expect(s, equals(0.0));
      expect(l, closeTo(0.5, 1e-10));
    });
  });

  group('hsl2rgb()', () {
    test('(0, 0, 0) → black', () {
      final (r, g, b) = hsl2rgb(0, 0, 0);
      expect(r, equals(0.0));
      expect(g, equals(0.0));
      expect(b, equals(0.0));
    });

    test('(0, 0, 1) → white', () {
      final (r, g, b) = hsl2rgb(0, 0, 1);
      expect(r, equals(1.0));
      expect(g, equals(1.0));
      expect(b, equals(1.0));
    });

    test('(0, 1, 0.5) → red', () {
      final (r, g, b) = hsl2rgb(0, 1, 0.5);
      expect(r, closeTo(1.0, 1e-10));
      expect(g, closeTo(0.0, 1e-10));
      expect(b, closeTo(0.0, 1e-10));
    });
  });

  group('HSL ↔ RGB roundtrip', () {
    test('roundtrips primary colors', () {
      _testRoundtrip(1, 0, 0); // red
      _testRoundtrip(0, 1, 0); // green
      _testRoundtrip(0, 0, 1); // blue
    });

    test('roundtrips secondary colors', () {
      _testRoundtrip(1, 1, 0); // yellow
      _testRoundtrip(0, 1, 1); // cyan
      _testRoundtrip(1, 0, 1); // magenta
    });

    test('roundtrips greys', () {
      _testRoundtrip(0.25, 0.25, 0.25);
      _testRoundtrip(0.5, 0.5, 0.5);
      _testRoundtrip(0.75, 0.75, 0.75);
    });

    test('roundtrips arbitrary colors', () {
      _testRoundtrip(0.2, 0.4, 0.6);
      _testRoundtrip(0.8, 0.3, 0.1);
      _testRoundtrip(0.1, 0.9, 0.5);
    });
  });

  group('increaseColorHue()', () {
    test('shifting by 0 returns the same color', () {
      final (r, g, b) = increaseColorHue(1.0, 0.0, 0.0, 0.0);
      expect(r, closeTo(1.0, 1e-10));
      expect(g, closeTo(0.0, 1e-10));
      expect(b, closeTo(0.0, 1e-10));
    });

    test('shifting red by 1/3 gives green', () {
      final (r, g, b) = increaseColorHue(1.0, 0.0, 0.0, 1.0 / 3.0);
      expect(r, closeTo(0.0, 1e-10));
      expect(g, closeTo(1.0, 1e-10));
      expect(b, closeTo(0.0, 1e-10));
    });

    test('shifting by 1.0 wraps back to same color', () {
      final (r, g, b) = increaseColorHue(0.5, 0.3, 0.7, 1.0);
      expect(r, closeTo(0.5, 1e-6));
      expect(g, closeTo(0.3, 1e-6));
      expect(b, closeTo(0.7, 1e-6));
    });

    test('preserves saturation and lightness', () {
      final (origH, origS, origL) = rgb2hsl(0.8, 0.2, 0.4);
      final (nr, ng, nb) = increaseColorHue(0.8, 0.2, 0.4, 0.25);
      final (newH, newS, newL) = rgb2hsl(nr, ng, nb);

      expect(newS, closeTo(origS, 1e-10));
      expect(newL, closeTo(origL, 1e-10));

      // Hue should have shifted by 0.25
      final expectedH = (origH + 0.25) % 1.0;
      expect(newH, closeTo(expectedH, 1e-10));
    });
  });
}

void _testRoundtrip(double r, double g, double b) {
  final (h, s, l) = rgb2hsl(r, g, b);
  final (rr, rg, rb) = hsl2rgb(h, s, l);
  expect(rr, closeTo(r, 1e-10), reason: 'R mismatch for ($r,$g,$b)');
  expect(rg, closeTo(g, 1e-10), reason: 'G mismatch for ($r,$g,$b)');
  expect(rb, closeTo(b, 1e-10), reason: 'B mismatch for ($r,$g,$b)');
}
