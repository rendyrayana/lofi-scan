"""
Milestone 2 — Binary search for minimum tri count at a target recognizability score.

Calls render_views.py (Blender headless) at each iteration to render the candidate
mesh, compares against the hi-res reference using SSIM, and converges on the minimum
tri count that clears the tier's target. Then calls decimate_bake.py for the final
textured output.

Usage:
    python3 blender_scripts/search.py config_search.json

Config JSON fields:
    input_mesh        (str)   Hi-res scan mesh (.obj / .glb / .ply)
    input_texture     (str)   Optional explicit texture path.
    tier              (int)   Quality tier 1–4 (overrides target_score).
    target_score      (float) Direct SSIM target 0–1 (used if tier is absent).
    output_dir        (str)   Root output dir; subdirs created automatically.
    search_lo         (int)   Lower tri bound for search (default 50).
    search_hi         (int)   Upper tri bound for search (default 5000).
    max_iter          (int)   Max binary-search steps (default 12).
    render_resolution (int)   Render size for scoring images (default 256).
    bake_resolution   (int)   Texture bake size for final output (default 1024).
    merge_distance    (float) Vertex-merge threshold; 0 = auto.
    blender_bin       (str)   Path to Blender binary (default 'blender').

Quality tiers (retained-recognizability targets):
    1 → 0.95  |  2 → 0.85  |  3 → 0.70  |  4 → 0.50
"""

import sys, json, os, subprocess, math
import numpy as np
from PIL import Image
from skimage.metrics import structural_similarity as ssim


TIER_TARGETS = {1: 0.95, 2: 0.85, 3: 0.70, 4: 0.50}

SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
BAKE_SCRIPT = os.path.join(SCRIPT_DIR, "decimate_bake.py")
VIEW_SCRIPT = os.path.join(SCRIPT_DIR, "render_views.py")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def run_blender(blender_bin, script, config_path):
    """Call a Blender headless script with a config JSON. Raises on failure."""
    cmd = [blender_bin, "--background", "--python", script, "--", config_path]
    result = subprocess.run(cmd, capture_output=True, text=True)
    # Surface any script-level errors
    for line in result.stdout.splitlines():
        if line.startswith("["):
            print(line)
    if result.returncode != 0:
        print(result.stderr[-2000:])
        raise RuntimeError(f"Blender script failed (exit {result.returncode}): {script}")


def load_gray(path):
    """Load a PNG as a float32 numpy array in [0, 1]."""
    return np.array(Image.open(path).convert("L"), dtype=np.float32) / 255.0


