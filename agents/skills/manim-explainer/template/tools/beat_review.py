"""Per-chapter review sheets: one frame per narration segment, paired with the words spoken there.

  python3 tools/beat_review.py ch04 ch05     -> review/beats_ch04.png + review/beats_ch04.md
  python3 tools/beat_review.py ch04 --hd 05 12   -> review/hd_ch04_05.png ...: those beat frames at 1080p
render.py runs this itself after every 480p render. Frames are taken 1.2 s after each segment starts (after its
animation has landed). Needs review/beat_times/ (written by the Beat class). This is how an agent "watches" the
film: read the sheet next to the .md and check that each frame shows what its sentence says.

Frames are kept in review/frames/<ch>/. A frame whose pixels differ from the previous render is marked `*` in the
.md and also tiled, in order, into review/beats_<ch>_changed.png, so after a fix you look at what changed only
(unchanged frames are byte-identical to ones already reviewed).

One decode per chapter: the frame for time t is the first frame whose timestamp is >= t (what `ffmpeg -ss t`
returns; checked frame for frame), found from the packet timestamps, and every wanted frame (plus the contact
sheet, when render.py asks for one) comes out of a single ffmpeg pass instead of one process per frame.
"""
import bisect
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))
from narration import CHAPTERS  # noqa: E402

LAG = 1.2
COLS = 4
SCALE = "scale=427:-1"


def tile(frames_dir, n, dest):
    """Tile frames_dir/000.png .. n-1 into a COLS-wide sheet (the last row padded with grey)."""
    rows = -(-n // COLS)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(frames_dir / "%03d.png"), "-vf",
                    f"tile={COLS}x{rows}:padding=4:color=0x333333", "-frames:v", "1", str(dest)], check=True)


def points(ch):
    """[(beat key, segment index, time in the chapter, segment text)], one per beat frame, in order."""
    times = {f.stem: float(f.read_text()) for f in (ROOT / "review/beat_times").glob("*.txt")}
    cues = json.loads((ROOT / "cues.json").read_text())
    out = []
    for key, text in CHAPTERS[ch]:
        segs = [s.strip() for s in re.split(r"\|\|?", text)]
        out += [(key, i, times[key] + c + LAG, segs[i]) for i, c in enumerate(cues[key])]
    return out


def probe(video):
    """(sorted frame timestamps, container duration) without decoding."""
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                          "packet=pts_time:format=duration", "-of", "json", str(video)],
                         capture_output=True, text=True, check=True).stdout
    data = json.loads(out)
    pts = sorted(float(p["pts_time"]) for p in data.get("packets", []) if p.get("pts_time") not in (None, "N/A"))
    return pts, float(data["format"]["duration"])


def extract(video, times, dest_dir, sheet=None, scale=SCALE):
    """Write the frame at each time in `times` to dest_dir/.new000.png ... in one decode (scale=None: full size);
    with sheet=(n, path), also a contact sheet of n evenly spaced frames from the same pass."""
    pts, dur = probe(video)
    # times are rounded to 2 decimals, as `-ss {t:.2f}` did; past the end means the last frame
    idx = [min(bisect.bisect_left(pts, float(f"{t:.2f}")), len(pts) - 1) for t in times]
    wanted = sorted(set(idx))
    tmp = dest_dir / ".extract"
    shutil.rmtree(tmp, ignore_errors=True)
    tmp.mkdir(parents=True)
    pick = "+".join(f"eq(n\\,{k})" for k in wanted) or "0"
    size = f",{scale}" if scale else ""
    graph, maps = f"[0:v]select='{pick}'{size}[f]", ["-map", "[f]", "-fps_mode", "passthrough",
                                                       "-start_number", "0", str(tmp / "%04d.png")]
    if sheet:
        n, path = sheet
        rows = -(-n // COLS)
        graph = (f"[0:v]split=2[a][b];[a]select='{pick}'{size}[f];"
                 f"[b]fps={n / dur:.5f},{SCALE},tile={COLS}x{rows}:padding=4:color=0x333333[s]")
        maps += ["-map", "[s]", "-frames:v", "1", str(path)]
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(video), "-filter_complex", graph, *maps], check=True)
    for j, k in enumerate(idx):
        shutil.copyfile(tmp / f"{wanted.index(k):04d}.png", dest_dir / f".new{j:03d}.png")
    shutil.rmtree(tmp)
    return dur


