"""
Milestone 1 — Blender headless: decimate to a fixed tri count + bake hi-to-low texture.

Usage:
    blender --background --python blender_scripts/decimate_bake.py -- config.json

Config JSON fields:
    input_mesh      (str)   Path to the hi-res scan mesh (.obj, .glb/.gltf, or .ply)
    input_texture   (str)   Optional. Path to texture if not embedded in the mesh.
    target_tri_count (int)  Fixed poly target for this run (adaptive search comes later).
    output_dir      (str)   Directory to write mesh_lo.glb, texture_baked.png, result.json.
    bake_resolution (int)   Bake image size in pixels (default 1024).
    cage_extrusion  (float) Blender bake cage extrusion in scene units (default 0.05).
    cycles_samples  (int)   Cycles samples for baking (default 32; raise if bake looks noisy).

Outputs written to output_dir/:
    mesh_lo.glb         Decimated mesh with baked material.
    texture_baked.png   Baked diffuse texture.
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
    """Import a mesh file; return the first MESH object added to the scene."""
    before = {o.name for o in bpy.data.objects}
    ext = os.path.splitext(filepath)[1].lower()

    if ext == ".obj":
        try:
            bpy.ops.wm.obj_import(filepath=filepath)          # Blender 4.x
        except AttributeError:
            bpy.ops.import_scene.obj(filepath=filepath)        # Blender 3.x
    elif ext in (".gltf", ".glb"):
        bpy.ops.import_scene.gltf(filepath=filepath)
    elif ext == ".ply":
        try:
            bpy.ops.wm.ply_import(filepath=filepath)          # Blender 4.x
        except AttributeError:
            bpy.ops.import_mesh.ply(filepath=filepath)         # Blender 3.x
    else:
        raise ValueError(f"Unsupported mesh format: {ext}")

    added = [o for o in bpy.data.objects
             if o.name not in before and o.type == "MESH"]
    if not added:
        raise RuntimeError(f"No mesh object found after importing {filepath}")
    return added[0]


def count_tris(obj):
    """Count triangles in a mesh object (quads estimated as 2 tris each)."""
    return sum(1 if len(p.vertices) == 3 else 2 for p in obj.data.polygons)


def set_active_select(obj, context):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    context.view_layer.objects.active = obj


def ensure_hi_res_has_texture(hi_res, texture_path):
    """
    If an explicit texture path is given and the hi-res mesh has a material,
    load that image into the first Image Texture node found (or create one).
    If no material exists, create a minimal one.
    """
    if not texture_path:
        return

    image = bpy.data.images.load(os.path.abspath(texture_path))

    if not hi_res.data.materials:
        mat = bpy.data.materials.new("HiResMat")
        mat.use_nodes = True
        hi_res.data.materials.append(mat)

    for mat in hi_res.data.materials:
        if mat is None:
            continue
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        img_nodes = [n for n in nodes if n.type == "TEX_IMAGE"]
        if img_nodes:
            img_nodes[0].image = image
        else:
            img_node = nodes.new("ShaderNodeTexImage")
            img_node.image = image
            # Connect to the Principled BSDF base color if one exists
            bsdf_nodes = [n for n in nodes if n.type == "BSDF_PRINCIPLED"]
            if bsdf_nodes:
                mat.node_tree.links.new(
                    img_node.outputs["Color"],
                    bsdf_nodes[0].inputs["Base Color"]
                )
        break  # only fix the first material


def add_bake_image_node(obj, bake_image):
    """
    Add (or reuse) an Image Texture node pointing at bake_image in every
    material slot of obj, and make it the active node. Blender bakes into the
    active Image Texture node on the active object's material.
    """
    if not obj.data.materials:
        mat = bpy.data.materials.new("BakeMat")
        mat.use_nodes = True
        obj.data.materials.append(mat)

    for mat in obj.data.materials:
        if mat is None:
            continue
        mat.use_nodes = True
        nodes = mat.node_tree.nodes

        # Find or create the bake target node
        bake_nodes = [n for n in nodes
                      if n.type == "TEX_IMAGE" and n.image == bake_image]
        if bake_nodes:
            node = bake_nodes[0]
        else:
            node = nodes.new("ShaderNodeTexImage")
            node.image = bake_image

        # Make it active (bake target)
        nodes.active = node


def apply_modifier(obj, mod_name, context):
    set_active_select(obj, context)
    bpy.ops.object.modifier_apply(modifier=mod_name)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    argv = sys.argv
    try:
        sep_index = argv.index("--")
    except ValueError:
        print("[decimate_bake] ERROR: Pass a config.json path after '--'")
        sys.exit(1)

    script_args = argv[sep_index + 1:]
    if not script_args:
        print("[decimate_bake] ERROR: No config.json path provided")
        sys.exit(1)

    config_path = script_args[0]
    with open(config_path) as f:
        cfg = json.load(f)

    input_mesh      = cfg["input_mesh"]
    input_texture   = cfg.get("input_texture")
    target_tri_count = int(cfg["target_tri_count"])
    output_dir      = cfg["output_dir"]
    bake_resolution = int(cfg.get("bake_resolution", 1024))
    cage_extrusion  = float(cfg.get("cage_extrusion", 0.05))
    cycles_samples  = int(cfg.get("cycles_samples", 32))

    os.makedirs(output_dir, exist_ok=True)
    context = bpy.context

    # ------------------------------------------------------------------
    # 1. Clean scene
    # ------------------------------------------------------------------
    bpy.ops.wm.read_factory_settings(use_empty=True)
    context = bpy.context  # refresh after factory reset

    # ------------------------------------------------------------------
    # 2. Import hi-res mesh
    # ------------------------------------------------------------------
    print(f"[decimate_bake] Importing: {input_mesh}")
    hi_res = import_mesh(os.path.abspath(input_mesh))
    hi_res.name = "HiRes"

    original_tri_count = count_tris(hi_res)
    print(f"[decimate_bake] Hi-res tri count: {original_tri_count}")

    # Patch in explicit texture if provided
    ensure_hi_res_has_texture(hi_res, input_texture)

    # ------------------------------------------------------------------
    # 3. Duplicate → lo-res target
    # ------------------------------------------------------------------
    set_active_select(hi_res, context)
    bpy.ops.object.duplicate()
    lo_res = context.active_object
    lo_res.name = "LoRes"

    # ------------------------------------------------------------------
    # 4. Decimate
    # ------------------------------------------------------------------
    ratio = min(target_tri_count / max(original_tri_count, 1), 1.0)
    mod = lo_res.modifiers.new("Decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = ratio
    mod.use_collapse_triangulate = True   # output is guaranteed triangles

    apply_modifier(lo_res, "Decimate", context)

    final_tri_count = count_tris(lo_res)
    print(f"[decimate_bake] After decimate: {final_tri_count} tris "
          f"(target was {target_tri_count})")

    # ------------------------------------------------------------------
    # 5. UV-unwrap the lo-res (needed for baking; skip if UVs already exist)
    # ------------------------------------------------------------------
    if not lo_res.data.uv_layers:
        set_active_select(lo_res, context)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=66, island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
        print("[decimate_bake] UV-unwrapped lo-res (smart project)")
    else:
        print("[decimate_bake] Lo-res already has UVs — skipping unwrap")

    # ------------------------------------------------------------------
    # 6. Create the bake target image
    # ------------------------------------------------------------------
    bake_image = bpy.data.images.new(
        "BakeResult",
        width=bake_resolution,
        height=bake_resolution,
        alpha=False
    )
    add_bake_image_node(lo_res, bake_image)

    # ------------------------------------------------------------------
    # 7. Configure Cycles baking
    # ------------------------------------------------------------------
    bpy.context.scene.render.engine = "CYCLES"
    bpy.context.scene.cycles.device = "CPU"
    bpy.context.scene.cycles.samples = cycles_samples

    bake_settings = bpy.context.scene.render.bake
    bake_settings.use_selected_to_active = True
    bake_settings.cage_extrusion = cage_extrusion
    bake_settings.use_cage = False         # cage object not needed here
    bake_settings.margin = 4              # pixel margin around UV islands

    # ------------------------------------------------------------------
    # 8. Bake: hi_res (selected) → lo_res (active)
    # ------------------------------------------------------------------
    bpy.ops.object.select_all(action="DESELECT")
    hi_res.select_set(True)
    lo_res.select_set(True)
    bpy.context.view_layer.objects.active = lo_res

    print("[decimate_bake] Baking diffuse color (this may take a moment)…")
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
    print("[decimate_bake] Bake complete")

    # ------------------------------------------------------------------
    # 9. Save baked texture
    # ------------------------------------------------------------------
    texture_out = os.path.abspath(os.path.join(output_dir, "texture_baked.png"))
    bake_image.filepath_raw = texture_out
    bake_image.file_format = "PNG"
    bake_image.save()
    print(f"[decimate_bake] Texture saved: {texture_out}")

    # ------------------------------------------------------------------
    # 10. Wire baked texture into lo-res material for correct glTF export
    # ------------------------------------------------------------------
    for mat in lo_res.data.materials:
        if mat is None:
            continue
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links

        img_node   = next((n for n in nodes if n.type == "TEX_IMAGE"
                           and n.image == bake_image), None)
        bsdf_nodes = [n for n in nodes if n.type == "BSDF_PRINCIPLED"]

        if img_node and bsdf_nodes:
            links.new(img_node.outputs["Color"],
                      bsdf_nodes[0].inputs["Base Color"])

    # ------------------------------------------------------------------
    # 11. Export lo-res mesh as GLB
    # ------------------------------------------------------------------
    set_active_select(lo_res, context)
    mesh_out = os.path.abspath(os.path.join(output_dir, "mesh_lo.glb"))
    bpy.ops.export_scene.gltf(
        filepath=mesh_out,
        use_selection=True,
        export_format="GLB",
        export_image_format="PNG",
    )
    print(f"[decimate_bake] Mesh saved: {mesh_out}")

    # ------------------------------------------------------------------
    # 12. Write result log
    # ------------------------------------------------------------------
    result = {
        "input_mesh":         os.path.abspath(input_mesh),
        "input_texture":      os.path.abspath(input_texture) if input_texture else None,
        "original_tri_count": original_tri_count,
        "target_tri_count":   target_tri_count,
        "final_tri_count":    final_tri_count,
        "bake_resolution":    bake_resolution,
        "cage_extrusion":     cage_extrusion,
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
