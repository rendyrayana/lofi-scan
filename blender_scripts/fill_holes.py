"""
fill_holes.py — Voxel remesh to close all holes (DynaMesh-style).

Voxelizes the surface and re-extracts it, closing every hole regardless of
shape, size, or position. Resolution auto-calculated from mesh size.

Usage:
    blender --background --python blender_scripts/fill_holes.py -- config.json

Config JSON:
    input_mesh        (str)    Source mesh path (.obj / .glb / .ply)
    output_glb        (str)    Destination .glb path
    voxel_resolution  (int)    Voxels across longest axis (default 300)
"""

import sys, json, os
import bpy


def import_mesh(filepath):
    before = {o.name for o in bpy.data.objects}
    ext = os.path.splitext(filepath)[1].lower()
    if ext == ".obj":
        try:
            bpy.ops.wm.obj_import(filepath=filepath)
        except AttributeError:
            bpy.ops.import_scene.obj(filepath=filepath)
    elif ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=filepath)
    elif ext == ".ply":
        try:
            bpy.ops.wm.ply_import(filepath=filepath)
        except AttributeError:
            bpy.ops.import_mesh.ply(filepath=filepath)
    else:
        raise ValueError(f"Unsupported mesh format: {ext}")
    added = [o for o in bpy.data.objects if o.name not in before and o.type == "MESH"]
    if not added:
        raise RuntimeError("No MESH object was imported")
    return added[0]


def main():
    argv = sys.argv
    if "--" not in argv:
        print("[fill_holes] No config path provided", file=sys.stderr)
        sys.exit(1)
    cfg_path = argv[argv.index("--") + 1]
    with open(cfg_path) as f:
        cfg = json.load(f)

    input_mesh       = cfg["input_mesh"]
    output_glb       = cfg["output_glb"]
    voxel_resolution = int(cfg.get("voxel_resolution", 300))
    os.makedirs(os.path.dirname(output_glb), exist_ok=True)

    # Clear default scene
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

    obj = import_mesh(input_mesh)
    tris_before = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"[fill_holes] Imported: {obj.name}  ({tris_before} tris)")

    # Pre-clean: merge vertices, delete loose geometry, fix normals.
    # All three steps are critical — voxel remesh fails badly on scan data
    # with stray pieces or inverted/inconsistent normals.
    bpy.context.view_layer.objects.active = obj
    dims = obj.dimensions
    merge_dist = max(dims.x, dims.y, dims.z) * 0.001
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=merge_dist)
    # Remove floating verts/edges/faces not connected to the main surface
    bpy.ops.mesh.delete_loose(use_verts=True, use_edges=True, use_faces=False)
    # Recalculate normals outward so voxeliser knows which side is outside
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")

    # Voxel remesh — closes all holes regardless of shape/position
    diag = (dims.x**2 + dims.y**2 + dims.z**2) ** 0.5
    voxel_size = max(diag / voxel_resolution, 0.0001)
    print(f"[fill_holes] Voxel remesh  size={voxel_size:.5f}  "
          f"(resolution={voxel_resolution}  diag={diag:.4f})")

    remesh = obj.modifiers.new("Remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel_size
    remesh.use_smooth_shade = False
    bpy.ops.object.modifier_apply(modifier="Remesh")

    tris_after = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"[fill_holes] Done: {tris_before} → {tris_after} tris")

    # Export
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=output_glb,
        use_selection=True,
        export_format="GLB",
        export_texcoords=True,
        export_normals=True,
    )
    print(f"[fill_holes] Saved → {output_glb}")


main()
