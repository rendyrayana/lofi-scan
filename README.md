# lofi-scan

Automated pipeline converting 3D scans into recognizability-calibrated PSX-style low-poly/low-res assets.

<!-- screenshot or short GIF goes here once the UI exists -->

## What it does

lofi-scan takes a hi-res 3D-scanned object (mesh + texture, from Revopoint or similar) and converts it into a PS1/PSX-style low-poly, low-res asset, automatically, without ZBrush or Maya. Rather than using fixed tri-count presets, the pipeline runs a per-object adaptive search to find the minimum polygon count and texture resolution that still preserves a target recognizability score. Every run logs its parameters and results for later analysis, making this usable as a research pipeline as well as a production tool.

## Architecture

```
Godot (front-end + shader preview + renderer/export)
   ↓  writes config.json, calls subprocess
Blender --background (headless)
   ↓  decimate → bake hi-to-low → export mesh
Python (Pillow/NumPy)
   ↓  texture downsample → upsample
back to Godot: load mesh + texture, apply PSX shader, render live preview
   ↓  Movie Maker mode captures frames
ffmpeg → encode video (mp4/webm/gif), apply loop
```

See [docs/psx-converter-spec.md](docs/psx-converter-spec.md) for the full design spec, including the adaptive search algorithm, quality tiers, UI requirements, and build order.

## Requirements

- Python 3.10+
- Blender (3.x or later; used headless via `--background --python`)
- Godot 4.x
- ffmpeg

Python packages (install via pip):

```bash
pip install Pillow numpy scikit-image
```

## Setup

```bash
git clone https://github.com/your-username/lofi-scan.git
cd lofi-scan
pip install Pillow numpy scikit-image
```

Install Blender, Godot, and ffmpeg separately and ensure they are on your PATH (or set their paths in the Godot UI once available).

## Usage

_Full usage instructions will be added as each milestone from the build order is completed._

1. Drop a scan (mesh + texture) into the Godot UI upload panel.
2. Select a quality tier (1–4) or set a custom recognizability target.
3. Click "Process" — the pipeline runs Blender decimation + bake, then texture sampling.
4. Preview the result live in the shader viewer with PSX-style effects applied.
5. Export the asset (glTF/.glb) or render a turntable video.

## Folder structure

```
/blender_scripts    headless Blender scripts (decimate, bake)
/python_texture     texture downsample/upsample utilities
/godot_app          Godot project (UI, shader viewer, orchestration)
  /shaders          psx_shader.gdshader lives here
/cache              per-object, per-tier processed outputs (gitignored)
/manifests          logged run results (JSON/CSV + thumbnails)
/video_out          exported turntable videos (gitignored)
/docs               project spec and repo guide
```

## License

MIT — see [LICENSE](LICENSE)

## Design rationale / full spec

See [docs/psx-converter-spec.md](docs/psx-converter-spec.md)
