import 'package:flutter_test/flutter_test.dart';
import 'package:tech_tonic/features/parameters/seed_generator.dart';

void main() {
  group('generateFromSeed()', () {
    test('is deterministic — same seed produces same parameters', () {
      final a = generateFromSeed(42);
      final b = generateFromSeed(42);

      expect(a.fxWithBlocking, equals(b.fxWithBlocking));
      expect(a.blockingScale, equals(b.blockingScale));
      expect(a.shouldMoveThreshold, equals(b.shouldMoveThreshold));
      expect(a.shouldFallThreshold, equals(b.shouldFallThreshold));
      expect(a.blackNoiseThreshold, equals(b.blackNoiseThreshold));
      expect(a.resetThreshold, equals(b.resetThreshold));
      expect(a.moveShapeScale, equals(b.moveShapeScale));
      expect(a.shouldFallScale, equals(b.shouldFallScale));
      expect(a.blackNoiseScale, equals(b.blackNoiseScale));
      expect(a.extraMoveShapeThreshold, equals(b.extraMoveShapeThreshold));
      expect(a.extraFallShapeThreshold, equals(b.extraFallShapeThreshold));
    });

    test('different seeds produce different parameters', () {
      final a = generateFromSeed(1);
      final b = generateFromSeed(9999);

      // Not all parameters will differ (some overlap in weighted random),
      // but the overall state should differ in at least some fields.
      final aMap = a.toShaderParams();
      final bMap = b.toShaderParams();

      int diffCount = 0;
      for (final key in aMap.keys) {
        if (aMap[key] != bMap[key]) diffCount++;
      }
      // Expect at least some parameters to differ
      expect(diffCount, greaterThan(3));
    });

    test('toShaderParams returns all expected keys', () {
      final p = generateFromSeed(42);
      final map = p.toShaderParams();

      // Spot-check critical keys
      expect(map.containsKey('targetFps'), isTrue);
      expect(map.containsKey('baseChunkSize'), isTrue);
      expect(map.containsKey('shouldMoveThreshold'), isTrue);
      expect(map.containsKey('moveSpeed'), isTrue);
      expect(map.containsKey('blackNoiseThreshold'), isTrue);
      expect(map.containsKey('blankColorR'), isTrue);
      expect(map.containsKey('staticColor3B'), isTrue);
      expect(map.containsKey('cycleColorHueSpeed'), isTrue);
      expect(map.containsKey('manualMode'), isTrue);
    });

    test('manual mode zeroes out movement thresholds', () {
      final p = generateFromSeed(42);
      p.manualMode = true;
      final map = p.toShaderParams();

      expect(map['shouldMoveThreshold'], equals(0.0));
      expect(map['shouldFallThreshold'], equals(0.0));
      expect(map['extraMoveShapeThreshold'], equals(0.0));
      expect(map['extraFallShapeThreshold'], equals(0.0));
      expect(map['manualMode'], equals(1.0));
    });

    test('produces valid numeric ranges', () {
      // Test with many seeds to check no parameters go out of bounds
      for (int seed = 0; seed < 100; seed++) {
        final p = generateFromSeed(seed);
        expect(p.shouldMoveThreshold, greaterThanOrEqualTo(0.0));
        expect(p.shouldMoveThreshold, lessThanOrEqualTo(1.0));
        expect(p.shouldFallThreshold, greaterThanOrEqualTo(0.0));
        expect(p.shouldFallThreshold, lessThanOrEqualTo(1.0));
        expect(p.blackNoiseThreshold, greaterThanOrEqualTo(0.0));
        expect(p.blackNoiseThreshold, lessThanOrEqualTo(1.0));
        expect(p.blockingScale, greaterThan(0));
      }
    });
  });
}
