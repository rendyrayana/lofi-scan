"""
Render a mesh from 3 fixed camera angles for SSIM scoring.

Used by search.py at every binary-search iteration to compare hi-res
vs lo-res renders. Uses a flat neutral material so SSIM measures
geometric shape, not texture colour.

Usage:
    blender --background --python blender_scripts/render_views.py -- config.json

Config JSON fields:
    input_mesh       (str)   Mesh to render (.obj / .glb / .ply)
    output_dir       (str)   Where to write view_front.png, view_3q.png, view_top.png
    target_tri_count (int)   If > 0, decimate to this count before rendering.
    merge_distance   (float) Vertex-merge threshold; 0 = auto.
    render_resolution(int)   Square render size in pixels (default 256).
    camera_distance  (float) Camera distance multiplier vs bounding-sphere radius (default 2.5).
    use_texture      (bool)  If true, keep original material instead of flat grey (default false).
    input_texture    (str)   Optional explicit texture path when use_texture=true on an .obj.

Outputs:
    view_front.png, view_3q.png, view_top.png   — grayscale-friendly renders
    result.json                                   — tri count + render paths
"""

import sys, json, os, math
import bpy
from mathutils import Vector


# ---------------------------------------------------------------------------
# Helpers (duplicated from decimate_bake.py to keep scripts self-contained)
# ---------------------------------------------------------------------------

def import_mesh(filepath):
    before = {o.name for o in bpy.data.objects}
    ext = os.path.splitext(filepath)[1].lower()
    if ext == ".obj":
        try:    bpy.ops.wm.obj_import(filepath=filepath)
        except AttributeError: bpy.ops.import_scene.obj(filepath=filepath)
    elif ext in (".gltf", ".glb"):
        bpy.ops.import_scene.gltf(filepath=filepath)
    elif ext == ".ply":
        try:    bpy.ops.wm.ply_import(filepath=filepath)
        except AttributeError: bpy.ops.import_mesh.ply(filepath=filepath)
    else:
        raise ValueError(f"Unsupported format: {ext}")
    added = [o for o in bpy.data.objects if o.name not in before and o.type == "MESH"]
    if not added:
        raise RuntimeError(f"No mesh found in {filepath}")
    return added[0]


def select_only(obj, ctx):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    ctx.view_layer.objects.active = obj


def count_tris(obj):
    return sum(1 if len(p.vertices) == 3 else 2 for p in obj.data.polygons)


def assign_flat_material(obj):
    """Replace all materials with a neutral flat grey for unbiased SSIM scoring."""
    mat = bpy.data.materials.new("FlatGrey")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    bsdf = nodes.new("ShaderNodeBsdfDiffuse")
    bsdf.inputs["Color"].default_value = (0.7, 0.7, 0.7, 1.0)
    out = nodes.new("ShaderNodeOutputMaterial")
    mat.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def bbox_center_and_radius(obj):
    corners = [obj.matrix_world @ Vector(v) for v in obj.bound_box]
    center = sum(corners, Vector()) / 8
    radius = max((v - center).length for v in corners)
    return center, radius


def add_camera(name, location, target, scene):
    cam_data = bpy.data.cameras.new(name)
    cam_data.lens = 50
    cam = bpy.data.objects.new(name, cam_data)
    scene.collection.objects.link(cam)
    cam.location = location
    direction = target - location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return cam


def render_to(cam, filepath, scene):
    scene.camera = cam
    scene.render.filepath = filepath
    bpy.ops.render.render(write_still=True)


