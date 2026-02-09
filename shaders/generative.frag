// tech-Tonic generative fragment shader — Flutter GLSL port
// Ported from fragmentShader.glsl (770-line WebGL version)
#include <flutter/runtime_effect.glsl>

// ── Float uniforms (accessed via setFloat by index order) ────────
uniform vec2 u_resolution;        // 0,1
uniform float u_time;             // 2
uniform float u_pixelDensity;     // 3
uniform float u_frameCount;       // 4
uniform float u_displayFps;       // 5
uniform float u_seed;             // 6
uniform float u_targetFps;        // 7
uniform float u_baseChunkSize;    // 8
uniform float u_shouldMoveThreshold; // 9
uniform float u_moveSpeed;        // 10
uniform vec2 u_moveShapeScale;    // 11,12
uniform float u_moveShapeSpeed;   // 13
uniform float u_resetThreshold;   // 14
uniform float u_resetEdgeThreshold; // 15
uniform vec2 u_resetNoiseScale;   // 16,17
uniform float u_shouldFallThreshold; // 18
uniform vec2 u_shouldFallScale;   // 19,20
uniform float u_fallShapeSpeed;   // 21
uniform float u_fxWithBlocking;   // 22 (bool→float)
uniform float u_blockTimeMult;    // 23
uniform float u_structuralTimeMult; // 24
uniform float u_extraMoveShapeThreshold; // 25
uniform vec2 u_extraMoveStutterScale; // 26,27
uniform float u_extraMoveStutterThreshold; // 28
uniform float u_extraFallShapeThreshold; // 29
uniform vec2 u_extraFallStutterScale; // 30,31
uniform float u_extraFallStutterThreshold; // 32
uniform float u_fallWaterfallMult; // 33
uniform vec2 u_extraFallShapeScale; // 34,35
uniform float u_extraFallShapeTimeMult; // 36
uniform float u_blocking;         // 37
uniform vec2 u_blackNoiseScale;   // 38,39
uniform float u_blackNoiseEdgeMult; // 40
uniform float u_blackNoiseThreshold; // 41
uniform float u_useRibbonThreshold; // 42
uniform vec2 u_dirtNoiseScale;    // 43,44
uniform float u_ribbonDirtThreshold; // 45
uniform vec2 u_blankStaticScale;  // 46,47
uniform float u_blankStaticThreshold; // 48
uniform float u_blankStaticTimeMult; // 49
uniform vec3 u_blankColor;        // 50,51,52
uniform float u_useGrayscale;     // 53 (bool→float)
uniform vec3 u_staticColor1;      // 54,55,56
uniform vec3 u_staticColor2;      // 57,58,59
uniform vec3 u_staticColor3;      // 60,61,62
uniform vec2 u_extraMoveShapeScale; // 63,64
uniform float u_cycleColorHueSpeed; // 65
uniform float u_globalFreeze;     // 66
uniform float u_forceReset;       // 67
uniform float u_manualMode;       // 68

// ── Sampler uniforms (accessed via setImageSampler) ─────────────
uniform sampler2D u_texture;      // sampler 0 — previous frame
uniform sampler2D u_drawTexture;  // sampler 1 — drawing buffer

// ── Output ──────────────────────────────────────────────────────
out vec4 fragColor;

// ── Constants ───────────────────────────────────────────────────
const float PI = 3.14159265;
const float DRAW_ACTIVE_THRESHOLD = 0.25;
const float DRAW_SHIFT_THRESHOLD = 0.5;
const float DRAW_DIRECTION_THRESHOLD = 0.75;

// ── Noise functions ─────────────────────────────────────────────

float random(vec2 st) {
    float seed = u_seed;
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233)) + seed) * 43758.5453123);
}

float seededRandom(vec2 st, float seed) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233)) + seed) * 43758.5453123);
}

float random3D(vec3 st) {
    float seed = u_seed;
    return fract(sin(dot(st.xyz, vec3(12.9898, 78.233, 37.719)) + seed) * 43758.5453123);
}

