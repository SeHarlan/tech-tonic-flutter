/// Mulberry32 seeded pseudo-random number generator.
///
/// Port of the JS `createSeededRNG()` function from main.js.
/// Returns a callable that produces deterministic floats in [0, 1)
/// given the same integer [seed].
class SeededRng {
  int _state;

  SeededRng(int seed) : _state = seed;

  /// Produce the next random double in [0, 1).
  double next() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    int t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t = (t ^ (t + _imul(t ^ (t >>> 7), t | 61))) & 0xFFFFFFFF;
    return (((t ^ (t >>> 14)) & 0xFFFFFFFF) >>> 0) / 4294967296.0;
  }

  /// Random float in [min, max).
  double nextFloat(double min, double max) => next() * (max - min) + min;

  /// Random element from [list].
  T nextFromList<T>(List<T> list) => list[(next() * list.length).floor()];

  /// Emulates `Math.imul` — 32-bit integer multiplication.
  static int _imul(int a, int b) {
    // Dart integers are 64-bit; mask to 32-bit behaviour.
    a &= 0xFFFFFFFF;
    b &= 0xFFFFFFFF;
    final aHi = (a >>> 16) & 0xFFFF;
    final aLo = a & 0xFFFF;
    final bHi = (b >>> 16) & 0xFFFF;
    final bLo = b & 0xFFFF;
    return ((aLo * bLo) + (((aHi * bLo + aLo * bHi) & 0xFFFF) << 16)) &
        0xFFFFFFFF;
  }
}

/// Convenience factory matching the JS API: `createSeededRNG(seedValue)`.
SeededRng createSeededRng(int seed) => SeededRng(seed);
