// tech-Tonic generative fragment shader — Flutter GLSL port (MINIMAL VERSION)
// Ported from fragmentShader.glsl (770-line WebGL version)
// OPTIMIZED: Hard-coded all non-runtime parameters to stay under Metal's 31 buffer limit
#include <flutter/runtime_effect.glsl>

// ── Runtime uniforms (only 8 floats + 2 samplers = 10 buffers) ─────
uniform vec2 u_resolution;        // 0: screen resolution
uniform float u_time;             // 1: elapsed time
uniform float u_pixelDensity;     // 2: device pixel ratio
uniform float u_frameCount;       // 3: frame counter
uniform float u_seed;             // 4: random seed
uniform float u_globalFreeze;     // 5: freeze animation flag
uniform float u_forceReset;       // 6: force reset flag
uniform float u_manualMode;       // 7: manual mode flag

uniform sampler2D u_texture;      // sampler 0 — previous frame
uniform sampler2D u_drawTexture;  // sampler 1 — drawing buffer

// ── Hard-coded constants (previously dynamic uniforms) ───────────────
const float TARGET_FPS = 60.0;
const float BASE_CHUNK_SIZE = 160.0;
const float BLOCK_TIME_MULT = 0.05;
const float STRUCTURAL_TIME_MULT = 0.01;
const float MOVE_SPEED = 0.0033;
const float CYCLE_COLOR_HUE_BASE_SPEED = 0.0025;
const float RESET_EDGE_THRESHOLD = 0.33;
const float RIBBON_DIRT_THRESHOLD = 0.9;
const float USE_RIBBON_THRESHOLD = 0.25;
const float BLANK_STATIC_THRESHOLD = 0.33;
const float BLANK_STATIC_TIME_MULT = 2.0;

// Movement params (hard-coded defaults)
const float SHOULD_MOVE_THRESHOLD = 0.2;
const vec2 MOVE_SHAPE_SCALE = vec2(0.5, 5.0);
const float MOVE_SHAPE_SPEED = 0.025;

// Reset params
const float RESET_THRESHOLD = 0.5;
const vec2 RESET_NOISE_SCALE = vec2(0.0625, 0.0625);

// Fall params
const float SHOULD_FALL_THRESHOLD = 0.2;
const vec2 SHOULD_FALL_SCALE = vec2(10.0, 0.5);
const float FALL_SHAPE_SPEED = 0.044;
const float FALL_WATERFALL_MULT = 2.0;

// Extra move params
const float EXTRA_MOVE_SHAPE_THRESHOLD = 0.2;
const vec2 EXTRA_MOVE_STUTTER_SCALE = vec2(500.0, 50.01);
const float EXTRA_MOVE_STUTTER_THRESHOLD = 0.1;
const vec2 EXTRA_MOVE_SHAPE_SCALE = vec2(1.0, 10.0);

// Extra fall params
const float EXTRA_FALL_SHAPE_THRESHOLD = 0.2;
const vec2 EXTRA_FALL_STUTTER_SCALE = vec2(50.0, 500.01);
const float EXTRA_FALL_STUTTER_THRESHOLD = 0.1;
const vec2 EXTRA_FALL_SHAPE_SCALE = vec2(30.0, 1.0);
const float EXTRA_FALL_SHAPE_TIME_MULT = 0.025;

// FX params
const bool FX_WITH_BLOCKING = false;
const float BLOCKING = 0.0;  // 128.0 when enabled

// Noise params
const vec2 BLACK_NOISE_SCALE = vec2(0.0625, 0.0625);
const float BLACK_NOISE_EDGE_MULT = 0.02;
const float BLACK_NOISE_THRESHOLD = 0.5;
const vec2 DIRT_NOISE_SCALE = vec2(2500.1, 2490.9);

// Static params
const vec2 BLANK_STATIC_SCALE = vec2(100.0, 0.01);

// Colors
const vec3 BLANK_COLOR = vec3(0.0, 0.0, 0.0);
const bool USE_GRAYSCALE = false;
const vec3 STATIC_COLOR_1 = vec3(1.0, 0.0, 0.0);
const vec3 STATIC_COLOR_2 = vec3(0.0, 1.0, 0.0);
const vec3 STATIC_COLOR_3 = vec3(0.0, 0.0, 1.0);

