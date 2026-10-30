"""Concatenate rendered chapters and master the audio (two-pass EBU R128 loudnorm).

  python3 tools/assemble.py -q h       # -> final.mp4 (a series: assemble.py ep1 -q p -> final/ep1.mp4)
  python3 tools/assemble.py -q l       # quick full-length preview -> review/preview.mp4
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
from narration import EPISODES, ORDER  # noqa: E402
from render import QDIR, output  # noqa: E402

TARGET = "I=-16:TP=-1.5:LRA=11"


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ep", nargs="?", choices=list(EPISODES) or None)
    ap.add_argument("-q", default="h", choices=QDIR)
    args = ap.parse_args()
    parts = [output(k, args.q) for k in (EPISODES[args.ep] if args.ep else ORDER)]
    missing = [str(p) for p in parts if not p.exists()]
    if missing:
        raise SystemExit("missing renders:\n" + "\n".join(missing))

    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        # Manim's audio track stops at the last sound, 1-2 s before the video ends. Concatenating
        # and re-encoding AAC collapses those gaps, so the voice drifts ahead chapter by chapter.
        # Pad each chapter's audio to exactly its video length as PCM, then join video and audio separately.
        wavs = []
        for i, p in enumerate(parts):
            vdur = run(["ffprobe", "-v", "error", "-select_streams", "v", "-show_entries", "stream=duration",
                        "-of", "csv=p=0", str(p)]).stdout.strip()
            wav = tmp / f"a{i:02d}.wav"
            run(["ffmpeg", "-y", "-v", "error", "-i", str(p), "-map", "0:a", "-af",
                 f"aresample=48000,apad=whole_dur={vdur},atrim=end={vdur}", "-ac", "2", "-c:a", "pcm_s16le", str(wav)])
            wavs.append(wav)
        vlist, alist = tmp / "v.txt", tmp / "a.txt"
        vlist.write_text("".join(f"file '{p}'\n" for p in parts))
        alist.write_text("".join(f"file '{w}'\n" for w in wavs))
        jv, ja = tmp / "video.mp4", tmp / "audio.wav"
        run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", str(vlist), "-map", "0:v",
             "-c", "copy", str(jv)])
        run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", str(alist), "-c", "copy", str(ja)])

        measure = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(ja), "-af",
                                  f"loudnorm={TARGET}:print_format=json", "-f", "null", "-"],
                                 capture_output=True, text=True).stderr
        stats = json.loads(measure[measure.rindex("{"):measure.rindex("}") + 1])
        second = (f"loudnorm={TARGET}:measured_I={stats['input_i']}:measured_TP={stats['input_tp']}:"
                  f"measured_LRA={stats['input_lra']}:measured_thresh={stats['input_thresh']}:"
                  f"offset={stats['target_offset']}:linear=true")
        if args.q in ("h", "p"):
            dest = ROOT / (f"final/{args.ep}.mp4" if args.ep else "final.mp4")
        else:
            dest = ROOT / f"review/{args.ep or 'full'}_preview.mp4"
        dest.parent.mkdir(exist_ok=True)
        run(["ffmpeg", "-y", "-v", "error", "-i", str(jv), "-i", str(ja), "-map", "0:v", "-map", "1:a",
             "-af", second, "-ar", "48000", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
             "-movflags", "+faststart", str(dest)])

    dur = float(run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
                     str(dest)]).stdout)
    pcm = subprocess.run(["ffmpeg", "-v", "error", "-i", str(dest), "-map", "0:a", "-f", "s16le", "-ac", "1",
                          "-ar", "48000", "-"], capture_output=True).stdout
    audio_s = len(pcm) / 2 / 48000
    vdur = float(run(["ffprobe", "-v", "error", "-select_streams", "v", "-show_entries", "stream=duration",
                      "-of", "csv=p=0", str(dest)]).stdout)
    print(f"{dest.relative_to(ROOT)}: {dur / 60:.1f} min, input loudness {stats['input_i']} LUFS -> -16, "
          f"decoded audio {audio_s:.2f} s vs video {vdur:.2f} s")
    if abs(audio_s - vdur) > 0.15:
        raise SystemExit("audio/video length mismatch: sync is broken")


if __name__ == "__main__":
    main()
