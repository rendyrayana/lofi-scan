"""
make_video.py  <frames_dir> <output_path> <fps>

Encodes a directory of frame_%04d.png files into mp4 or gif.
- GIF  : PIL (no external binary needed)
- MP4  : imageio-ffmpeg (bundles its own ffmpeg binary)
"""
import sys, os, glob
from pathlib import Path

def main():
    if len(sys.argv) < 4:
        print("usage: make_video.py <frames_dir> <output_path> <fps>", file=sys.stderr)
        sys.exit(1)

    frames_dir  = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    fps         = int(sys.argv[3])
    fmt         = output_path.suffix.lower().lstrip(".")

    frames = sorted(frames_dir.glob("frame_*.png"))
    if not frames:
        print(f"[make_video] No frames found in {frames_dir}", file=sys.stderr)
        sys.exit(1)

    print(f"[make_video] {len(frames)} frames → {output_path} ({fmt}, {fps}fps)")

    if fmt == "gif":
        _encode_gif(frames, output_path, fps)
    elif fmt == "mp4":
        _encode_mp4(frames, output_path, fps)
    else:
        print(f"[make_video] Unknown format: {fmt}", file=sys.stderr)
        sys.exit(1)

    print(f"[make_video] Done: {output_path}")


def _encode_gif(frames, output_path, fps):
    from PIL import Image
    duration_ms = int(1000 / fps)
    imgs = [Image.open(f).convert("RGB") for f in frames]
    imgs[0].save(
        output_path,
        save_all=True,
        append_images=imgs[1:],
        loop=0,
        duration=duration_ms,
        optimize=False,
    )


def _encode_mp4(frames, output_path, fps):
    try:
        import imageio_ffmpeg
    except ImportError:
        print("[make_video] imageio-ffmpeg not installed. Run: pip3 install imageio-ffmpeg", file=sys.stderr)
        sys.exit(1)

    ffmpeg_bin = imageio_ffmpeg.get_ffmpeg_exe()
    import subprocess, shlex
    # Read first frame for size
    from PIL import Image
    w, h = Image.open(frames[0]).size

    cmd = [
        ffmpeg_bin, "-y",
        "-framerate", str(fps),
        "-i", str(frames[0].parent / "frame_%04d.png"),
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-crf", "18",
        # ensure even dimensions (libx264 requirement)
        "-vf", f"scale={w - w%2}:{h - h%2}",
        str(output_path),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        sys.exit(result.returncode)


if __name__ == "__main__":
    main()
