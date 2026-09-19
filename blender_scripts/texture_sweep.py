"""
Milestone 3 — Texture resolution sweep.

Fixes the mesh at the tri count found by search.py, then sweeps a small set
of bake resolutions to find the minimum texture size that still clears the
tier's SSIM target. Renders are textured (not flat grey) so SSIM measures
colour fidelity, not just shape.

Usage:
    python3 blender_scripts/texture_sweep.py config_texture_sweep.json

Config JSON fields:
    input_mesh        (str)        Hi-res scan mesh (.obj / .glb / .ply)
    input_texture     (str)        Optional explicit texture path.
    fixed_tri_count   (int)        Tri count to lock (use best_tris from search log).
    tier              (int)        Quality tier 1–4 (overrides target_score).
    target_score      (float)      Direct SSIM target if tier is absent.
    output_dir        (str)        Root output dir.
    resolutions       (list[int])  Texture sizes to sweep (default [16,32,64,128,256]).
    render_resolution (int)        Scoring render size in pixels (default 256).
    merge_distance    (float)      Vertex-merge threshold; 0 = auto.
    blender_bin       (str)        Path to Blender binary (default 'blender').
    camera_distance   (float)      Camera distance factor (default 2.5).
"""

import sys, json, os, subprocess
import numpy as np
from PIL import Image
from skimage.metrics import structural_similarity as ssim


TIER_TARGETS = {1: 0.95, 2: 0.85, 3: 0.70, 4: 0.50}
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
BAKE_SCRIPT  = os.path.join(SCRIPT_DIR, "decimate_bake.py")
VIEW_SCRIPT  = os.path.join(SCRIPT_DIR, "render_views.py")


def run_blender(blender_bin, script, config_path):
    cmd = [blender_bin, "--background", "--python", script, "--", config_path]
    result = subprocess.run(cmd, capture_output=True, text=True)
    for line in result.stdout.splitlines():
        if line.startswith("["):
            print(line)
    if result.returncode != 0:
        print(result.stderr[-2000:])
        raise RuntimeError(f"Blender script failed: {script}")


def load_gray(path):
    return np.array(Image.open(path).convert("L"), dtype=np.float32) / 255.0


def score_views(ref_dir, cand_dir):
    scores = []
    for view in ("front", "3q", "top"):
        hi = load_gray(os.path.join(ref_dir,  f"view_{view}.png"))
        lo = load_gray(os.path.join(cand_dir, f"view_{view}.png"))
        s  = ssim(hi, lo, data_range=1.0)
        scores.append(s)
        print(f"  [ssim] {view}: {s:.4f}")
    avg = float(np.mean(scores))
    print(f"  [ssim] avg: {avg:.4f}")
    return avg


def write_config(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2)


