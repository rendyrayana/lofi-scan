"""
export_3mf.py — Convert a textured GLB to a color 3MF for color 3D printing.

Bakes UV texture into per-vertex RGB colors (m:colorgroup) using bilinear
texture sampling. Optionally quantizes to a small color palette via K-means
(good for multi-filament FDM printers like Bambu AMS).

Usage:
    blender --background --python blender_scripts/export_3mf.py -- config.json

Config JSON:
    input_glb       (str)  Source GLB with baked UV texture
    output_3mf      (str)  Destination .3mf path
    palette_colors  (int)  0 = full colors, otherwise quantize to N colors
    subdivisions    (int)  0 = none, 1 = 4× tris, 2 = 16× tris (Simple subdiv)
"""

import sys, json, os, zipfile
import bpy, bmesh
import numpy as np


_NS_CORE = "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"
_NS_MAT  = "http://schemas.microsoft.com/3dmanufacturing/material/2015/02"

_CONTENT_TYPES = '''\
<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>
</Types>'''

_RELS = '''\
<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Target="/3D/3dmodel.model" Id="rel0"
    Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>
</Relationships>'''


def _sample_bilinear(pixels, w, h, u, v):
    """Bilinear interpolation over a flat RGBA pixel array. Returns (r, g, b) 0-255."""
    u = u % 1.0
    v = 1.0 - (v % 1.0)   # flip V: Blender bottom-left → 3MF top-left

    fx = u * w - 0.5
    fy = v * h - 0.5
    x0 = int(fx) % w;  x1 = (x0 + 1) % w
    y0 = int(fy) % h;  y1 = (y0 + 1) % h
    tx = fx - int(fx);  ty = fy - int(fy)

    def _px(x, y):
        i = (y * w + x) * 4
        return pixels[i], pixels[i + 1], pixels[i + 2]

    r00, g00, b00 = _px(x0, y0)
    r10, g10, b10 = _px(x1, y0)
    r01, g01, b01 = _px(x0, y1)
    r11, g11, b11 = _px(x1, y1)

    w00 = (1 - tx) * (1 - ty)
    w10 = tx       * (1 - ty)
    w01 = (1 - tx) * ty
    w11 = tx       * ty

    r = r00*w00 + r10*w10 + r01*w01 + r11*w11
    g = g00*w00 + g10*w10 + g01*w01 + g11*w11
    b = b00*w00 + b10*w10 + b01*w01 + b11*w11

    return (min(255, int(r * 255 + 0.5)),
            min(255, int(g * 255 + 0.5)),
            min(255, int(b * 255 + 0.5)))


def _kmeans_quantize(rgb: np.ndarray, k: int, max_iter: int = 40) -> np.ndarray:
    """
    K-means color quantization.
    rgb: (N, 3) uint8 array  →  returns (N, 3) uint8 array with at most k unique colors.
    """
    n = len(rgb)
    k = min(k, n)
    rgb_f = rgb.astype(np.float32)

    # K-means++ initialisation: first center random, then pick farthest
    rng = np.random.default_rng(42)
    centers = [rgb_f[rng.integers(n)]]
    for _ in range(k - 1):
        dists = np.min(
            np.sum((rgb_f[:, None] - np.array(centers)[None]) ** 2, axis=2), axis=1
        )
        probs = dists / dists.sum()
        centers.append(rgb_f[rng.choice(n, p=probs)])
    centers = np.array(centers)          # (k, 3)

    assignments = np.zeros(n, dtype=np.int32)
    for _ in range(max_iter):
        dists      = np.sum((rgb_f[:, None] - centers[None]) ** 2, axis=2)  # N×k
        new_assign = np.argmin(dists, axis=1)
        if np.array_equal(new_assign, assignments):
            break
        assignments = new_assign
        for i in range(k):
            mask = assignments == i
            if mask.any():
                centers[i] = rgb_f[mask].mean(axis=0)

    quantized = centers[assignments].clip(0, 255).astype(np.uint8)
    unique = len(np.unique(quantized, axis=0))
    print(f"[export_3mf] K-means k={k} → {unique} unique colors after {max_iter} iter")
    return quantized


def _build_model_xml(split_verts, vert_colors_hex, triangles, has_color):
    lines = []
    a = lines.append

    if has_color:
        a(f'<?xml version="1.0" encoding="UTF-8"?>')
        a(f'<model unit="millimeter" xml:lang="en-US"')
        a(f'       xmlns="{_NS_CORE}" xmlns:m="{_NS_MAT}">')
        a(f'  <resources>')
        a(f'    <m:colorgroup id="1">')
        for c in vert_colors_hex:
            a(f'      <m:color color="{c}"/>')
        a(f'    </m:colorgroup>')
    else:
        a(f'<?xml version="1.0" encoding="UTF-8"?>')
        a(f'<model unit="millimeter" xml:lang="en-US" xmlns="{_NS_CORE}">')
        a(f'  <resources>')

    a(f'    <object id="2" type="model">')
    a(f'      <mesh>')
    a(f'        <vertices>')
    for x, y, z in split_verts:
        a(f'          <vertex x="{x:.4f}" y="{y:.4f}" z="{z:.4f}"/>')
    a(f'        </vertices>')
    a(f'        <triangles>')
    for v1, v2, v3 in triangles:
        if has_color:
            a(f'          <triangle v1="{v1}" v2="{v2}" v3="{v3}"'
              f' pid="1" p1="{v1}" p2="{v2}" p3="{v3}"/>')
        else:
            a(f'          <triangle v1="{v1}" v2="{v2}" v3="{v3}"/>')
    a(f'        </triangles>')
    a(f'      </mesh>')
    a(f'    </object>')
    a(f'  </resources>')
    a(f'  <build>')
    a(f'    <item objectid="2"/>')
    a(f'  </build>')
    a(f'</model>')
    return "\n".join(lines)