def score_views(hi_dir, lo_dir):
    """Average SSIM across the three fixed views (front, 3q, top)."""
    scores = []
    for view in ("front", "3q", "top"):
        hi_path = os.path.join(hi_dir, f"view_{view}.png")
        lo_path = os.path.join(lo_dir, f"view_{view}.png")
        hi = load_gray(hi_path)
        lo = load_gray(lo_path)
        s = ssim(hi, lo, data_range=1.0)
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


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 search.py config_search.json")
        sys.exit(1)

    with open(sys.argv[1]) as f:
        cfg = json.load(f)

    input_mesh       = cfg["input_mesh"]
    input_texture    = cfg.get("input_texture")
    output_dir       = cfg["output_dir"]
    search_lo        = int(cfg.get("search_lo", 50))
    search_hi        = int(cfg.get("search_hi", 5000))
    max_iter         = int(cfg.get("max_iter", 12))
    render_res       = int(cfg.get("render_resolution", 256))
    bake_res         = int(cfg.get("bake_resolution", 1024))
    merge_distance   = float(cfg.get("merge_distance", 0.0))
    fill_holes       = bool(cfg.get("fill_holes", False))
    blender_bin      = cfg.get("blender_bin", "blender")
    cam_dist         = float(cfg.get("camera_distance", 2.5))
    progress_file    = cfg.get("progress_file", None)

    if "tier" in cfg:
        tier = int(cfg["tier"])
        target_score = TIER_TARGETS[tier]
        print(f"[search] Tier {tier} → target SSIM {target_score}")
    else:
        tier = None
        target_score = float(cfg["target_score"])
        print(f"[search] Custom target SSIM {target_score}")

    os.makedirs(output_dir, exist_ok=True)
    scratch = os.path.join(output_dir, "_scratch")
    os.makedirs(scratch, exist_ok=True)

    # ------------------------------------------------------------------
    # 1. Render hi-res reference (once)
    # ------------------------------------------------------------------
    write_progress(progress_file, 3, "Rendering reference")
    print("\n[search] Rendering hi-res reference…")
    hi_dir = os.path.join(scratch, "hi_res")
    hi_cfg_path = os.path.join(scratch, "cfg_hi.json")
    write_config(hi_cfg_path, {
        "input_mesh":       input_mesh,
        "output_dir":       hi_dir,
        "target_tri_count": 0,          # no decimation
        "merge_distance":   merge_distance,
        "fill_holes":       fill_holes,
        "render_resolution": render_res,
        "camera_distance":  cam_dist,
    })
    run_blender(blender_bin, VIEW_SCRIPT, hi_cfg_path)

    with open(os.path.join(hi_dir, "result.json")) as f:
        hi_result = json.load(f)
    hi_tris = hi_result["merged_tris"]
    print(f"[search] Hi-res: {hi_tris} tris (after merge)")

    # Cap search_hi at actual hi-res count
    search_hi = min(search_hi, hi_tris)

    # ------------------------------------------------------------------
    # 2. Binary search
    # ------------------------------------------------------------------
    print(f"\n[search] Binary search: {search_lo}–{search_hi} tris, "
          f"target SSIM ≥ {target_score}, max {max_iter} iterations")

    lo, hi = search_lo, search_hi
    best_tris   = search_hi   # conservative fallback
    best_score  = 0.0
    history     = []

    for i in range(max_iter):
        if lo > hi:
            break
        mid = (lo + hi) // 2
        pct = 10 + int((i / max_iter) * 65)
        write_progress(progress_file, pct, f"Search iter {i+1}/{max_iter}")
        print(f"\n[search] Iter {i+1}/{max_iter}  candidate={mid} tris  [{lo}–{hi}]")

        lo_dir      = os.path.join(scratch, f"iter_{i:02d}_{mid}")
        lo_cfg_path = os.path.join(scratch, f"cfg_iter_{i:02d}.json")
        write_config(lo_cfg_path, {
            "input_mesh":        input_mesh,
            "output_dir":        lo_dir,
            "target_tri_count":  mid,
            "merge_distance":    merge_distance,
            "fill_holes":        fill_holes,
            "render_resolution": render_res,
            "camera_distance":   cam_dist,
        })
        run_blender(blender_bin, VIEW_SCRIPT, lo_cfg_path)

        # Read actual tri count produced (may differ slightly from mid)
        with open(os.path.join(lo_dir, "result.json")) as f:
            lo_result = json.load(f)
        actual_tris = lo_result["final_tris"]

        score = score_views(hi_dir, lo_dir)
        history.append({"candidate": mid, "actual_tris": actual_tris,
                         "ssim": score, "pass": score >= target_score})

        if score >= target_score:
            # Passed — this tri count is sufficient; try fewer
            best_tris  = actual_tris
            best_score = score
            hi = mid - 1
            print(f"  [search] PASS  score={score:.4f} ≥ {target_score}  → try fewer tris")
        else:
            # Failed — need more tris
            lo = mid + 1
            print(f"  [search] FAIL  score={score:.4f} < {target_score}  → need more tris")

    print(f"\n[search] Converged: {best_tris} tris (SSIM {best_score:.4f})")

    # ------------------------------------------------------------------
    # 3. Final decimate + bake at the confirmed tri count
    # ------------------------------------------------------------------
    write_progress(progress_file, 78, "Final bake")
    print("\n[search] Running final decimate + bake…")
    final_dir     = os.path.join(output_dir, f"final_{best_tris}tris")
    final_cfg_path = os.path.join(scratch, "cfg_final.json")
    write_config(final_cfg_path, {
        "input_mesh":        input_mesh,
        "input_texture":     input_texture,
        "target_tri_count":  best_tris,
        "output_dir":        final_dir,
        "bake_resolution":   bake_res,
        "merge_distance":    merge_distance,
        "fill_holes":        fill_holes,
        "cage_extrusion":    0,
        "cycles_samples":    32,
    })
    run_blender(blender_bin, BAKE_SCRIPT, final_cfg_path)

    # ------------------------------------------------------------------
    # 4. Write search log
    # ------------------------------------------------------------------
    log = {
        "input_mesh":    input_mesh,
        "tier":          tier,
        "target_score":  target_score,
        "hi_res_tris":   hi_tris,
        "search_lo":     search_lo,
        "search_hi":     search_hi,
        "best_tris":     best_tris,
        "best_ssim":     best_score,
        "iterations":    history,
        "output_dir":    final_dir,
    }
    log_path = os.path.join(output_dir, "search_log.json")
    with open(log_path, "w") as f:
        json.dump(log, f, indent=2)
    write_progress(progress_file, 100, "Analysis complete")
    print(f"\n[search] Log: {log_path}")
    print(f"[search] Final assets: {final_dir}")
    print("[search] Done.")


main()
