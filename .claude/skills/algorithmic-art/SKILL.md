---
name: algorithmic-art
description: Creating algorithmic art using p5.js with seeded randomness and interactive parameter exploration. Use when users request creating art using code, generative art, algorithmic art, flow fields, or particle systems. Create original algorithmic art rather than copying existing artists' work.
---

Algorithmic philosophies are computational aesthetic movements expressed through code. Output .md files (philosophy), .html files (interactive viewer), and .js files (generative algorithms).

This happens in two steps:
1. Algorithmic Philosophy Creation (.md file)
2. Express by creating p5.js generative art (.html + .js files)

## Algorithmic Philosophy Creation

Create an ALGORITHMIC PHILOSOPHY (not static images) interpreted through:
- Computational processes, emergent behavior, mathematical beauty
- Seeded randomness, noise fields, organic systems
- Particles, flows, fields, forces
- Parametric variation and controlled chaos

### The Critical Understanding

- What is received: Subtle input from the user as a foundation (not a constraint)
- What is created: An algorithmic philosophy/generative aesthetic movement
- What happens next: Express it in code - creating p5.js sketches that are 90% algorithmic generation, 10% essential parameters

### How to Generate a Philosophy

**Name the movement** (1-2 words): "Organic Turbulence" / "Quantum Harmonics" / "Emergent Stillness"

**Articulate the philosophy** (4-6 paragraphs) expressing how this manifests through:
- Computational processes and mathematical relationships
- Noise functions and randomness patterns
- Particle behaviors and field dynamics
- Temporal evolution and system states
- Parametric variation and emergent complexity

**Guidelines:**
- Avoid redundancy - each algorithmic aspect mentioned once
- Emphasize craftsmanship - the algorithm should appear meticulously crafted
- Leave creative space for implementation choices

### Philosophy Examples

**"Organic Turbulence"**
Philosophy: Chaos constrained by natural law, order emerging from disorder.
Algorithmic expression: Flow fields driven by layered Perlin noise. Thousands of particles following vector forces, their trails accumulating into organic density maps.

**"Quantum Harmonics"**
Philosophy: Discrete entities exhibiting wave-like interference patterns.
Algorithmic expression: Particles initialized on a grid, each carrying a phase value that evolves through sine waves. Phase interference creates bright nodes and voids.

**"Field Dynamics"**
Philosophy: Invisible forces made visible through their effects on matter.
Algorithmic expression: Vector fields from mathematical functions or noise. Particles flowing along field lines, showing ghost-like evidence of invisible forces.

---

## P5.JS Implementation

### Technical Requirements

**Seeded Randomness (Art Blocks Pattern)**:
```javascript
let seed = 12345;
randomSeed(seed);
noiseSeed(seed);
```

**Parameter Structure**:
```javascript
let params = {
  seed: 12345,
  // Quantities (how many?)
  // Scales (how big? how fast?)
  // Probabilities (how likely?)
  // Ratios (what proportions?)
  // Angles (what direction?)
  // Thresholds (when does behavior change?)
};
```

### Craftsmanship Requirements

Create algorithms that feel meticulously crafted by a master generative artist:
- **Balance**: Complexity without visual noise, order without rigidity
- **Color Harmony**: Thoughtful palettes, not random RGB values
- **Composition**: Even in randomness, maintain visual hierarchy and flow
- **Performance**: Smooth execution, optimized for real-time if animated
- **Reproducibility**: Same seed ALWAYS produces identical output

### Common P5.js Patterns

```javascript
// Drawing with transparency for trails/fading
function fadeBackground(opacity) {
    fill(250, 249, 245, opacity);
    noStroke();
    rect(0, 0, width, height);
}

// Using noise for organic variation
function getNoiseValue(x, y, scale = 0.01) {
    return noise(x * scale, y * scale);
}

// Creating vectors from angles
function vectorFromAngle(angle, magnitude = 1) {
    return createVector(cos(angle), sin(angle)).mult(magnitude);
}

// Color utilities
function hexToRgb(hex) {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? {
        r: parseInt(result[1], 16),
        g: parseInt(result[2], 16),
        b: parseInt(result[3], 16)
    } : null;
}
```

### Output Format

1. **Algorithmic Philosophy** - Markdown file explaining the generative aesthetic
2. **Single HTML Artifact** - Self-contained interactive generative art

The HTML artifact contains everything: p5.js (from CDN), the algorithm, parameter controls, and UI - all in one file that works immediately in any browser.

---

## Resources

Templates are available in this skill's directory:
- **templates/viewer.html**: Starting point for HTML artifacts with UI structure
- **templates/generator_template.js**: Reference for p5.js best practices and code structure

Read these files for implementation patterns.
