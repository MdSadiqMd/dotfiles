"""Render chapters and build review contact sheets.

  python3 tools/render.py ch00 ch01        # 480p15 preview + contact sheet
  python3 tools/render.py all -q h         # final quality, every chapter
  python3 tools/render.py ch03 --sheet 20  # denser contact sheet
"""
import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from narration import ORDER  # noqa: E402

TEX = Path.home() / "Library/TinyTeX/bin/universal-darwin"
QDIR = {"l": "480p15", "m": "720p30", "h": "1080p60", "k": "2160p60"}


def scene_file(key):
    return next((ROOT / "scenes").glob(f"{key}_*.py"))


def output(key, q):
    f = scene_file(key)
    return ROOT / "media" / "videos" / f.stem / QDIR[q] / f"{key.capitalize()}.mp4"


def render(key, q):
    env = dict(os.environ, PATH=f"{TEX}:{os.environ['PATH']}")
    cmd = ["manim", "render", f"-q{q}", "--disable_caching",
           "--media_dir", str(ROOT / "media"), str(scene_file(key)), key.capitalize()]
    res = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True)
    if res.returncode != 0:
        print(res.stdout[-3000:], res.stderr[-3000:])
        raise SystemExit(f"render failed: {key}")
    return output(key, q)


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                          "-of", "csv=p=0", str(path)], capture_output=True, text=True)
    return float(out.stdout.strip())


def sheet(path, key, n):
    cols = 4
    rows = -(-n // cols)
    dur = duration(path)
    dest = ROOT / "review" / f"{key}.png"
    dest.parent.mkdir(exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(path), "-vf",
                    f"fps={n / dur:.5f},scale=427:-1,tile={cols}x{rows}:padding=4:color=0x333333",
                    "-frames:v", "1", str(dest)], check=True)
    print(f"{key}: {dur:.1f}s -> {dest.relative_to(ROOT)}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("keys", nargs="+")
    ap.add_argument("-q", default="l", choices=QDIR)
    ap.add_argument("--sheet", type=int, default=16)
    args = ap.parse_args()
    keys = ORDER if args.keys == ["all"] else args.keys
    for key in keys:
        path = render(key, args.q)
        sheet(path, key, args.sheet)


if __name__ == "__main__":
    main()
