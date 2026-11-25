#!/usr/bin/env python3
"""The skill's toolchain: newest stable Manim, Kokoro, Whisper and Python, swapped in only after a self-test passes.

  python3 setup.py              build what's missing (nix activation runs this; instant when set up)
  python3 setup.py --upgrade    move to the newest versions that pass the self-test (a daily job runs this)
  python3 setup.py --check      self-test the installed toolchain
  python3 setup.py --upgrade --accept-look   take an upgrade whose frames moved more than the guard allows
  python3 setup.py --check --accept-look     after changing the template's look: make its frames the new reference

Nothing is pinned. For each stack (render: manim; voice: kokoro + whisper) it picks the newest stable CPython for
which the compiled dependencies have wheels, installs the newest releases into a staged relocatable venv, and runs
the whole template pipeline on a test chapter that touches every helper (voice -> ASR -> render -> beat sheets ->
assembly with its sync check), then compares the frames with the last accepted toolchain's. Only when all of that
passes is the staged venv moved into place; otherwise the next older Python is tried, and failing that the current
toolchain stays and the reason is printed (the job's log: ~/.local/state/jobs/manim-explainer-upgrade.log).
"""
import argparse
import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

SKILL = Path(__file__).resolve().parent
HOME = Path.home()
# Keep this path short: under a ~150-character prefix espeak-ng (Kokoro's phonemizer) can't find its data files.
DATA = Path(os.environ.get("MANIM_EXPLAINER_HOME") or
            Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share") / "manim-explainer")
UV = os.environ.get("UV") or shutil.which("uv") or "uv"
DARWIN = sys.platform == "darwin"
STACKS = {
    "render": ["manim"],
    # ponytail: Linux is untested; faster-whisper stands in for MLX there.
    "voice": ["kokoro", "soundfile", "mlx-whisper" if DARWIN else "faster-whisper"],
}
KEY_PACKAGES = ["manim", "manimpango", "pycairo", "numpy", "pillow", "av", "kokoro", "misaki", "torch", "spacy",
                "en-core-web-sm", "mlx-whisper", "mlx", "faster-whisper", "soundfile", "huggingface-hub"]
# Compiled packages that must arrive as wheels when choosing a Python: a brand-new Python usually fails by
# lacking these, and building numpy or torch from source would take long. pycairo is exempt (sdist only on macOS).
WHEELS_ONLY = ["numpy", "av", "pillow", "manimpango", "scipy", "skia-pathops", "mapbox-earcut", "moderngl",
               "glcontext", "torch", "mlx", "mlx-metal", "spacy", "thinc", "blis", "cymem", "preshed", "murmurhash",
               "srsly", "tokenizers", "safetensors", "numba", "llvmlite", "ctranslate2", "onnxruntime"]
# Largest change of any 8x8 block of the self-test's beat frames, 0..1. Measured: reruns and Manim 0.22.0 ->
# 0.22.1 give 0.0 (the self-test's timings are fixed); one text block 1 px off gives 0.12, a missing name label
# 0.12, a missing image 0.77. So any visible change holds the upgrade until a person has looked (--accept-look).
LOOK_LIMIT = 0.03
SELFTEST_LINES = [("c99_1", "First, the parts. | Then they move."), ("c99_2", "Now the numbers. | And we are done.")]


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def run(cmd, timeout=3600, **kw):
    return subprocess.run([str(c) for c in cmd], capture_output=True, text=True, timeout=timeout, **kw)


def build_env():
    env = dict(os.environ)
    brew = shutil.which("brew") or "/opt/homebrew/bin/brew"
    if DARWIN and Path(brew).exists():
        # pycairo builds against Homebrew's cairo. Nix's pkg-config comes first on PATH but neither searches
        # Homebrew's prefix nor expands cairo's private requirements, so the build fails on xcb/xcb.h.
        prefix = run([brew, "--prefix"]).stdout.strip()
        if Path(prefix, "bin/pkgconf").exists():
            env["PKG_CONFIG"] = f"{prefix}/bin/pkgconf"
    return env


def pythons():
    """Stable CPython minors that uv has or can download, newest first."""
    minors = set()
    for p in json.loads(run([UV, "python", "list", "--output-format", "json"]).stdout or "[]"):
        m = re.fullmatch(r"3\.(\d+)\.\d+", p.get("version", ""))  # no a/b/rc pre-releases
        if m and p.get("implementation") == "cpython" and p.get("variant", "default") == "default":
            minors.add(int(m.group(1)))
    return [f"3.{m}" for m in sorted(minors, reverse=True) if m >= 11]


def resolve(stack, py):
    """{package: version} uv would install for this stack on Python `py`, or None if it can't with wheels."""
    cmd = [UV, "pip", "compile", "-", "--python-version", py, "-q", "--no-header", "--no-annotate"]
    for p in WHEELS_ONLY:
        cmd += ["--only-binary", p]
    r = run(cmd, input="\n".join(STACKS[stack]), timeout=300)
    if r.returncode:
        return None
    return dict(line.split("==", 1) for line in r.stdout.splitlines() if "==" in line)


def installed(venv):
    r = run([UV, "pip", "list", "--python", venv / "bin/python", "--format", "json"])
    pkgs = {p["name"].lower(): p["version"] for p in json.loads(r.stdout or "[]")}
    py = run([venv / "bin/python", "-c", "import sys; print('%d.%d.%d' % sys.version_info[:3])"]).stdout.strip()
    return {"python": py, "packages": {k: pkgs[k] for k in KEY_PACKAGES if k in pkgs}}


def build(stack, py, dest):
    """Install the newest releases of `stack` on Python `py` into a fresh relocatable venv at `dest`."""
    shutil.rmtree(dest, ignore_errors=True)
    env = build_env()
    for cmd in ([UV, "venv", "-q", "--relocatable", "--python", py, dest],
                [UV, "pip", "install", "-q", "--upgrade", "--python", dest / "bin/python", *STACKS[stack]]):
        r = run(cmd, env=env)
        if r.returncode:
            return f"{' '.join(map(str, cmd[:3]))} failed: {(r.stderr or r.stdout).strip()[-1500:]}"
    if stack == "voice":
        # misaki needs spaCy's English model; the model release must match the installed spaCy, so ask spaCy.
        code = ("from spacy.cli.download import get_compatibility, get_version, get_model_filename;"
                "from spacy import about; m = 'en_core_web_sm';"
                "print(about.__download_url__ + '/' + get_model_filename(m, get_version(m, get_compatibility())))")
        r = run([dest / "bin/python", "-c", code])
        url = r.stdout.strip().splitlines()[-1] if r.returncode == 0 and r.stdout.strip() else ""
        if not url:
            return f"could not find the spaCy model for this spaCy: {r.stderr.strip()[-800:]}"
        r = run([UV, "pip", "install", "-q", "--python", dest / "bin/python", url], env=env)
        if r.returncode:
            return f"spaCy model install failed: {r.stderr.strip()[-800:]}"
    return None


def compare_frames(py, ref, new):
    """Largest look change between matching frame files, 0..1, from the render venv (it has numpy + Pillow)."""
    code = r'''
import sys, numpy as np
from pathlib import Path
from PIL import Image
ref, new = Path(sys.argv[1]), Path(sys.argv[2])
worst = (0.0, "")
def load(p):
    return np.asarray(Image.open(p).convert("L"), dtype=float)
B = 8  # 8x8-pixel blocks of the 427-wide frame: a missing label fills a block, a 1 px kerning shift doesn't
for a in sorted(ref.rglob("*.png")):
    b = new / a.relative_to(ref)
    if not b.exists():
        print(f"1.0 missing {b.relative_to(new)}"); sys.exit()
    x, y = load(a), load(b)
    if x.shape != y.shape:
        print(f"1.0 size {a.relative_to(ref)}"); sys.exit()
    h, w = (x.shape[0] // B) * B, (x.shape[1] // B) * B
    d = np.abs(x - y)[:h, :w].reshape(h // B, B, w // B, B).mean(axis=(1, 3))
    worst = max(worst, (float(d.max() / 255), str(a.relative_to(ref))))
print(f"{worst[0]:.4f} {worst[1]}")
'''
    out = run([py, "-c", code, ref, new]).stdout.strip().split(" ", 1)
    return (float(out[0]), out[1] if len(out) > 1 else "") if out and out[0] else (1.0, "comparison failed")


def selftest(home, online, accept_look=False):
    """Run the template pipeline against the toolchain in `home`. Returns (failed stack or None, message)."""
    work = home / ".selftest"
    shutil.rmtree(work, ignore_errors=True)
    shutil.copytree(SKILL / "template", work, ignore=shutil.ignore_patterns("__pycache__"))
    shutil.copy(SKILL / "selftest/ch99_selftest.py", work / "scenes/ch99_selftest.py")
    with open(work / "narration.py", "a") as fh:
        fh.write(f"\nCHAPTERS[\"ch99\"] = {SELFTEST_LINES!r}\nORDER = list(CHAPTERS)\n")
    (work / "assets/stills").mkdir(parents=True, exist_ok=True)
    run(["ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i", "testsrc2=s=320x180", "-frames:v", "1",
         work / "assets/stills/selftest.png"])
    env = dict(os.environ, MANIM_EXPLAINER_HOME=str(home))
    env["HF_HUB_OFFLINE"] = "0" if online else env.get("HF_HUB_OFFLINE", "")
    py = sys.executable

    def step(stack, *args):
        r = run([py, *args], cwd=work, env=env)
        return None if r.returncode == 0 else (stack, f"{' '.join(args)}: {(r.stdout + r.stderr).strip()[-2000:]}")

    if err := step("voice", "tools/make_voice.py"):
        return err
    # Kokoro adds random noise, so clip lengths (and the frames sampled after each cue) jitter run to run. Fixed
    # timings make the frames a function of the render toolchain alone, so the comparison below sees only it.
    beats = [k for k in json.loads((work / "durations.json").read_text())]
    (work / "durations.json").write_text(json.dumps({k: 7.0 for k in beats}))
    (work / "cues.json").write_text(json.dumps({k: [0.0, 3.0] for k in beats}))
    r = run([py, "tools/qa_asr.py"], cwd=work, env=env)
    asr = r.stdout + r.stderr
    m = re.search(r"mean WER ([0-9.]+)", asr)
    if r.returncode or not m:
        return "voice", f"tools/qa_asr.py: {asr.strip()[-2000:]}"
    wer = float(m.group(1))
    if wer > 0.35:
        return "voice", f"speech check heard the test lines badly (mean WER {wer:.2f}):\n{asr[-1500:]}"
    for args in (["tools/render.py", "all"], ["tools/assemble.py", "-q", "l"], ["tools/freeze_report.py"]):
        if err := step("render", *args):
            return err
    r = run([home / "render/bin/python", SKILL / "selftest/test_lint.py", work])
    if r.returncode:
        return "render", f"layout lint cases: {(r.stdout + r.stderr).strip()[-2000:]}"
    frames = work / "review/frames"
    ref = DATA / "reference"
    if ref.exists() and not accept_look:
        score, where = compare_frames(home / "render/bin/python", ref, frames)
        if score > LOOK_LIMIT:
            keep = DATA / "rejected-frames"
            shutil.rmtree(keep, ignore_errors=True)
            shutil.copytree(frames, keep)
            side = DATA / "look-change.png"  # accepted | new, the frame that moved most
            run(["ffmpeg", "-y", "-v", "error", "-i", ref / where, "-i", keep / where, "-filter_complex",
                 "[0][1]hstack", side])
            return "render", (f"frames changed ({score:.3f} > {LOOK_LIMIT} at {where}): see {side} (accepted | new). "
                              f"If the new look is fine: python3 {SKILL}/setup.py --upgrade --accept-look")
    return None, f"self-test passed (mean WER {wer:.2f})"


def notify(msg):
    """Desktop notice for the unattended daily upgrade, so a held upgrade doesn't sit unseen in a log."""
    if DARWIN:
        run(["osascript", "-e", f"display notification {json.dumps(msg[:200])} with title \"manim-explainer\""])
    elif shutil.which("notify-send"):
        run(["notify-send", "manim-explainer", msg[:200]])


def lock():
    DATA.mkdir(parents=True, exist_ok=True)
    fh = open(DATA / ".lock", "w")
    try:
        fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        log("another setup.py is running; leaving it to that one")
        sys.exit(0)
    return fh


def busy():
    """A video is being made with the current toolchain right now (don't swap venvs under it)."""
    r = run(["pgrep", "-f", f"{DATA}/(render|voice)/bin/"])
    return r.returncode == 0


def link_cli():
    """`manim` on PATH is the render venv's (it replaces the old uv-tool install made for this skill)."""
    if "manim" in run([UV, "tool", "list"]).stdout.split():
        run([UV, "tool", "uninstall", "manim"])
    cli = HOME / ".local/bin/manim"
    if cli.is_symlink() or not cli.exists():
        cli.parent.mkdir(parents=True, exist_ok=True)
        cli.unlink(missing_ok=True)
        cli.symlink_to(DATA / "render/bin/manim")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--upgrade", action="store_true", help="move to the newest versions that pass the self-test")
    ap.add_argument("--check", action="store_true", help="self-test the installed toolchain")
    ap.add_argument("--accept-look", action="store_true", help="accept the new frames as the reference")
    args = ap.parse_args()
    current = json.loads((DATA / "versions.json").read_text()) if (DATA / "versions.json").exists() else {}
    missing = [s for s in STACKS if not (DATA / s / "bin/python").exists() or s not in current]
    if not (args.upgrade or args.check or missing):
        print(f"manim-explainer toolchain ready: manim {current['render']['packages'].get('manim')}, "
              f"kokoro {current['voice']['packages'].get('kokoro')} ({DATA})")
        return
    held = lock()  # noqa: F841 (kept open: the lock lasts until exit)
    t0 = time.time()
    if args.check:
        failed, msg = selftest(DATA, online=False, accept_look=args.accept_look)
        if failed is None and args.accept_look:
            shutil.rmtree(DATA / "reference", ignore_errors=True)
            shutil.copytree(DATA / ".selftest/review/frames", DATA / "reference")
        log(msg if failed is None else f"FAILED ({failed}): {msg} (work dir kept: {DATA / '.selftest'})")
        if failed is None:
            shutil.rmtree(DATA / ".selftest", ignore_errors=True)
        sys.exit(1 if failed else 0)

    # For each stack: candidate Pythons (newest first) where the newest releases resolve with wheels.
    plans = {}
    for stack in STACKS:
        if not (args.upgrade or stack in missing):
            continue
        cands = [(py, res) for py in pythons() if (res := resolve(stack, py))]
        if not cands:
            log(f"{stack}: nothing resolves on any Python; keeping what is installed")
            continue
        have = current.get(stack, {})
        best_py, best = cands[0]
        same = (have.get("python", "").startswith(best_py + ".") and all(
            have.get("packages", {}).get(k.lower()) == v for k, v in best.items() if k.lower() in KEY_PACKAGES))
        if stack not in missing and same:
            log(f"{stack}: already newest (Python {have['python']}, " +
                ", ".join(f"{k} {v}" for k, v in have["packages"].items()) + ")")
            continue
        plans[stack] = cands
    if not plans:
        log("nothing to do")
        return
    if busy():
        log("a render or voice job is running with the current toolchain; trying again next run")
        return

    stage = DATA / ".stage"
    stage.mkdir(exist_ok=True)
    for stack in STACKS:  # stacks not being rebuilt are tested as they are
        link = stage / stack
        if stack not in plans and (DATA / stack).exists():
            if link.is_symlink() or link.exists():
                shutil.rmtree(link) if link.is_dir() and not link.is_symlink() else link.unlink()
            link.symlink_to(DATA / stack)
    tries = {s: 0 for s in plans}
    built = {}
    while True:
        for stack, cands in plans.items():
            while stack not in built and tries[stack] < len(cands):
                py, res = cands[tries[stack]]
                log(f"{stack}: building on Python {py} (" + ", ".join(
                    f"{k} {v}" for k, v in res.items() if k.lower() in KEY_PACKAGES) + ")")
                err = build(stack, py, stage / stack)
                if err:
                    log(f"{stack}: {err}")
                    tries[stack] += 1
                else:
                    built[stack] = py
            if stack not in built:
                log(f"{stack}: no Python worked; keeping the installed toolchain")
                shutil.rmtree(stage, ignore_errors=True)
                notify(f"{stack} upgrade failed on every Python; still on the previous toolchain (see the job log)")
                sys.exit(1)
        log("self-test: voice -> ASR -> render (every helper) -> beat sheets -> assembly -> frame comparison")
        failed, msg = selftest(stage, online=True, accept_look=args.accept_look)
        if failed is None:
            log(msg)
            break
        log(f"self-test FAILED in {failed}: {msg}")
        if failed not in plans or msg.startswith("frames changed"):
            shutil.rmtree(stage, ignore_errors=True)
            notify(f"upgrade held, still on the previous toolchain: {msg}")
            sys.exit(1)
        built.pop(failed)
        tries[failed] += 1

    # Swap the tested venvs in. Relocatable venvs keep working after the move.
    frames = stage / ".selftest/review/frames"
    for stack in plans:
        old = DATA / f".old-{stack}"
        shutil.rmtree(old, ignore_errors=True)
        if (DATA / stack).exists():
            (DATA / stack).rename(old)
        (stage / stack).rename(DATA / stack)
        shutil.rmtree(old, ignore_errors=True)
    shutil.rmtree(DATA / "reference", ignore_errors=True)
    shutil.copytree(frames, DATA / "reference")
    shutil.rmtree(stage, ignore_errors=True)
    shutil.rmtree(DATA / "venv", ignore_errors=True)  # the pre-2026-11 single voice venv
    current = {s: installed(DATA / s) for s in STACKS}
    (DATA / "versions.json").write_text(json.dumps(current, indent=1) + "\n")
    link_cli()
    for s in plans:
        log(f"{s}: now Python {current[s]['python']}, " + ", ".join(f"{k} {v}" for k, v in current[s]["packages"].items()))
    log(f"done in {time.time() - t0:.0f}s")


if __name__ == "__main__":
    main()
