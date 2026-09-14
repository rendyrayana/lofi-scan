# Claude Code Guide — lofi-scan

Read alongside `PROJECT_SUMMARY.md` (current build state). This is the one
guide needed for the current UI redesign work — control rules, layout,
performance checks, and the build order, all in one place.

## Resolved decisions (don't re-litigate)

1. **Wireframe** (green overlay, PSX/Look section) is an independent toggle
   layered on top of the shaded render — not an exclusive shading mode.
   - The Phase-1 Clay matcap + auto-wireframe (auto-shown during geo
     analysis, auto-hidden entering texture phase) is a **separate,
     automatic** feature — keep it automatic, don't merge it with the Look
     toggle.
2. **Poly tier and Texture tier selection are fully independent** — no
   coupling logic needed.

## Recognizability metric: SSIM + Hausdorff, combined

Use both, not one:
- **SSIM** (render-based) — catches "does it look right from a normal
  angle," but averages across the whole image, so a small collapsed
  feature barely moves the score.
- **Hausdorff distance** (geometric, no render — nearest-neighbor distance
  via `trimesh`/`Open3D`, normalized to bbox diagonal) — catches worst-case
  local deviation anywhere on the mesh, which is exactly what SSIM misses.
  Costs milliseconds, since it needs no render pass — doesn't change the
  pipeline's speed profile. SSIM's render step remains the actual
  bottleneck.
- Show **both** next to each poly preset (e.g. "75% - SSIM 91% - max dev
  2.8%") instead of one collapsed number — this is what fixes the "85% SSIM
  but still visibly under-poly'd" case, since Hausdorff flags the local
  miss SSIM's average smooths over.

## Control type rules

| Use... | ...when the value is |
|---|---|
| Toggle | Binary on/off, no meaningful in-between |
| Slider (0–1, shown as %) | A normalized blend/mix factor (CRT intensity, curvature) |
| Slider (custom range + units) | A physical quantity — light intensity, gamma, degrees, speed. Don't force these into 0–1. |
| Segmented control | 2–5 exclusive choices, switched often (poly tier, manipulator mode) |
| Dropdown | >5 choices, or switched rarely |
| Numeric stepper | An exact value matters (tri count override, resolution, fps) |
| Color picker | Feeds a `source_color` uniform |
| Dual-range slider | A min/max pair (fog range) |
| Direction gizmo, not XYZ sliders | A 3D direction (sun direction) |
| Action button | A one-shot operation, not a state |

## Section regrouping — old location to new home

Five collapsible sections: **Shape - Surface - Look - Motion - Export**,
replacing the current flat panel list.

**Shape** (was Phase 1): Load button, 4 poly presets (+ SSIM/Hausdorff
score per preset), poly range arrows, GeoStatus, stats toggle.
New: Manipulator (Move/Scale/Rotate as a real viewport gizmo, not just
buttons), Center Pivot (action button — recenters pivot to bounds), Center
at Origin (action button — moves object to world 0,0,0; distinct from
Center Pivot).

**Surface** (was Phase 2): Bake Texture button, 4 texture size buttons, tex
range arrows, TexStatus, result label.

**Look** (was PSX + CRT + background sections): Pixelate, Snap/Affine/
Dither toggles, Wireframe toggle, CRT sliders (Grain/Chroma/Scanlines/
Vignette/Warble — already correctly 0–1, no changes needed), background
color.
New: Directional light (color + energy slider, NOT 0–1 — e.g. 0–3, default
1.0) and Ambient light (color + energy slider, same pattern). Check
`fill_light` uniform in the shader first — may need one new float uniform
for energy if it's currently color-only.

**Motion** (was Scene section): Turntable toggle + speed slider.

**Export** (was scattered — GLB export lived in Surface, capture was its
own section): Snapshot, Record + format picker (keep the existing embedded
Python encoder — it avoids bundling system ffmpeg, which is the right
call), Export GLB (moved here so every "produce a file" action lives in
one place).

## Performance — verify before restructuring UI

Not necessarily broken, just confirm:
1. Hi-res original mesh renders immediately on drop, while SSIM/Hausdorff
   analysis runs in the background — not a blank viewport during Analysis.
2. The 4 texture resolutions come from **one** Cycles bake + resizes, not 4
   separate bakes.
3. "Cache freshness check" covers the analysis result itself (not just the
   baked GLB), so re-dropping the same mesh doesn't rerun analysis.

## Godot implementation notes

- Convert the flat `VBoxContainer` list into five accordion sections —
  each header toggles via `Tween` (~0.2-0.25s ease-out), not instant
  show/hide.
- One shared `Theme` resource across all sections, not per-section styling.
- New Manipulator is a real viewport gizmo (drag handles), not side-panel
  buttons with no visual handle.
- New light energy sliders update live every frame, same as existing CRT
  sliders — no debounce. Debounce only applies to controls that trigger a
  background recompute (poly/texture custom overrides), not to any Look/
  Motion control.

## Build order

1. Verify the 3 performance items above.
2. Build Shape additions (Manipulator, Center Pivot, Center at Origin) —
   isolated, safe to add without touching working code.
3. Add lighting controls — check shader uniform support first.
4. Reorganize into the five accordion sections (structural only, no
   pipeline logic changes).
5. Apply shared Theme + Tween transitions.
6. Add SSIM + Hausdorff score display next to poly presets.
