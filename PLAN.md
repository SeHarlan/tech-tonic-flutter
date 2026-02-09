# tech-Tonic Flutter Conversion Plan

## Context

tech-Tonic is a generative art app built with vanilla JS/WebGL featuring a 770-line GLSL fragment shader, ping-pong framebuffer rendering, and interactive drawing. We're rebuilding it from the ground up in Flutter for iOS & Android as a creative instrument with gesture-only controls. The original JS/GLSL source files remain in the repo as reference.

### Design Decisions
- **Platforms**: iOS + Android primary, simpler web player later (viewer only, takes saved state to replay)
- **Controls**: Gesture-only with one minimal floating button for mode picker
- **State management**: Riverpod with freezed immutable classes
- **Vibe**: Creative instrument — raw, expressive, minimal chrome, the art IS the interface
- **Brush size**: Two-finger pinch gesture
- **Save format (future)**: Seed + params + current frame texture + drawing buffer (everything to resume a session)

---

## Phase 1: Project Bootstrap & Math Utilities

**Goal**: Flutter project initialized, Dart ports of all noise/math/color functions with tests.

### 1a. Initialize Flutter project
- Run `flutter create --org com.ev3 --project-name tech_tonic .` in the repo (creates alongside existing JS files)
- Add dependencies to `pubspec.yaml`:
  - `flutter_riverpod` (state management)
  - `freezed_annotation` + `freezed` + `build_runner` (immutable state classes)
  - `json_annotation` + `json_serializable` (future save/load serialization)
- Declare shaders in `pubspec.yaml`:
  ```yaml
  flutter:
    shaders:
      - shaders/generative.frag
      - shaders/draw.frag
  ```

### 1b. Port math utilities → `lib/core/math/`
- **`noise.dart`** — Port `random()`, `seededRandom()`, `random3D()`, `noise()`, `noise3D()`, `structuralNoise()`, `fbm()` as pure Dart functions
  - These are needed for CPU-side parameter generation (the same functions also exist in the shader for GPU-side use)
- **`seeded_rng.dart`** — Port Mulberry32 seeded RNG (`createSeededRNG` from main.js)
- **`weighted_random.dart`** — Port `weightedRandom()` function
- **`color_utils.dart`** — Port `rgb2hsl()`, `hsl2rgb()`, `increaseColorHue()` (needed for UI color display)

### 1c. Write tests → `test/core/math/`
- Test noise functions produce deterministic output for known inputs
- Test seeded RNG matches JS output for same seeds (cross-validate with a few known seed→output pairs from the JS version)
- Test weighted random distribution is reasonable
- Test HSL↔RGB roundtrip accuracy

**Files created**:
- `lib/core/math/noise.dart`
- `lib/core/math/seeded_rng.dart`
- `lib/core/math/weighted_random.dart`
- `lib/core/math/color_utils.dart`
- `test/core/math/noise_test.dart`
- `test/core/math/seeded_rng_test.dart`

---

## Phase 2: Shader Porting (Highest Risk)

**Goal**: Both GLSL shaders compile and run in Flutter.

### 2a. Port fragment shader → `shaders/generative.frag`
- Start from `fragmentShader.glsl`, make these changes:
  - Add `#include <flutter/runtime_effect.glsl>` at top
  - Replace `varying vec2 v_texCoord` with `FlutterFragCoord()` and normalize by resolution
  - Replace all `texture2D()` calls with `texture()`
  - Replace `uniform` declarations with Flutter's `uniform` layout (float uniforms accessed by index via `setFloat()`)
  - Sampler2D: use `uniform sampler2D u_texture` and `uniform sampler2D u_drawTexture` — Flutter binds these via `setImageSampler(0, ...)` and `setImageSampler(1, ...)`
  - **FBM loop fix**: Replace dynamic `if(i >= octaves) break;` with `step()` accumulation
  - **Float equality fix**: Replace `color.r == 0.` checks with tolerance `color.r < 0.01`
  - `bool` uniforms → encode as `float` (0.0/1.0) since Flutter's `setFloat()` only does floats
  - Remove `precision mediump float;` (Flutter handles precision)

### 2b. Port drawing shader → `shaders/draw.frag`
- Port the inline drawing fragment shader from main.js (lines 1109-1171)
- Same Flutter GLSL adaptations as above
- Uniforms: center, radius, color, writeR/G/B, clearB, squareMode, eraseMode
- Sampler: existing draw texture for ping-pong read

