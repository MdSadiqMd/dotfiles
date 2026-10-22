"""Render every narration beat with Kokoro (voice af_heart) into audio/<key>.wav.

Run with the Kokoro venv:  .kokoro/bin/python tools/make_voice.py

Delivery is built sentence by sentence with deliberate pauses (longer after questions),
so it sounds explained rather than read. Narration text may contain cue markers:
  " | "   short pause, and a new cue (an animation can land exactly here)
  " || "  long pause (a beat to think), and a new cue
Outputs: durations.json (key -> seconds) and cues.json (key -> cue start times).
Clips are cached by text hash.
"""
import hashlib
import json
import re
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from narration import CHAPTERS  # noqa: E402

AUDIO = ROOT / "audio"
VOICE = "af_heart"
SPEED = 0.92
SR = 24000
TARGET_RMS = 0.075  # matched loudness across clips; final master does LUFS
CUE_PAUSE = {"|": 0.45, "||": 0.95}
SENTENCE_PAUSE = {".": 0.32, "?": 0.6, "!": 0.4, ":": 0.25}
VERSION = "v2-sentences"


def trim(audio, thresh=0.01, keep=0.04):
    """Drop leading/trailing near-silence, keeping a short natural tail."""
    loud = np.where(np.abs(audio) > thresh)[0]
    if len(loud) == 0:
        return audio
    pad = int(keep * SR)
    return audio[max(0, loud[0] - pad): min(len(audio), loud[-1] + pad)]


def silence(sec):
    return np.zeros(int(sec * SR), dtype=np.float32)


def segments(text):
    """Split on cue markers -> [(pause_before, segment_text)]."""
    parts = re.split(r"\s*(\|\|?)\s*", text.strip())
    out = [(0.0, parts[0])]
    for marker, seg in zip(parts[1::2], parts[2::2]):
        out.append((CUE_PAUSE[marker], seg))
    return out


def sentences(seg):
    return [s for s in re.split(r"(?<=[.?!:])\s+", seg.strip()) if s]


def speak(pipe, sentence):
    chunks = [a.numpy() if hasattr(a, "numpy") else a for _, _, a in pipe(sentence, voice=VOICE, speed=SPEED)]
    return trim(np.concatenate(chunks))


def build(pipe, text):
    """Returns (audio, cue start times in seconds)."""
    pieces, cues, t = [], [], 0.0
    for pause, seg in segments(text):
        if pieces:
            pieces.append(silence(pause))
            t += pause
        cues.append(round(t, 3))
        sents = sentences(seg)
        for i, s in enumerate(sents):
            audio = speak(pipe, s)
            pieces.append(audio)
            t += len(audio) / SR
            if i < len(sents) - 1:
                gap = SENTENCE_PAUSE.get(s[-1], 0.25)
                pieces.append(silence(gap))
                t += gap
    audio = np.concatenate(pieces)
    rms = np.sqrt(np.mean(audio[np.abs(audio) > 0.005] ** 2)) + 1e-9
    audio = audio * (TARGET_RMS / rms)
    peak = np.max(np.abs(audio))
    if peak > 0.97:
        audio *= 0.97 / peak
    fade = int(0.012 * SR)
    audio[:fade] *= np.linspace(0, 1, fade)
    audio[-fade:] *= np.linspace(1, 0, fade)
    return audio.astype(np.float32), cues


def main():
    AUDIO.mkdir(exist_ok=True)
    cache_file = AUDIO / "cache.json"
    cache = json.loads(cache_file.read_text()) if cache_file.exists() else {}
    cues_file = ROOT / "cues.json"
    all_cues = json.loads(cues_file.read_text()) if cues_file.exists() else {}
    pipe = None
    durations = {}
    for beats in CHAPTERS.values():
        for key, text in beats:
            out = AUDIO / f"{key}.wav"
            sig = hashlib.sha1(f"{VERSION}|{VOICE}|{SPEED}|{text}".encode()).hexdigest()
            if not (out.exists() and cache.get(key) == sig and key in all_cues):
                if pipe is None:
                    from kokoro import KPipeline
                    pipe = KPipeline(lang_code="a", repo_id="hexgrad/Kokoro-82M")
                audio, cues = build(pipe, text)
                sf.write(out, audio, SR)
                cache[key] = sig
                all_cues[key] = cues
                print(f"  generated {key} ({len(cues)} cues)")
            durations[key] = round(sf.info(out).duration, 3)
    keys = set(durations)
    all_cues = {k: v for k, v in all_cues.items() if k in keys}
    cache_file.write_text(json.dumps(cache, indent=1))
    cues_file.write_text(json.dumps(all_cues, indent=1))
    (ROOT / "durations.json").write_text(json.dumps(durations, indent=1))
    total = sum(durations.values())
    print(f"{len(durations)} beats, {total:.1f}s of speech ({total / 60:.1f} min)")


if __name__ == "__main__":
    main()
