# tech-Tonic (Flutter)

A generative art application converted from vanilla JS/WebGL to Flutter for mobile. Features interactive controls for drawing, movement effects, and particle-like behavior using GLSL fragment shaders.

## Project Overview

- **Stack**: Flutter 3.38+, Dart, GLSL fragment shaders (`FragmentProgram`), Riverpod
- **Source Stack**: Vanilla JavaScript, HTML5, CSS3, WebGL (original, in `reference/`)
- **Type**: Interactive generative art / creative coding
- **Platforms**: iOS (primary), Android (untested)
- **Key Features**: Waterfall effects, brush controls, movement patterns, shader-based rendering with feedback loop

## Critical Platform Notes

### iOS / Impeller Compatibility
Flutter uses **Impeller** as its mandatory rendering engine on iOS physical devices (cannot be disabled as of Flutter 3.38). This has major implications:

- **`toImageSync()` is BROKEN** with Impeller when the Picture contains custom shaders with `sampler2D` uniforms — causes immediate crash
- **`Picture.toImage()` with shader samplers** also crashes on Impeller
- **`RenderRepaintBoundary.toImage()`** works correctly with Impeller — this is the approved approach for frame capture
- **`Picture.toImage()` WITHOUT shader samplers** (plain Canvas operations like `drawCircle`, `drawImageRect`) works fine with Impeller
- **`decodeImageFromPixels()`** works for creating placeholder images without Picture/PictureRecorder

### Build & Deploy
- **Debug builds crash** when launched from the iOS home screen without the debugger attached — this is normal Flutter behavior, not a bug
- **Profile/release builds** work standalone on physical devices
- **iCloud interference**: The Desktop folder is iCloud-synced; resource forks break code signing. Build from `~/Development/tech-tonic-flutter` instead
- **Untrusted developer**: Each reinstall resets trust — go to Settings > General > VPN & Device Management to re-trust

### Coordinate System
- **`FlutterFragCoord()`** returns coordinates in **logical pixel space** with Y=0 at top (Flutter convention)
- **WebGL/OpenGL** has Y=0 at bottom — the shader flips Y at the start (`st.y = 1.0 - st.y`) and flips back for texture sampling (`vec2(st.x, 1.0 - st.y)`)
- **Resolution uniform** must be set to logical pixels (not physical), and `pixelDensity` = 1.0
- **`boundary.toImage(pixelRatio: 1.0)`** captures at logical resolution

## Architecture

### Rendering Pipeline
The feedback loop works as follows:
1. `RenderController` drives a `Ticker` that fires each frame
2. `GenerativePainter` (CustomPainter) renders the generative shader to canvas
3. The shader reads the previous frame via `u_texture` (sampler 0) and the draw buffer via `u_drawTexture` (sampler 1)
4. A `RepaintBoundary` wraps the CustomPaint widget
5. After each paint, `RenderRepaintBoundary.toImage()` captures the rendered frame
6. The captured image is stored in `RenderState.frameImages` (ping-pong) for the next frame

### Drawing Pipeline
Touch drawing uses a Canvas API approach (NOT the draw shader) to avoid Impeller crashes:
1. `DrawingOverlay` captures touch events and queues stroke points in `DrawingController`
2. Each frame, `DrawingController.processPendingStrokes()` composites all pending strokes:
   - Creates a `PictureRecorder` + `Canvas`
   - Draws the existing draw buffer as a base layer via `drawImageRect`
   - Draws brush circles/rects with the encoded paint mode color on top
   - Calls `Picture.toImage()` (safe — no custom shader samplers)
3. The resulting image is stored in `RenderState.drawImages` (ping-pong)
4. The generative shader reads this as `u_drawTexture`

### Shader Uniforms
Uniforms are minimized to stay under **Metal's 31 buffer limit**. Only 8 float uniforms + 2 samplers are passed at runtime; all other parameters are hard-coded as constants in the shader.

