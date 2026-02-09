import 'package:flutter_test/flutter_test.dart';
import 'package:tech_tonic/core/math/seeded_rng.dart';
import 'package:tech_tonic/core/math/weighted_random.dart';

void main() {
  group('weightedRandom()', () {
    test('returns null for empty list', () {
      expect(weightedRandom<int>([]), isNull);
    });

    test('returns null when all weights are zero', () {
      final result = weightedRandom<String>([
        ('a', 0.0),
        ('b', 0.0),
      ]);
      expect(result, isNull);
    });

    test('returns the only option when list has one entry', () {
      final result = weightedRandom<int>([
        (42, 1.0),
      ]);
      expect(result, equals(42));
    });

    test('deterministic with SeededRng', () {
      final entries = <(String, double)>[
        ('a', 1.0),
        ('b', 2.0),
        ('c', 3.0),
      ];

      final rng1 = SeededRng(100);
      final rng2 = SeededRng(100);

      for (int i = 0; i < 20; i++) {
        expect(
          weightedRandom(entries, rng: rng1),
          equals(weightedRandom(entries, rng: rng2)),
        );
      }
    });

    test('heavily weighted item is chosen most often', () {
      final entries = <(String, double)>[
        ('rare', 1.0),
        ('common', 99.0),
      ];

      final rng = SeededRng(42);
      int commonCount = 0;
      const trials = 1000;

      for (int i = 0; i < trials; i++) {
        if (weightedRandom(entries, rng: rng) == 'common') {
          commonCount++;
        }
      }

      // Should be picked roughly 99% of the time
      expect(commonCount, greaterThan(950));
    });

    test('negative weights are treated as zero', () {
      final entries = <(String, double)>[
        ('negative', -5.0),
        ('positive', 1.0),
      ];

      final rng = SeededRng(7);
      // With negative clamped to 0, only 'positive' has weight
      for (int i = 0; i < 10; i++) {
        expect(weightedRandom(entries, rng: rng), equals('positive'));
      }
    });

    test('works with boolean values (matching JS pattern)', () {
      final entries = <(bool, double)>[
        (true, 1.0),
        (false, 4.0),
      ];

      final rng = SeededRng(42);
      int falseCount = 0;
      const trials = 500;

      for (int i = 0; i < trials; i++) {
        if (weightedRandom(entries, rng: rng) == false) {
          falseCount++;
        }
      }

      // false should win ~80% of the time (4 out of 5 weight)
      expect(falseCount, greaterThan(350));
      expect(falseCount, lessThan(450));
    });
  });
}
