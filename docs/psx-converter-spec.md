# PSX-Style 3D Asset Converter — Project Spec

## 1. Goal

A standalone desktop app that converts a 3D-scanned object (hi-res mesh + texture,
from Revopoint) into a PS1/PSX-style low-poly, low-res asset — automatically,
without ZBrush/Maya, and with per-object parameters chosen automatically rather
than guessed manually. This is also intended as a research pipeline: every run
should log its parameters and results for later analysis.

## 2. Why this design

Manual testing showed recognizable poly count and texture resolution vary
enormously per object — some objects hold up at 100 tris, others need 1000+;
some read fine at 16px texture, others need 128px or more. So the app must not
use fixed tri-count/resolution presets. Instead, it searches for the minimum
tri count / texture resolution that preserves a target recognizability score,
per object, per quality tier.

## 3. Architecture

```
Godot (front-end + shader preview + renderer/export)
   |  writes config.json, calls subprocess
   v
Blender --background (headless)
   |  decimate -> bake hi-to-low -> export mesh
   v
Python (Pillow/NumPy)
   |  texture downsample -> upsample
   v
back to Godot: load mesh + texture, apply existing PSX shader, render live preview
   |  Movie Maker mode captures frames
   v
ffmpeg (external binary, bundled) -> encode video (mp4/webm/gif), apply loop
```

- **Godot** is the only thing the user touches directly: UI (built visually,
  same workflow as designing a game UI), trigger button, live shader
  viewer, and renderer/export controls.
- **Blender headless** (`bpy`) does decimation and hi-to-low texture baking.
  Free, scriptable, no external license needed by anyone reproducing this.
- **Python (Pillow/NumPy)** handles texture down/upsampling.
- **meshoptimizer** (Python bindings) is the preferred decimation backend if
  Blender's built-in decimate modifier proves too coarse for error-targeted
  simplification — verify current API/bindings when implementing, libraries
  update over time.
- **ffmpeg** (free, open-source, bundleable binary) encodes captured frame
  sequences into video files — see section 6.
- All stages communicate via files on disk (config in, mesh/texture out) —
  simple, debuggable, and lets any stage be swapped without touching others.
- The existing PS1-style spatial shader (provided separately, place at
  `godot_app/shaders/psx_shader.gdshader`) already implements vertex snapping,
  affine UV warping, Bayer dithering, distance fog, and a two-light
  (sun + fill) Gouraud lighting model. UI controls in sections 5 and 6 should
  bind directly to this shader's existing uniforms rather than modifying it,
  except where noted.

## 4. Core logic: adaptive per-object parameter search

### 4.1 Quality tiers (fixed, defined as retained-recognizability targets, not
raw numbers)

| Tier | Target recognizability retained |
|------|----------------------------------|
| 1    | 95% |
| 2    | 85% |
| 3    | 70% |
| 4    | 50% |

### 4.2 Recognizability metric

- Render the original hi-res mesh and a candidate simplified mesh from a small
  fixed set of camera angles (e.g. front/3-quarter/top).
- Score similarity with **SSIM** as the baseline metric (fast, simple).
- Leave room to swap in **LPIPS** (a learned perceptual metric) if SSIM proves
  too crude for feature-heavy objects — decide after calibration (4.4).

### 4.3 Search procedure (per object, per tier)

1. **Polygon count** — binary search between a low bound (~50 tris) and high
   bound (~5000 tris, or hi-res count if lower). Each step: decimate to
   candidate count, render, score against original, narrow range. Converges
   in ~7-10 iterations to the minimum tri count hitting the tier's target.
2. **Texture resolution** — fixed mesh from step 1, sweep a small fixed set of
   resolutions (e.g. 16/32/64/128/256px) rather than binary search (small
   space), find the minimum that clears the tier's target.
3. Log per object, per tier: final tri count, final texture resolution,
   achieved recognizability score, and thumbnail renders.

### 4.4 Calibration step (do this before trusting the search at scale)