Runtime uniforms (see `uniform_mapping.dart`):
| Index | Name | Type |
|-------|------|------|
| 0-1 | `u_resolution` | vec2 |
| 2 | `u_time` | float |
| 3 | `u_pixelDensity` | float (always 1.0) |
| 4 | `u_frameCount` | float |
| 5 | `u_seed` | float |
| 6 | `u_globalFreeze` | float (bool) |
| 7 | `u_forceReset` | float (bool) |
| 8 | `u_manualMode` | float (bool) |
| sampler 0 | `u_texture` | previous frame |
| sampler 1 | `u_drawTexture` | draw buffer |

### State Management
- **Riverpod** for UI/parameter state (`parameterProvider`, `seedProvider`)
- **`RenderState`** (mutable class, not Riverpod) for frame images and render loop state
- **`DrawingController`** manages brush state, paint mode, and pending strokes

## Project Structure (Actual)

```
lib/
  main.dart
  app.dart
  core/
    rendering/
      render_controller.dart       # Ticker-based frame loop
      generative_painter.dart      # CustomPainter for generative shader
      render_state.dart            # Ping-pong frame state
      shader_renderer.dart         # ImageHelper (placeholder creation)
      uniform_mapping.dart         # Uniform index constants + extensions
  features/
    canvas/
      canvas_screen.dart           # Main screen, RepaintBoundary capture
    drawing/
      drawing_controller.dart      # Touch → draw buffer (Canvas API)
      drawing_overlay.dart         # GestureDetector for touch input
    controls/
      controls_drawer.dart         # Settings panel UI
      brush_controls.dart
      direction_pad.dart
      paint_mode_selector.dart
    parameters/
      parameter_state.dart         # Shader parameter state (freezed)
      parameter_provider.dart      # Riverpod provider for params
    export/
      image_exporter.dart          # Screenshot capture & share
shaders/
  generative.frag                  # 473-line generative shader (ported from 770-line WebGL)
  draw.frag                        # Draw shader (currently unused — Canvas API used instead)
reference/
  main.js                          # Original JS source
  fragmentShader.glsl              # Original 770-line shader
  vertexShader.glsl                # Original vertex shader
  index.html / style.css           # Original UI
```

## Development Workflow

1. **Run on simulator** (debug mode OK):
   ```bash
   flutter run -d <simulator_id>
   ```

2. **Run on physical iPhone** (MUST use profile or release):
   ```bash
   # Build from the Development directory to avoid iCloud code-signing issues
   cd ~/Development/tech-tonic-flutter
   flutter run --profile -d <device_id>
   ```

3. **Build only** (faster iteration):
   ```bash
   flutter build ios --profile
   flutter install --profile -d <device_id>
   ```

4. **Check for analysis errors**:
   ```bash
   flutter analyze --no-fatal-infos
   ```

## Code Review Guidelines

1. **Impeller Safety**: Never use `toImageSync()` or `Picture.toImage()` with custom shaders containing `sampler2D`. Use `RenderRepaintBoundary.toImage()` for frame capture.
2. **Coordinate System**: Shader uses flipped Y (WebGL convention). Texture samples must flip Y back. Drawing coordinates are in Flutter's logical pixel space.
3. **Metal Buffer Limit**: Keep total shader buffers (floats + samplers) under 31. Add new parameters as constants, not uniforms.
4. **Memory**: Dispose old images in ping-pong slots before storing new ones.
5. **Touch UX**: Controls are mobile-first — no hover states, fat-finger friendly.
6. **Profile Mode**: Always test on physical devices in `--profile` mode. Debug builds won't work standalone.

## Constraints & Notes

- Flutter's `FragmentProgram` only supports fragment shaders (no custom vertex shaders needed for 2D)
- Shader uniforms are passed via `FragmentShader.setFloat()` — no named uniforms, index-based
- `draw.frag` exists but is NOT currently used — drawing is done via Canvas API for Impeller compatibility
- The generative shader's Y axis is flipped at the top of `main()` to match WebGL convention; all texture() calls flip Y back
- `shouldRepaint: true` on the CustomPainter ensures every frame repaints
