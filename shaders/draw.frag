// tech-Tonic drawing fragment shader — Flutter GLSL port
// Ported from the inline drawFragmentShaderSource in main.js
#include <flutter/runtime_effect.glsl>

// ── Float uniforms (accessed via setFloat by index order) ────────
uniform vec3 u_color;         // 0,1,2 — RGB color value to write
uniform float u_writeR;       // 3 — 1.0 to write R, 0.0 otherwise
uniform float u_writeG;       // 4 — 1.0 to write G, 0.0 otherwise
uniform float u_writeB;       // 5 — 1.0 to write B, 0.0 otherwise
uniform float u_clearB;       // 6 — 1.0 to clear B, 0.0 otherwise
uniform float u_squareMode;   // 7 — 1.0 for rectangular brush, 0.0 for circle
uniform float u_eraseMode;    // 8 — 1.0 for erase (clear to transparent)
uniform vec2 u_resolution;    // 9,10
uniform vec2 u_center;        // 11,12 — brush center in pixel coords
uniform vec2 u_radius;        // 13,14 — x and y radii

// ── Sampler uniforms ────────────────────────────────────────────
uniform sampler2D u_existingTexture; // sampler 0 — existing draw buffer

// ── Output ──────────────────────────────────────────────────────
out vec4 fragColor;

void main() {
    // Calculate distance from center in pixel space
    vec2 pixelCoord = FlutterFragCoord().xy;
    vec2 texCoord = pixelCoord / u_resolution;
    vec2 diff = pixelCoord - u_center;

    // Sample existing texture — we always need this for passthrough
    vec4 existingColor = texture(u_existingTexture, texCoord);

    // Use Chebyshev distance for rectangles, Euclidean for circles
    bool outsideBrush = false;
    if (u_squareMode > 0.5) {
        vec2 normalizedDiff = abs(diff) / u_radius;
        float dist = max(normalizedDiff.x, normalizedDiff.y);
        outsideBrush = dist > 1.0;
    } else {
        float dist = length(diff);
        outsideBrush = dist > u_radius.x;
    }

    // For pixels outside the brush, pass through the existing texture
    if (outsideBrush) {
        fragColor = existingColor;
        return;
    }

    // Erase mode: clear to transparent
    if (u_eraseMode > 0.5) {
        fragColor = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }

    // Write to channels based on flags
    vec4 result = existingColor;
    result.r = mix(result.r, u_color.r, step(0.5, u_writeR));
    result.g = mix(result.g, u_color.g, step(0.5, u_writeG));
    result.b = mix(result.b, u_color.b, step(0.5, u_writeB));
    result.b = mix(result.b, 0.0, step(0.5, u_clearB));

    result.a = 1.0;
    fragColor = result;
}
