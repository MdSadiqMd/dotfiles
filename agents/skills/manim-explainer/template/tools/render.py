"""Render chapters in parallel, skip the ones whose inputs haven't changed, and build the review sheets.

  python3 tools/render.py ch00 ch01        # 480p15 preview + contact sheet + beat sheet + lint, per chapter
  python3 tools/render.py all              # every chapter (or an episode key, e.g. ep1); unchanged ones are skipped
  python3 tools/render.py all -q h         # final quality (1080p60); -q p = 1080p30
  python3 tools/render.py ch03 --force     # re-render even if nothing changed
  python3 tools/render.py ch03 --sheet 20  # denser contact sheet

Chapters render side by side, longest first; each one's contact sheet and beat sheet are built in its own worker
from a single decode. Compiled LaTeX is shared by every chapter and project (tex_store). A chapter is skipped
when its scene file, the shared scenes (common, kits, stage), the chapter files it imports,
its beats' audio, durations and cues, assets/ and the Manim toolchain are all unchanged since its last render at
that quality.
"""
import argparse
import concurrent.futures as cf
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from functools import cache
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))
from env import tool_path, versions  # noqa: E402
from narration import CHAPTERS, EPISODES, ORDER  # noqa: E402

QDIR = {"l": "480p15", "m": "720p30", "p": "1080p30", "h": "1080p60", "k": "2160p60"}
CHAPTER = re.compile(r"ch\d+|e\d+c\d+", re.I)


def scene_file(key):
    return next((ROOT / "scenes").glob(f"{key}_*.py"))


def output(key, q):
    f = scene_file(key)
    return ROOT / "media" / "videos" / f.stem / QDIR[q] / f"{key.capitalize()}.mp4"


def lint_files(key):
    return [ROOT / "review" / "lint" / f"{beat}.txt" for beat, _ in CHAPTERS[key]]


def fingerprint(key, q):
    """Hash of everything a chapter's render depends on."""
    h = hashlib.sha1(f"{q}|v1|{json.dumps(versions().get('render'), sort_keys=True)}".encode())
    own = scene_file(key)
    src = own.read_text()
    files = [own]
    for f in sorted((ROOT / "scenes").glob("*.py")):
        # shared modules always; another chapter's file only when this one imports it
        if f != own and (not CHAPTER.match(f.stem) or re.search(rf"\b{re.escape(f.stem)}\b", src)):
            files.append(f)
    assets = ROOT / "assets"
    files += sorted(p for p in assets.rglob("*") if p.is_file()) if assets.exists() else []
    beats = [b for b, _ in CHAPTERS[key]]
    files += [ROOT / "audio" / f"{b}.wav" for b in beats]
    for f in files:
        h.update(str(f.relative_to(ROOT)).encode())
        h.update(f.read_bytes() if f.exists() else b"missing")
    for name in ("durations.json", "cues.json"):
        data = json.loads((ROOT / name).read_text())
        h.update(json.dumps([data.get(b) for b in beats]).encode())
    return h.hexdigest()


@cache
def tex_store():
    """Compiled-LaTeX SVGs shared by every chapter and project on this machine. Manim names each SVG by a hash of
    the TeX source, and latex + dvisvgm are deterministic (checked: 261 strings compiled in several chapters were
    byte-identical), so a string compiled once never needs compiling again: each compile is two processes,
    ~0.15 s, and a cold chapter has 50-100 of them. Keyed by the TeX and Manim installs, so an upgrade starts
    a fresh store instead of reusing SVGs drawn by the old one."""
    path = tool_path()
    tools = [os.path.realpath(shutil.which(t, path=path) or t) for t in ("latex", "dvisvgm")]
    key = hashlib.sha1(json.dumps([tools, versions().get("render")], sort_keys=True).encode()).hexdigest()[:12]
    store = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "manim-explainer" / "tex" / key
    store.mkdir(parents=True, exist_ok=True)
    return store


def share_tex(chapter_dir, pull):
    """Hard-link SVGs between a chapter's own TeX cache and the shared store: pull=True before a render (what the
    store has that the chapter lacks), False after it (what the chapter compiled that the store lacks). Links are
    atomic and the chapter keeps its own directory, so parallel renders still never touch each other's files."""
    store = tex_store()
    chapter_dir.mkdir(parents=True, exist_ok=True)
    src, dst = (store, chapter_dir) if pull else (chapter_dir, store)
    have = {e.name for e in os.scandir(dst)}
    for e in os.scandir(src):
        if e.name.endswith(".svg") and e.name not in have:
            try:
                os.link(e.path, dst / e.name)
            except FileExistsError:
                pass
            except OSError:  # another filesystem: copy to a temp name, then rename into place
                tmp = dst / f".{e.name}.{os.getpid()}"
                shutil.copyfile(e.path, tmp)
                os.replace(tmp, dst / e.name)


def stamp(key, q):
    return ROOT / "media" / "stamps" / f"{key}.{q}"


