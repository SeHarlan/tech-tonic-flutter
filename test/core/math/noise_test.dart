import 'package:flutter_test/flutter_test.dart';
import 'package:tech_tonic/core/math/noise.dart';

void main() {
  group('random()', () {
    test('is deterministic for the same inputs', () {
      final a = random(1.0, 2.0, 42.0);
      final b = random(1.0, 2.0, 42.0);
      expect(a, equals(b));
    });

    test('returns values in [0, 1)', () {
      for (int i = 0; i < 100; i++) {
        final v = random(i.toDouble(), i * 0.5, 7.0);
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThan(1.0));
      }
    });

    test('different inputs produce different outputs', () {
      final a = random(1.0, 2.0, 42.0);
      final b = random(3.0, 4.0, 42.0);
      expect(a, isNot(equals(b)));
    });

    test('different seeds produce different outputs', () {
      final a = random(1.0, 2.0, 0.0);
      final b = random(1.0, 2.0, 100.0);
      expect(a, isNot(equals(b)));
    });
  });

  group('noise()', () {
    test('is deterministic', () {
      final a = noise(5.5, 3.2, 10.0);
      final b = noise(5.5, 3.2, 10.0);
      expect(a, equals(b));
    });

    test('returns values in [0, 1]', () {
      for (int i = 0; i < 100; i++) {
        final v = noise(i * 0.7, i * 1.3, 5.0);
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThanOrEqualTo(1.0));
      }
    });

    test('produces smooth variation (nearby inputs yield nearby outputs)', () {
      final a = noise(5.0, 5.0, 1.0);
      final b = noise(5.01, 5.0, 1.0);
      // Smooth noise should not jump dramatically for tiny steps
      expect((a - b).abs(), lessThan(0.1));
    });
  });

  group('noise3D()', () {
    test('is deterministic', () {
      final a = noise3D(1.0, 2.0, 3.0, 42.0);
      final b = noise3D(1.0, 2.0, 3.0, 42.0);
      expect(a, equals(b));
    });

    test('returns values in [0, 1]', () {
      for (int i = 0; i < 50; i++) {
        final v = noise3D(i * 0.3, i * 0.7, i * 0.1, 5.0);
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('structuralNoise()', () {
    test('delegates to noise3D correctly', () {
      final a = structuralNoise(1.0, 2.0, 3.0, 42.0);
      final b = noise3D(1.0, 2.0, 3.0, 42.0);
      expect(a, equals(b));
    });
  });

  group('fbm()', () {
    test('is deterministic', () {
      final a = fbm(2.5, 3.5, 4, 10.0);
      final b = fbm(2.5, 3.5, 4, 10.0);
      expect(a, equals(b));
    });

    test('more octaves add detail (values differ from fewer octaves)', () {
      final low = fbm(5.0, 5.0, 1, 1.0);
      final high = fbm(5.0, 5.0, 4, 1.0);
      // Not necessarily different magnitude, but the values should differ
      // because higher octaves add finer detail.
      expect(low, isNot(equals(high)));
    });

    test('returns values in a reasonable range', () {
      for (int i = 0; i < 50; i++) {
        final v = fbm(i * 0.5, i * 0.3, 4, 7.0);
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThanOrEqualTo(1.0));
      }
    });

    test('clamps octaves to 1..8', () {
      // Should not throw for out-of-range octaves
      expect(() => fbm(1.0, 1.0, 0, 1.0), returnsNormally);
      expect(() => fbm(1.0, 1.0, 20, 1.0), returnsNormally);
    });
  });
}