### 2c. Uniform index mapping → `lib/core/rendering/uniform_mapping.dart`
- Create a Dart class that maps named parameters to `setFloat()` indices
- Document the exact index order (must match shader `uniform` declaration order)
- The generative shader has ~52 uniforms = ~67 float values (vec2 = 2 floats, vec3 = 3 floats)

### 2d. Validate shaders compile
- Create a minimal test screen that loads both shaders via `FragmentProgram.fromAsset()`
- Render a simple full-screen quad with the generative shader and hardcoded uniforms
- **This is the highest-risk step** — if Flutter's shader compiler rejects anything, we debug here

**Files created**:
- `shaders/generative.frag`
- `shaders/draw.frag`
- `lib/core/rendering/uniform_mapping.dart`

---

## Phase 3: Ping-Pong Rendering Pipeline

**Goal**: Feedback loop working — each frame reads previous frame and writes new output.

### 3a. Render controller → `lib/core/rendering/render_controller.dart`
- Uses `Ticker` (via `SingleTickerProviderStateMixin`) for frame scheduling
- Each tick:
  1. Update time, frameCount
  2. Trigger repaint on CustomPainter
- FPS throttling: skip frames if elapsed < target interval (default 60fps)
- Track actual FPS for display

### 3b. Ping-pong painter → `lib/core/rendering/generative_painter.dart`
- `CustomPainter` subclass that implements the ping-pong:
  1. Create `PictureRecorder` → `Canvas`
  2. Set all float uniforms via `shader.setFloat(index, value)`
  3. Bind previous frame image: `shader.setImageSampler(0, previousFrameImage)`
  4. Bind draw buffer image: `shader.setImageSampler(1, drawBufferImage)`
  5. `canvas.drawRect(fullScreen, Paint()..shader = shader)`
  6. `recorder.endRecording().toImageSync(width, height)` → store as next frame's input
  7. Also paint to the visible canvas for display
- Two `dart:ui.Image` references for ping-pong swap
- Dispose old images to prevent memory leaks

### 3c. Render state → `lib/core/rendering/render_state.dart`
- Riverpod `Notifier` holding:
  - `time`, `frameCount`, `fps`
  - `isPaused` (globalFreeze)
  - `seed`
  - Reference to current ping-pong images (for future save)

### 3d. Main screen → `lib/features/canvas/canvas_screen.dart`
- `ConsumerStatefulWidget` with `SingleTickerProviderStateMixin`
- Full-screen `CustomPaint` widget using `GenerativePainter`
- No UI chrome — just the canvas

**Files created**:
- `lib/core/rendering/render_controller.dart`
- `lib/core/rendering/generative_painter.dart`
- `lib/core/rendering/render_state.dart`
- `lib/features/canvas/canvas_screen.dart`

**Verification**: App launches showing animated generative art with feedback loop. No interaction yet.

---

## Phase 4: Shader Parameters & Seed System

**Goal**: Randomized parameter sets from seeds, matching JS behavior.

### 4a. Parameter state → `lib/features/parameters/parameter_state.dart`
- Freezed immutable class with all 52 uniform values
- Factory `ParameterState.fromSeed(double seed)` that uses Mulberry32 RNG + weighted random to generate parameters (port `randomizeShaderParameters()` from main.js)
- Method to serialize to/from JSON (for future save)

### 4b. Parameter provider → `lib/features/parameters/parameter_provider.dart`
- Riverpod `Notifier<ParameterState>`
- Actions: `newSeed()`, `toggleBlocking()`, `toggleManualMode()`, `setForceReset()`
- On `newSeed()`: generate new seed → create new `ParameterState.fromSeed()`

### 4c. Wire parameters to shader
- Update `GenerativePainter` to read from `ParameterState`
- Map all fields to `setFloat()` calls using `UniformMapping`

**Files created**:
- `lib/features/parameters/parameter_state.dart`
- `lib/features/parameters/parameter_provider.dart`

**Verification**: Tap to trigger `newSeed()` → visuals change with new randomized parameters.

---

## Phase 5: Drawing Buffer & Interaction

**Goal**: User can draw on canvas, encoded as RGB channel values in a separate texture.

### 5a. Draw buffer painter → `lib/core/rendering/draw_buffer_painter.dart`
- Separate `CustomPainter` for the drawing shader
- Also ping-pong: reads existing draw texture, writes new one with brush mark added
- Handles circle and square brush shapes
- Channel-aware writes (R, G, B independently based on mode)