def write_progress(path, pct, msg):
    if path:
        try:
            with open(path, "w") as f:
                json.dump({"pct": pct, "msg": msg}, f)
        except Exception:
            pass


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 texture_sweep.py config.json"); sys.exit(1)

    with open(sys.argv[1]) as f:
        cfg = json.load(f)

    input_mesh       = cfg["input_mesh"]
    input_texture    = cfg.get("input_texture")
    lo_res_mesh      = cfg.get("lo_res_mesh")   # pre-decimated GLB from poly preview
    fixed_tri_count  = int(cfg["fixed_tri_count"])
    output_dir       = cfg["output_dir"]
    resolutions      = cfg.get("resolutions", [16, 32, 64, 128, 256])
    render_res       = int(cfg.get("render_resolution", 256))
    merge_distance   = float(cfg.get("merge_distance", 0.0))
    blender_bin      = cfg.get("blender_bin", "blender")
    cam_dist         = float(cfg.get("camera_distance", 2.5))
    progress_file    = cfg.get("progress_file", None)

    if lo_res_mesh:
        print(f"[tex_sweep] Using pre-decimated lo-res mesh: {lo_res_mesh}")

    if "tier" in cfg:
        tier         = int(cfg["tier"])
        target_score = TIER_TARGETS[tier]
        print(f"[tex_sweep] Tier {tier} → target SSIM {target_score}")
    else:
        tier         = None
        target_score = float(cfg["target_score"])
        print(f"[tex_sweep] Custom target SSIM {target_score}")

    os.makedirs(output_dir, exist_ok=True)
    scratch = os.path.join(output_dir, "_scratch_tex")
    os.makedirs(scratch, exist_ok=True)

    # ------------------------------------------------------------------
    # 1. Textured hi-res reference (rendered with original texture)
    # ------------------------------------------------------------------
    write_progress(progress_file, 5, "Hi-res reference")
    print("\n[tex_sweep] Rendering textured hi-res reference…")
    hi_dir      = os.path.join(scratch, "hi_res_textured")
    hi_cfg_path = os.path.join(scratch, "cfg_hi_tex.json")
    write_config(hi_cfg_path, {
        "input_mesh":        input_mesh,
        "input_texture":     input_texture,
        "output_dir":        hi_dir,
        "target_tri_count":  0,
        "merge_distance":    merge_distance,
        "render_resolution": render_res,
        "camera_distance":   cam_dist,
        "use_texture":       True,
    })
    run_blender(blender_bin, VIEW_SCRIPT, hi_cfg_path)
    print(f"[tex_sweep] Hi-res reference saved to {hi_dir}")

    # ------------------------------------------------------------------
    # 2. Render lo-res at MAX resolution as the texture-quality ceiling.
    #    We compare each candidate resolution against THIS, not against the
    #    hi-res reference. The hi-res comparison is dominated by shape
    #    degradation (fixed), so SSIM barely moves with texture resolution.
    #    Comparing lo-res-at-res vs lo-res-at-max_res isolates texture quality.
    # ------------------------------------------------------------------
    max_res = max(resolutions)
    write_progress(progress_file, 18, f"Baking ceiling {max_res}px")
    print(f"\n[tex_sweep] Baking ceiling at max resolution ({max_res}px)…")
    ceil_dir = os.path.join(scratch, f"bake_{max_res}px")
    ceil_cfg = os.path.join(scratch, f"cfg_bake_{max_res}.json")
    write_config(ceil_cfg, {
        "input_mesh":        input_mesh,
        "input_texture":     input_texture,
        "lo_res_mesh":       lo_res_mesh,
        "target_tri_count":  fixed_tri_count,
        "output_dir":        ceil_dir,
        "bake_resolution":   max_res,
        "merge_distance":    merge_distance,
        "cage_extrusion":    0,
        "cycles_samples":    32,
    })
    run_blender(blender_bin, BAKE_SCRIPT, ceil_cfg)

    ceil_glb     = os.path.join(ceil_dir, "mesh_lo.glb")
    ceil_view_dir = os.path.join(scratch, f"views_{max_res}px")
    ceil_view_cfg = os.path.join(scratch, f"cfg_views_{max_res}.json")
    write_config(ceil_view_cfg, {
        "input_mesh":        ceil_glb,
        "output_dir":        ceil_view_dir,
        "target_tri_count":  0,
        "merge_distance":    0,
        "render_resolution": render_res,
        "camera_distance":   cam_dist,
        "use_texture":       True,
    })
    run_blender(blender_bin, VIEW_SCRIPT, ceil_view_cfg)
    print(f"[tex_sweep] Ceiling renders saved to {ceil_view_dir}")

    # ------------------------------------------------------------------
    # 3. Sweep resolutions (compare each vs max-res ceiling)
    # ------------------------------------------------------------------
    print(f"\n[tex_sweep] Sweeping resolutions: {resolutions} (vs {max_res}px ceiling)")
    history     = []
    best_res    = resolutions[-1]   # conservative fallback = largest
    best_score  = 0.0

    total_res = len(resolutions)
    for res_idx, res in enumerate(resolutions):
        pct = 30 + int((res_idx / total_res) * 55)
        write_progress(progress_file, pct, f"Baking {res}px ({res_idx+1}/{total_res})")
        print(f"\n[tex_sweep] Baking at {res}px…")

        # Max-res already baked above — reuse it
        if res == max_res:
            view_dir = ceil_view_dir
            score    = score_views(ceil_view_dir, ceil_view_dir)  # 1.0 by definition
            passed   = True
            history.append({"resolution": res, "ssim": score,
                             "pass": passed, "vs": f"{max_res}px ceiling"})
            print(f"  [tex_sweep] PASS {res}px → SSIM {score:.4f} (ceiling)")
            if passed:
                best_res   = res
                best_score = score
                break
            continue

        # Bake at this resolution
        bake_dir = os.path.join(scratch, f"bake_{res}px")
        bake_cfg = os.path.join(scratch, f"cfg_bake_{res}.json")
        write_config(bake_cfg, {
            "input_mesh":        input_mesh,
            "input_texture":     input_texture,
            "lo_res_mesh":       lo_res_mesh,
            "target_tri_count":  fixed_tri_count,
            "output_dir":        bake_dir,
            "bake_resolution":   res,
            "merge_distance":    merge_distance,
            "cage_extrusion":    0,
            "cycles_samples":    32,
        })
        run_blender(blender_bin, BAKE_SCRIPT, bake_cfg)

        # Render lo-res WITH baked texture
        lo_glb   = os.path.join(bake_dir, "mesh_lo.glb")
        view_dir = os.path.join(scratch, f"views_{res}px")
        view_cfg = os.path.join(scratch, f"cfg_views_{res}.json")
        write_config(view_cfg, {
            "input_mesh":        lo_glb,
            "output_dir":        view_dir,
            "target_tri_count":  0,
            "merge_distance":    0,
            "render_resolution": render_res,
            "camera_distance":   cam_dist,
            "use_texture":       True,
        })
        run_blender(blender_bin, VIEW_SCRIPT, view_cfg)

        # Compare against max-res ceiling (not hi-res) to isolate texture quality
        score  = score_views(ceil_view_dir, view_dir)
        passed = score >= target_score
        history.append({"resolution": res, "ssim": score,
                         "pass": passed, "vs": f"{max_res}px ceiling"})

        if passed:
            best_res   = res
            best_score = score
            print(f"  [tex_sweep] PASS {res}px → SSIM {score:.4f} ≥ {target_score}")
            break   # sweep low-to-high; first pass = minimum sufficient
        else:
            print(f"  [tex_sweep] FAIL {res}px → SSIM {score:.4f} < {target_score}")

    # ------------------------------------------------------------------
    # 3. Final bake at confirmed resolution
    # ------------------------------------------------------------------
    write_progress(progress_file, 88, f"Final bake {best_res}px")
    print(f"\n[tex_sweep] Minimum passing resolution: {best_res}px (SSIM {best_score:.4f})")
    print("[tex_sweep] Running final bake at confirmed resolution…")
    final_dir     = os.path.join(output_dir, f"final_{fixed_tri_count}tris_{best_res}px")
    final_cfg     = os.path.join(scratch, "cfg_final_tex.json")
    write_config(final_cfg, {
        "input_mesh":        input_mesh,
        "input_texture":     input_texture,
        "lo_res_mesh":       lo_res_mesh,
        "target_tri_count":  fixed_tri_count,
        "output_dir":        final_dir,
        "bake_resolution":   best_res,
        "merge_distance":    merge_distance,
        "cage_extrusion":    0,
        "cycles_samples":    32,
    })
    run_blender(blender_bin, BAKE_SCRIPT, final_cfg)

    # ------------------------------------------------------------------
    # 4. Write log
    # ------------------------------------------------------------------
    log = {
        "input_mesh":        input_mesh,
        "tier":              tier,
        "target_score":      target_score,
        "fixed_tri_count":   fixed_tri_count,
        "resolutions_swept": resolutions,
        "ceiling_resolution": max_res,
        "comparison":        "lo_res vs lo_res_at_max_res (isolates texture quality from shape)",
        "best_resolution":   best_res,
        "best_ssim":         best_score,
        "sweep":             history,
        "output_dir":        final_dir,
    }
    log_path = os.path.join(output_dir, "texture_sweep_log.json")
    with open(log_path, "w") as f:
        json.dump(log, f, indent=2)
    write_progress(progress_file, 100, "Bake complete")
    print(f"\n[tex_sweep] Log: {log_path}")
    print(f"[tex_sweep] Final assets: {final_dir}")
    print("[tex_sweep] Done.")


main()