// ── Output ──────────────────────────────────────────────────────────
out vec4 fragColor;

// ── Drawing constants ───────────────────────────────────────────────
const float PI = 3.14159265;
const float DRAW_ACTIVE_THRESHOLD = 0.25;
const float DRAW_SHIFT_THRESHOLD = 0.5;
const float DRAW_DIRECTION_THRESHOLD = 0.75;

// ── Noise functions ─────────────────────────────────────────────────

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233)) + u_seed) * 43758.5453123);
}

float seededRandom(vec2 st, float seed) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233)) + seed) * 43758.5453123);
}

float random3D(vec3 st) {
    return fract(sin(dot(st.xyz, vec3(12.9898, 78.233, 37.719)) + u_seed) * 43758.5453123);
}

float noise3D(vec3 st) {
    st += vec3(u_seed * 13.591, u_seed * 7.123, 0.0);
    vec3 i = floor(st);
    vec3 f = fract(st);
    float a = random3D(i);
    float b = random3D(i + vec3(1.0, 0.0, 0.0));
    float c = random3D(i + vec3(0.0, 1.0, 0.0));
    float d = random3D(i + vec3(1.0, 1.0, 0.0));
    float e = random3D(i + vec3(0.0, 0.0, 1.0));
    float f_corner = random3D(i + vec3(1.0, 0.0, 1.0));
    float g = random3D(i + vec3(0.0, 1.0, 1.0));
    float h = random3D(i + vec3(1.0, 1.0, 1.0));
    vec3 u = f * f * (3.0 - 2.0 * f);
    float ab = mix(a, b, u.x);
    float cd = mix(c, d, u.x);
    float ef = mix(e, f_corner, u.x);
    float gh = mix(g, h, u.x);
    float abcd = mix(ab, cd, u.y);
    float efgh = mix(ef, gh, u.y);
    return mix(abcd, efgh, u.z);
}

float structuralNoise(vec2 st, float t) {
    return noise3D(vec3(st, t));
}

