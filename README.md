# lofi-scan

Convert 3D scans into PSX-style low-poly assets, automatically.

<!-- screenshot or GIF goes here -->

## What it does

Takes a hi-res 3D-scanned object and converts it into a PS1-style low-poly, low-res asset without ZBrush or Maya. Instead of fixed presets, it runs a per-object search to find the minimum polygon count and texture resolution that still keeps the object recognizable. Results are logged for use as a research pipeline or production tool.

## How it works

```
Godot (UI + shader preview + export)
   calls Blender headless
Blender (decimate + bake hi-to-low mesh)
   calls Python
Python (texture downsample/upsample)
   back to Godot
Godot (apply PSX shader, live preview, export)
   captures frames
ffmpeg (encode mp4/gif)
```

## Requirements

- Godot 4.x
- Blender 3.x or later
- Python 3.10+
- ffmpeg

```bash
pip install Pillow numpy scikit-image
```

## Setup

```bash
git clone https://github.com/your-username/lofi-scan.git
cd lofi-scan
pip install Pillow numpy scikit-image
```

Install Blender, Godot, and ffmpeg separately. Set their paths in the Godot UI if they are not on your PATH.

## Usage

1. Load a scan (mesh + texture) in the Godot app.
2. Pick a polygon count and texture resolution.
3. Bake texture and preview the result live with PSX effects.
4. Export as GLB or render a turntable video.

## Folder structure

```
/blender_scripts    Blender processing scripts (decimate, bake, export)
/godot_app          Godot project (UI, shader, orchestration)
/docs               Project spec and design notes
/cache              Processed outputs (gitignored)
/manifests          Run logs (JSON + thumbnails)
/video_out          Exported videos (gitignored)
```

## License

MIT. See [LICENSE](LICENSE).
