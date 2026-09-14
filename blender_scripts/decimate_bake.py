"""
Milestone 1 — Blender headless: decimate to a fixed tri count + bake hi-to-low texture.

Usage:
    blender --background --python blender_scripts/decimate_bake.py -- config.json

Config JSON fields:
    input_mesh       (str)   Path to the hi-res scan mesh (.obj, .glb/.gltf, or .ply)
    input_texture    (str)   Optional. Explicit texture path if not embedded in the mesh.
    target_tri_count (int)   Fixed poly target for this run (adaptive search comes later).
    output_dir       (str)   Directory to write mesh_lo.glb, texture_baked.png, result.json.
    bake_resolution  (int)   Bake image size in pixels (default 1024).
    cage_extrusion   (float) Blender bake cage extrusion. 0 = auto (2% of bounding box).
    cycles_samples   (int)   Cycles samples for baking (default 32).

Outputs written to output_dir/:
    mesh_lo.glb         Decimated mesh with baked material embedded.
    texture_baked.png   Baked diffuse texture (flat UV atlas).
    result.json         Run log: tri counts, paths, config echo.
"""

import sys
import json
import os

import bpy


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def import_mesh(filepath):
    """Import a mesh file and return the first MESH object added to the scene."""
    before = {o.name for o in bpy.data.objects}
    ext = os.path.splitext(filepath)[1].lower()

    if ext == ".obj":
        try:
            bpy.ops.wm.obj_import(filepath=filepath)       # Blender 4.x+
        except AttributeError:
            bpy.ops.import_scene.obj(filepath=filepath)    # Blender 3.x
    elif ext in (".gltf", ".glb"):
        bpy.ops.import_scene.gltf(filepath=filepath)
    elif ext == ".ply":
        try:
            bpy.ops.wm.ply_import(filepath=filepath)       # Blender 4.x+
        except AttributeError:
            bpy.ops.import_mesh.ply(filepath=filepath)     # Blender 3.x
    else:
        raise ValueError(f"Unsupported mesh format: {ext}")

    added = [o for o in bpy.data.objects
             if o.name not in before and o.type == "MESH"]
    if not added:
        raise RuntimeError(f"No MESH object found after importing {filepath}")
    return added[0]


def count_tris(obj):
    """Approximate tri count (quads counted as 2)."""
    return sum(1 if len(p.vertices) == 3 else 2 for p in obj.data.polygons)


def select_only(obj, context):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    context.view_layer.objects.active = obj


def apply_modifier(obj, mod_name, context):
    select_only(obj, context)
    bpy.ops.object.modifier_apply(modifier=mod_name)


def find_texture_in_material(mat):
    """Return the first Image Texture node image in a material, or None."""
    if not mat or not mat.use_nodes:
        return None
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image:
            return node.image
    return None