### 5b. Drawing controller → `lib/features/drawing/drawing_controller.dart`
- Manages drawing state: `isDrawing`, `lastPoint`, `currentMode`, `currentDirection`
- `drawAt(Offset point)` — calls draw buffer painter at point
- `drawLine(Offset from, Offset to)` — interpolates with `brushSize * 0.5` stepping
- Block snapping logic when `fxWithBlocking` is active
- Coordinate conversion: Flutter local → texture coordinates (with Y-flip for shader space)

### 5c. Mode color encoding → `lib/features/drawing/mode_color.dart`
- Port `getModeColor()` — returns RGB values for each mode
- All 12+ modes with exact channel values matching the JS version:

| Channel | Range | Meaning |
|---------|-------|---------|
| R | 0.25-0.5 | Shuffle (0.375) |
| R | 0.5-0.75 | Move left (0.625) |
| R | 0.75+ | Move right (0.875) |
| G | 0.25-0.5 | Trickle (0.375) |
| G | 0.5-0.75 | Waterfall down (0.625) |
| G | 0.75+ | Waterfall up (0.875) |
| B | 0.25-0.5 | Freeze (0.375) |
| B | 0.5-0.5625 | Reset (0.53125) |
| B | 0.5625-0.625 | Empty (0.59375) |
| B | 0.625-0.6875 | Static (0.65625) |
| B | 0.6875-0.75 | Gem (0.71875) |

### 5d. Brush size system → `lib/features/drawing/brush_state.dart`
- Port `generateBrushSizeOptions()` — both blocking and normal mode distributions
- Riverpod provider for brush size, responds to pinch gestures
- Recalculates on screen resize or blocking mode toggle

**Files created**:
- `lib/core/rendering/draw_buffer_painter.dart`
- `lib/features/drawing/drawing_controller.dart`
- `lib/features/drawing/mode_color.dart`
- `lib/features/drawing/brush_state.dart`

**Verification**: Touch and drag on canvas → marks appear and affect the generative animation.

---

## Phase 6: Gesture System

**Goal**: Full touch interaction — draw, pinch to resize, mode picker.

### 6a. Gesture handler → `lib/features/canvas/gesture_handler.dart`
- Single `GestureDetector` using `onScaleStart/Update/End` (handles both 1-finger and 2-finger)
- **One finger**: drawing (pass focal point to drawing controller)
- **Two fingers**: brush size (use `scale` factor relative to start, multiply against current brush size)
- Detect finger count from `ScaleUpdateDetails.pointerCount`
- When going from 1→2 fingers: stop drawing, start resize
- When going from 2→1 fingers: stop resize, resume drawing

### 6b. Wire to canvas screen
- Wrap `CustomPaint` in `GestureDetector`
- Connect scale events to drawing controller and brush state

**Files created**:
- `lib/features/canvas/gesture_handler.dart`

**Verification**: Draw with one finger, pinch with two to resize brush.

---

## Phase 7: Mode Picker UI (Minimal Floating Button)

**Goal**: Single floating button that opens a clean mode picker.

### 7a. Mode picker → `lib/features/controls/mode_picker.dart`
- Small floating button in bottom-right corner (semi-transparent, minimal)
- On tap: expands to a compact grid/radial of mode icons
- Mode categories:
  - **Movement**: ↑↓←→ waterfall/move arrows
  - **Effects**: shuffle, trickle, freeze, erase
  - **Paint**: reset, empty, static, gem
- Selected mode highlighted, tap to select then auto-close
- Current mode shown as subtle icon on the floating button

### 7b. Mode state → `lib/features/controls/mode_state.dart`
- Riverpod provider for `currentMode`, `currentDirection`, `currentResetVariant`
- Actions: `setMode()`, `cycleDirection()`, `cyclePaintVariant()`

### 7c. Additional gestures
- **Double-tap**: new seed (equivalent to N key)
- **Three-finger tap**: toggle pause/freeze (equivalent to Space)
- **Swipe down with 3 fingers**: screenshot/save

**Files created**:
- `lib/features/controls/mode_picker.dart`
- `lib/features/controls/mode_state.dart`

**Verification**: Mode picker opens/closes, switching modes changes drawing behavior.

---

## Phase 8: Polish & Platform

**Goal**: Production-quality creative instrument feel.

### 8a. Brush overlay → `lib/features/drawing/brush_overlay.dart`
- Show brush size/shape indicator at touch point
- Circle in normal mode, square in blocking mode
- Semi-transparent, follows finger position
- Hidden when not touching

