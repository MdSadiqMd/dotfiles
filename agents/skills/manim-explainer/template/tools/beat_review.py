"""Per-chapter review sheets: one frame per narration segment, paired with the words spoken there.

  python3 tools/beat_review.py ch04 ch05     -> review/beats_ch04.png + review/beats_ch04.md
Frames are taken 1.2 s after each segment starts (after its animation has landed), from the 480p render.
Needs review/beat_times/ (written by the Beat class). This is how an agent "watches" the film: read the sheet
next to the .md and check that each frame shows what its sentence says.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))
from narration import CHAPTERS  # noqa: E402
from render import output  # noqa: E402

LAG = 1.2


def main():
    times = {f.stem: float(f.read_text()) for f in (ROOT / "review/beat_times").glob("*.txt")}
    cues = json.loads((ROOT / "cues.json").read_text())
    for ch in sys.argv[1:]:
        video = output(ch, "l")
        frames, lines = [], [f"# {ch} beat review\n"]
        n = 0
        for key, text in CHAPTERS[ch]:
            segs = [s.strip() for s in re.split(r"\|\|?", text)]
            for i, c in enumerate(cues[key]):
                t = times[key] + c + LAG
                png = Path(f"/tmp/fl_br_{ch}_{n:03d}.png")
                subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", f"{t:.2f}", "-i", str(video), "-frames:v", "1",
                                "-vf", "scale=427:-1", str(png)], check=True)
                frames.append(png)
                lines.append(f"{n:02d}  {key}[{i}]  {segs[i]}")
                n += 1
        cols = 4
        rows = -(-len(frames) // cols)
        inputs = sum([["-i", str(f)] for f in frames], [])
        pad = rows * cols - len(frames)
        filt = "".join(f"[{i}]" for i in range(len(frames)))
        if pad:
            inputs += ["-f", "lavfi", "-i", "color=c=0x222222:s=427x240:d=1"]
            filt += "".join(f"[{len(frames)}]" for _ in range(pad))
        filt += f"xstack=inputs={rows * cols}:layout=" + "|".join(
            f"{(k % cols) * 427 + (k % cols) * 4}_{(k // cols) * 244}" for k in range(rows * cols)) + ":fill=0x333333"
        subprocess.run(["ffmpeg", "-y", "-v", "error", *inputs, "-filter_complex", filt, "-frames:v", "1",
                        str(ROOT / f"review/beats_{ch}.png")], check=True)
        (ROOT / f"review/beats_{ch}.md").write_text("\n".join(lines) + "\n")
        print(f"{ch}: {len(frames)} frames -> review/beats_{ch}.png")


if __name__ == "__main__":
    main()
