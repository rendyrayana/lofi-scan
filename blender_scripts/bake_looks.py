"""
bake_looks.py — Apply PSX color grading to a GLB's embedded texture.

Reads the GLB binary, extracts every image buffer, applies exposure /
brightness / contrast / Bayer-dither colour quantisation with Pillow+NumPy,
then writes a new GLB with the processed images in place.

Usage:
    python3 blender_scripts/bake_looks.py config.json

Config JSON:
    input_glb     (str)   Source GLB path
    output_glb    (str)   Destination GLB path
    exposure      (float) Exposure multiplier   (default 1.0)
    brightness    (float) Brightness multiplier (default 1.0)
    contrast      (float) Contrast              (default 1.0)
    use_dither    (bool)  Apply PS1 Bayer dithering (default true)
    dither_gamma  (float) Gamma used during dithering (default 1.0)
"""

import sys, json, struct
from io import BytesIO

try:
    from PIL import Image
    import numpy as np
except ImportError:
    print("[bake_looks] ERROR: Pillow + numpy required.  pip install Pillow numpy")
    sys.exit(1)


# PS1 4×4 Bayer ordered-dither matrix (same values as psx_shader.gdshader)
BAYER = np.array([
    [-4,  0, -3,  1],
    [ 2, -2,  3, -1],
    [-3,  1, -4,  0],
    [ 3, -1,  2, -2],
], dtype=np.float32)


def apply_psx(img_bytes: bytes, cfg: dict) -> bytes:
    exposure     = float(cfg.get("exposure",     1.0))
    brightness   = float(cfg.get("brightness",   1.0))
    contrast     = float(cfg.get("contrast",     1.0))
    use_dither   = bool (cfg.get("use_dither",   True))
    dither_gamma = float(cfg.get("dither_gamma", 1.0))

    img = Image.open(BytesIO(img_bytes)).convert("RGBA")
    alpha = np.array(img)[:, :, 3:4].astype(np.float32) / 255.0
    arr   = np.array(img)[:, :, :3].astype(np.float32) / 255.0

    arr = np.clip(arr * exposure,                        0.0, 1.0)
    arr = np.clip((arr - 0.5) * contrast + 0.5,         0.0, 1.0)
    arr = np.clip(arr * brightness,                      0.0, 1.0)

    if use_dither:
        h, w = arr.shape[:2]
        # Tile the 4×4 Bayer matrix to cover the full image
        by = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w, np.newaxis]

        g = max(dither_gamma, 0.01)
        gc      = np.power(np.clip(arr, 1e-6, 1.0), 1.0 / g)
        shifted = gc * 255.0 + by
        clamped = np.clip(np.floor(shifted + 0.5), 0.0, 255.0)
        quant   = np.clip(np.floor(clamped / 8.0), 0.0, 31.0) / 31.0
        arr     = np.power(quant, g)

    rgb   = (np.clip(arr, 0.0, 1.0) * 255.0).astype(np.uint8)
    a_u8  = (np.clip(alpha, 0.0, 1.0) * 255.0).astype(np.uint8)
    rgba  = np.concatenate([rgb, a_u8], axis=2)

    out = BytesIO()
    Image.fromarray(rgba, "RGBA").save(out, format="PNG", optimize=False)
    return out.getvalue()


# ── GLB binary parsing / packing ─────────────────────────────────────────────

JSON_CHUNK = 0x4E4F534A
BIN_CHUNK  = 0x004E4942


def _align4(n: int) -> int:
    return (n + 3) & ~3


def parse_glb(data: bytes):
    magic, version, _ = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF" and version == 2, "Not a valid GLB v2 file"

    chunks: dict[int, bytes] = {}
    offset = 12
    while offset < len(data):
        chunk_len, chunk_type = struct.unpack_from("<II", data, offset)
        chunks[chunk_type] = data[offset + 8: offset + 8 + chunk_len]
        offset += 8 + chunk_len

    return chunks.get(JSON_CHUNK, b"{}"), chunks.get(BIN_CHUNK)


def pack_glb(json_bytes: bytes, bin_bytes: bytes) -> bytes:
    jp = json_bytes + b" "  * (_align4(len(json_bytes)) - len(json_bytes))
    bp = bin_bytes  + b"\x00" * (_align4(len(bin_bytes))  - len(bin_bytes))
    total = 12 + 8 + len(jp) + 8 + len(bp)
    out = bytearray()
    out += struct.pack("<4sII", b"glTF", 2, total)
    out += struct.pack("<II", len(jp), JSON_CHUNK) + jp
    out += struct.pack("<II", len(bp), BIN_CHUNK)  + bp
    return bytes(out)


def process_glb(input_path: str, output_path: str, cfg: dict) -> None:
    with open(input_path, "rb") as f:
        data = f.read()

    json_bytes, bin_bytes = parse_glb(data)

    if not bin_bytes:
        import shutil
        print("[bake_looks] No BIN chunk — copying unchanged")
        shutil.copy(input_path, output_path)
        return

    gltf         = json.loads(json_bytes)
    images       = gltf.get("images", [])
    buffer_views = gltf.get("bufferViews", [])
    mod_bin      = bytearray(bin_bytes)

    for img_info in images:
        bv_idx = img_info.get("bufferView")
        if bv_idx is None:
            continue
        bv     = buffer_views[bv_idx]
        offset = bv.get("byteOffset", 0)
        length = bv["byteLength"]

        print(f"[bake_looks] Processing image bv={bv_idx} ({length} bytes)")
        raw      = bytes(mod_bin[offset: offset + length])
        new_raw  = apply_psx(raw, cfg)

        if len(new_raw) <= length:
            # Fits in place — zero-pad the remainder
            mod_bin[offset: offset + length] = new_raw + b"\x00" * (length - len(new_raw))
        else:
            # Larger than original: append at 4-byte-aligned end, update bufferView
            new_offset = _align4(len(mod_bin))
            mod_bin   += b"\x00" * (new_offset - len(mod_bin))
            mod_bin   += new_raw
            bv["byteOffset"] = new_offset
            bv["byteLength"] = len(new_raw)
            print(f"[bake_looks] Image grew ({length}→{len(new_raw)}), relocated to {new_offset}")

    if gltf.get("buffers"):
        gltf["buffers"][0]["byteLength"] = len(mod_bin)

    new_json = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    packed   = pack_glb(new_json, bytes(mod_bin))

    with open(output_path, "wb") as f:
        f.write(packed)
    print(f"[bake_looks] Saved → {output_path}  ({len(packed)} bytes)")


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python3 bake_looks.py config.json")
        sys.exit(1)
    with open(sys.argv[1]) as f:
        cfg = json.load(f)
    process_glb(cfg["input_glb"], cfg["output_glb"], cfg)


main()