### 8b. Screenshot → `lib/features/export/screenshot_service.dart`
- Capture current frame image
- Save to photo gallery (use `image_gallery_saver` or platform channels)

### 8c. Haptic feedback
- Subtle haptic on mode switch, new seed, brush size snap points

### 8d. App lifecycle
- Pause rendering when app is backgrounded
- Resume when foregrounded
- Prevent screen sleep while active

### 8e. Performance optimization
- Profile on real devices (both iOS and Android)
- Ensure 60fps with the 770-line shader
- Reduce uniform count if needed for older devices

**Files created**:
- `lib/features/drawing/brush_overlay.dart`
- `lib/features/export/screenshot_service.dart`

---

## Final Project Structure

```
lib/
  main.dart                              # App entry, ProviderScope
  app.dart                               # MaterialApp, theme (dark/minimal)
  core/
    math/
      noise.dart                         # Perlin noise, FBM (Dart)
      seeded_rng.dart                    # Mulberry32 RNG
      weighted_random.dart               # Weighted selection
      color_utils.dart                   # HSL↔RGB conversion
    rendering/
      render_controller.dart             # Ticker-based frame loop
      generative_painter.dart            # Main shader CustomPainter
      draw_buffer_painter.dart           # Drawing shader CustomPainter
      render_state.dart                  # Frame state (time, fps, images)
      uniform_mapping.dart               # Named param → setFloat index
  features/
    canvas/
      canvas_screen.dart                 # Full-screen canvas widget
      gesture_handler.dart               # Scale gesture → draw/pinch
    drawing/
      drawing_controller.dart            # Draw logic, line interpolation
      mode_color.dart                    # Mode → RGB channel encoding
      brush_state.dart                   # Brush size provider + options
      brush_overlay.dart                 # Visual brush cursor
    parameters/
      parameter_state.dart               # All 52 shader params (freezed)
      parameter_provider.dart            # Seed → params generation
    controls/
      mode_picker.dart                   # Floating button + mode grid
      mode_state.dart                    # Current mode provider
    export/
      screenshot_service.dart            # Capture + save to gallery
shaders/
  generative.frag                        # Main 770-line shader (ported)
  draw.frag                              # Drawing interaction shader
test/
  core/math/
    noise_test.dart
    seeded_rng_test.dart
```

---

## Build Sequence & Risk Assessment

| Phase | Risk | Why | Mitigation |
|-------|------|-----|------------|
| 1. Bootstrap + Math | Low | Pure Dart, well-tested | Write tests first |
| 2. Shader Porting | **HIGH** | Flutter GLSL is a subset, 770 lines to adapt | Start here after bootstrap, debug early |
| 3. Ping-Pong | **HIGH** | toImageSync + sampler binding is tricky | Minimal test first, check iOS vs Android |
| 4. Parameters | Low | Pure Dart state logic | Cross-validate with JS output |
| 5. Drawing Buffer | Medium | Second ping-pong system + channel encoding | Build on Phase 3 foundation |
| 6. Gestures | Low | Well-documented Flutter APIs | Use ScaleGestureRecognizer |
| 7. Mode Picker | Low | Standard Flutter widgets | Keep minimal |
| 8. Polish | Low | Incremental improvements | Profile on real devices |

**Critical path**: Phase 2 (shader compilation) and Phase 3 (ping-pong rendering) are the make-or-break steps. If Flutter's FragmentProgram can't handle the shader complexity or the dual-sampler ping-pong, we'll need to fall back to `flutter_gl` (raw OpenGL ES) or `flutter_opengl` packages via platform channels.

---

## Verification Plan

After each phase, verify before moving on:

1. **Phase 1**: `flutter test` — all math tests pass
2. **Phase 2**: App launches, shaders compile without error (check debug console)
3. **Phase 3**: Animated generative art visible on screen with feedback loop
4. **Phase 4**: New seed changes visuals, parameters are visibly different
5. **Phase 5**: Drawing on screen affects the animation
6. **Phase 6**: One-finger draws, two-finger pinch resizes brush
7. **Phase 7**: Mode picker opens, mode changes affect drawing
8. **Phase 8**: 60fps on real device, screenshot saves to gallery

---

## Reference Files (Original JS/WebGL Source)

These files remain in the repo as conversion reference:
- `fragmentShader.glsl` — 770-line generative fragment shader (52 uniforms)
- `vertexShader.glsl` — Simple passthrough vertex shader
- `main.js` — WebGL rendering, drawing system, input handling, state management
- `index.html` — Menu UI structure
- `style.css` — UI styling
