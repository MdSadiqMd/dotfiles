"""List stretches where the preview frame sits frozen while the voice keeps talking, mapped to the sentence.

  python3 tools/assemble.py -q l && python3 tools/freeze_report.py
Reads review/full_preview.mp4, the 480p chapter renders and review/beat_times/. Prints stretches >= 4.5 s.
Small motion (a counter, a probe dot) can read as frozen: check flagged lines with tools/beat_review.py.
The fix is motion that shows what that sentence says, not decorative motion (camera drift was tried and cut).
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))
from narration import CHAPTERS, ORDER  # noqa: E402
from render import output  # noqa: E402


def probe(path):
    return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
                                 str(path)], capture_output=True, text=True).stdout)


def main():
    log = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(ROOT / "review/full_preview.mp4"), "-vf",
                          "freezedetect=n=0.001:d=3", "-map", "0:v", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    starts = re.findall(r"freeze_start: ([0-9.]+)", log)
    durs = re.findall(r"freeze_duration: ([0-9.]+)", log)
    offsets, t = {}, 0.0
    for k in ORDER:
        offsets[k] = t
        t += probe(output(k, "l"))
    beat_times = {f.stem: float(f.read_text()) for f in (ROOT / "review/beat_times").glob("*.txt")}
    cues = json.loads((ROOT / "cues.json").read_text())
    total = 0.0
    for s, d in zip(map(float, starts), map(float, durs)):
        ch = [k for k in ORDER if offsets[k] <= s][-1]
        total += d
        local = s - offsets[ch]
        beats = [(t, k) for k, t in beat_times.items() for kk, _ in CHAPTERS[ch] if kk == k]
        line = ""
        if beats:
            t0, key = max((b for b in beats if b[0] <= local + 0.01), default=min(beats))
            segs = [x.strip() for x in re.split(r"\|\|?", dict(CHAPTERS[ch])[key])]
            idx = max([i for i, c in enumerate(cues[key]) if c <= local - t0] or [0])
            line = f"{key}[{idx}] {segs[idx][:70]}"
        if d >= 4.5:
            print(f"{ch} +{local:6.1f}s  frozen {d:4.1f}s  {line}")
    print(f"total frozen {total:.0f}s of {t:.0f}s")


if __name__ == "__main__":
    main()
