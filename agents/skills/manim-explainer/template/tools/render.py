"""Render chapters and build review contact sheets.

  python3 tools/render.py ch00 ch01        # 480p15 preview + contact sheet
  python3 tools/render.py all -q h         # final quality, every chapter (or an episode key, e.g. ep1)
  python3 tools/render.py ch03 --sheet 20  # denser contact sheet
"""
import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from narration import CHAPTERS, EPISODES, ORDER  # noqa: E402

TEX = Path.home() / "Library/TinyTeX/bin/universal-darwin"
QDIR = {"l": "480p15", "m": "720p30", "p": "1080p30", "h": "1080p60", "k": "2160p60"}


def scene_file(key):
    return next((ROOT / "scenes").glob(f"{key}_*.py"))


def output(key, q):
    f = scene_file(key)
    return ROOT / "media" / "videos" / f.stem / QDIR[q] / f"{key.capitalize()}.mp4"


def lint_files(key):
    return [ROOT / "review" / "lint" / f"{beat}.txt" for beat, _ in CHAPTERS[key]]


def render(key, q):
    for f in lint_files(key):  # common.lint appends; start each render clean
        f.unlink(missing_ok=True)
    env = dict(os.environ, PATH=f"{TEX}:{os.environ['PATH']}")
    # A LaTeX and a Text (SVG) cache per chapter: chapters rendering in parallel otherwise race on the shared
    # caches and fail with "ParseError: no element found".
    cfg = ROOT / "media" / f"manim_{key}.cfg"
    cfg.parent.mkdir(exist_ok=True)
    cfg.write_text(f"[CLI]\ntex_dir = {ROOT / 'media' / 'Tex' / key}\ntext_dir = {ROOT / 'media' / 'texts' / key}\n")
    # "p" = 1080p at 30 fps: final quality at half the render time of 1080p60.
    qflags = ["-qh", "--frame_rate", "30"] if q == "p" else [f"-q{q}"]
    cmd = ["manim", "render", *qflags, "--disable_caching", "--config_file", str(cfg),
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
    keys = [k for a in args.keys for k in (ORDER if a == "all" else EPISODES.get(a, [a]))]
    for key in keys:
        path = render(key, args.q)
        sheet(path, key, args.sheet)
        found = [line for f in lint_files(key) if f.exists() for line in f.read_text().splitlines()]
        if found:
            print(f"{key}: {len(found)} layout warnings (review/lint/); fix them or confirm they are intended:")
            print("\n".join(f"  {line}" for line in dict.fromkeys(found)))


if __name__ == "__main__":
    main()
