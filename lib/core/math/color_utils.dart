import 'dart:math' as math;

/// RGB → HSL conversion matching the GLSL `rgb2hsl()`.
///
/// Input and output components are in range [0, 1].
/// Returns `(h, s, l)`.
(double h, double s, double l) rgb2hsl(double r, double g, double b) {
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final delta = maxC - minC;

  double h = 0.0;
  double s = 0.0;
  final l = (maxC + minC) / 2.0;

  if (delta > 0.0) {
    s = l < 0.5
        ? delta / (maxC + minC)
        : delta / (2.0 - maxC - minC);

    if (maxC == r) {
      h = (g - b) / delta + (g < b ? 6.0 : 0.0);
    } else if (maxC == g) {
      h = (b - r) / delta + 2.0;
    } else {
      h = (r - g) / delta + 4.0;
    }
    h /= 6.0;
  }

  return (h, s, l);
}

/// HSL → RGB conversion matching the GLSL `hsl2rgb()`.
///
/// All components in range [0, 1].
/// Returns `(r, g, b)`.
(double r, double g, double b) hsl2rgb(double h, double s, double l) {
  if (s == 0.0) {
    return (l, l, l); // achromatic
  }

  final q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
  final p = 2.0 * l - q;

  return (
    _hue2rgb(p, q, h + 1.0 / 3.0),
    _hue2rgb(p, q, h),
    _hue2rgb(p, q, h - 1.0 / 3.0),
  );
}

/// Shift the hue of an RGB colour by [amount] (in turns, 0–1 wraps).
///
/// Matches the GLSL `increaseColorHue()`.
(double r, double g, double b) increaseColorHue(
  double r, double g, double b, double amount,
) {
  var (h, s, l) = rgb2hsl(r, g, b);
  h = (h + amount) % 1.0;
  if (h < 0) h += 1.0;
  return hsl2rgb(h, s, l);
}

// ── private helpers ──────────────────────────────────────────────

double _hue2rgb(double p, double q, double t) {
  double tt = t;
  if (tt < 0.0) tt += 1.0;
  if (tt > 1.0) tt -= 1.0;
  if (tt < 1.0 / 6.0) return p + (q - p) * 6.0 * tt;
  if (tt < 1.0 / 2.0) return q;
  if (tt < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - tt) * 6.0;
  return p;
}
