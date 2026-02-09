precision mediump float;

uniform sampler2D u_texture;
uniform vec2 u_resolution;
uniform float u_time;
uniform float u_pixelDensity, u_frameCount, u_displayFps;
uniform float u_seed;
uniform float u_targetFps;
uniform float u_baseChunkSize;
uniform float u_shouldMoveThreshold;
uniform float u_moveSpeed;
uniform vec2 u_moveShapeScale;
uniform float u_moveShapeSpeed;
uniform float u_resetThreshold;
uniform float u_resetEdgeThreshold;
uniform vec2 u_resetNoiseScale;
uniform float u_shouldFallThreshold;
uniform vec2 u_shouldFallScale;
uniform float u_fallShapeSpeed;
uniform bool u_fxWithBlocking;
uniform float u_blockTimeMult;
uniform float u_structuralTimeMult;
uniform float u_extraMoveShapeThreshold;
uniform vec2 u_extraMoveStutterScale;
uniform float u_extraMoveStutterThreshold;
uniform float u_extraFallShapeThreshold;
uniform vec2 u_extraFallStutterScale;
uniform float u_extraFallStutterThreshold;
uniform float u_fallWaterfallMult;
uniform vec2 u_extraFallShapeScale;
uniform float u_extraFallShapeTimeMult;
uniform float u_blocking;
uniform vec2 u_blackNoiseScale;
uniform float u_blackNoiseEdgeMult;
uniform float u_blackNoiseThreshold;
uniform float u_useRibbonThreshold;
uniform vec2 u_dirtNoiseScale;
uniform float u_ribbonDirtThreshold;
uniform vec2 u_blankStaticScale;
uniform float u_blankStaticThreshold;
uniform float u_blankStaticTimeMult;
uniform vec3 u_blankColor;
uniform bool u_useGrayscale;
uniform vec3 u_staticColor1;
uniform vec3 u_staticColor2;
uniform vec3 u_staticColor3;
uniform vec2 u_extraMoveShapeScale;
uniform float u_cycleColorHueSpeed;
uniform float u_globalFreeze;
uniform float u_forceReset;
uniform float u_manualMode;
uniform sampler2D u_drawTexture;


varying vec2 v_texCoord;

// Using a shorter PI constant to avoid precision issues
const float PI = 3.14159265;

// Drawing buffer color detection thresholds
// R channel: <0.25=off, 0.25-0.5=shuffle, 0.5-0.75=move left, 0.75+=move right
// G channel: <0.25=off, 0.25-0.5=trickle, 0.5-0.75=waterfall down, 0.75+=waterfall up
// B channel: <0.25=off, 0.25-0.5=freeze, 0.5-0.75=reset
const float DRAW_ACTIVE_THRESHOLD = 0.25;
const float DRAW_SHIFT_THRESHOLD = 0.5;
const float DRAW_DIRECTION_THRESHOLD = 0.75;


//IDEAS: 
// - Have the fall noise decrease and move noise increase, in a sin wave aptter so the piece climaxes and relaxes
//loops to be filled with cool patterns and slow down, less new material, then the oposite  , new only material, faster, more black and reseting
//twice a day, a "snapshot" is taken and saved 

// Add drawing canvas where different colors trigger different behaviors (eg black is fall, red is move horizontal, white resets, eetc and you can clear the canvas in brushes too )


// A pseudo-random function
float random(vec2 st) {
    float seed = u_seed;
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233)) + seed) * 43758.5453123);
}

// A seeded random function that accepts a custom seed value
float seededRandom(vec2 st, float seed) {
    // Add the seed to the dot product calculation
    // The seed should generally be in range [0, 1000] for good distribution
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233)) + seed) * 43758.5453123);
}

// 3D random function matching the 2D random style
float random3D(vec3 st) {
    float seed = u_seed;
    return fract(sin(dot(st.xyz, vec3(12.9898, 78.233, 37.719)) + seed) * 43758.5453123);
}

