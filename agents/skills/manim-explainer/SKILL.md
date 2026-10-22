---
name: manim-explainer
description: >-
  Make a narrated 3Blue1Brown-style Manim explainer video (dark mode, voiceover,
  beginner-friendly) of a paper, algorithm, repo or concept. Use when asked for a
  "manim video", "explainer video", "3b1b style video", or to explain a paper/code
  as a video. Ships a template: Kokoro TTS with cue-synced animations, Whisper QA,
  render + contact sheets, loudness-mastered assembly.
---

# Manim Explainer (3b1b style, narrated)

Lessons from the Dust video: the first two versions were rejected ("text overlapping",
"generic animations", "bad audio"), the third was "complex", and the fourth "just reading".
The rules below are what fixed each of those. Follow all of them from the start.

## Setup (once per machine, skip what exists)

```bash
P=<project-dir>; cp -r ~/.claude/skills/manim-explainer/template/. $P && cd $P
uv tool install manim                       # Manim CE 0.22; renders via system python3
# LaTeX: TinyTeX at ~/Library/TinyTeX (render.py adds its bin to PATH). If the installer stalls,
# curl the tarball directly with retries and extract it by hand.
uv venv .kokoro --python 3.12
uv pip install -p .kokoro kokoro soundfile mlx-whisper jiwer \
  https://github.com/explosion/spacy-models/releases/download/en_core_web_sm-3.8.0/en_core_web_sm-3.8.0-py3-none-any.whl
```

Project layout: `docs/storyboard.md`, `narration.py` (CHAPTERS, ORDER), `scenes/chNN_name.py`
(class `ChNN`), `tools/`, outputs in `audio/ media/ review/`, final at `final.mp4`.

## Workflow

1. **Understand deeply first.** Read the whole paper/appendix and the code. Build a facts
   table (claim → exact source). Every on-screen number comes from it. Be honest: show
   where the method loses, which results are extrapolations, and what was never released.
2. **Storyboard before code** (`docs/storyboard.md`). Plan it like a cinematographer: what the
   viewer must leave with, one teaching device per idea, fixed color semantics, then a
   shot list per beat saying what moves, where, and on which spoken phrase.
3. **Write the narration as a teacher, not a reader** (`narration.py`):
   - Ask the question before giving the answer: "But what decides how bright each circle gets? || The lines."
   - Give the *why* for every step, and walk through a tiny concrete case ("+1 → +3 → +6, so ×6").
   - Make the viewer feel an idea before naming it: "slope" first, then "a.k.a. derivative";
     analogies like knobs, surprise, a hilly landscape, votes.
   - Never read on-screen text aloud. The screen shows short labels; the voice explains.
   - Write numbers as words. Put ` | ` (short pause + cue) or ` || ` (long pause + cue)
     wherever an animation should land.
4. **Voice:** `.kokoro/bin/python tools/make_voice.py`. This makes `audio/*.wav`,
   `durations.json` and `cues.json` (Kokoro af_heart, speed 0.92, built sentence by sentence
   with longer pauses after questions). Then QA it: `.kokoro/bin/python tools/qa_asr.py`.
   Mean WER should be < 0.05, and flags should only be number formatting. Fix mispronounced
   words by respelling them.
5. **Scenes.** Every scene subclasses `VoiceScene` / `Voice3DScene` from `scenes/common.py`
   and wraps each beat in `with self.beat("c1_2") as b:`. Call `b.cue(i)` right before the
   animation for segment i, and `b.span(i, j, frac)` to fill the time between cues.
6. **Render + review:** `python3 tools/render.py ch03` (480p plus a `review/ch03.png` contact
   sheet). **Look at every contact sheet** and fix overlaps, clipping and empty frames before
   you move on. Spot-check single frames with `ffmpeg -ss T -i file -frames:v 1 x.png`.
7. **Final:** `python3 tools/render.py all -q h && python3 tools/assemble.py -q h`. This
   produces 1080p60 with a two-pass loudnorm to −16 LUFS. Check the duration and LUFS, and
   grab a few frames.

## Visual rules (taken from 3b1b's own source)

- Pure black background. LaTeX everywhere (`T()` = Tex, `M()` = MathTex). No titles bars,
  no subtitles, no decorative boxes, no paragraphs on screen.
- Network: neurons are BLUE-stroked circles filled WHITE by activation; edges are BLUE (+) /
  RED (−) with width ∝ |w|; the forward pass is a YELLOW `ShowPassingFlash`. Use `Net` in common.py.
- One color per concept for the whole film (e.g. TEAL input, ORANGE error, PURPLE noise,
  GREEN backprop).
- Transform, don't cut. Dim (opacity ≈ 0.18) instead of deleting when you refocus. Push the
  camera in for emphasis. Show sensitivity with `wiggle`. Use live `ValueTracker` /
  `DecimalNumber` readouts and `always_redraw`. Hold 0.5–1 s on every key reveal.
- Explain with **what-if demos**, not statements: drive a value to 0 and watch the result go
  to 0; a live estimate converging ("off by 105°" → "off by 2°") as the voice says each count;
  a real simulation for anything stochastic (seeded).
- Real data plotted from the paper's tables, never made-up curves.

## Common mistakes

- Animating a child of a group registers it on its own. Use `self.drop(group)` (it removes
  the whole family) before re-adding the group, or you get ghost copies and dead updaters.
- `DecimalNumber.animate.set_value` crashes when the digit count changes. Use `ChangeDecimalToValue`.
- Pillow ≥13 breaks Manim's image canvas. The shim at the top of `common.py` fixes it, so keep it.
- `MathTex` with `%` needs `\%`. `rng.choice` on a mobject list fails, so pick by index.
- ffmpeg on macOS (brew) has no `drawtext`, so contact sheets are unlabeled.
- Never render the final until every chapter's contact sheet is clean and the ASR QA has passed.
- Length: pauses plus reasoning grew the Dust video from 12 to 17.5 min, and that was accepted.
  Clarity beats brevity.

Worked example (if it still exists): `~/Developer/dust-video` (12 chapters, storyboard, scenes).
