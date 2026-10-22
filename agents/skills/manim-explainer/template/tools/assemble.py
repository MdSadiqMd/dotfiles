"""Concatenate rendered chapters and master the audio (two-pass EBU R128 loudnorm).

  python3 tools/assemble.py -q h      # -> final.mp4
  python3 tools/assemble.py -q l      # quick full-length preview -> review/preview.mp4
"""
import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT))
from narration import ORDER  # noqa: E402
from render import QDIR, output  # noqa: E402

TARGET = "I=-16:TP=-1.5:LRA=11"


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-q", default="h", choices=QDIR)
    args = ap.parse_args()
    parts = [output(k, args.q) for k in ORDER]
    missing = [str(p) for p in parts if not p.exists()]
    if missing:
        raise SystemExit("missing renders:\n" + "\n".join(missing))

    with tempfile.TemporaryDirectory() as tmp:
        listing = Path(tmp) / "list.txt"
        listing.write_text("".join(f"file '{p}'\n" for p in parts))
        joined = Path(tmp) / "joined.mp4"
        run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", str(listing),
             "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", str(joined)])

        measure = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(joined), "-af",
                                  f"loudnorm={TARGET}:print_format=json", "-f", "null", "-"],
                                 capture_output=True, text=True).stderr
        stats = json.loads(measure[measure.rindex("{"):measure.rindex("}") + 1])
        second = (f"loudnorm={TARGET}:measured_I={stats['input_i']}:measured_TP={stats['input_tp']}:"
                  f"measured_LRA={stats['input_lra']}:measured_thresh={stats['input_thresh']}:"
                  f"offset={stats['target_offset']}:linear=true")
        dest = ROOT / ("final.mp4" if args.q == "h" else "review/preview.mp4")
        run(["ffmpeg", "-y", "-v", "error", "-i", str(joined), "-af", second, "-ar", "48000",
             "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(dest)])

    dur = float(run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
                     str(dest)]).stdout)
    print(f"{dest.relative_to(ROOT)}: {dur / 60:.1f} min, input loudness {stats['input_i']} LUFS -> -16")


if __name__ == "__main__":
    main()
