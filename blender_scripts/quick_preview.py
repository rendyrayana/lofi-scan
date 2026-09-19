"""
quick_preview.py — decimate only, no texture baking, fast export.

Usage (called by Godot via Blender subprocess):
    blender --background --python blender_scripts/quick_preview.py -- config.json

Config JSON:
    input_mesh       (str)   Source mesh path (.obj / .glb / .ply)
    input_texture    (str)   Optional texture path for coloured preview.
    target_tri_count (int)   Target triangle count (0 = no decimation).
    output_dir       (str)   Directory for mesh_lo.glb output.
    merge_distance   (float) Vertex-merge threshold; 0 = skip merge.
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


def write_progress(path, pct, msg):
    if path:
        try:
            with open(path, "w") as f:
                json.dump({"pct": pct, "msg": msg}, f)
        except Exception:
            pass


def main():
    argv = sys.argv
    if "--" not in argv:
        print("[quick_preview] ERROR: no config path after --", file=sys.stderr)
        sys.exit(1)
    cfg_path = argv[argv.index("--") + 1]

    with open(cfg_path) as f:
        cfg = json.load(f)

    input_mesh       = cfg["input_mesh"]
    target_tri_count = int(cfg.get("target_tri_count", 0))
    output_dir       = cfg["output_dir"]
    merge_dist       = float(cfg.get("merge_distance", 0.0))
    fill_holes       = bool(cfg.get("fill_holes", False))
    input_texture    = cfg.get("input_texture")
    progress_file    = cfg.get("progress_file", None)

    os.makedirs(output_dir, exist_ok=True)
    print(f"[quick_preview] {input_mesh} → {target_tri_count} tris → {output_dir}")

    write_progress(progress_file, 10, "Importing mesh")

    # Clear default scene
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

    obj = import_mesh(input_mesh)
    print(f"[quick_preview] Imported: {obj.name}")

    write_progress(progress_file, 35, "Decimating")

    # Merge vertices — scan meshes are often triangle soup (no shared verts).
    # Without merging, COLLAPSE decimator just picks N random isolated triangles.
    if merge_dist <= 0.0:
        dims = obj.dimensions
        merge_dist = max(dims.x, dims.y, dims.z) * 0.001
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=merge_dist)
    bpy.ops.object.mode_set(mode="OBJECT")
    print(f"[quick_preview] Merged vertices (threshold {merge_dist:.6f})")

    if fill_holes:
        import bmesh as _bmesh
        print("[quick_preview] Filling holes…")
        bm = _bmesh.new()
        bm.from_mesh(obj.data)
        boundary = [e for e in bm.edges if not e.is_manifold]
        if boundary:
            _bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
            _bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
        bm.to_mesh(obj.data)
        obj.data.update()
        bm.free()
        tris_after = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        print(f"[quick_preview] After fill holes: {tris_after} tris")

    # Voxel remesh — creates a uniform closed surface so COLLAPSE decimate
    # distributes triangles evenly instead of leaving dense/sparse patches.
    # Target voxel size aims for ~6x the target tri count as the remesh base.
    if target_tri_count > 0:
        dims = obj.dimensions
        diag = (dims.x**2 + dims.y**2 + dims.z**2) ** 0.5
        voxel_size = max(diag / (target_tri_count ** 0.5), diag * 0.002)
        remesh = obj.modifiers.new("Remesh", "REMESH")
        remesh.mode = "VOXEL"
        remesh.voxel_size = voxel_size
        remesh.use_smooth_shade = False
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=remesh.name)
        print(f"[quick_preview] Voxel remeshed (voxel_size={voxel_size:.4f})")

    # Decimate
    if target_tri_count > 0:
        src_tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        print(f"[quick_preview] Source tris: {src_tris}, target: {target_tri_count}")
        if src_tris > target_tri_count:
            ratio = max(0.001, min(1.0, target_tri_count / src_tris))
            mod = obj.modifiers.new("Decimate", "DECIMATE")
            mod.decimate_type = "COLLAPSE"
            mod.ratio = ratio
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=mod.name)
            result_tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
            print(f"[quick_preview] Result tris: {result_tris}")

    # Recalculate normals to fix inverted/inconsistent faces from scan data
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")

    write_progress(progress_file, 70, "Building material")

    # Material: use source texture if available, otherwise flat gray
    mat = bpy.data.materials.new(name="preview_mat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        tex_path = input_texture
        # Attempt to use the original texture embedded in obj materials if none provided
        if not tex_path and obj.data.materials:
            for src_mat in obj.data.materials:
                if src_mat and src_mat.use_nodes:
                    for n in src_mat.node_tree.nodes:
                        if n.type == "TEX_IMAGE" and n.image:
                            tex_path = n.image.filepath_from_user()
                            break
                if tex_path:
                    break

        if tex_path and os.path.exists(tex_path):
            img = bpy.data.images.load(tex_path)
            tex_node = mat.node_tree.nodes.new("ShaderNodeTexImage")
            tex_node.image = img
            mat.node_tree.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
            print(f"[quick_preview] Using texture: {tex_path}")
        else:
            bsdf.inputs["Base Color"].default_value = (0.65, 0.65, 0.65, 1.0)
            print("[quick_preview] No texture found; using flat gray")

    obj.data.materials.clear()
    obj.data.materials.append(mat)

    # Export
    out_path = os.path.join(output_dir, "mesh_lo.glb")
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        use_selection=False,
        export_apply=True,
    )

    # Hausdorff score: only meaningful when decimation was applied
    if target_tri_count > 0:
        try:
            import trimesh as _trimesh
            from scipy.spatial import cKDTree as _cKDTree
            import numpy as _np_h
            import json as _json_h
            _src = _trimesh.load(input_mesh, force='mesh')
            _lo  = _trimesh.load(out_path,   force='mesh')
            _sp, _ = _trimesh.sample.sample_surface(_src, 5000)
            _lp, _ = _trimesh.sample.sample_surface(_lo,  5000)
            _tree  = _cKDTree(_lp)
            _dists, _ = _tree.query(_sp)
            _h = float(_dists.max())
            _diag = float(_np_h.linalg.norm(_src.bounding_box.extents))
            _h_norm = _h / _diag if _diag > 0 else 0.0
            with open(os.path.join(output_dir, "scores.json"), "w") as _f:
                _json_h.dump({"hausdorff_normalized": _h_norm}, _f)
            print(f"[quick_preview] Hausdorff: {_h_norm * 100:.1f}% of bbox diagonal")
        except Exception as _e:
            print(f"[quick_preview] Hausdorff skipped: {_e}", file=sys.stderr)

    write_progress(progress_file, 100, "Preview ready")
    print(f"[quick_preview] Done: {out_path}")


main()