// 3D noise function matching the 2D noise style
float noise3D(vec3 st) {
    float seed = u_seed;
    st += vec3(seed * 13.591, seed * 7.123, 0.0);

    vec3 i = floor(st);
    vec3 f = fract(st);
    
    // Eight corners of a cube in 3D
    float a = random3D(i);
    float b = random3D(i + vec3(1.0, 0.0, 0.0));
    float c = random3D(i + vec3(0.0, 1.0, 0.0));
    float d = random3D(i + vec3(1.0, 1.0, 0.0));
    float e = random3D(i + vec3(0.0, 0.0, 1.0));
    float f_corner = random3D(i + vec3(1.0, 0.0, 1.0));
    float g = random3D(i + vec3(0.0, 1.0, 1.0));
    float h = random3D(i + vec3(1.0, 1.0, 1.0));
    
    // Smooth interpolation
    vec3 u = f * f * (3.0 - 2.0 * f); // Cubic Hermite curve
    
    // Interpolate along x
    float ab = mix(a, b, u.x);
    float cd = mix(c, d, u.x);
    float ef = mix(e, f_corner, u.x);
    float gh = mix(g, h, u.x);
    
    // Interpolate along y
    float abcd = mix(ab, cd, u.y);
    float efgh = mix(ef, gh, u.y);
    
    // Interpolate along z
    return mix(abcd, efgh, u.z);
}

// 3D structural noise - takes 2D coordinates and uses uniform z value
float structuralNoise(vec2 st, float t) {
    vec3 st3D = vec3(st, t);
    return noise3D(st3D);
}

// Simplified Perlin noise function
float noise(vec2 st) {
    float seed = u_seed;
    st += vec2(seed * 13.591, seed * 7.123);

    vec2 i = floor(st);
    vec2 f = fract(st);
    
    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    
    // Smooth interpolation
    vec2 u = f * f * (3.0 - 2.0 * f); // Cubic Hermite curve
    
    // Mix 4 corners percentages
    return mix(mix(a, b, u.x),
               mix(c, d, u.x), u.y);
}