def main():
    argv = sys.argv
    if "--" not in argv:
        print("[export_3mf] ERROR: no config path after --", file=sys.stderr)
        sys.exit(1)
    cfg_path = argv[argv.index("--") + 1]
    with open(cfg_path) as f:
        cfg = json.load(f)

    input_glb      = cfg["input_glb"]
    output_3mf     = cfg["output_3mf"]
    palette_colors = int(cfg.get("palette_colors", 0))
    subdivisions   = int(cfg.get("subdivisions", 0))
    os.makedirs(os.path.dirname(output_3mf), exist_ok=True)

    # Clear default scene
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

    bpy.ops.import_scene.gltf(filepath=input_glb)

    mesh_objs = [o for o in bpy.data.objects if o.type == "MESH"]
    if not mesh_objs:
        print("[export_3mf] No mesh imported", file=sys.stderr)
        sys.exit(1)

    bpy.ops.object.select_all(action="DESELECT")
    for o in mesh_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = mesh_objs[0]
    if len(mesh_objs) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object

    # Subdivide for finer color sampling (Simple = shape-preserving)
    if subdivisions > 0:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        sub = obj.modifiers.new("Subdiv", "SUBSURF")
        sub.subdivision_type = "SIMPLE"
        sub.levels = subdivisions
        sub.render_levels = subdivisions
        bpy.ops.object.modifier_apply(modifier="Subdiv")
        tris_after = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        print(f"[export_3mf] Subdivided ×{subdivisions} → {tris_after} tris")

    # Read embedded texture pixels (GLB packs images; skip has_data guard)
    tex_pixels = None
    tex_w = tex_h = 0
    for mat in bpy.data.materials:
        if mat and mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image:
                    img = node.image
                    try:
                        px = img.pixels[:]
                        if len(px) > 0:
                            tex_pixels = list(px)
                            tex_w, tex_h = img.size
                            print(f"[export_3mf] Texture: {img.name} ({tex_w}×{tex_h})")
                        else:
                            print(f"[export_3mf] {img.name} has 0 pixels", file=sys.stderr)
                    except Exception as e:
                        print(f"[export_3mf] Pixel read failed: {e}", file=sys.stderr)
                    break
        if tex_pixels:
            break

    if not tex_pixels:
        print("[export_3mf] No texture — geometry only")

    # Extract triangulated mesh; split per-loop to avoid UV-seam color bleeding
    depsgraph = bpy.context.evaluated_depsgraph_get()
    bm = bmesh.new()
    bm.from_object(obj.evaluated_get(depsgraph), depsgraph)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.faces.ensure_lookup_table()

    uv_layer   = bm.loops.layers.uv.active
    split_verts = []       # (x_mm, y_mm, z_mm)
    vert_colors_rgb = []   # (r, g, b) 0-255
    triangles   = []

    for face in bm.faces:
        tri = []
        for loop in face.loops:
            v   = loop.vert
            idx = len(split_verts)
            split_verts.append((v.co.x * 1000.0, v.co.y * 1000.0, v.co.z * 1000.0))

            if tex_pixels and uv_layer:
                uv = loop[uv_layer].uv
                rgb = _sample_bilinear(tex_pixels, tex_w, tex_h,
                                       float(uv.x), float(uv.y))
            else:
                rgb = (128, 128, 128)
            vert_colors_rgb.append(rgb)
            tri.append(idx)
        triangles.append((tri[0], tri[1], tri[2]))

    bm.free()

    has_color = tex_pixels is not None and uv_layer is not None

    # K-means palette quantization
    if has_color and palette_colors > 0:
        print(f"[export_3mf] Quantizing to {palette_colors} colors…")
        rgb_arr   = np.array(vert_colors_rgb, dtype=np.uint8)
        rgb_arr   = _kmeans_quantize(rgb_arr, palette_colors)
        vert_colors_rgb = [tuple(c) for c in rgb_arr]

    vert_colors_hex = [f"#{r:02X}{g:02X}{b:02X}" for r, g, b in vert_colors_rgb]

    # Center model: XY centroid, Z sits on z=0
    if split_verts:
        xs = [v[0] for v in split_verts]; ys = [v[1] for v in split_verts]
        zs = [v[2] for v in split_verts]
        cx = (min(xs) + max(xs)) / 2.0
        cy = (min(ys) + max(ys)) / 2.0
        cz = min(zs)
        split_verts = [(x - cx, y - cy, z - cz) for x, y, z in split_verts]

    print(f"[export_3mf] {len(split_verts)} verts, {len(triangles)} tris"
          + (f" | palette={palette_colors}" if palette_colors > 0 else " | full color")
          + (" | colored" if has_color else " | grey"))

    model_xml = _build_model_xml(split_verts, vert_colors_hex, triangles, has_color)

    with zipfile.ZipFile(output_3mf, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", _CONTENT_TYPES)
        zf.writestr("_rels/.rels", _RELS)
        zf.writestr("3D/3dmodel.model", model_xml)

    size_kb = os.path.getsize(output_3mf) / 1024
    print(f"[export_3mf] Saved → {output_3mf} ({size_kb:.0f} KB)")


main()