def setup_lighting(scene, center, radius):
    # Key sun
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 4
    sun = bpy.data.objects.new("Sun", sun_data)
    scene.collection.objects.link(sun)
    sun.location = center + Vector((radius * 2, -radius * 2, radius * 3))
    sun.rotation_euler = (math.radians(40), 0, math.radians(45))
    # Soft ambient via world
    scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    bg.inputs["Strength"].default_value = 0.4


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    argv = sys.argv
    try:
        args = argv[argv.index("--") + 1:]
    except ValueError:
        print("[render_views] ERROR: pass config.json after '--'"); sys.exit(1)

    with open(args[0]) as f:
        cfg = json.load(f)

    input_mesh       = cfg["input_mesh"]
    output_dir       = cfg["output_dir"]
    target_tri_count = int(cfg.get("target_tri_count", 0))
    merge_distance   = float(cfg.get("merge_distance", 0.0))
    render_res       = int(cfg.get("render_resolution", 256))
    cam_dist_factor  = float(cfg.get("camera_distance", 2.5))
    use_texture      = bool(cfg.get("use_texture", False))
    input_texture    = cfg.get("input_texture")

    os.makedirs(output_dir, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    ctx = bpy.context
    scene = ctx.scene

    # -- Import --
    obj = import_mesh(os.path.abspath(input_mesh))

    # -- Optional merge + decimate (same logic as decimate_bake.py) --
    if merge_distance <= 0:
        dims = obj.dimensions
        merge_distance = min(dims.x, dims.y, dims.z) * 0.001

    select_only(obj, ctx)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=merge_distance)
    bpy.ops.object.mode_set(mode="OBJECT")
    merged_tris = count_tris(obj)

    if target_tri_count > 0 and target_tri_count < merged_tris:
        ratio = target_tri_count / max(merged_tris, 1)
        mod = obj.modifiers.new("Dec", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        select_only(obj, ctx)
        bpy.ops.object.modifier_apply(modifier="Dec")

    final_tris = count_tris(obj)

    # -- Material: flat grey for shape scoring; keep original for texture scoring --
    if use_texture:
        # If an explicit texture path was given, wire it into the first material.
        # GLB files already have texture embedded — nothing extra needed there.
        if input_texture:
            image = bpy.data.images.load(os.path.abspath(input_texture))
            if not obj.data.materials:
                mat = bpy.data.materials.new("TexMat")
                mat.use_nodes = True
                obj.data.materials.append(mat)
            mat = obj.data.materials[0]
            mat.use_nodes = True
            nodes = mat.node_tree.nodes
            img_nodes = [n for n in nodes if n.type == "TEX_IMAGE"]
            if img_nodes:
                img_nodes[0].image = image
            else:
                img_node = nodes.new("ShaderNodeTexImage")
                img_node.image = image
                bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
                if bsdf:
                    mat.node_tree.links.new(img_node.outputs["Color"],
                                            bsdf.inputs["Base Color"])
    else:
        assign_flat_material(obj)

    # -- Camera positions (fixed relative to bounding box) --
    center, radius = bbox_center_and_radius(obj)
    d = radius * cam_dist_factor

    # Front: looking along +Y toward center
    cam_front = add_camera("CamFront",
        center + Vector((0, -d, 0)),
        center, scene)

    # 3-quarter: 45° horizontal + 25° vertical
    cam_3q = add_camera("Cam3Q",
        center + Vector((
            d * math.sin(math.radians(45)),
            -d * math.cos(math.radians(45)),
            d * math.sin(math.radians(25)),
        )),
        center, scene)

    # Top: looking straight down
    cam_top = add_camera("CamTop",
        center + Vector((0, 0, d)),
        center + Vector((0, 0.001, 0)),  # slight Y offset avoids gimbal lock
        scene)

    # -- Lighting --
    setup_lighting(scene, center, radius)

    # -- Render settings --
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = render_res
    scene.render.resolution_y = render_res
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False

    # -- Render 3 views --
    views = {}
    for cam, name in [(cam_front, "front"), (cam_3q, "3q"), (cam_top, "top")]:
        path = os.path.abspath(os.path.join(output_dir, f"view_{name}.png"))
        render_to(cam, path, scene)
        views[name] = path
        print(f"[render_views] {name}: {path}")

    result = {
        "input_mesh":   os.path.abspath(input_mesh),
        "merged_tris":  merged_tris,
        "final_tris":   final_tris,
        "views":        views,
    }
    with open(os.path.join(output_dir, "result.json"), "w") as f:
        json.dump(result, f, indent=2)
    print(f"[render_views] Done. tris={final_tris}")


main()
