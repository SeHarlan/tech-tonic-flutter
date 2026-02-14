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

## Current Status (as of commit `6a057f9`)

### Completed
- Phase 1: Project bootstrap (no math utils ported — noise lives in shader only)
- Phase 2: Shader porting (generative.frag: 473 lines, draw.frag: 64 lines)
- Phase 3: Ping-pong rendering pipeline (Impeller-compatible)
- Phase 4: Shader parameters & seed system (minimal — 8 runtime uniforms, rest hard-coded)
- Phase 5: Touch drawing & draw buffer (Canvas API approach, not draw shader)
- Phase 6: Controls UI (controls drawer with paint mode selector, brush controls, direction pad)
- Phase 7-8: Image export, basic polish

### Key Deviations from Original Plan
1. **No `toImageSync()`** — crashes with Impeller on iOS. Replaced with `RenderRepaintBoundary.toImage()` for the feedback loop.
2. **No draw shader for compositing** — `Picture.toImage()` crashes with Impeller when the Picture contains custom shaders with `sampler2D`. Drawing uses Flutter Canvas API instead.
3. **Uniforms reduced to 8 floats + 2 samplers** — Metal's 31 buffer limit required hard-coding most parameters as shader constants.
4. **Y-axis flipped in shader** — `FlutterFragCoord()` has Y=0 at top (Flutter) vs Y=0 at bottom (WebGL). Shader flips Y at start and flips back for texture sampling.
5. **Placeholder images via `decodeImageFromPixels()`** — avoids Picture/PictureRecorder entirely for initial frame creation.
6. **Profile mode required** — debug builds crash when launched from iOS home screen without debugger. Must use `--profile` or `--release`.
7. **Build from ~/Development** — iCloud-synced Desktop folder breaks code signing with resource forks.

### What Still Needs Work
- Pinch-to-zoom gesture for brush size (not yet wired)
- Multi-finger gestures (double-tap for new seed, three-finger for screenshot)
- Brush cursor overlay (visual indicator at touch point)
- Android testing (untested)
- Performance profiling & optimization
- Save/load session state
- Making draw buffer channel-selective (currently overwrites all channels; original shader preserved individual channels)

---

## Phase 1: Project Bootstrap & Math Utilities -- COMPLETE

**Goal**: Flutter project initialized, Dart ports of all noise/math/color functions with tests.

### 1a. Initialize Flutter project -- DONE
- Flutter project created with `flutter create`
- Dependencies: `flutter_riverpod`, `freezed_annotation`, `freezed`, `build_runner`, `json_annotation`, `json_serializable`
- Shaders declared in `pubspec.yaml`

### 1b. Port math utilities -- SKIPPED
- Noise/math functions live exclusively in the GLSL shader (GPU-side)
- No CPU-side Dart ports needed since parameters are hard-coded in the shader

### 1c. Tests -- SKIPPED
- No math utility tests needed since functions are shader-only

---

## Phase 2: Shader Porting (Highest Risk) -- COMPLETE

**Goal**: Both GLSL shaders compile and run in Flutter.

### 2a. Port fragment shader → `shaders/generative.frag` -- DONE
- Ported from 770-line WebGL shader to 473-line Flutter GLSL
- Key adaptations:
  - `#include <flutter/runtime_effect.glsl>` added
  - `gl_FragCoord` → `FlutterFragCoord()`
  - `texture2D()` → `texture()`
  - Y-axis flip: `st.y = 1.0 - st.y` at start, `vec2(st.x, 1.0 - st.y)` for all texture samples
  - Bool uniforms encoded as floats (0.0/1.0)
  - FBM loop uses `step()` instead of dynamic break
  - Float equality uses tolerance (`< 0.01`) instead of `==`
  - Most uniforms hard-coded as `const` to stay under Metal's 31 buffer limit

### 2b. Port drawing shader → `shaders/draw.frag` -- DONE
- 64-line shader for brush compositing
- **Note**: Currently unused at runtime — drawing is done via Flutter Canvas API for Impeller compatibility. Shader is retained for potential future use.

### 2c. Uniform index mapping → `lib/core/rendering/uniform_mapping.dart` -- DONE
- `GenerativeUniforms` class: 8 float indices + 2 sampler indices
- `DrawUniforms` class: 15 float indices + 1 sampler index (unused at runtime)
- Extension methods: `setVec2`, `setVec3`, `setBool` on `ui.FragmentShader`

---

## Phase 3: Ping-Pong Rendering Pipeline -- COMPLETE

**Goal**: Feedback loop working — each frame reads previous frame and writes new output.

### 3a. Render controller → `lib/core/rendering/render_controller.dart` -- DONE
- Uses `Ticker` via `SingleTickerProviderStateMixin`
- Tracks time, frameCount, FPS (sampled every 1 second)
- Pause/resume support

### 3b. Generative painter → `lib/core/rendering/generative_painter.dart` -- DONE (REVISED)
- **Original plan**: Use `PictureRecorder` + `toImageSync()` for ping-pong capture
- **Actual implementation**: `CustomPainter` renders shader to canvas; frame capture done externally via `RenderRepaintBoundary.toImage()` in `canvas_screen.dart`
- Accepts `previousFrame` and `drawBuffer` as `ui.Image` parameters
- Sets 8 float uniforms + 2 image samplers

### 3c. Render state → `lib/core/rendering/render_state.dart` -- DONE
- Mutable class (not Riverpod) holding:
  - `time`, `frameCount`, `fps`, `isPaused`, `seed`
  - `frameImages[2]` — ping-pong frame slots
  - `drawImages[2]` — ping-pong draw buffer slots
  - `readIndex` / `writeIndex` with swap methods

