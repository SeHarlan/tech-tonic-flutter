import 'dart:math' as math;
import '../../core/math/seeded_rng.dart';
import '../../core/math/weighted_random.dart';
import 'parameter_state.dart';

/// Generates randomized shader parameters from a seed integer,
/// matching the JS `randomizeShaderParameters()` function.
ParameterState generateFromSeed(int seedValue) {
  final rng = SeededRng(seedValue);
  final p = ParameterState();

  // ── Blocking ───────────────────────────────────────────────────
  p.fxWithBlocking = weightedRandom<bool>([
    (true, 1.0),
    (false, 4.0),
  ], rng: rng)!;

  if (p.fxWithBlocking) {
    p.blockingScale = weightedRandom<double>([
      (4.0, 1.0),
      (8.0, 2.0),
      (16.0, 3.0),
      (32.0, 2.0),
      (64.0, 1.0),
    ], rng: rng)!;
  } else {
    p.blockingScale = weightedRandom<double>([
      (8.0, 1.0),
      (16.0, 2.0),
      (32.0, 3.0),
      (64.0, 4.0),
      (128.0, 3.0),
      (256.0, 2.0),
    ], rng: rng)!;
  }

  // ── Movement ───────────────────────────────────────────────────
  p.shouldMoveThreshold = weightedRandom<double>([
    (0.0, 1.0),
    (0.15, 2.0),
    (0.2, 5.0),
    (0.25, 2.0),
    (0.4, 1.0),
  ], rng: rng)!;

  p.useMoveBlob = rng.next() < 0.2;
  p.moveShapeSpeed = p.useMoveBlob ? 0.03125 : 0.025;
  p.moveShapeScale = _getMoveShapeScale(
    p.shouldMoveThreshold, p.useMoveBlob, p.fxWithBlocking, p.blockingScale, rng,
  );

  // ── Fall ───────────────────────────────────────────────────────
  p.shouldFallThreshold = weightedRandom<double>([
    (0.0, 1.0),
    (0.15, 2.0),
    (0.2, 5.0),
    (0.25, 2.0),
    (0.4, 1.0),
  ], rng: rng)!;

  p.fallWaterfallMult = weightedRandom<double>([
    (0.0, 1.0),
    (2.0, 4.0),
  ], rng: rng)!;

  p.useFallBlob = rng.next() < 0.2;
  p.fallShapeSpeed = p.useFallBlob ? 0.052 : 0.044;
  p.shouldFallScale = _getFallShapeScale(
    p.shouldFallThreshold, p.useFallBlob, p.fxWithBlocking, p.blockingScale, rng,
  );

  // ── Black noise ────────────────────────────────────────────────
  p.blackNoiseThreshold = weightedRandom<double>([
    (0.4, 1.0),
    (0.5, 4.0),
    (0.6, 1.0),
  ], rng: rng)!;

  final squaresOf2 = _getArrayOfSquares(2.0, 3);
  final blackNoiseBaseX = rng.nextFromList(squaresOf2);
  final blackNoiseBaseY = rng.nextFromList(squaresOf2);
  p.blackNoiseScale = [
    blackNoiseBaseX / p.blockingScale,
    blackNoiseBaseY / p.blockingScale,
  ];

  p.blackNoiseEdgeMult = weightedRandom<double>([
    (0.0, 1.0),
    (0.025, 4.0),
  ], rng: rng)!;

  // ── Reset ──────────────────────────────────────────────────────
  p.resetThreshold = weightedRandom<double>([
    (0.4, 1.0),
    (0.5, 4.0),
    (0.6, 1.0),
  ], rng: rng)!;

  p.resetNoiseScale = [
    blackNoiseBaseX / p.blockingScale,
    blackNoiseBaseY / p.blockingScale,
  ];

  // ── Ribbon/dirt ────────────────────────────────────────────────
  p.dirtNoiseScale = [
    rng.nextFloat(2400.0, 2600.0),
    rng.nextFloat(2400.0, 2600.0),
  ];
  p.blankStaticScale = [rng.nextFloat(90.0, 110.0), 0.01];

  // ── Extra fall ─────────────────────────────────────────────────
  p.extraFallShapeThreshold = weightedRandom<double>([
    (0.0, 1.0),
    (0.05, 2.0),
    (0.1, 5.0),
    (0.2, 2.0),
    (0.3, 1.0),
  ], rng: rng)!;

  final extraFallBase = _getFallShapeScale(
    p.extraFallShapeThreshold, p.useFallBlob, p.fxWithBlocking, p.blockingScale, rng,
  );
  p.extraFallShapeScale = extraFallBase.map((x) => x * 3).toList();

  // ── Extra move ─────────────────────────────────────────────────
  p.extraMoveShapeThreshold = weightedRandom<double>([
    (0.0, 1.0),
    (0.05, 2.0),
    (0.1, 5.0),
    (0.2, 2.0),
    (0.3, 1.0),
  ], rng: rng)!;

  final extraMoveBase = _getMoveShapeScale(
    p.extraMoveShapeThreshold, p.useMoveBlob, p.fxWithBlocking, p.blockingScale, rng,
  );
  p.extraMoveShapeScale = extraMoveBase.map((x) => x * 3).toList();

  return p;
}

// ── Helpers ─────────────────────────────────────────────────────

/// Generates `[start, start*2, start*4, ...]` (length items).
List<double> _getArrayOfSquares(double start, int length) {
  return List.generate(length, (i) => start * math.pow(2, i).toDouble());
}

/// Shape scale calculation matching `getShapeScale()` in main.js.
List<double> _getShapeScale(
  List<double> baseScale,
  double threshold,
  double adjustmentFactor,
  bool fxWithBlocking,
  double blockingScale,
) {
  if (threshold == 0) return baseScale;
  final normalizer = 0.2 / threshold;
  return baseScale.map((n) {
    double base = fxWithBlocking ? n / blockingScale : n;
    base /= normalizer;
    base /= adjustmentFactor;
    return base;
  }).toList();
}

List<double> _getMoveShapeScale(
  double threshold,
  bool useMoveBlob,
  bool fxWithBlocking,
  double blockingScale,
  SeededRng rng,
) {
  final baseScale = useMoveBlob ? [5.0, 5.0] : [0.5, 5.0];
  final blobAdj = useMoveBlob ? 2.0 : 1.0;
  return _getShapeScale(baseScale, threshold, blobAdj, fxWithBlocking, blockingScale);
}

List<double> _getFallShapeScale(
  double threshold,
  bool useFallBlob,
  bool fxWithBlocking,
  double blockingScale,
  SeededRng rng,
) {
  final baseScale = useFallBlob ? [10.0, 8.0] : [10.0, 0.5];
  final blobAdj = useFallBlob ? 3.0 : 1.0;
  return _getShapeScale(baseScale, threshold, blobAdj, fxWithBlocking, blockingScale);
}
