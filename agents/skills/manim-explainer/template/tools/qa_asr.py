"""Transcribe every narration clip with Whisper and diff it against the script.

Flags beats whose word error rate exceeds a threshold, which catches
mispronounced terms, dropped words, and garbled numbers.
Run: .kokoro/bin/python tools/qa_asr.py
"""
import re
import sys
from pathlib import Path

import jiwer
import mlx_whisper

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from narration import CHAPTERS  # noqa: E402

MODEL = "mlx-community/whisper-large-v3-turbo"
FLAG = 0.08


def norm(s):
    s = s.lower().replace("-", " ").replace("’", "'")
    s = re.sub(r"[^a-z0-9' ]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def main():
    flagged, total_wer, n = [], 0.0, 0
    for beats in CHAPTERS.values():
        for key, text in beats:
            heard = mlx_whisper.transcribe(str(ROOT / "audio" / f"{key}.wav"),
                                           path_or_hf_repo=MODEL)["text"]
            wer = jiwer.wer(norm(text), norm(heard))
            total_wer += wer
            n += 1
            if wer > FLAG:
                flagged.append((key, wer, text, heard.strip()))
    print(f"mean WER {total_wer / n:.3f} over {n} clips; {len(flagged)} flagged (> {FLAG})")
    for key, wer, text, heard in flagged:
        print(f"\n[{key}] WER {wer:.2f}\n  script: {text}\n  heard:  {heard}")


if __name__ == "__main__":
    main()
