# Calibration Note — kirby.obj

**Date:** 2026-09-14  
**Object:** Kirby figurine scan (Revopoint), 513K raw tris → 435K after vertex merge

---

## Milestone 2 — Geometry search (Tier 2, SSIM ≥ 0.85)

| Candidate | Actual tris | SSIM (flat grey) | Pass |
|-----------|-------------|------------------|------|
| 2525 | 2524 | 0.9946 | ✓ |
| 1287 | 1286 | 0.9861 | ✓ |
| 668  | 668  | 0.9605 | ✓ |
| 358  | 358  | 0.9078 | ✓ |
| 203+ | **336** | 0.8965 | ✓ |

**Result: 336 tris minimum.** Iterations 5–12 all returned 336 — this is the Decimate modifier's topology floor for this mesh. The search correctly identified it.

---

## Milestone 3 — Texture sweep (Tier 2, SSIM ≥ 0.85 vs 256px ceiling)

| Resolution | SSIM vs 256px | Pass |
|------------|---------------|------|
| 16px | 0.9226 | ✓ |

**Result: 16px is sufficient for Tier 2.** Kirby is mostly solid pink — very little high-frequency colour detail — so texture resolution is not the bottleneck. Shape is.

**Key finding:** When comparing lo-res against the hi-res reference directly, texture resolution SSIM is dominated by shape degradation (all sizes score ~0.83 regardless of resolution). The correct comparison for texture sweep is lo-res-at-res vs lo-res-at-max-res, which isolates texture quality from the fixed shape penalty.

---

## What this predicts for other objects

- **Simple, flat-coloured objects** (like Kirby): shape is the only bottleneck. Texture resolution can go very low.
- **Complex, detailed objects** (fine surface texture, markings, text): texture resolution will matter much more. Expect 128–256px to be necessary.
- **Objects with fine geometric features** (thin parts, sharp edges): the Decimate floor may be higher than 336 — the geometry search range may need to extend beyond 5000 tris.

This calibration result validates the pipeline logic before running on a full scan collection.
