"""
make_video.py  <frames_dir> <output_path> <fps> [WxH]

Encodes a directory of frame_%04d.png files into mp4 or gif.
- GIF  : PIL (no external binary needed)
- MP4  : imageio-ffmpeg (bundles its own ffmpeg binary)

Optional 4th arg: target resolution e.g. "1920x1080".
Frames (typically low-res from a pixelated SubViewport) are bilinear-
upscaled to the target size before encoding.
"""
import sys, os, glob
from pathlib import Path


def _parse_target_size(arg: str):
    """Parse 'WxH' string into (w, h) tuple, or return None."""
    if not arg:
        return None
    try:
        w, h = arg.lower().split("x")
        return int(w), int(h)
    except Exception:
        return None


def main():
    if len(sys.argv) < 4:
        print("usage: make_video.py <frames_dir> <output_path> <fps> [WxH]", file=sys.stderr)
        sys.exit(1)

    frames_dir  = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    fps         = int(sys.argv[3])
    target_size = _parse_target_size(sys.argv[4] if len(sys.argv) > 4 else "")
    fmt         = output_path.suffix.lower().lstrip(".")

    frames = sorted(frames_dir.glob("frame_*.png"))
    if not frames:
        print(f"[make_video] No frames found in {frames_dir}", file=sys.stderr)
        sys.exit(1)

    tgt_label = f" → {target_size[0]}x{target_size[1]}" if target_size else ""
    print(f"[make_video] {len(frames)} frames{tgt_label} → {output_path} ({fmt}, {fps}fps)")

    if fmt == "gif":
        _encode_gif(frames, output_path, fps, target_size)
    elif fmt == "mp4":
        _encode_mp4(frames, output_path, fps, target_size)
    else:
        print(f"[make_video] Unknown format: {fmt}", file=sys.stderr)
        sys.exit(1)

    print(f"[make_video] Done: {output_path}")


def _load_frames(frames, target_size):
    """Load all frames as PIL Images, bilinear-upscaling to target_size if given."""
    from PIL import Image
    imgs = []
    for f in frames:
        img = Image.open(f).convert("RGB")
        if target_size:
            tw, th = target_size
            # ensure even dimensions (libx264 / palette requirement)
            tw = tw - tw % 2
            th = th - th % 2
            img = img.resize((tw, th), Image.BILINEAR)
        imgs.append(img)
    return imgs


def _encode_gif(frames, output_path, fps, target_size=None):
    duration_ms = int(1000 / fps)
    imgs = _load_frames(frames, target_size)
    imgs[0].save(
        output_path,
        save_all=True,
        append_images=imgs[1:],
        loop=0,
        duration=duration_ms,
        optimize=False,
    )


def _encode_mp4(frames, output_path, fps, target_size=None):
    try:
        import imageio_ffmpeg
    except ImportError:
        print("[make_video] imageio-ffmpeg not installed. Run: pip3 install imageio-ffmpeg", file=sys.stderr)
        sys.exit(1)

    ffmpeg_bin = imageio_ffmpeg.get_ffmpeg_exe()
    import subprocess
    from PIL import Image

    src_w, src_h = Image.open(frames[0]).size
    if target_size:
        out_w = target_size[0] - target_size[0] % 2
        out_h = target_size[1] - target_size[1] % 2
        vf = f"scale={out_w}:{out_h}:flags=bilinear"
    else:
        out_w = src_w - src_w % 2
        out_h = src_h - src_h % 2
        vf = f"scale={out_w}:{out_h}"

    cmd = [
        ffmpeg_bin, "-y",
        "-framerate", str(fps),
        "-i", str(frames[0].parent / "frame_%04d.png"),
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-crf", "18",
        "-vf", vf,
        str(output_path),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        sys.exit(result.returncode)


if __name__ == "__main__":
    main()