def review(ch, video=None, sheet=None):
    """Build the beat sheet for one chapter (and the contact sheet if sheet=(n, path));
    returns (frame count, indices of frames that changed, video duration)."""
    from render import output
    video = video or output(ch, "l")
    frames = ROOT / "review" / "frames" / ch
    frames.mkdir(parents=True, exist_ok=True)
    pts = points(ch)
    dur = extract(video, [t for _, _, t, _ in pts], frames, sheet)
    lines, changed = [f"# {ch} beat review (* = changed since the last render)\n"], []
    for n, (key, i, _, seg) in enumerate(pts):
        png, new_png = frames / f"{n:03d}.png", frames / f".new{n:03d}.png"
        new = not png.exists() or png.read_bytes() != new_png.read_bytes()
        new_png.replace(png)
        if new:
            changed.append(n)
        lines.append(f"{n:02d}{'*' if new else ' '} {key}[{i}]  {seg}")
    n = len(pts)
    for stale in frames.glob("*.png"):
        if int(stale.stem) >= n:
            stale.unlink()
    tile(frames, n, ROOT / f"review/beats_{ch}.png")
    part = ROOT / f"review/beats_{ch}_changed.png"
    part.unlink(missing_ok=True)
    if changed and len(changed) < n:
        tmp = ROOT / "review" / "frames" / f".{ch}_changed"
        shutil.rmtree(tmp, ignore_errors=True)
        tmp.mkdir()
        for j, k in enumerate(changed):
            shutil.copy(frames / f"{k:03d}.png", tmp / f"{j:03d}.png")
        tile(tmp, len(changed), part)
        shutil.rmtree(tmp)
        lines.append(f"\nbeats_{ch}_changed.png tiles, in order: " + " ".join(f"{k:02d}" for k in changed))
    (ROOT / f"review/beats_{ch}.md").write_text("\n".join(lines) + "\n")
    return n, changed, dur


def describe(ch, n, changed, *_):
    if not changed:
        return f"{ch}: {n} beat frames, none changed -> nothing new to review"
    if len(changed) == n:
        return f"{ch}: {n} beat frames -> review/beats_{ch}.png + .md"
    return (f"{ch}: {len(changed)} of {n} beat frames changed -> review/beats_{ch}_changed.png "
            f"(frames {' '.join(f'{k:02d}' for k in changed)}; full sheet review/beats_{ch}.png)")


def hd(ch, idxs):
    """Full-resolution stills of beat frames `idxs` (numbers from the .md) from the chapter's 1080p render."""
    from render import output
    video = next((output(ch, q) for q in ("h", "p") if output(ch, q).exists()), None)
    if video is None:
        raise SystemExit(f"no 1080p render of {ch} yet: python3 tools/render.py {ch} -q p")
    pts = points(ch)
    tmp = ROOT / "review" / ".hd"
    tmp.mkdir(parents=True, exist_ok=True)
    extract(video, [pts[k][2] for k in idxs], tmp, scale=None)
    for j, k in enumerate(idxs):
        key, i, _, seg = pts[k]
        png = ROOT / "review" / f"hd_{ch}_{k:02d}.png"
        (tmp / f".new{j:03d}.png").replace(png)
        print(f"{png.relative_to(ROOT)}  {key}[{i}]  {seg}")
    shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--hd" in args:  # beat_review.py ch03 --hd 05 12
        hd(args[0], [int(a) for a in args[args.index("--hd") + 1:]])
    else:
        for ch in args:
            print(describe(ch, *review(ch)))
