import 'dart:math' as math;

import 'seeded_rng.dart';

/// Picks a value from a list of `(value, weight)` pairs using weighted
/// probability.
///
/// If [rng] is provided, uses it for deterministic selection;
/// otherwise falls back to `dart:math.Random`.
///
/// Returns `null` when [entries] is empty or total weight is zero.
T? weightedRandom<T>(
  List<(T value, double weight)> entries, {
  SeededRng? rng,
}) {
  if (entries.isEmpty) return null;

  final totalWeight = entries.fold<double>(
    0.0,
    (acc, e) => acc + math.max(0, e.$2),
  );
  if (totalWeight == 0) return null;

  final randomValue =
      (rng != null ? rng.next() : math.Random().nextDouble()) * totalWeight;

  double cumulative = 0.0;
  for (final (value, weight) in entries) {
    cumulative += math.max(0, weight);
    if (randomValue <= cumulative) return value;
  }

  // Floating-point edge case fallback.
  return entries.last.$1;
}