float noise(vec2 st) {
    st += vec2(u_seed * 13.591, u_seed * 7.123);
    vec2 i = floor(st);
    vec2 f = fract(st);
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 st, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    const int MAX_OCTAVES = 8;
    for (int i = 0; i < MAX_OCTAVES; i++) {
        float weight = step(float(i) + 0.5, float(octaves));
        value += weight * amplitude * noise(st * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// ── Color functions ─────────────────────────────────────────────────

vec3 rgb2hsl(vec3 color) {
    float maxColor = max(max(color.r, color.g), color.b);
    float minColor = min(min(color.r, color.g), color.b);
    float delta = maxColor - minColor;
    float h = 0.0;
    float s = 0.0;
    float l = (maxColor + minColor) / 2.0;
    if (delta > 0.0) {
        s = l < 0.5 ? delta / (maxColor + minColor) : delta / (2.0 - maxColor - minColor);
        if (maxColor == color.r) {
            h = (color.g - color.b) / delta + (color.g < color.b ? 6.0 : 0.0);
        } else if (maxColor == color.g) {
            h = (color.b - color.r) / delta + 2.0;
        } else {
            h = (color.r - color.g) / delta + 4.0;
        }
        h /= 6.0;
    }
    return vec3(h, s, l);
}

float hue2rgb(float p, float q, float t) {
    float tt = t;
    if (tt < 0.0) tt += 1.0;
    if (tt > 1.0) tt -= 1.0;
    if (tt < 1.0 / 6.0) return p + (q - p) * 6.0 * tt;
    if (tt < 1.0 / 2.0) return q;
    if (tt < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - tt) * 6.0;
    return p;
}

vec3 hsl2rgb(vec3 hsl) {
    float h = hsl.x;
    float s = hsl.y;
    float l = hsl.z;
    float r, g, b;
    if (s < 0.001) {
        r = g = b = l;
    } else {
        float q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
        float p = 2.0 * l - q;
        r = hue2rgb(p, q, h + 1.0 / 3.0);
        g = hue2rgb(p, q, h);
        b = hue2rgb(p, q, h - 1.0 / 3.0);
    }
    return vec3(r, g, b);
}

vec4 increaseColorHue(vec4 color, float amount) {
    vec3 hsl = rgb2hsl(color.rgb);
    hsl.x += amount;
    hsl.x = fract(hsl.x);
    vec3 rgb = hsl2rgb(hsl);
    return vec4(rgb, color.a);
}

vec4 cycleColorHue(vec4 color, float speed) {
    bool isBlack = color.r < 0.01 && color.g < 0.01 && color.b < 0.01;
    bool isWhite = color.r > 0.99 && color.g > 0.99 && color.b > 0.99;
    if (isBlack || isWhite) return color;
    return increaseColorHue(color, speed);
}

vec4 createWithHueCycle(vec4 base, float time) {
    float cycleSpeed = CYCLE_COLOR_HUE_BASE_SPEED * (60.0 / TARGET_FPS);
    float amount = time * cycleSpeed;
    return increaseColorHue(base, amount);
}

vec4 createGradientBlock(vec2 st, bool horizontal) {
    float wavelength = pow(2.0, 6.0) + 0.2;
    vec4 base = vec4(1.0, 0.0, 1.0, 1.0);
    float amount = cos(PI / 2.0 + st.y * PI * wavelength) * 0.5 + 0.5;
    return increaseColorHue(base, amount);
}

// ── Main ────────────────────────────────────────────────────────────

void main() {
    vec2 st = FlutterFragCoord().xy / u_resolution;
    vec4 blankColor = vec4(BLANK_COLOR, 1.0);

    // Global freeze
    if (u_globalFreeze > 0.5) {
        vec4 color = texture(u_texture, st);
        bool isBgColor = abs(color.r - blankColor.r) < 0.01
                      && abs(color.g - blankColor.g) < 0.01
                      && abs(color.b - blankColor.b) < 0.01;
        if (!isBgColor) {
            float cycleSpeed = CYCLE_COLOR_HUE_BASE_SPEED * (60.0 / TARGET_FPS);
            color = cycleColorHue(color, cycleSpeed);
        }
        fragColor = color;
        return;
    }

    vec2 orgSt = st;
    float densityAdjustment = ceil(2.0 / u_pixelDensity);
    float time = u_time;
    float baseChunkSize = BASE_CHUNK_SIZE;
    bool useBlocking = BLOCKING > 0.0;
    vec2 blockingSt = useBlocking ? floor(st * BLOCKING) : st;
    bool onTick = true;
    float blockTime = floor(time * BLOCK_TIME_MULT);
    float moveTime = time * (TARGET_FPS / 30.0);
    float structuralMoveTime = u_manualMode > 0.5 ? 0.0 : moveTime * STRUCTURAL_TIME_MULT;
    float scaledChunkSize = baseChunkSize * u_pixelDensity;
    vec2 blockSize = vec2(scaledChunkSize / u_resolution.x, scaledChunkSize / u_resolution.y);
    vec2 maxValidCoord = vec2(1.0);
    float shouldMoveThreshold = SHOULD_MOVE_THRESHOLD;

    // Movement shape
    vec2 moveShapeSt = FX_WITH_BLOCKING ? blockingSt : st;
    moveShapeSt *= MOVE_SHAPE_SCALE;
    float moveContourNoise = noise(vec2(moveTime * MOVE_SHAPE_SPEED * 0.5, moveShapeSt.y * 0.05));
    float moveShapeContourMult = 5.0 + moveContourNoise * 5.0;
    float moveShapeContourStrength = (1.0 - moveContourNoise) * 0.2;
    float moveShapeContour = noise(vec2(moveShapeSt.y * moveShapeContourMult, moveTime * MOVE_SHAPE_SPEED * 0.5)) * moveShapeContourStrength;
    moveShapeSt.x += moveShapeContour;
    float moveNoise = structuralNoise(moveShapeSt + vec2(moveTime * MOVE_SHAPE_SPEED, 100.0), moveTime * MOVE_SHAPE_SPEED * 0.25);
    float direction = moveNoise < 0.5 ? -1.0 : 1.0;

    // Sample drawing buffer
    vec2 drawSt = (FX_WITH_BLOCKING && useBlocking) ? (floor(orgSt * BLOCKING) + 0.5) / BLOCKING : orgSt;
    vec4 drawColor = texture(u_drawTexture, drawSt);

    // Decode drawing modes
    bool shuffleMode = false, moveMode = false;
    float moveDirectionOverride = 0.0;
    if (drawColor.a >= DRAW_ACTIVE_THRESHOLD && drawColor.r >= DRAW_ACTIVE_THRESHOLD) {
        if (drawColor.r < DRAW_SHIFT_THRESHOLD) shuffleMode = true;
        else if (drawColor.r < DRAW_DIRECTION_THRESHOLD) { moveMode = true; moveDirectionOverride = -1.0; }
        else { moveMode = true; moveDirectionOverride = 1.0; }
    }

    bool trickleMode = false, waterfallMode = false;
    float fallDirectionOverride = 1.0;
    if (drawColor.a >= DRAW_ACTIVE_THRESHOLD && drawColor.g >= DRAW_ACTIVE_THRESHOLD) {
        if (drawColor.g < DRAW_SHIFT_THRESHOLD) trickleMode = true;
        else if (drawColor.g < DRAW_DIRECTION_THRESHOLD) { waterfallMode = true; fallDirectionOverride = 1.0; }
        else { waterfallMode = true; fallDirectionOverride = -1.0; }
    }

    bool freezeMode = false, resetMode = false;
    int resetVariant = 0;
    if (drawColor.a >= DRAW_ACTIVE_THRESHOLD && drawColor.b >= DRAW_ACTIVE_THRESHOLD) {
        if (drawColor.b < DRAW_SHIFT_THRESHOLD) freezeMode = true;
        else if (drawColor.b < DRAW_DIRECTION_THRESHOLD) {
            resetMode = true;
            float resetB = drawColor.b;
            if (resetB < 0.5625) resetVariant = 0;
            else if (resetB < 0.625) resetVariant = 1;
            else if (resetB < 0.6875) resetVariant = 2;
            else resetVariant = 3;
        }
    }

    if (moveDirectionOverride != 0.0) direction = moveDirectionOverride;
    bool shouldMove = moveNoise < shouldMoveThreshold || moveNoise > 1.0 - shouldMoveThreshold;
    shouldMove = shouldMove || moveMode;
    float moveSpeed = MOVE_SPEED;
    float moveAmount = 0.0;

    // Fall logic
    vec2 shouldFallSt = FX_WITH_BLOCKING ? blockingSt : st;
    shouldFallSt *= SHOULD_FALL_SCALE;
    float fallContourNoise = noise(vec2(shouldFallSt.x * 0.2, -moveTime * FALL_SHAPE_SPEED * 0.5));
    float fallShapeContourMult = 5.0 + fallContourNoise * 5.0;
    float fallShapeContourStrength = (1.0 - fallContourNoise) * 0.3;
    float fallShapeContour = noise(vec2(shouldFallSt.x * fallShapeContourMult, moveTime * FALL_SHAPE_SPEED * 0.5)) * fallShapeContourStrength;
    shouldFallSt.y += fallShapeContour;
    float shouldFallNoise = structuralNoise(shouldFallSt + vec2(20.124, moveTime * FALL_SHAPE_SPEED), moveTime * FALL_SHAPE_SPEED * 0.25);
    bool shouldFall = shouldFallNoise < SHOULD_FALL_THRESHOLD;
    shouldFall = shouldFall || waterfallMode;
    float fallDirection = waterfallMode ? fallDirectionOverride : 1.0;

    // Reset logic
    vec2 resetNoiseSt = (blockingSt + vec2(moveShapeContour, fallShapeContour)) * RESET_NOISE_SCALE;
    float resetNoise = structuralNoise(resetNoiseSt + 678.543, structuralMoveTime);
    bool willReset = resetNoise < RESET_THRESHOLD;

    // Extra moves
    vec2 extraMoveShapeSt = FX_WITH_BLOCKING ? blockingSt : st;
    float extraMoveTime = moveTime * MOVE_SHAPE_SPEED;
    float extraMoveShape = structuralNoise(extraMoveShapeSt * EXTRA_MOVE_SHAPE_SCALE - 1.345 + vec2(extraMoveTime * direction, 0.0), extraMoveTime);
    bool extraMoveStutter = random(floor(st * EXTRA_MOVE_STUTTER_SCALE) + moveTime + 1.49) < EXTRA_MOVE_STUTTER_THRESHOLD;
    bool inExtraMove = extraMoveShape < EXTRA_MOVE_SHAPE_THRESHOLD || shuffleMode;
    bool extraMoves = extraMoveStutter && inExtraMove;
    shouldMove = shouldMove || extraMoves;

    if (shouldMove && onTick) moveAmount = direction * moveSpeed * blockSize.x;

    float fallAmount = 0.0;
    float yFall = moveSpeed * blockSize.y;

    // Extra fall
    vec2 extraFallShapeSt = FX_WITH_BLOCKING ? blockingSt : st;
    extraFallShapeSt *= EXTRA_FALL_SHAPE_SCALE;
    float extraFallTime = moveTime * FALL_SHAPE_SPEED;
    float extraFallShape = structuralNoise(extraFallShapeSt + 1.123 + vec2(0.2, extraFallTime), extraFallTime * 0.25);
    bool extraFallStutter = random(floor(st * EXTRA_FALL_STUTTER_SCALE) + moveTime + 2.0) < EXTRA_FALL_STUTTER_THRESHOLD;
    bool inExtraFall = extraFallShape < EXTRA_FALL_SHAPE_THRESHOLD || trickleMode;
    bool extraFall = extraFallStutter && inExtraFall;
    shouldFall = shouldFall || extraFall;

    if (shouldFall && onTick) {
        float waterX = FX_WITH_BLOCKING ? blockingSt.x : floor(st.x * (u_resolution.x / 2.0));
        vec2 waterFallSt = vec2(waterX, floor(moveTime * 0.5));
        float waterFallSpeedMult = FALL_WATERFALL_MULT / 2.0;
        if (FALL_WATERFALL_MULT > 0.0) {
            float waterFallVariance = random(waterFallSt) * FALL_WATERFALL_MULT;
            waterFallSpeedMult *= waterFallVariance;
        }
        fallAmount = yFall + yFall * waterFallSpeedMult;
        fallAmount *= fallDirection;
    }

    // Apply freeze/movement
    if (freezeMode) { moveAmount = 0.0; fallAmount = 0.0; }
    if (onTick) {
        st.x += moveAmount * densityAdjustment;
        st.y += fallAmount * densityAdjustment;
    }

    // Boundary handling
    vec2 margin = (1.0 / u_resolution) * 2.0;
    bool isOutOfXBounds = (st.x >= maxValidCoord.x - margin.x || st.x <= margin.x);
    bool isOutOfYBounds = st.y >= maxValidCoord.y - margin.y || st.y <= margin.y;
    bool resetting = true;
    float wrappingTime = structuralMoveTime * 2.0;
    vec2 wrappingSt = blockingSt;
    bool isWrapping = (structuralNoise(wrappingSt * BLACK_NOISE_SCALE + 11.909, wrappingTime) < 0.5) ? (direction < 0.0) : (direction > 0.0);
    isWrapping = isWrapping || moveMode;
    if (isWrapping) resetting = false;

    bool useReset = false;
    if (isOutOfXBounds && shouldMove && onTick) {
        if (resetting) {
            float xSpeed = (150.0 * blockSize.x) * moveSpeed;
            if (direction < 0.0 && st.x < margin.x) { st.x -= xSpeed * moveTime; useReset = true; }
            if (direction > 0.0 && st.x > maxValidCoord.x - margin.x) { st.x += xSpeed * moveTime; useReset = true; }
        } else {
            if (direction < 0.0 && st.x < margin.x) st.x = maxValidCoord.x - st.x;
            if (direction > 0.0 && st.x > maxValidCoord.x - margin.x) st.x = mod(st.x + margin.x, maxValidCoord.x);
        }
    }

    if (isOutOfYBounds && shouldFall && onTick) {
        if (fallDirection < 0.0 && st.y < margin.y) st.y = maxValidCoord.y - st.y;
        if (fallDirection > 0.0 && st.y > maxValidCoord.y - margin.y) st.y = mod(st.y + margin.y, maxValidCoord.y);
    }

    blockingSt = useBlocking ? floor(st * BLOCKING) : st;
    vec2 blockFloor = floor(st / blockSize);
    vec2 blockFract = fract(st / blockSize);
    vec4 initColor = vec4(1.0);

    float blackNoiseEdge = random(st.y + vec2(10.45)) * BLACK_NOISE_EDGE_MULT;
    float blackNoise = structuralNoise(blockingSt * BLACK_NOISE_SCALE + 1000.0, structuralMoveTime) + blackNoiseEdge;
    bool useBlack = blackNoise < BLACK_NOISE_THRESHOLD;
    float ribbonNoise = structuralNoise(blockingSt * BLACK_NOISE_SCALE - 2000.0, structuralMoveTime) - blackNoiseEdge;
    bool useRibbon = ribbonNoise < USE_RIBBON_THRESHOLD;

    // Reset variant overrides
    if (resetMode) {
        if (resetVariant == 1) useBlack = true;
        else if (resetVariant == 2) { useBlack = false; useRibbon = false; }
        else if (resetVariant == 3) { useBlack = false; useRibbon = true; }
    }

    bool useBlankStatic = random(st * BLANK_STATIC_SCALE + floor(cos(moveTime * 10.123) * BLANK_STATIC_TIME_MULT + sin(moveTime * 1.05) * BLANK_STATIC_TIME_MULT) + 1.0) < BLANK_STATIC_THRESHOLD;
    bool useBlank = (useBlankStatic && !useRibbon) || useBlack;

    if (useBlank) {
        initColor = blankColor;
    } else {
        vec2 dirtNoiseSt = floor(st * DIRT_NOISE_SCALE);
        float rnd = random(dirtNoiseSt + blockTime);
        float blockRnd = random(dirtNoiseSt + blockTime + 10.24);
        bool useBlock = useRibbon && blockRnd < RIBBON_DIRT_THRESHOLD;
        vec2 stPlus = st / blockSize;
        if (useBlock) {
            initColor = createGradientBlock(stPlus, isWrapping);
        } else {
            if (rnd < 0.25) initColor = createGradientBlock(stPlus, isWrapping);
            else if (rnd < 0.5) initColor = vec4(STATIC_COLOR_1, 1.0);
            else if (rnd < 0.75) initColor = vec4(STATIC_COLOR_2, 1.0);
            else initColor = vec4(STATIC_COLOR_3, 1.0);
        }
        initColor = createWithHueCycle(initColor, u_frameCount + PI);
    }

    if (resetMode) willReset = true;
    bool resetEdge = onTick && random(2.0 * st + fract(moveTime)) < RESET_EDGE_THRESHOLD;
    bool naturalReset = !shouldMove && !shouldFall && willReset;
    if ((naturalReset || resetMode) && resetEdge) useReset = true;
    if (u_forceReset > 0.5) useReset = true;
    if (freezeMode) useReset = false;

    // Sample previous state
    vec4 color = texture(u_texture, st);
    if (color.a < 0.025 || useReset) {
        fragColor = initColor;
        return;
    }

    bool isBgColor = abs(color.r - blankColor.r) < 0.01 && abs(color.g - blankColor.g) < 0.01 && abs(color.b - blankColor.b) < 0.01;
    if (!isBgColor && onTick) {
        float cycleSpeed = CYCLE_COLOR_HUE_BASE_SPEED * (60.0 / TARGET_FPS);
        color = cycleColorHue(color, cycleSpeed);
    }

    if (USE_GRAYSCALE) color.rgb = vec3(0.299 * color.r + 0.587 * color.g + 0.114 * color.b);

    fragColor = color;
}