def make_emission_material(name, image):
    """
    Build a simple Emission material that outputs the raw texture colour.
    Used on the hi-res so the bake captures pure texture colour, no lighting.
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image

    emit = nodes.new("ShaderNodeEmission")
    out  = nodes.new("ShaderNodeOutputMaterial")

    links.new(tex.outputs["Color"], emit.inputs["Color"])
    links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return mat


def make_bake_target_material(name, bake_image):
    """
    Build the lo-res material: Principled BSDF wired to output (for export),
    plus an unconnected Image Texture node set as active (bake destination).
    The Image Texture is connected to Base Color after baking completes.
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    tex  = nodes.new("ShaderNodeTexImage")
    tex.image = bake_image

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    out  = nodes.new("ShaderNodeOutputMaterial")

    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    # tex is intentionally NOT connected yet — Blender bakes into the active
    # Image Texture node; connection happens after the bake.
    nodes.active = tex
    return mat, tex, bsdf


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    argv = sys.argv
    try:
        sep_index = argv.index("--")
    except ValueError:
        print("[decimate_bake] ERROR: pass a config.json path after '--'")
        sys.exit(1)

    script_args = argv[sep_index + 1:]
    if not script_args:
        print("[decimate_bake] ERROR: no config.json path provided")
        sys.exit(1)

    config_path = script_args[0]
    with open(config_path) as f:
        cfg = json.load(f)

    input_mesh       = cfg["input_mesh"]
    input_texture    = cfg.get("input_texture")
    target_tri_count = int(cfg["target_tri_count"])
    output_dir       = cfg["output_dir"]
    bake_resolution  = int(cfg.get("bake_resolution", 1024))
    cage_extrusion   = float(cfg.get("cage_extrusion", 0.0))
    cycles_samples   = int(cfg.get("cycles_samples", 32))

    os.makedirs(output_dir, exist_ok=True)

    # ------------------------------------------------------------------
    # 1. Clean scene
    # ------------------------------------------------------------------
    bpy.ops.wm.read_factory_settings(use_empty=True)
    context = bpy.context

    # ------------------------------------------------------------------
    # 2. Import hi-res mesh
    # ------------------------------------------------------------------
    print(f"[decimate_bake] Importing: {input_mesh}")
    hi_res = import_mesh(os.path.abspath(input_mesh))
    hi_res.name = "HiRes"
    original_tri_count = count_tris(hi_res)
    print(f"[decimate_bake] Hi-res tri count: {original_tri_count}")

    # ------------------------------------------------------------------
    # 3. Resolve the source texture image
    #    Priority: explicit input_texture arg > texture already in material
    # ------------------------------------------------------------------
    source_image = None
    if input_texture:
        source_image = bpy.data.images.load(os.path.abspath(input_texture))
        print(f"[decimate_bake] Using explicit texture: {input_texture}")
    else:
        for mat in hi_res.data.materials:
            source_image = find_texture_in_material(mat)
            if source_image:
                print(f"[decimate_bake] Using embedded texture: {source_image.name}")
                break

    if source_image is None:
        raise RuntimeError(
            "No texture found. Supply 'input_texture' in the config "
            "or ensure the mesh has an embedded material with a texture."
        )

    # ------------------------------------------------------------------
    # 4. Set hi-res material → pure Emission (texture colour, no lighting).
    #    This is the bake SOURCE. Using Emission + EMIT bake type gives a
    #    clean, lighting-independent colour transfer.
    # ------------------------------------------------------------------
    hi_emit_mat = make_emission_material("HiRes_Emit", source_image)
    hi_res.data.materials.clear()
    hi_res.data.materials.append(hi_emit_mat)

    # ------------------------------------------------------------------
    # 5. Merge vertices by distance on hi-res before duplicating.
    #    Raw scan meshes are often "triangle soup" — every triangle is a
    #    disconnected island with no shared vertices. The Decimate modifier
    #    can't collapse isolated triangles, so without this step it just
    #    picks N random floating triangles instead of simplifying the shape.
    #    Merging welds spatially coincident vertices into a proper mesh.
    # ------------------------------------------------------------------
    merge_distance = float(cfg.get("merge_distance", 0.0))
    if merge_distance <= 0:
        # Auto: 0.1% of shortest bounding-box dimension
        dims = hi_res.dimensions
        merge_distance = min(dims.x, dims.y, dims.z) * 0.001
    print(f"[decimate_bake] Merging vertices (threshold {merge_distance:.6f})…")

    select_only(hi_res, context)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=merge_distance)
    bpy.ops.object.mode_set(mode="OBJECT")
    merged_tri_count = count_tris(hi_res)
    print(f"[decimate_bake] After merge: {merged_tri_count} tris, "
          f"{len(hi_res.data.vertices)} verts")

    # ------------------------------------------------------------------
    # 6. Duplicate hi-res → lo-res (for decimation)
    # ------------------------------------------------------------------
    select_only(hi_res, context)
    bpy.ops.object.duplicate()
    lo_res = context.active_object
    lo_res.name = "LoRes"

    # ------------------------------------------------------------------
    # 7. Decimate (ratio against post-merge count, not raw import count)
    # ------------------------------------------------------------------
    ratio = min(target_tri_count / max(merged_tri_count, 1), 1.0)
    mod = lo_res.modifiers.new("Decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = ratio
    mod.use_collapse_triangulate = True

    apply_modifier(lo_res, "Decimate", context)
    final_tri_count = count_tris(lo_res)
    print(f"[decimate_bake] Decimated: {merged_tri_count} → {final_tri_count} tris "
          f"(target {target_tri_count})")

    # ------------------------------------------------------------------
    # 8. Fresh UV unwrap on lo-res.
    #    The inherited hi-res UV layout is meaningless after aggressive
    #    decimation — islands shrink to specks and the bake comes out black.
    #    Always re-unwrap after decimating.
    # ------------------------------------------------------------------
    while lo_res.data.uv_layers:
        lo_res.data.uv_layers.remove(lo_res.data.uv_layers[0])

    select_only(lo_res, context)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=66, island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    print("[decimate_bake] UV-unwrapped lo-res (smart project)")

    # ------------------------------------------------------------------
    # 8. Auto cage extrusion — 2% of longest bounding-box dimension.
    # ------------------------------------------------------------------
    if cage_extrusion <= 0:
        dims = lo_res.dimensions
        cage_extrusion = max(dims.x, dims.y, dims.z) * 0.02
    print(f"[decimate_bake] Cage extrusion: {cage_extrusion:.4f}")

    # ------------------------------------------------------------------
    # 9. Assign a fresh bake-target material to lo-res (not shared with hi-res).
    #    The shared-material bug: bpy.ops.object.duplicate() links the same
    #    material datablock to both objects. Adding the bake node to lo-res
    #    would also modify hi-res, confusing the bake. Give lo-res its own.
    # ------------------------------------------------------------------
    bake_image = bpy.data.images.new(
        "BakeResult", width=bake_resolution, height=bake_resolution, alpha=False
    )
    lo_mat, bake_tex_node, lo_bsdf = make_bake_target_material("LoRes_Bake", bake_image)
    lo_res.data.materials.clear()
    lo_res.data.materials.append(lo_mat)

    # ------------------------------------------------------------------
    # 10. Configure Cycles (required for baking)
    # ------------------------------------------------------------------
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = cycles_samples
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = cage_extrusion
    scene.render.bake.use_cage = False
    scene.render.bake.margin = 16

    # ------------------------------------------------------------------
    # 11. Bake EMIT: hi_res (selected/source) → lo_res (active/target)
    #     EMIT captures the raw emission colour = the texture image,
    #     with no lighting calculation, which is exactly what we want
    #     for a texture transfer bake.
    # ------------------------------------------------------------------
    bpy.ops.object.select_all(action="DESELECT")
    hi_res.select_set(True)
    lo_res.select_set(True)
    context.view_layer.objects.active = lo_res

    print("[decimate_bake] Baking (EMIT, hi→lo)…")
    bpy.ops.object.bake(type="EMIT")
    print("[decimate_bake] Bake complete")

    # ------------------------------------------------------------------
    # 12. Save baked texture
    # ------------------------------------------------------------------
    texture_out = os.path.abspath(os.path.join(output_dir, "texture_baked.png"))
    bake_image.filepath_raw = texture_out
    bake_image.file_format = "PNG"
    bake_image.save()
    print(f"[decimate_bake] Texture saved: {texture_out}")

    # ------------------------------------------------------------------
    # 13. Wire baked texture into lo-res BSDF Base Color for correct export
    # ------------------------------------------------------------------
    lo_mat.node_tree.links.new(
        bake_tex_node.outputs["Color"],
        lo_bsdf.inputs["Base Color"]
    )

    # ------------------------------------------------------------------
    # 14. Export lo-res as GLB (texture embedded)
    # ------------------------------------------------------------------
    select_only(lo_res, context)
    mesh_out = os.path.abspath(os.path.join(output_dir, "mesh_lo.glb"))
    bpy.ops.export_scene.gltf(
        filepath=mesh_out,
        use_selection=True,
        export_format="GLB",
        export_image_format="AUTO",
    )
    print(f"[decimate_bake] Mesh saved: {mesh_out}")

    # ------------------------------------------------------------------
    # 15. Write result log
    # ------------------------------------------------------------------
    result = {
        "input_mesh":         os.path.abspath(input_mesh),
        "input_texture":      os.path.abspath(input_texture) if input_texture else None,
        "original_tri_count": original_tri_count,
        "target_tri_count":   target_tri_count,
        "final_tri_count":    final_tri_count,
        "bake_resolution":    bake_resolution,
        "cage_extrusion":     round(cage_extrusion, 5),
        "cycles_samples":     cycles_samples,
        "output_mesh":        mesh_out,
        "output_texture":     texture_out,
    }
    result_path = os.path.join(output_dir, "result.json")
    with open(result_path, "w") as f:
        json.dump(result, f, indent=2)
    print(f"[decimate_bake] Run log: {result_path}")
    print("[decimate_bake] Done.")


main()
