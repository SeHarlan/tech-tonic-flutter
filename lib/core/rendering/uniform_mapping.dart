import 'dart:ui' as ui;

/// Maps named shader parameters to `FragmentShader.setFloat()` indices.
///
/// The index order **must** match the declaration order in the GLSL file.
/// vec2 occupies 2 consecutive indices, vec3 occupies 3.
///
/// See `shaders/generative.frag` and `shaders/draw.frag` for the
/// authoritative uniform declarations.
class GenerativeUniforms {
  // ── Index constants ─────────────────────────────────────────────
  // Each constant is the *first* float index for that uniform.
  static const int resolution = 0;       // vec2 (0,1)
  static const int time = 2;             // float
  static const int pixelDensity = 3;     // float
  static const int frameCount = 4;       // float
  static const int displayFps = 5;       // float
  static const int seed = 6;             // float
  static const int targetFps = 7;        // float
  static const int baseChunkSize = 8;    // float
  static const int shouldMoveThreshold = 9; // float
  static const int moveSpeed = 10;       // float
  static const int moveShapeScale = 11;  // vec2 (11,12)
  static const int moveShapeSpeed = 13;  // float
  static const int resetThreshold = 14;  // float
  static const int resetEdgeThreshold = 15; // float
  static const int resetNoiseScale = 16; // vec2 (16,17)
  static const int shouldFallThreshold = 18; // float
  static const int shouldFallScale = 19; // vec2 (19,20)
  static const int fallShapeSpeed = 21;  // float
  static const int fxWithBlocking = 22;  // float (bool→float)
  static const int blockTimeMult = 23;   // float
  static const int structuralTimeMult = 24; // float
  static const int extraMoveShapeThreshold = 25; // float
  static const int extraMoveStutterScale = 26; // vec2 (26,27)
  static const int extraMoveStutterThreshold = 28; // float
  static const int extraFallShapeThreshold = 29; // float
  static const int extraFallStutterScale = 30; // vec2 (30,31)
  static const int extraFallStutterThreshold = 32; // float
  static const int fallWaterfallMult = 33; // float
  static const int extraFallShapeScale = 34; // vec2 (34,35)
  static const int extraFallShapeTimeMult = 36; // float
  static const int blocking = 37;        // float
  static const int blackNoiseScale = 38; // vec2 (38,39)
  static const int blackNoiseEdgeMult = 40; // float
  static const int blackNoiseThreshold = 41; // float
  static const int useRibbonThreshold = 42; // float
  static const int dirtNoiseScale = 43;  // vec2 (43,44)
  static const int ribbonDirtThreshold = 45; // float
  static const int blankStaticScale = 46; // vec2 (46,47)
  static const int blankStaticThreshold = 48; // float
  static const int blankStaticTimeMult = 49; // float
  static const int blankColor = 50;      // vec3 (50,51,52)
  static const int useGrayscale = 53;    // float (bool→float)
  static const int staticColor1 = 54;    // vec3 (54,55,56)
  static const int staticColor2 = 57;    // vec3 (57,58,59)
  static const int staticColor3 = 60;    // vec3 (60,61,62)
  static const int extraMoveShapeScale = 63; // vec2 (63,64)
  static const int cycleColorHueSpeed = 65; // float
  static const int globalFreeze = 66;    // float
  static const int forceReset = 67;      // float
  static const int manualMode = 68;      // float

  /// Total number of float indices used by the generative shader.
  static const int totalFloats = 69;

  // ── Sampler indices (setImageSampler) ───────────────────────────
  static const int textureSampler = 0;     // previous frame
  static const int drawTextureSampler = 1; // drawing buffer
}

/// Maps named parameters to `setFloat()` indices for the draw shader.
///
/// See `shaders/draw.frag`.
class DrawUniforms {
  static const int color = 0;          // vec3 (0,1,2)
  static const int writeR = 3;         // float
  static const int writeG = 4;         // float
  static const int writeB = 5;         // float
  static const int clearB = 6;         // float
  static const int squareMode = 7;     // float
  static const int eraseMode = 8;      // float
  static const int resolution = 9;     // vec2 (9,10)
  static const int center = 11;        // vec2 (11,12)
  static const int radius = 13;        // vec2 (13,14)

  /// Total number of float indices used by the draw shader.
  static const int totalFloats = 15;

  // ── Sampler indices ────────────────────────────────────────────
  static const int existingTextureSampler = 0;
}

// ── Convenience setters ──────────────────────────────────────────

extension ShaderVec2 on ui.FragmentShader {
  /// Set a vec2 uniform starting at [index].
  void setVec2(int index, double x, double y) {
    setFloat(index, x);
    setFloat(index + 1, y);
  }

  /// Set a vec3 uniform starting at [index].
  void setVec3(int index, double x, double y, double z) {
    setFloat(index, x);
    setFloat(index + 1, y);
    setFloat(index + 2, z);
  }

  /// Set a boolean-as-float uniform.
  void setBool(int index, bool value) {
    setFloat(index, value ? 1.0 : 0.0);
  }
}