// Function to get smoother noise at different scales
float fbm(vec2 st, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    // Add octaves of noise with different frequencies
    // Using a fixed maximum number of octaves and breaking early if needed
    const int MAX_OCTAVES = 8; // Define a constant maximum
    for(int i = 0; i < MAX_OCTAVES; i++) {
        if(i >= octaves) break; // Break early if we've reached the desired number of octaves
        value += amplitude * noise(st * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}


//HUE FUNCTIONS
// Function to convert RGB to HSL
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

// Helper function for HSL to RGB conversion
float hue2rgb(float p, float q, float t) {
    if (t < 0.0) t += 1.0;
    if (t > 1.0) t -= 1.0;
    if (t < 1.0/6.0) return p + (q - p) * 6.0 * t;
    if (t < 1.0/2.0) return q;
    if (t < 2.0/3.0) return p + (q - p) * (2.0/3.0 - t) * 6.0;
    return p;
}

// Function to convert HSL to RGB
vec3 hsl2rgb(vec3 hsl) {
    float h = hsl.x;
    float s = hsl.y;
    float l = hsl.z;
    
    float r, g, b;
    
    if (s == 0.0) {
        r = g = b = l; // Achromatic (grey)
    } else {
        float q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
        float p = 2.0 * l - q;
        
        r = hue2rgb(p, q, h + 1.0/3.0);
        g = hue2rgb(p, q, h);
        b = hue2rgb(p, q, h - 1.0/3.0);
    }
    
    return vec3(r, g, b);
}



// Function to increase color by moving through the color wheel
vec4 increaseColorHue(vec4 color, float amount) {
    // Convert RGB to HSL
    vec3 hsl = rgb2hsl(color.rgb);
    
    // Increment hue (move through color wheel)
    hsl.x += amount; // Speed of color rotation
    hsl.x = fract(hsl.x); // Ensure hue is in [0,1] range
    
    // Convert back to RGB
    vec3 rgb = hsl2rgb(hsl);
    
    // Return the new color with preserved alpha
    return vec4(rgb, color.a);
}

vec4 cycleColorHue(vec4 color, float speed) {
    //if black or white color, return the color
    bool isBlack = color.r == 0. && color.g == 0. && color.b == 0.;
    bool isWhite = color.r == 1. && color.g == 1. && color.b == 1.;
    if (isBlack || isWhite) {
        return color;
    }

    return increaseColorHue(color, speed);
}

vec4 createWithHueCycle(vec4 base, float time) {

  float amount = time * u_cycleColorHueSpeed;
  return increaseColorHue(base, amount);
}

// Function to create a gradient pattern within a block
vec4 createGradientBlock(vec2 st, bool horizontal) {
  // start with red to orange gradient
  //TODO check this on monitor
  float wavelength = pow(2., 6.) + .2;

  vec4 base = vec4(1., 1., 1., 1.0);
  float amount = 0.;

//skipping vert for now
  horizontal = true;

  if(horizontal) {
    base = vec4(1., 0.,1., 1.0);
    amount = cos(PI/2. + st.y * PI * wavelength) * 0.5 + 0.5; // Amount to increase hue
  } else {
    float y = st.y ;
    base = vec4(y,0., 1., 1.0);
    amount = cos(PI/2. + st.x * PI * wavelength) * 0.5 + 0.5; // Amount to increase hue
  }
  base = increaseColorHue(base, amount);

  return base;
}

float round(float x) {
  if(fract(x) < 0.5) {
    return floor(x);
  } else {
    return ceil(x);
  }
}

void main() {
    vec2 st = v_texCoord;
    vec4 blankColor = vec4(u_blankColor, 1.);


    // Global freeze: stop all movement but keep color cycling
    if (u_globalFreeze > 0.5) {

      vec4 color = texture2D(u_texture, st);
      bool isBgColor = color == blankColor;

      if(!isBgColor) {
        // Apply time-based color animation with wrapping to colors (other thank bg)
        color = cycleColorHue(color, u_cycleColorHueSpeed);
      }
    
      gl_FragColor = color;
      return;
    }

    vec2 orgSt = st; // Store original texture coordinates for later use
    
    float densityAdjustment = ceil(2. / u_pixelDensity);

    float time = u_time; //in seconds
    float baseChunkSize = u_baseChunkSize;

    bool useBlocking = u_blocking > 0.0;

    vec2 blockingSt = useBlocking ? floor(st * u_blocking) : st;

    float targetFps = u_targetFps;


//using actualy frame rate manipulation// keeping this code just in case though it seems to work fine without it
    bool onTick = true;//mod(targetFps + u_frameCount * densityAdjustment, floor((u_displayFps * densityAdjustment) / targetFps)) == 0.;
    
    float blockTime = floor(time * u_blockTimeMult);

    float moveTime = time * (u_targetFps / 30.);
    // Freeze structural time in manual mode so reset shape doesn't move
    float structuralMoveTime = u_manualMode > 0.5 ? 0.0 : moveTime * u_structuralTimeMult; 


    // baseChunkSize is in CSS pixels, u_resolution is in actual pixels (already scaled by pixel density)
    // Scale baseChunkSize to actual pixels to match the resolution coordinate space
    float scaledChunkSize = baseChunkSize * u_pixelDensity;

    // Create normalized block sizes that account for aspect ratio to maintain square chunks
    vec2 blockSize = vec2(
      scaledChunkSize / u_resolution.x,  // Width component 
      scaledChunkSize / u_resolution.y   // Height component
    );

    // Calculate the maximum valid texture coordinate (right/bottom boundary)
    vec2 maxValidCoord = vec2(1.);

    // Determine if this row should move (approximately 20% of rows)
    // Using a different random seed for each row
    float shouldMoveThreshold = u_shouldMoveThreshold; 

    vec2 moveShapeSt = u_fxWithBlocking ? blockingSt : st;

    moveShapeSt *= u_moveShapeScale;




    float moveContourNoise = noise(vec2(moveTime *  u_moveShapeSpeed * 0.5, moveShapeSt.y * .05));
    float moveShapeContourMult = 5. + moveContourNoise * 5.; 
    float moveShapeContourStrength = (1.-moveContourNoise) * 0.2;
    float moveShapeContour = noise(vec2(moveShapeSt.y * moveShapeContourMult, moveTime * u_moveShapeSpeed * 0.5)) * moveShapeContourStrength;
    moveShapeSt.x += moveShapeContour;

    float moveNoise = structuralNoise(moveShapeSt + vec2(moveTime * u_moveShapeSpeed, 100.), moveTime * u_moveShapeSpeed * 0.25);
    float direction = moveNoise < 0.5 ? -1.0 : 1.0;
    
    // Sample drawing buffer for mode detection
    // Snap to block center using the same normalized grid as blockingSt
    vec2 drawSt;
    if (u_fxWithBlocking && useBlocking) {
      // Snap to block center: (floor(st * u_blocking) + 0.5) / u_blocking
      drawSt = (floor(orgSt * u_blocking) + 0.5) / u_blocking;
    } else {
      drawSt = orgSt;
    }
    vec4 drawColor = texture2D(u_drawTexture, drawSt);
    
    // Decode R channel (move/shuffle)
    bool shuffleMode = false;
    bool moveMode = false;
    float moveDirectionOverride = 0.0; // -1.0 for left, 1.0 for right, 0.0 for no override
    
    if (drawColor.a >= DRAW_ACTIVE_THRESHOLD && drawColor.r >= DRAW_ACTIVE_THRESHOLD) {
      if (drawColor.r < DRAW_SHIFT_THRESHOLD) {
        // 0.25-0.5: shuffle
        shuffleMode = true;
      } else if (drawColor.r < DRAW_DIRECTION_THRESHOLD) {
        // 0.5-0.75: move left
        moveMode = true;
        moveDirectionOverride = -1.0;
      } else {
        // 0.75+: move right
        moveMode = true;
        moveDirectionOverride = 1.0;
      }
    }
    
    // Decode G channel (waterfall/trickle)
    bool trickleMode = false;
    bool waterfallMode = false;
    float fallDirectionOverride = 1.0; // -1.0 for up, 1.0 for down, default 1.0
    
    if (drawColor.a >= DRAW_ACTIVE_THRESHOLD && drawColor.g >= DRAW_ACTIVE_THRESHOLD) {
      if (drawColor.g < DRAW_SHIFT_THRESHOLD) {
        // 0.25-0.5: trickle
        trickleMode = true;
      } else if (drawColor.g < DRAW_DIRECTION_THRESHOLD) {
        // 0.5-0.75: waterfall down
        waterfallMode = true;
        fallDirectionOverride = 1.0;
      } else {
        // 0.75+: waterfall up
        waterfallMode = true;
        fallDirectionOverride = -1.0;
      }
    }
    
    // Decode B channel (freeze/reset)
    bool freezeMode = false;
    bool resetMode = false;
    int resetVariant = 0; // 0=default, 1=empty, 2=static, 3=gem
    
    if (drawColor.a >= DRAW_ACTIVE_THRESHOLD && drawColor.b >= DRAW_ACTIVE_THRESHOLD) {
      if (drawColor.b < DRAW_SHIFT_THRESHOLD) {
        // 0.25-0.5: freeze
        freezeMode = true;
      } else if (drawColor.b < DRAW_DIRECTION_THRESHOLD) {
        // 0.5-0.75: reset (with variants)
        resetMode = true;
        // Decode reset variant from B channel
        // 0.5-0.5625: default (0.53125)
        // 0.5625-0.625: empty (0.59375)
        // 0.625-0.6875: static (0.65625)
        // 0.6875-0.75: gem (0.71875)
        float resetB = drawColor.b;
        if (resetB < 0.5625) {
          resetVariant = 0; // default
        } else if (resetB < 0.625) {
          resetVariant = 1; // empty
        } else if (resetB < 0.6875) {
          resetVariant = 2; // static
        } else {
          resetVariant = 3; // gem
        }
      }
    }

    // Override direction if move mode is active from drawing
    if (moveDirectionOverride != 0.0) {
      direction = moveDirectionOverride;
    }

    bool shouldMove = moveNoise < shouldMoveThreshold || moveNoise > 1. - shouldMoveThreshold;
    shouldMove = shouldMove || moveMode;

    // Calculate movement offset for the row, if it should move
    float moveSpeed = u_moveSpeed; // Adjust for faster/slower movement
  
    float moveAmount = 0.0;


    //FALL
    vec2 shouldFallSt = u_fxWithBlocking ? blockingSt : st;
    shouldFallSt *=  u_shouldFallScale;

    float fallContourNoise = noise(vec2(shouldFallSt.x * .2, -moveTime* u_fallShapeSpeed * 0.5));
    float fallShapeContourMult = 5. + fallContourNoise * 5.;
    float fallShapeContourStrength = (1. - fallContourNoise) * 0.3;
    float fallShapeContour = noise(vec2(shouldFallSt.x * fallShapeContourMult, moveTime* u_fallShapeSpeed * 0.5)) * fallShapeContourStrength;
    shouldFallSt.y += fallShapeContour;
    float shouldFallNoise  = structuralNoise(
      shouldFallSt + vec2(20.124,  moveTime * u_fallShapeSpeed), 
      moveTime * u_fallShapeSpeed * 0.25);
    bool shouldFall =  shouldFallNoise  < u_shouldFallThreshold;
    shouldFall = shouldFall || waterfallMode;

    float fallDirection = 1.0;
    // Override fall direction if waterfall mode is active from drawing
    if (waterfallMode) {
      fallDirection = fallDirectionOverride;
    }


    vec2 resetNoiseSt = (blockingSt + vec2(moveShapeContour, fallShapeContour)) * u_resetNoiseScale;
    float resetNoise = structuralNoise(resetNoiseSt + 678.543, structuralMoveTime);

    bool willReset = resetNoise < u_resetThreshold;
 
    //EXTRA MOVES

    vec2 extraMoveShapeSt = u_fxWithBlocking ? blockingSt : st;
    float extraMoveTime = moveTime * u_moveShapeSpeed ;
    float extraMoveShape = structuralNoise(extraMoveShapeSt * u_extraMoveShapeScale - 1.345 + vec2(extraMoveTime * direction, 0.), extraMoveTime);

    bool extraMoveStutter = random(floor(st * u_extraMoveStutterScale) + moveTime + 1.49) < u_extraMoveStutterThreshold;
    bool inExtraMove = extraMoveShape < u_extraMoveShapeThreshold;
    inExtraMove = inExtraMove || shuffleMode;
    bool extraMoves = extraMoveStutter && inExtraMove;

    shouldMove = shouldMove || extraMoves;

    if (shouldMove && onTick) {
      // // 🚀 EXTRA MOVE DEBUG
      // gl_FragColor = vec4(1., 0., 0., 1.);
      // return;
      moveAmount = direction * moveSpeed * blockSize.x;
    }

    float fallAmount = 0.0;

    float yFall = moveSpeed * blockSize.y;

    //EXTRA FALL
    vec2 extraFallShapeSt = u_fxWithBlocking ? blockingSt : st;
    extraFallShapeSt *= u_extraFallShapeScale;

    float extraFallTime = moveTime * u_fallShapeSpeed;

    float extraFallShape = structuralNoise(
      extraFallShapeSt + 1.123 + vec2(0.2, extraFallTime), 
      extraFallTime * 0.25);
    bool extraFallStutter = random(floor(st * u_extraFallStutterScale) + moveTime + 2.) < u_extraFallStutterThreshold;
    bool inExtraFall = extraFallShape < u_extraFallShapeThreshold;
    inExtraFall = inExtraFall || trickleMode;
    bool extraFall = extraFallStutter && inExtraFall;

    shouldFall = shouldFall || extraFall;

    if(shouldFall && onTick) {
      // // 🚀 EXTRA  FALL DEBUG
      // gl_FragColor = vec4(1., 1., 1., 1.);
      // return;

      float waterX = u_fxWithBlocking ? blockingSt.x : floor(st.x * (u_resolution.x / 2.));
      vec2 waterFallSt = vec2(waterX, floor(moveTime * .5));

      
      float waterFallSpeedMult = u_fallWaterfallMult / 2.;

      if (u_fallWaterfallMult > 0.) {
        float waterFallVariance = random(waterFallSt) * u_fallWaterfallMult;
        waterFallSpeedMult *= waterFallVariance;
      }



      fallAmount = yFall + yFall * waterFallSpeedMult;//waterfall
      fallAmount *= fallDirection; // Apply the random direction
    }
 
    // Apply freeze mode (zeros out movement)
    if (freezeMode) {
      moveAmount = 0.0;
      fallAmount = 0.0;
    }

    // Apply the horizontal offset to the texture coordinate
    if(onTick) {
      st.x += moveAmount * densityAdjustment;
      st.y += fallAmount * densityAdjustment;
    }

    //one pixel margin for the blocks
    vec2 margin = (1.0 / u_resolution) * 2.;
    // Check if we're outside the valid area (beyond complete blocks)
    bool isOutOfXBounds = (st.x >= maxValidCoord.x - margin.x || st.x <= margin.x);
    bool isOutOfYBounds = st.y >= maxValidCoord.y - margin.y || st.y <= margin.y;
    bool isOutOfBounds = isOutOfXBounds || isOutOfYBounds;

    bool isOutOfXFrame = st.x < 0.0 || st.x > maxValidCoord.x;
    bool isOutOfYFrame = st.y < 0.0 || st.y > maxValidCoord.y;

    bool resetting = true;

    //Allows for wrapping

    float wrappingTime = structuralMoveTime * 2.;
    vec2 wrappingSt = blockingSt;
    bool isWrapping = (structuralNoise(wrappingSt * u_blackNoiseScale + 11.909, wrappingTime) < 0.5) 
      ? (direction < 0.) 
      : (direction > 0.);

    isWrapping = isWrapping || moveMode;
    
    if(isWrapping) {
      resetting = false;
    }

    bool useReset = false;

    if(isOutOfXBounds) {
      if(shouldMove && onTick) {
        if(resetting) {
          float xSpeed =  (150. * blockSize.x) * moveSpeed;

          if(direction < 0. && st.x < margin.x) {
              st.x -= xSpeed * moveTime;
              useReset = true;
          }
          if(direction > 0. && st.x > maxValidCoord.x - margin.x) {
              st.x += xSpeed * moveTime;
              useReset = true;
          }
        } else {
          if (direction < 0. && st.x < margin.x) {
              st.x = maxValidCoord.x - st.x;
          } 
          if (direction > 0. && st.x > maxValidCoord.x - margin.x) {
              st.x = mod(st.x + margin.x, maxValidCoord.x);
          }  
        }        
      } 
    }

    

    if (isOutOfYBounds) {
        if (shouldFall && onTick) {
            // Wrap around the y coordinate
            if (fallDirection < 0. && st.y < margin.y) {
                st.y = maxValidCoord.y - st.y;
            } 
            if (fallDirection > 0. && st.y > maxValidCoord.y - margin.y) {
                st.y = mod(st.y + margin.y, maxValidCoord.y);
            }
        }
    }


    blockingSt = useBlocking ? floor(st * u_blocking) : st;

    // Calculate block coordinates and fractional position within block
    vec2 blockFloor = floor(st / blockSize);
    vec2 blockFract = fract(st / blockSize);  

    vec4 initColor = vec4(1.);

    float blackNoiseEdge = random(st.y + vec2(10.45)) * u_blackNoiseEdgeMult;
 
    float blackNoise = structuralNoise(blockingSt * u_blackNoiseScale + 1000., structuralMoveTime) + blackNoiseEdge;

    bool useBlack = blackNoise < u_blackNoiseThreshold;

    float ribbonNoise = structuralNoise(blockingSt * u_blackNoiseScale - 2000., structuralMoveTime) - blackNoiseEdge;
    bool useRibbon = ribbonNoise < u_useRibbonThreshold;

    // Apply reset variant overrides (must happen before useBlank calculation)
    if (resetMode) {
      if (resetVariant == 1) {
        // empty: override useBlack = true
        useBlack = true;
      } else if (resetVariant == 2) {
        // static: override useBlack = false and useRibbon = false
        useBlack = false;
        useRibbon = false;
      } else if (resetVariant == 3) {
        // gem: override useBlack = false and useRibbon = true
        useBlack = false;
        useRibbon = true;
      }
      // resetVariant == 0 (default): no additional overrides
    }

    bool useBlankStatic = random(st * u_blankStaticScale + floor(
      cos(moveTime * 10.123) * u_blankStaticTimeMult + 
      sin(moveTime * 1.05) * u_blankStaticTimeMult) + 1.) < u_blankStaticThreshold;
    bool useBlank = useBlankStatic && !useRibbon || useBlack;


    

    if (useBlank) {
      initColor = blankColor;
    } else {

      vec2 dirtNoiseSt = floor(st * u_dirtNoiseScale);
      float rnd = random(dirtNoiseSt + blockTime);
      float blockRnd = random(dirtNoiseSt + blockTime + 10.24);

      bool useBlock = useRibbon && blockRnd < u_ribbonDirtThreshold;

      vec2 stPlus = ((st) / blockSize);
      if(useBlock) {
        initColor = createGradientBlock(stPlus, isWrapping);
      } else {
        if (rnd < .25) {
          initColor = createGradientBlock(stPlus, isWrapping);
        } else if(rnd < .5) {
          initColor = vec4(u_staticColor1, 1.);
        } else if(rnd < 0.75) {  
          initColor = vec4(u_staticColor2, 1.);
        } else {
          initColor = vec4(u_staticColor3, 1.);
        }
      }

      initColor = createWithHueCycle(initColor, u_frameCount + PI);
    }

    // Apply reset mode override (after all other useReset logic)
    if (resetMode) {
      willReset = true;
    }
    

    float resetEdgeThreshold = u_resetEdgeThreshold;
    bool resetEdge = onTick && random(2. * st + fract(moveTime)) < resetEdgeThreshold;

    bool naturalReset = !shouldMove && !shouldFall && willReset;


    if((naturalReset || resetMode) && resetEdge) {
      useReset = true;
    }
    
    // Force reset override (from clear operation)
    if (u_forceReset > 0.5) {
      useReset = true;
    }
    
    // Apply freeze mode (also sets reset to false, overrides reset mode)
    if (freezeMode) {
      useReset = false;
    }


    // //🚀 DEBUG
    // useReset = true;

    // Sample from the previous state with the calculated coordinates
    vec4 color = texture2D(u_texture, st);
    // During the first 0.05 seconds after resize, show the gradient
    if (color.a < .025 || useReset) {
        // Generate the original gradient (red from x, blue from y)
        gl_FragColor = initColor;
        return;
    }
    
    bool isBgColor = color == blankColor;

    if(!isBgColor && onTick) {
      // Apply time-based color animation with wrapping to colors (other thank bg)
      color = cycleColorHue(color, u_cycleColorHueSpeed);
    }

    // Convert to gray scale weight
    if(u_useGrayscale) {
      color.rgb = vec3(0.299 * color.r + 0.587 * color.g + 0.114 * color.b);
    }

    // Use the color with time-based animation applied
    gl_FragColor = color;
}