float noise3D(vec3 st) {
    float seed = u_seed;
    st += vec3(seed * 13.591, seed * 7.123, 0.0);

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
    float seed = u_seed;
    st += vec2(seed * 13.591, seed * 7.123);

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

    // Flutter GLSL: use step() accumulation instead of dynamic break
    const int MAX_OCTAVES = 8;
    for (int i = 0; i < MAX_OCTAVES; i++) {
        float weight = step(float(i) + 0.5, float(octaves));
        value += weight * amplitude * noise(st * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

// ── Color functions ─────────────────────────────────────────────

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
    // Use tolerance instead of exact equality
    bool isBlack = color.r < 0.01 && color.g < 0.01 && color.b < 0.01;
    bool isWhite = color.r > 0.99 && color.g > 0.99 && color.b > 0.99;
    if (isBlack || isWhite) {
        return color;
    }
    return increaseColorHue(color, speed);
}

vec4 createWithHueCycle(vec4 base, float time) {
    float amount = time * u_cycleColorHueSpeed;
    return increaseColorHue(base, amount);
}

// ── Gradient block ──────────────────────────────────────────────

vec4 createGradientBlock(vec2 st, bool horizontal) {
    float wavelength = pow(2.0, 6.0) + 0.2;
    vec4 base = vec4(1.0, 1.0, 1.0, 1.0);
    float amount = 0.0;

    // Always horizontal (matching original)
    base = vec4(1.0, 0.0, 1.0, 1.0);
    amount = cos(PI / 2.0 + st.y * PI * wavelength) * 0.5 + 0.5;

    base = increaseColorHue(base, amount);
    return base;
}

float roundVal(float x) {
    if (fract(x) < 0.5) {
        return floor(x);
    } else {
        return ceil(x);
    }
}

// ── Main ────────────────────────────────────────────────────────

void main() {
    // Compute normalized texture coordinates from FlutterFragCoord
    vec2 st = FlutterFragCoord().xy / u_resolution;
    vec4 blankColor = vec4(u_blankColor, 1.0);

    // Global freeze: stop all movement but keep color cycling
    if (u_globalFreeze > 0.5) {
        vec4 color = texture(u_texture, st);
        // Use tolerance for bg comparison
        bool isBgColor = abs(color.r - blankColor.r) < 0.01
                      && abs(color.g - blankColor.g) < 0.01
                      && abs(color.b - blankColor.b) < 0.01;

        if (!isBgColor) {
            color = cycleColorHue(color, u_cycleColorHueSpeed);
        }

        fragColor = color;
        return;
    }

    vec2 orgSt = st;

    float densityAdjustment = ceil(2.0 / u_pixelDensity);

    float time = u_time;
    float baseChunkSize = u_baseChunkSize;

    bool useBlocking = u_blocking > 0.0;

    vec2 blockingSt = useBlocking ? floor(st * u_blocking) : st;

    float targetFps = u_targetFps;

    bool onTick = true;

    float blockTime = floor(time * u_blockTimeMult);

    float moveTime = time * (u_targetFps / 30.0);
    float structuralMoveTime = u_manualMode > 0.5 ? 0.0 : moveTime * u_structuralTimeMult;

    float scaledChunkSize = baseChunkSize * u_pixelDensity;

    vec2 blockSize = vec2(
        scaledChunkSize / u_resolution.x,
        scaledChunkSize / u_resolution.y
    );

    vec2 maxValidCoord = vec2(1.0);

    float shouldMoveThreshold = u_shouldMoveThreshold;

    vec2 moveShapeSt = u_fxWithBlocking > 0.5 ? blockingSt : st;
    moveShapeSt *= u_moveShapeScale;

    float moveContourNoise = noise(vec2(moveTime * u_moveShapeSpeed * 0.5, moveShapeSt.y * 0.05));
    float moveShapeContourMult = 5.0 + moveContourNoise * 5.0;
    float moveShapeContourStrength = (1.0 - moveContourNoise) * 0.2;
    float moveShapeContour = noise(vec2(moveShapeSt.y * moveShapeContourMult, moveTime * u_moveShapeSpeed * 0.5)) * moveShapeContourStrength;
    moveShapeSt.x += moveShapeContour;

    float moveNoise = structuralNoise(moveShapeSt + vec2(moveTime * u_moveShapeSpeed, 100.0), moveTime * u_moveShapeSpeed * 0.25);
    float direction = moveNoise < 0.5 ? -1.0 : 1.0;

    // Sample drawing buffer for mode detection
    vec2 drawSt;
    if (u_fxWithBlocking > 0.5 && useBlocking) {
        drawSt = (floor(orgSt * u_blocking) + 0.5) / u_blocking;
    } else {
        drawSt = orgSt;
    }
    vec4 drawColor = texture(u_drawTexture, drawSt);

    // Decode R channel (move/shuffle)
    bool shuffleMode = false;
    bool moveMode = false;
    float moveDirectionOverride = 0.0;

    if (drawColor.a >= DRAW_ACTIVE_THRESHOLD && drawColor.r >= DRAW_ACTIVE_THRESHOLD) {
        if (drawColor.r < DRAW_SHIFT_THRESHOLD) {
            shuffleMode = true;
        } else if (drawColor.r < DRAW_DIRECTION_THRESHOLD) {
            moveMode = true;
            moveDirectionOverride = -1.0;
        } else {
            moveMode = true;
            moveDirectionOverride = 1.0;
        }
    }

    // Decode G channel (waterfall/trickle)
    bool trickleMode = false;
    bool waterfallMode = false;
    float fallDirectionOverride = 1.0;

    if (drawColor.a >= DRAW_ACTIVE_THRESHOLD && drawColor.g >= DRAW_ACTIVE_THRESHOLD) {
        if (drawColor.g < DRAW_SHIFT_THRESHOLD) {
            trickleMode = true;
        } else if (drawColor.g < DRAW_DIRECTION_THRESHOLD) {
            waterfallMode = true;
            fallDirectionOverride = 1.0;
        } else {
            waterfallMode = true;
            fallDirectionOverride = -1.0;
        }
    }

    // Decode B channel (freeze/reset)
    bool freezeMode = false;
    bool resetMode = false;
    int resetVariant = 0;

    if (drawColor.a >= DRAW_ACTIVE_THRESHOLD && drawColor.b >= DRAW_ACTIVE_THRESHOLD) {
        if (drawColor.b < DRAW_SHIFT_THRESHOLD) {
            freezeMode = true;
        } else if (drawColor.b < DRAW_DIRECTION_THRESHOLD) {
            resetMode = true;
            float resetB = drawColor.b;
            if (resetB < 0.5625) {
                resetVariant = 0;
            } else if (resetB < 0.625) {
                resetVariant = 1;
            } else if (resetB < 0.6875) {
                resetVariant = 2;
            } else {
                resetVariant = 3;
            }
        }
    }

    // Override direction if move mode is active from drawing
    if (moveDirectionOverride != 0.0) {
        direction = moveDirectionOverride;
    }

    bool shouldMove = moveNoise < shouldMoveThreshold || moveNoise > 1.0 - shouldMoveThreshold;
    shouldMove = shouldMove || moveMode;

    float moveSpeed = u_moveSpeed;
    float moveAmount = 0.0;

    // FALL
    vec2 shouldFallSt = u_fxWithBlocking > 0.5 ? blockingSt : st;
    shouldFallSt *= u_shouldFallScale;

    float fallContourNoise = noise(vec2(shouldFallSt.x * 0.2, -moveTime * u_fallShapeSpeed * 0.5));
    float fallShapeContourMult = 5.0 + fallContourNoise * 5.0;
    float fallShapeContourStrength = (1.0 - fallContourNoise) * 0.3;
    float fallShapeContour = noise(vec2(shouldFallSt.x * fallShapeContourMult, moveTime * u_fallShapeSpeed * 0.5)) * fallShapeContourStrength;
    shouldFallSt.y += fallShapeContour;
    float shouldFallNoise = structuralNoise(
        shouldFallSt + vec2(20.124, moveTime * u_fallShapeSpeed),
        moveTime * u_fallShapeSpeed * 0.25);
    bool shouldFall = shouldFallNoise < u_shouldFallThreshold;
    shouldFall = shouldFall || waterfallMode;

    float fallDirection = 1.0;
    if (waterfallMode) {
        fallDirection = fallDirectionOverride;
    }

    vec2 resetNoiseSt = (blockingSt + vec2(moveShapeContour, fallShapeContour)) * u_resetNoiseScale;
    float resetNoise = structuralNoise(resetNoiseSt + 678.543, structuralMoveTime);

    bool willReset = resetNoise < u_resetThreshold;

    // EXTRA MOVES
    vec2 extraMoveShapeSt = u_fxWithBlocking > 0.5 ? blockingSt : st;
    float extraMoveTime = moveTime * u_moveShapeSpeed;
    float extraMoveShape = structuralNoise(extraMoveShapeSt * u_extraMoveShapeScale - 1.345 + vec2(extraMoveTime * direction, 0.0), extraMoveTime);

    bool extraMoveStutter = random(floor(st * u_extraMoveStutterScale) + moveTime + 1.49) < u_extraMoveStutterThreshold;
    bool inExtraMove = extraMoveShape < u_extraMoveShapeThreshold;
    inExtraMove = inExtraMove || shuffleMode;
    bool extraMoves = extraMoveStutter && inExtraMove;

    shouldMove = shouldMove || extraMoves;

    if (shouldMove && onTick) {
        moveAmount = direction * moveSpeed * blockSize.x;
    }

    float fallAmount = 0.0;
    float yFall = moveSpeed * blockSize.y;

    // EXTRA FALL
    vec2 extraFallShapeSt = u_fxWithBlocking > 0.5 ? blockingSt : st;
    extraFallShapeSt *= u_extraFallShapeScale;

    float extraFallTime = moveTime * u_fallShapeSpeed;

    float extraFallShape = structuralNoise(
        extraFallShapeSt + 1.123 + vec2(0.2, extraFallTime),
        extraFallTime * 0.25);
    bool extraFallStutter = random(floor(st * u_extraFallStutterScale) + moveTime + 2.0) < u_extraFallStutterThreshold;
    bool inExtraFall = extraFallShape < u_extraFallShapeThreshold;
    inExtraFall = inExtraFall || trickleMode;
    bool extraFall = extraFallStutter && inExtraFall;

    shouldFall = shouldFall || extraFall;

    if (shouldFall && onTick) {
        float waterX = u_fxWithBlocking > 0.5 ? blockingSt.x : floor(st.x * (u_resolution.x / 2.0));
        vec2 waterFallSt = vec2(waterX, floor(moveTime * 0.5));

        float waterFallSpeedMult = u_fallWaterfallMult / 2.0;

        if (u_fallWaterfallMult > 0.0) {
            float waterFallVariance = random(waterFallSt) * u_fallWaterfallMult;
            waterFallSpeedMult *= waterFallVariance;
        }

        fallAmount = yFall + yFall * waterFallSpeedMult;
        fallAmount *= fallDirection;
    }

    // Apply freeze mode
    if (freezeMode) {
        moveAmount = 0.0;
        fallAmount = 0.0;
    }

    // Apply movement
    if (onTick) {
        st.x += moveAmount * densityAdjustment;
        st.y += fallAmount * densityAdjustment;
    }

    // Margin for boundary detection
    vec2 margin = (1.0 / u_resolution) * 2.0;
    bool isOutOfXBounds = (st.x >= maxValidCoord.x - margin.x || st.x <= margin.x);
    bool isOutOfYBounds = st.y >= maxValidCoord.y - margin.y || st.y <= margin.y;
    bool isOutOfBounds = isOutOfXBounds || isOutOfYBounds;

    bool isOutOfXFrame = st.x < 0.0 || st.x > maxValidCoord.x;
    bool isOutOfYFrame = st.y < 0.0 || st.y > maxValidCoord.y;

    bool resetting = true;

    // Wrapping logic
    float wrappingTime = structuralMoveTime * 2.0;
    vec2 wrappingSt = blockingSt;
    bool isWrapping = (structuralNoise(wrappingSt * u_blackNoiseScale + 11.909, wrappingTime) < 0.5)
        ? (direction < 0.0)
        : (direction > 0.0);

    isWrapping = isWrapping || moveMode;

    if (isWrapping) {
        resetting = false;
    }

    bool useReset = false;

    if (isOutOfXBounds) {
        if (shouldMove && onTick) {
            if (resetting) {
                float xSpeed = (150.0 * blockSize.x) * moveSpeed;

                if (direction < 0.0 && st.x < margin.x) {
                    st.x -= xSpeed * moveTime;
                    useReset = true;
                }
                if (direction > 0.0 && st.x > maxValidCoord.x - margin.x) {
                    st.x += xSpeed * moveTime;
                    useReset = true;
                }
            } else {
                if (direction < 0.0 && st.x < margin.x) {
                    st.x = maxValidCoord.x - st.x;
                }
                if (direction > 0.0 && st.x > maxValidCoord.x - margin.x) {
                    st.x = mod(st.x + margin.x, maxValidCoord.x);
                }
            }
        }
    }

    if (isOutOfYBounds) {
        if (shouldFall && onTick) {
            if (fallDirection < 0.0 && st.y < margin.y) {
                st.y = maxValidCoord.y - st.y;
            }
            if (fallDirection > 0.0 && st.y > maxValidCoord.y - margin.y) {
                st.y = mod(st.y + margin.y, maxValidCoord.y);
            }
        }
    }

    blockingSt = useBlocking ? floor(st * u_blocking) : st;

    vec2 blockFloor = floor(st / blockSize);
    vec2 blockFract = fract(st / blockSize);

    vec4 initColor = vec4(1.0);

    float blackNoiseEdge = random(st.y + vec2(10.45)) * u_blackNoiseEdgeMult;

    float blackNoise = structuralNoise(blockingSt * u_blackNoiseScale + 1000.0, structuralMoveTime) + blackNoiseEdge;

    bool useBlack = blackNoise < u_blackNoiseThreshold;

    float ribbonNoise = structuralNoise(blockingSt * u_blackNoiseScale - 2000.0, structuralMoveTime) - blackNoiseEdge;
    bool useRibbon = ribbonNoise < u_useRibbonThreshold;

    // Apply reset variant overrides
    if (resetMode) {
        if (resetVariant == 1) {
            useBlack = true;
        } else if (resetVariant == 2) {
            useBlack = false;
            useRibbon = false;
        } else if (resetVariant == 3) {
            useBlack = false;
            useRibbon = true;
        }
    }

    bool useBlankStatic = random(st * u_blankStaticScale + floor(
        cos(moveTime * 10.123) * u_blankStaticTimeMult +
        sin(moveTime * 1.05) * u_blankStaticTimeMult) + 1.0) < u_blankStaticThreshold;
    bool useBlank = (useBlankStatic && !useRibbon) || useBlack;

    if (useBlank) {
        initColor = blankColor;
    } else {
        vec2 dirtNoiseSt = floor(st * u_dirtNoiseScale);
        float rnd = random(dirtNoiseSt + blockTime);
        float blockRnd = random(dirtNoiseSt + blockTime + 10.24);

        bool useBlock = useRibbon && blockRnd < u_ribbonDirtThreshold;

        vec2 stPlus = st / blockSize;
        if (useBlock) {
            initColor = createGradientBlock(stPlus, isWrapping);
        } else {
            if (rnd < 0.25) {
                initColor = createGradientBlock(stPlus, isWrapping);
            } else if (rnd < 0.5) {
                initColor = vec4(u_staticColor1, 1.0);
            } else if (rnd < 0.75) {
                initColor = vec4(u_staticColor2, 1.0);
            } else {
                initColor = vec4(u_staticColor3, 1.0);
            }
        }

        initColor = createWithHueCycle(initColor, u_frameCount + PI);
    }

    // Apply reset mode override
    if (resetMode) {
        willReset = true;
    }

    float resetEdgeThreshold = u_resetEdgeThreshold;
    bool resetEdge = onTick && random(2.0 * st + fract(moveTime)) < resetEdgeThreshold;

    bool naturalReset = !shouldMove && !shouldFall && willReset;

    if ((naturalReset || resetMode) && resetEdge) {
        useReset = true;
    }

    // Force reset override
    if (u_forceReset > 0.5) {
        useReset = true;
    }

    // Freeze mode overrides reset
    if (freezeMode) {
        useReset = false;
    }

    // Sample from the previous state with the calculated coordinates
    vec4 color = texture(u_texture, st);

    // Reset or init
    if (color.a < 0.025 || useReset) {
        fragColor = initColor;
        return;
    }

    // Use tolerance for bg comparison
    bool isBgColor = abs(color.r - blankColor.r) < 0.01
                  && abs(color.g - blankColor.g) < 0.01
                  && abs(color.b - blankColor.b) < 0.01;

    if (!isBgColor && onTick) {
        color = cycleColorHue(color, u_cycleColorHueSpeed);
    }

    // Grayscale conversion
    if (u_useGrayscale > 0.5) {
        color.rgb = vec3(0.299 * color.r + 0.587 * color.g + 0.114 * color.b);
    }

    fragColor = color;
}
