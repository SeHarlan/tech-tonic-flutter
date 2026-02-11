# tech-Tonic (Flutter)

A generative art application being converted from vanilla JS/WebGL to Flutter for mobile. Features interactive controls for drawing, movement effects, and particle-like behavior using GLSL fragment shaders.

## Project Overview

- **Target Stack**: Flutter 3+, Dart, GLSL fragment shaders (`FragmentProgram`)
- **Source Stack**: Vanilla JavaScript, HTML5, CSS3, WebGL (being converted)
- **Type**: Interactive generative art / creative coding
- **Platforms**: iOS, Android (mobile-first)
- **Key Features**: Waterfall effects, brush controls, movement patterns, shader-based rendering

## Conversion Context

This project is a ground-up Flutter rebuild of a vanilla JS/WebGL generative art app. The original source files live in the `reference/` folder.

### Original Architecture (Reference)
- `reference/main.js` - Core WebGL rendering, ping-pong framebuffers, state management, input handling
- `reference/fragmentShader.glsl` - 770-line fragment shader with 53 uniforms (movement, waterfall, reset, colors, noise)
- `reference/vertexShader.glsl` - Simple passthrough vertex shader
- `reference/index.html` - Menu UI with drawer, brush controls, directional pad
- `reference/style.css` - Terminal-aesthetic UI styling

### Key Technical Patterns to Preserve
- **Ping-pong rendering**: Frame N reads from texture A, writes to B; frame N+1 reads from B, writes to A
- **Drawing buffer**: Separate texture where user input is encoded as RGB channel values (R=move/shuffle, G=waterfall/trickle, B=freeze/reset)
- **Seeded randomization**: Reproducible parameter sets from a seed value
- **Noise-based generation**: Perlin-like noise with FBM for pattern selection
- **Feedback loop**: Each frame builds on the previous, creating perpetual animation

## Flutter Architecture

### Shader Strategy
- Use Flutter's `FragmentProgram` API for custom GLSL fragment shaders
- Flutter supports `.frag` shaders in `shaders/` directory (declared in `pubspec.yaml`)
- Port the fragment shader logic, adapting WebGL-specific code to Flutter's GLSL dialect
- Ping-pong rendering via `CustomPainter` with offscreen textures

### State Management
- Use Riverpod for state management
- Shader parameters, drawing state, and UI state as separate providers

### Project Structure (Target)
```
lib/
  main.dart
  app.dart
  features/
    canvas/              # Core rendering
      canvas_screen.dart
      canvas_painter.dart
      shader_controller.dart
    drawing/             # User interaction / brush
      drawing_controller.dart
      drawing_overlay.dart
    controls/            # Menu UI
      controls_drawer.dart
      brush_controls.dart
      direction_pad.dart
      paint_mode_selector.dart
    parameters/          # Shader parameter management
      parameter_state.dart
      seed_generator.dart
shaders/
  fragment.frag          # Main generative shader
  draw.frag              # Drawing/interaction shader
assets/
```

### Input Mapping (Touch-First)
- **Mouse/keyboard controls** → **Touch gestures**
- Single finger draw → brush painting
- Pinch → brush size
- Swipe from bottom → open controls drawer
- Long press → mode selection
- Keyboard shortcuts preserved for desktop builds

## Development Workflow

1. **Run on device/simulator**:
   ```bash
   flutter run
   ```

2. **Run tests**:
   ```bash
   flutter test
   ```

3. **Check shader compilation**:
   - Shaders are compiled at build time via `pubspec.yaml` declarations
   - Test on real devices — shader behavior can differ from simulator

4. **Profile performance**:
   ```bash
   flutter run --profile
   ```

## Code Review Guidelines

1. **Shader Performance**: Check for GPU bottlenecks, minimize uniform updates, batch draws
2. **Shader Compatibility**: Flutter GLSL is a subset — no texture2D (use `texture()`), no WebGL-specific extensions
3. **Touch UX**: Ensure controls are intuitive for mobile (no hover states, fat-finger friendly)
4. **State Management**: Keep rendering state separate from UI state
5. **Memory**: Watch for texture leaks with ping-pong buffers
6. **Platform Differences**: Test shaders on both iOS (Metal backend) and Android (Vulkan/GLES)

## Constraints & Notes

- Flutter's `FragmentProgram` only supports fragment shaders (no custom vertex shaders needed for 2D)
- Shader uniforms are passed via `FragmentShader.setFloat()` — no named uniforms, index-based
- Image/texture sampling in Flutter shaders uses `sampler2D` with specific binding conventions
- Maximum texture units and uniform counts vary by device — keep within OpenGL ES 3.0 limits
- `CustomPainter` with `shouldRepaint: true` drives the render loop
