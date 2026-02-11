import 'dart:ui' as ui;

/// Maps shader parameters to `FragmentShader.setFloat()` indices.
///
/// MINIMAL VERSION: Only 8 float uniforms (10 total buffers with samplers)
/// to stay under Metal's 31 buffer limit. All other parameters are hard-coded
/// in the shader.
class GenerativeUniforms {
  // ── Float uniform indices ──────────────────────────────────────────
  static const int resolution = 0;       // vec2 (0,1)
  static const int time = 2;             // float
  static const int pixelDensity = 3;     // float
  static const int frameCount = 4;       // float
  static const int seed = 5;             // float
  static const int globalFreeze = 6;     // float (bool→float)
  static const int forceReset = 7;       // float (bool→float)
  static const int manualMode = 8;       // float (bool→float)

  /// Total number of float indices (8 floats = vec2 + 6 floats).
  static const int totalFloats = 9;

  // ── Sampler indices (setImageSampler) ───────────────────────────────
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