### 3d. Canvas screen → `lib/features/canvas/canvas_screen.dart` -- DONE (REVISED)
- `ConsumerStatefulWidget` with `SingleTickerProviderStateMixin`
- Loads shaders via `FutureProvider<ui.FragmentProgram>`
- `RepaintBoundary` wraps `CustomPaint` for frame capture
- Post-frame callback captures via `boundary.toImage(pixelRatio: 1.0)`
- `_capturing` flag prevents concurrent capture

### Additional: Image helper → `lib/core/rendering/shader_renderer.dart` -- ADDED
- `ImageHelper.createPlaceholder(w, h)` — creates transparent placeholder images
- Uses `decodeImageFromPixels()` instead of Picture/PictureRecorder (Impeller-safe)

---

## Phase 4: Shader Parameters & Seed System -- COMPLETE (SIMPLIFIED)

**Goal**: Randomized parameter sets from seeds, matching JS behavior.

### Implementation -- DONE (simplified)
- `parameter_state.dart` — Freezed immutable class for UI-facing state (manualMode, globalFreeze, forceReset, seed)
- `parameter_provider.dart` — Riverpod notifier with actions (toggleManualMode, toggleGlobalFreeze, setForceReset, etc.)
- **Note**: Most shader parameters are hard-coded in the shader as constants, not passed as uniforms. Only 8 runtime values are dynamic. Full parameter randomization from seed is a future enhancement.

---

## Phase 5: Drawing Buffer & Interaction -- COMPLETE (REVISED APPROACH)

**Goal**: User can draw on canvas, encoded as RGB channel values in a separate texture.

### Implementation -- DONE (Canvas API approach)
- **Original plan**: Use draw shader (`draw.frag`) with `PictureRecorder` + `toImageSync()` for draw buffer compositing
- **Actual implementation**: Uses Flutter Canvas API (no custom shader) to avoid Impeller crashes
- `DrawingController` queues touch points via `addStroke()` / `addLine()`
- `processPendingStrokes()` composites all queued strokes in one batch:
  1. Draws existing draw buffer via `canvas.drawImageRect()`
  2. Draws brush shapes (circle/rect) with encoded paint mode color
  3. Captures via `Picture.toImage()` (safe — no shader samplers in the Picture)
- `DrawingOverlay` captures pan gestures and queues stroke points
- Paint mode encoding preserved from JS (R=move/shuffle, G=waterfall/trickle, B=freeze/reset)

### Known Limitation
- Current Canvas approach overwrites all RGB channels when painting. The original draw shader preserved individual channels (e.g., painting waterfall on G only preserved existing R and B values). This means you can't layer multiple effects at the same pixel. Could be addressed later with color filter matrix or by re-enabling the draw shader if Impeller compatibility improves.

---

## Phase 6: Gesture System -- PARTIALLY COMPLETE

### Completed
- Single-finger drawing via `DrawingOverlay` (pan start/update/end)
- Controls drawer toggle button

### Not Yet Implemented
- Two-finger pinch for brush size
- Double-tap for new seed
- Three-finger tap for screenshot
- Proper gesture arbitration between draw and pinch

---

## Phase 7: Controls UI -- COMPLETE

### Implemented
- `ControlsDrawer` — settings panel with terminal aesthetic
- `PaintModeSelector` — mode selection for all 12 paint modes
- `BrushControls` — brush size adjustment (button-based, not pinch)
- `DirectionPad` — directional control
- New seed, clear canvas, capture, manual mode, freeze toggle buttons

---

## Phase 8: Polish & Platform -- PARTIALLY COMPLETE

### Completed
- `ImageExporter` — screenshot capture & share
- App launches and runs on physical iPhone (profile mode)

### Not Yet Implemented
- Brush cursor overlay at touch point
- Haptic feedback
- App lifecycle handling (pause when backgrounded)
- Screen sleep prevention
- Android testing
- Performance profiling & optimization

---

## Discovered Issues & Solutions

| Issue | Root Cause | Solution |
|-------|-----------|----------|
| App crashes on physical iPhone | `toImageSync()` incompatible with Impeller | Use `RenderRepaintBoundary.toImage()` for frame capture |
| Draw buffer crashes on iPhone | `Picture.toImage()` with shader samplers crashes on Impeller | Use Canvas API (drawCircle/drawRect) instead of draw shader |
| App crashes when launched from home screen | Debug builds require debugger connection | Use `--profile` or `--release` mode |
| Glitchy rendering on simulator | Resolution set to physical pixels but `FlutterFragCoord()` returns logical pixels | Pass logical size to `u_resolution`, set `pixelDensity = 1.0` |
| Waterfall direction inverted | Flutter Y=0 at top, WebGL Y=0 at bottom | Flip Y in shader: `st.y = 1.0 - st.y` at start, flip back for texture samples |
| Code signing fails | iCloud resource forks in Desktop folder | Build from `~/Development/tech-tonic-flutter` |
| Metal 31 buffer limit exceeded | Too many shader uniforms | Hard-code most parameters as `const` in shader |
| Placeholder image creation crashes | `PictureRecorder` + `toImageSync()` crashes with Impeller | Use `decodeImageFromPixels()` for placeholder creation |

---

## Reference Files (Original JS/WebGL Source)

These files remain in the repo as conversion reference:
- `reference/fragmentShader.glsl` — 770-line generative fragment shader (52 uniforms)
- `reference/vertexShader.glsl` — Simple passthrough vertex shader
- `reference/main.js` — WebGL rendering, drawing system, input handling, state management
- `reference/index.html` — Menu UI structure
- `reference/style.css` — UI styling
