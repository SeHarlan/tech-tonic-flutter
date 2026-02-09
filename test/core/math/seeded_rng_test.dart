import 'package:flutter_test/flutter_test.dart';
import 'package:tech_tonic/core/math/seeded_rng.dart';

void main() {
  group('SeededRng (Mulberry32)', () {
    test('is deterministic — same seed produces same sequence', () {
      final rng1 = SeededRng(12345);
      final rng2 = SeededRng(12345);

      for (int i = 0; i < 20; i++) {
        expect(rng1.next(), equals(rng2.next()));
      }
    });

    test('different seeds produce different sequences', () {
      final rng1 = SeededRng(1);
      final rng2 = SeededRng(2);

      // At least one of the first few values should differ
      bool anyDifferent = false;
      for (int i = 0; i < 10; i++) {
        if (rng1.next() != rng2.next()) anyDifferent = true;
      }
      expect(anyDifferent, isTrue);
    });

    test('values are in [0, 1)', () {
      final rng = SeededRng(42);
      for (int i = 0; i < 1000; i++) {
        final v = rng.next();
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThan(1.0));
      }
    });

    test('matches JS Mulberry32 output for seed 42', () {
      // Cross-validated with the JS implementation run in Node.js.
      // Seed 42 produces these first 5 values:
      final rng = SeededRng(42);
      final first = rng.next();
      final second = rng.next();
      final third = rng.next();
      final fourth = rng.next();
      final fifth = rng.next();

      expect(first, closeTo(0.6011037519201636, 1e-10));
      expect(second, closeTo(0.44829055899754167, 1e-10));
      expect(third, closeTo(0.8524657934904099, 1e-10));
      expect(fourth, closeTo(0.6697340414393693, 1e-10));
      expect(fifth, closeTo(0.17481389874592423, 1e-10));
    });

    test('nextFloat produces values in range', () {
      final rng = SeededRng(99);
      for (int i = 0; i < 100; i++) {
        final v = rng.nextFloat(10.0, 20.0);
        expect(v, greaterThanOrEqualTo(10.0));
        expect(v, lessThan(20.0));
      }
    });

    test('nextFromList picks from list', () {
      final rng = SeededRng(77);
      final items = ['a', 'b', 'c', 'd'];
      final picks = <String>{};
      for (int i = 0; i < 50; i++) {
        picks.add(rng.nextFromList(items));
      }
      // Should pick multiple different items over 50 draws
      expect(picks.length, greaterThan(1));
      // All picks should be from the list
      expect(picks.every(items.contains), isTrue);
    });
  });

  group('createSeededRng()', () {
    test('convenience factory matches direct construction', () {
      final a = createSeededRng(555);
      final b = SeededRng(555);
      for (int i = 0; i < 10; i++) {
        expect(a.next(), equals(b.next()));
      }
    });
  });
}