def render(key, q):
    """Returns (key, rendered: bool, error text or None)."""
    sig = fingerprint(key, q)
    st = stamp(key, q)
    if output(key, q).exists() and st.exists() and st.read_text() == sig:
        return key, False, None
    for f in lint_files(key):  # common.lint appends; start each render clean
        f.unlink(missing_ok=True)
    # A LaTeX and a Text (SVG) cache per chapter: chapters rendering in parallel otherwise race on the shared
    # caches and fail with "ParseError: no element found". Not under media/Tex: Manim's LaTeX cleanup unlinks
    # every non-.svg entry there, so a folder in it crashes any ad-hoc probe script run from the project root.
    cache = ROOT / "media" / "cache" / key
    share_tex(cache / "Tex", pull=True)
    cfg = ROOT / "media" / f"manim_{key}.cfg"
    cfg.parent.mkdir(exist_ok=True)
    cfg.write_text(f"[CLI]\ntex_dir = {cache / 'Tex'}\ntext_dir = {cache / 'texts'}\n")
    # "p" = 1080p at 30 fps: final quality at half the render time of 1080p60.
    qflags = ["-qh", "--frame_rate", "30"] if q == "p" else [f"-q{q}"]
    cmd = ["manim", "render", *qflags, "--disable_caching", "--config_file", str(cfg),
           "--media_dir", str(ROOT / "media"), str(scene_file(key)), key.capitalize()]
    res = subprocess.run(cmd, cwd=ROOT, env=dict(os.environ, PATH=tool_path()), capture_output=True, text=True)
    if res.returncode != 0:
        st.unlink(missing_ok=True)
        return key, True, (res.stdout[-3000:] + res.stderr[-3000:])
    share_tex(cache / "Tex", pull=False)
    st.parent.mkdir(exist_ok=True)
    st.write_text(sig)
    return key, True, None


def lint_report(key):
    found = [line for f in lint_files(key) if f.exists() for line in f.read_text().splitlines()]
    if not found:
        return []
    # one line per distinct issue with where it first and last showed, so a persistent stage problem
    # doesn't print once per cue and bury the new ones
    seen = {}
    for line in found:
        where, msg = line.split("  ", 1)
        seen.setdefault(msg, []).append(where)
    out = [f"{key}: {len(seen)} distinct layout warnings (review/lint/); fix them or confirm they are intended:"]
    for msg, ws in seen.items():
        span = ws[0] if len(ws) == 1 else f"{ws[0]} .. {ws[-1]}, {len(ws)}x"
        out.append(f"  {msg}  [{span}]")
    return out


def review(key, q, n):
    """Contact sheet + beat sheet (480p only, one decode for both) and lint lines for a freshly rendered chapter."""
    from beat_review import describe, review as beats
    out = []
    if q == "l":
        dest = ROOT / "review" / f"{key}.png"
        frames, changed, dur = beats(key, output(key, q), sheet=(n, dest))
        out += [f"{key}: {dur:.1f}s -> contact sheet {dest.relative_to(ROOT)}", describe(key, frames, changed)]
    return out + lint_report(key)


def job(key, q, n):
    """Render one chapter and build its review in the same worker, so sheets don't queue behind each other."""
    key, rendered, err = render(key, q)
    return key, rendered, err, (review(key, q, n) if rendered and not err else [])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("keys", nargs="+")
    ap.add_argument("-q", default="l", choices=QDIR)
    ap.add_argument("--sheet", type=int, default=16)
    ap.add_argument("--force", action="store_true", help="render even when nothing changed")
    ap.add_argument("-j", type=int, default=int(os.environ.get("RENDER_JOBS", 0)) or min(8, (os.cpu_count() or 2) // 2),
                    help="chapters rendered at once (default: half the cores, at most 8)")
    args = ap.parse_args()
    keys = list(dict.fromkeys(k for a in args.keys for k in (ORDER if a == "all" else EPISODES.get(a, [a]))))
    if args.force:
        for k in keys:
            stamp(k, args.q).unlink(missing_ok=True)
    failed, skipped = [], []
    # Each chapter is its own manim process (single-threaded Cairo), so chapters render side by side.
    with cf.ThreadPoolExecutor(max(1, args.j)) as pool:
        # longest chapters first, so a long one doesn't start last and set the finishing time
        durs = json.loads((ROOT / "durations.json").read_text())
        order = sorted(keys, key=lambda k: -sum(durs.get(b, 0) for b, _ in CHAPTERS[k]))
        for done in cf.as_completed([pool.submit(job, k, args.q, args.sheet) for k in order]):
            key, rendered, err, lines = done.result()
            if err:
                failed.append(key)
                print(f"{key}: RENDER FAILED\n{err}\n", flush=True)
            elif not rendered:
                skipped.append(key)
            else:
                print("\n".join(lines), flush=True)
    if skipped:
        print(f"unchanged, not re-rendered: {' '.join(sorted(skipped))} (--force to redo)")
    if failed:
        raise SystemExit(f"render failed: {' '.join(sorted(failed))}")


if __name__ == "__main__":
    main()