Run the search on a handful of objects where the manual answer is already
known (e.g. one that's safe at 100 tris, one that needs 1000+). Compare the
automated result to the known-good manual result. If they disagree
meaningfully, that's the signal to swap SSIM for LPIPS or add a stricter
local-feature check — this comparison is also useful to document directly in
the eventual write-up as validation of the automated proxy.

## 5. UI requirements

### Required controls
1. **Upload** — drop/select a scan folder or mesh+texture file pair.
2. **Download/Export** — export final asset (mesh + texture) in a standard
   format (glTF/.glb preferred for portability; consider also offering
   .obj+textures).
3. **Polygon parameter controls** — not a single slider, since tri count is a
   *result* of the search, not a direct input. Show:
   - Tier selector (1–4, or "custom target %")
   - Read-only display of the resulting tri count once search completes
   - Manual override slider, for cases where the user wants to force a
     specific count after seeing the auto result
4. **Texture parameter controls** — same pattern:
   - Auto-searched resolution shown after processing
   - Manual override for intermediate downsample resolution
5. **Texture modification sliders** — for the PSX-style look itself, exposed
   as sliders/toggles bound to the shader's existing uniforms:
   - `use_dither` toggle + `dither_gamma` slider
   - Color tint (`color_tint`)
   - `use_affine_uv` toggle (classic PSX warping)
   - `snap_vertices` toggle (PSX vertex jitter/snapping)
   - `use_fog` toggle + `fog_tint` color + `fog_range` min/max sliders
6. **Background color** — a color picker bound to the scene's
   `WorldEnvironment` background/clear color. No shader changes needed.
7. **Lighting controls** — bound to the shader's existing `dynamic_lighting`
   uniforms:
   - Toggle `dynamic_lighting`
   - Sun direction (a direction gizmo or pitch/yaw sliders feeding
     `sun_direction`)
   - Sun intensity slider (`sun_intensity`)
   - Fill light color picker (`fill_light`)
   - Optional: a second independent light. The current shader bakes exactly
     one sun + one flat fill into the vertex stage (deliberately, since real
     PS1 lighting was per-vertex/Gouraud). Adding a second sun-like light is a
     small, contained shader edit (one more direction/intensity uniform pair
     folded into the existing `n_dot_l` calculation) — worth deciding whether
     to include this now or treat as a later addition.
8. **Turntable controls**:
   - Rotation speed (degrees/second)
   - Axis (default Y, expose as override if needed)
   - Start/stop toggle for live preview spin
9. **Video export controls**:
   - "Export video" button/trigger
   - Loop mode: single pass / loop N times / loop forever
   - Output format: mp4 / webm / gif
   - Resolution and frame rate

### Suggested additional features
- **Before/after compare view** — side-by-side or toggle between original
  hi-res render and processed PSX result.
- **Recognizability score display** — show the achieved score next to each
  tier result so the user isn't guessing whether "Tier 2" actually held up
  for this specific object.
- **Batch mode** — run the full search across a folder of multiple scanned
  objects unattended (this is where the parallel-processing benefit
  discussed earlier actually applies — multiple objects/tiers processed
  concurrently, bounded by CPU cores).
- **Manifest/log export** — a CSV or JSON dump of every object's per-tier
  results (tri count, texture res, score) for later analysis/writeup.
- **Preset save/load** — save a particular manual override combination
  (including lighting/background/turntable settings) as a named preset for
  reuse.
- **Progress indicator** — search + bake take real time per object; a
  progress bar or status log avoids the app looking frozen. Video export via
  Movie Maker mode also runs slower than real-time, so it needs its own
  progress indicator.
- **Reset to auto** — one-click revert from manual override back to the
  searched result.

## 6. Turntable & video export — technical approach

1. **Rotation**: script-driven rotation of either the object or the camera
   around a fixed axis, at the speed set in the UI (degrees/second) — not a
   baked AnimationPlayer clip, since speed needs to stay a live parameter.
2. **Frame capture**: use Godot 4's built-in **Movie Maker mode**, which
   captures frames deterministically (it slows real-time down to however long
   each frame takes to render, so output is smooth regardless of the host
   machine's performance) and writes an image sequence or uncompressed AVI.
3. **Encoding**: pipe the captured frames through **ffmpeg** (bundled as a
   standalone binary alongside Blender, same reasoning — free, no license
   dependency for anyone reproducing this) to produce mp4/webm/gif.
4. **Looping is free by construction**: a full 360° turntable naturally
   returns to its starting frame, so any exported clip loops seamlessly
   as long as background and lighting stay static during the render — no
   special loop-point handling needed. Loop *count* vs. infinite loop is
   just an ffmpeg flag (`-loop`) applied at encode time.
5. **Speed** is decoupled from encode frame rate: rotation degrees/second
   controls how much the object turns per real second, while export frame
   rate controls output smoothness — both should be independent UI fields.

## 7. Suggested folder structure

```
/project-root
  /blender_scripts       # decimate + bake, called headless
  /python_texture        # downsample/upsample, dither, palette reduction
  /godot_app              # UI + shader viewer + orchestration
    /shaders               # existing psx_shader.gdshader lives here
  /cache                  # per-object, per-tier processed outputs
  /manifests               # logged run results (JSON/CSV)
  /video_out               # exported turntable videos
```

## 8. Suggested dependencies to install before starting

- Python 3.10+
- Blender (bundles its own Python; used headless via `--background --python`)
- Godot (already in use)
- Git (version control from day one)
- ffmpeg (for turntable video export/encoding)
- Python packages: `Pillow`, `numpy`, `scikit-image` (for SSIM), optionally
  `lpips` and `meshoptimizer` bindings if needed later

## 9. Build order (suggested milestones)

1. Blender headless script: decimate to a *fixed* tri count + bake, tested on
   one real scan — confirm mesh/texture integrity before anything else.
2. Wrap step 1 in the binary-search loop against a recognizability score for
   one object, one tier — confirm the search converges sensibly.
3. Add texture resolution sweep on top of the result.
4. Minimal Godot UI: upload button, "Process" button, viewer with existing
   PSX shader applied to whatever's in `/cache`.
5. Wire Godot -> Blender subprocess call end-to-end for one object, one tier.
6. Add remaining tiers, manual override sliders, export/download.
7. Add background color, lighting controls, turntable rotation.
8. Add video export (Movie Maker capture + ffmpeg encode), loop/speed options.
9. Add batch mode + manifest logging.
10. Calibration pass (4.4) across several known objects before trusting the
    pipeline on a full scan collection.

## 10. Open decisions to confirm before/while building

- SSIM vs LPIPS for the recognizability metric (start with SSIM, revisit
  after calibration).
- Exact camera angle set used for scoring (must be fixed/consistent across
  all objects for fair comparison).
- Export format(s): glTF/.glb only, or also .obj?
- Whether meshoptimizer is needed or Blender's native decimate modifier is
  sufficient once error-driven rather than ratio-driven.
- Whether to add a second independent light to the shader now, or keep the
  single sun+fill model for the initial version.
