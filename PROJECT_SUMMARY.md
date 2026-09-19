# lofi-scan — Project Summary

## What is it?
A desktop app (Godot 4.7 + Python/Blender pipeline) that converts hi-res 3D-scanned objects into PSX-style low-poly/low-res assets. Drag in a `.obj`/`.ply`/`.glb`, it auto-finds the minimum recognizable polygon count, lets you pick a level, bakes a texture, and exports a PSX-ready GLB.

---

## Pipeline Overview

```
Scan mesh (.obj / .ply / .glb)
    ↓
[Analysis] Binary search via SSIM — finds minimum tri count
    ↓
[Geo Preview] Pick from 4 poly presets (25/50/75/100% of minimum)
    ↓
[Texture Bake] Bakes 4 resolutions: 64 / 128 / 256 / 512 px
    ↓
[PSX Renderer] Apply PSX effects, preview, export
```

---

## Current Features

### Phase 1 — Geometry
- **Auto-analysis**: Blender headless binary search using SSIM (structural similarity) finds the minimum recognizable tri count
- **4 poly preset buttons**: 25%, 50%, 75%, 100% of minimum — recalculate to actual tri counts
- **Poly range ↑/↓**: Double/halve max tris (capped at source mesh limit so ↑ stops when it hits the actual mesh resolution)
- **Batch preview**: After analysis, all 4 presets are pre-baked simultaneously in background — clicking a preset is usually instant (no re-render)
- **Clay matcap preview**: Mathematical clay-ball shader (view-space normals, no texture file needed) with fake cavity AO — shows facets and form clearly
- **Wireframe auto-enabled** in geo preview, auto-disabled when entering texture phase
- **Stats overlay**: Shows tri count in bottom-left of viewport (always on by default)
- **Cache freshness check**: Detects stale cached GLBs and regenerates

### Phase 2 — Texture
- **4 baked resolutions**: 64 / 128 / 256 / 512 px (configurable range via ↑/↓ before baking)
- **Instant texture switching**: All 4 GLBs are preloaded into the scene tree — switching resolution is zero-latency (hide/show, no disk I/O)
- **GPU auto-detection**: Metal (Mac) → CUDA → OpenCL → CPU fallback
- **Fast baking**: Cycles samples reduced to 8, render resolution 256px
- **Cage extrusion auto-set to 6%** of bounding box longest axis (reduces backface bleed at low poly)

### Phase 3 — PSX Renderer
- **PSX shader**: Vertex snapping, affine UV warping, dithering
- **Pixelation**: Shrinks SubViewport to n% then upscales with NEAREST filter — true pixel-art resolution
- **CRT effects**: Film grain, chromatic aberration, scanlines, vignette, warble (all with sliders)
- **Turntable**: Auto-rotate with speed control
- **Wireframe toggle**: Green wireframe overlay
- **Background color picker**

### Capture
- **Snapshot**: Save current frame as PNG
- **Video export**: 72-frame 360° turntable → MP4 or GIF (via embedded Python encoder, no system ffmpeg needed)
- **GLB export**: Copy the final baked GLB to any path

### UX / General
- **Drag & drop**: Drop mesh files directly onto the window
- **Auto-load**: On startup, finds the most recent baked GLB in cache and loads it
- **Real-time progress**: Python scripts write `{pct, msg}` to a JSON file; Godot polls every 0.3s and shows e.g. `"Baking… 47%"`
- **Vertex merge fix**: Scan meshes are often "triangle soup" (disconnected triangles) — Blender merges coincident vertices before decimating so the shape decimates properly

---

## Technical Stack

| Layer | Technology |
|---|---|
| App / UI | Godot 4.7, GDScript, GL Compatibility renderer |
| 3D preview | SubViewport → TextureRect (NEAREST filter for pixelation) |
| PSX shader | Custom `.gdshader` (vertex snap, affine UV, dither) |
| Clay preview | Custom `.gdshader` (mathematical matcap, no texture file) |
| Analysis | Python 3 → Blender headless → SSIM scoring via scikit-image |
| Baking | Blender Cycles (emission bake, hi→lo) |
| Video | Python (Pillow + imageio) |

---

## Current UI Layout (side panel, top → bottom)

1. Load button + filename label
2. 4 × Poly preset buttons (tri counts)
3. Preview row: [Wireframe toggle] [Stats toggle]
4. Poly range row: [↓] [max N tris label] [↑]
5. GeoStatus (progress / result text)
6. Bake Texture button
7. 4 × Texture size buttons (64 / 128 / 256 / 512 px)
8. Tex range row: [↓] [64–512px label] [↑]
9. TexStatus (progress / result text)
10. Result label ("N tris · Npx tex")
11. Export GLB button
12. — PSX section —
13. Pixelate toggle + slider
14. Snap / Affine / Dither / Wireframe toggles
15. — CRT section —
16. Grain / Chroma / Scanlines / Vignette / Warble (each: toggle + slider)
17. — Scene section —
18. Background color picker
19. Turntable toggle + speed slider
20. — Capture section —
21. Snapshot / Record buttons + format picker

**Floating overlay**: Stats counter (bottom-left of 3D viewport)

---

## Pending / Desired Features (not yet implemented)

### Object Manipulation
- Move / rotate / scale the object (not orbit camera — the object itself)
- Center pivot to model bounds
- Center object at world origin

### Scene / Lighting
- Change directional light color and energy
- Change ambient light color and energy
- (Background color already exists)

### Other
- Any remaining render/scene controls not yet exposed in the side panel
