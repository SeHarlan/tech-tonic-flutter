import 'dart:math' as math;

/// Pseudo-random function matching the GLSL `random(vec2)`.
///
/// Uses the classic `fract(sin(dot(...)) * 43758.5453)` hash.
/// [seed] offsets the dot product for reproducible variation.
double random(double x, double y, double seed) {
  final dot = x * 12.9898 + y * 78.233 + seed;
  return _fract(math.sin(dot) * 43758.5453123);
}

/// Seeded variant — accepts an explicit seed separate from the global seed.
double seededRandom(double x, double y, double seed) {
  return random(x, y, seed);
}

/// 3D pseudo-random matching GLSL `random3D(vec3)`.
double random3D(double x, double y, double z, double seed) {
  final dot = x * 12.9898 + y * 78.233 + z * 37.719 + seed;
  return _fract(math.sin(dot) * 43758.5453123);
}

/// 3D value noise matching GLSL `noise3D(vec3)`.
///
/// Trilinear interpolation of random values at the 8 corners of the
/// integer lattice cell containing ([x],[y],[z]).
double noise3D(double x, double y, double z, double seed) {
  // Offset by seed
  final sx = x + seed * 13.591;
  final sy = y + seed * 7.123;
  final sz = z;

  final ix = sx.floorToDouble();
  final iy = sy.floorToDouble();
  final iz = sz.floorToDouble();

  final fx = sx - ix;
  final fy = sy - iy;
  final fz = sz - iz;

  // Eight corners of the cube
  final a = random3D(ix, iy, iz, seed);
  final b = random3D(ix + 1, iy, iz, seed);
  final c = random3D(ix, iy + 1, iz, seed);
  final d = random3D(ix + 1, iy + 1, iz, seed);
  final e = random3D(ix, iy, iz + 1, seed);
  final fCorner = random3D(ix + 1, iy, iz + 1, seed);
  final g = random3D(ix, iy + 1, iz + 1, seed);
  final h = random3D(ix + 1, iy + 1, iz + 1, seed);

  // Cubic Hermite smooth-step
  final ux = fx * fx * (3.0 - 2.0 * fx);
  final uy = fy * fy * (3.0 - 2.0 * fy);
  final uz = fz * fz * (3.0 - 2.0 * fz);

  // Trilinear interpolation
  final ab = _mix(a, b, ux);
  final cd = _mix(c, d, ux);
  final ef = _mix(e, fCorner, ux);
  final gh = _mix(g, h, ux);

  final abcd = _mix(ab, cd, uy);
  final efgh = _mix(ef, gh, uy);

  return _mix(abcd, efgh, uz);
}

/// 3D structural noise — 2D coordinates with a time-varying z.
double structuralNoise(double x, double y, double t, double seed) {
  return noise3D(x, y, t, seed);
}

/// 2D value noise matching GLSL `noise(vec2)`.
///
/// Bilinear interpolation of random values at the 4 corners of the
/// integer lattice cell containing ([x],[y]).
double noise(double x, double y, double seed) {
  // Offset by seed
  final sx = x + seed * 13.591;
  final sy = y + seed * 7.123;

  final ix = sx.floorToDouble();
  final iy = sy.floorToDouble();

  final fx = sx - ix;
  final fy = sy - iy;

  // Four corners
  final a = random(ix, iy, seed);
  final b = random(ix + 1, iy, seed);
  final c = random(ix, iy + 1, seed);
  final d = random(ix + 1, iy + 1, seed);

  // Cubic Hermite smooth-step
  final ux = fx * fx * (3.0 - 2.0 * fx);
  final uy = fy * fy * (3.0 - 2.0 * fy);

  return _mix(_mix(a, b, ux), _mix(c, d, ux), uy);
}

/// Fractal Brownian Motion — layered noise at increasing frequencies.
///
/// [octaves] is clamped to a maximum of 8, matching the GLSL MAX_OCTAVES.
double fbm(double x, double y, int octaves, double seed) {
  final clampedOctaves = octaves.clamp(1, 8);
  double value = 0.0;
  double amplitude = 0.5;
  double frequency = 1.0;

  for (int i = 0; i < clampedOctaves; i++) {
    value += amplitude * noise(x * frequency, y * frequency, seed);
    frequency *= 2.0;
    amplitude *= 0.5;
  }

  return value;
}

// ── helpers ──────────────────────────────────────────────────────

double _fract(double v) => v - v.floorToDouble();

double _mix(double a, double b, double t) => a + (b - a) * t;
