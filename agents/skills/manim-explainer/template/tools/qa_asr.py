"""Transcribe every narration clip with Whisper and diff it against the script.

Flags beats whose word error rate exceeds a threshold, which catches
mispronounced terms, dropped words, and garbled numbers.
Run: python3 tools/qa_asr.py [key prefixes, e.g. e5 e6]
Transcripts are cached by audio hash in audio/asr.json, so a re-check after re-voicing one line only transcribes
that line; when nothing changed it runs on plain python3 and loads no model at all.
"""
import hashlib
import json
import re
import sys
from pathlib import Path

from env import hf_offline, voice_python

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from narration import CHAPTERS  # noqa: E402

MODEL = "mlx-community/whisper-large-v3-turbo"
FLAG = 0.08
CACHE = ROOT / "audio" / "asr.json"


def transcriber():
    # Only now (a clip needs transcribing) move into the voice venv. Restarting the script there is safe: nothing
    # has been written yet.
    hf_offline(MODEL)  # before any import: huggingface_hub reads HF_HUB_OFFLINE once, at import time
    voice_python("mlx_whisper" if sys.platform == "darwin" else "faster_whisper")
    try:
        import mlx_whisper
        return lambda wav: mlx_whisper.transcribe(str(wav), path_or_hf_repo=MODEL)["text"]
    except ImportError:
        # ponytail: Linux has no MLX; faster-whisper's turbo checkpoint is the CPU stand-in (same model family).
        from faster_whisper import WhisperModel
        model = WhisperModel("large-v3-turbo", compute_type="int8")
        return lambda wav: " ".join(s.text for s in model.transcribe(str(wav))[0])


def norm(s):
    s = s.lower().replace("-", " ").replace("’", "'")
    s = re.sub(r"[^a-z0-9' ]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def wer(ref, hyp):
    """Word error rate: word-level edit distance (substitutions + deletions + insertions) over the reference
    length. Equal to jiwer.wer on every pair tried (3,050), without the dependency or its API changes."""
    r, h = ref.split(), hyp.split()
    prev = list(range(len(h) + 1))
    for i, rw in enumerate(r, 1):
        cur = [i]
        for j, hw in enumerate(h, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (rw != hw)))
        prev = cur
    return prev[-1] / max(len(r), 1)


def main():
    prefixes = tuple(sys.argv[1:]) or ("",)
    cache = json.loads(CACHE.read_text()) if CACHE.exists() else {}
    listen = None
    flagged, total_wer, n, fresh = [], 0.0, 0, 0
    for beats in CHAPTERS.values():
        for key, text in beats:
            if not key.startswith(prefixes):
                continue
            wav = ROOT / "audio" / f"{key}.wav"
            sig = hashlib.sha1(wav.read_bytes()).hexdigest()
            if cache.get(key, {}).get("sig") != sig:
                listen = listen or transcriber()
                cache[key] = {"sig": sig, "heard": listen(wav)}
                fresh += 1
            heard = cache[key]["heard"]
            w = wer(norm(text), norm(heard))
            total_wer += w
            n += 1
            if w > FLAG:
                flagged.append((key, w, text, heard.strip()))
    CACHE.write_text(json.dumps(cache, indent=1))
    print(f"mean WER {total_wer / n:.3f} over {n} clips ({fresh} newly transcribed); {len(flagged)} flagged (> {FLAG})")
    for key, w, text, heard in flagged:
        print(f"\n[{key}] WER {w:.2f}\n  script: {text}\n  heard:  {heard}")


if __name__ == "__main__":
    main()
