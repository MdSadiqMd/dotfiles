---
name: manim-explainer
description: >-
  Makes narrated 3Blue1Brown-style Manim explainer videos (dark mode, voiceover,
  beginner-friendly) on any topic: math, algorithms, systems, science, papers, code or
  projects, as one video or a multi-episode series, optionally ending in question rounds.
  Use when asked for a "manim video", "explainer video", "3b1b style video", a video
  series, or to explain a topic, paper or codebase as a video. Ships a template: Kokoro
  TTS with cue-synced animations, Whisper QA, render + contact sheets, loudness-mastered
  assembly with an A/V sync check.
---

# Manim Explainer (3b1b style, narrated)

Past videos were rejected for the reasons in the table below. Every rule in this skill exists to prevent one of them,
so follow them from the start:

| Rejection | Prevented by |
|---|---|
| "text overlapping" | contact-sheet review (step 7), fit-to-width helpers |
| "generic animations" | what-if demos on real data; a motion verb in every storyboard row |
| "bad audio" | Kokoro voice, ASR QA, two-pass loudnorm |
| "too complex" | one idea per beat, ≤3 new elements, concrete before abstract |
| "just reading" | labels on screen, reasoning in the voice; never read the screen aloud |
| "audio ahead of the video" | `assemble.py` pads chapter audio and fails on any length mismatch |

Terms used throughout:
- **Episode:** one video in a series.
- **Chapter:** one scene file and one rendered clip.
- **Beat:** one narration line, `with self.beat(key)`.
- **Cue:** one ` | `-separated segment of a beat, `b.cue(i)`.

## Reference files (read when the step says so)

- [reference/planning-and-cinematography.md](reference/planning-and-cinematography.md): learning goals,
  misconceptions, visual vocabulary per kind of topic, the arc, storyboard format, camera, focus, pacing.
  **Read before planning.**
- [reference/clarity-and-flow.md](reference/clarity-and-flow.md): the three-pass review that keeps the video
  understandable. **Run it at steps 4, 7 and 8.**
- [reference/series-code-quizzes.md](reference/series-code-quizzes.md): read when the request is a series,
  explains a codebase/project, or wants question rounds (interview prep, exam practice, quizzes).

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

Layout:
- `research/` (facts tables), `docs/storyboard.md`, `narration.py` (+ `script/epN.py` for a series).
- `scenes/chNN_name.py` (class `ChNN`), `scenes/common.py` (shared look and helpers), optional
  `scenes/kit_<domain>.py`, `tools/`, `assets/data/*.json` + `assets/stills/` (measured or sourced).
- Outputs in `audio/ media/ review/`. The final is `final.mp4`, or `final/epN.mp4` for a series.
- The template's `ch00_intro.py` and its narration are a working sample (a what-if demo on cues).
  Run the pipeline on it once to check the setup, then replace it.

## Workflow

Copy this checklist into your reply and tick it off as you go:

```
- [ ] 1 Research → research/*.md facts tables
- [ ] 2 Plan: goals, misconceptions, visual vocabulary, arc, episode/chapter split
- [ ] 3 Storyboard: shot list per beat
- [ ] 4 Narration + flow review pass 1
- [ ] 5 Voice + ASR QA
- [ ] 6 Scenes
- [ ] 7 Render per chapter + review pass 2 (loop until clean)
- [ ] 8 Preview assembly + review pass 3 (cold watch)
- [ ] 9 Final render + assembly, sync/LUFS verified
```

1. **Research.** Go to primary sources: papers with their appendices, official docs and specs, the code
   itself, textbooks, datasets. Use web search to fill gaps and to find what learners usually get wrong.
   Save the findings to `research/<topic>.md` as a facts table (claim → exact source) *before* planning.
   - Every on-screen number and claim comes from that table.
   - Be honest: show where a method loses, what is an extrapolation, and what is unknown or disputed.
   - For code, measure by running it (see series-code-quizzes.md).
2. **Plan** (planning-and-cinematography.md §1–3):
   - 3–5 learning goals, each with its misconception and prerequisites.
   - Pick the picture for each idea (§2a).
   - Hook puzzle → roadmap → but/therefore chain → payoff.
   - One idea per 1–3 min chapter.
3. **Storyboard** (`docs/storyboard.md`, §4–6): one row per beat covering:
   - the question it answers and the focal object;
   - the motion verb and the cue phrase it lands on;
   - what is left on screen.
   Fix the concept → color mapping and the screen geography here.
4. **Narration as a teacher, not a reader** (`narration.py`):
   - Ask the question before giving the answer: "So what happens to the area? || It quadruples."
   - Give the *why* for every step, with a tiny concrete case first ("1 → 3 → 6, so six times"), then the
     name, then the general rule.
   - Never read on-screen text aloud. The screen shows short labels; the voice explains.
   - Talk to the viewer ("you", "we", "notice that"). Write numbers as words.
   - Put ` | ` (short pause + cue) or ` || ` (long pause + cue) where an animation should land.
   - Then run **clarity-and-flow pass 1**.
5. **Voice:** `.kokoro/bin/python tools/make_voice.py` writes `audio/*.wav`, `durations.json` and
   `cues.json`. Then `.kokoro/bin/python tools/qa_asr.py [prefix]`: mean WER should be < 0.05, and flags
   should only be number formatting. Fix mispronounced words (names, jargon, acronyms) by respelling
   them, re-voice, and re-check.
6. **Scenes.** Subclass `VoiceScene` / `Voice3DScene` / `InterviewScene` from `scenes/common.py`.
   - Wrap each beat in `with self.beat("c1_2") as b:`.
   - Call `b.cue(i)` right before the animation for segment i, and `b.span(i, j, frac)` to fill the time between cues.
   - Between beats, call `self.fade_except(header)`; between chapters, `self.fade_all()`.
   - Alias concept colors at the top of `common.py` (`INPUT = P_TEAL`).
7. **Render + review:** `python3 tools/render.py ch03` renders 480p and writes `review/ch03.png`.
   - **Look at every contact sheet** and run **pass 2**. Fix and re-render until clean.
   - Spot-check single frames with `ffmpeg -ss T -i file -frames:v 1 x.png`.
   - Chapters can render in parallel; each gets its own LaTeX dir.
8. **Preview:** `python3 tools/assemble.py [ep] -q l`, then **pass 3**: watch at 1×, note every timestamp
   where you got lost, fix the root cause, and re-watch.
9. **Final:** `python3 tools/render.py all -q h && python3 tools/assemble.py -q h` gives 1080p60.
   - For long videos or series, use `-q p` (1080p30, half the render time).
   - Assembly does a two-pass loudnorm to −16 LUFS and **fails unless decoded audio length equals video
     length** (±0.15 s).
   - Report the duration, LUFS and the sync line, and grab frames from the last chapter, where drift shows first.

## Visual rules (taken from 3b1b's own source)

- **Background and text:**
  - Pure black background. LaTeX for prose and math (`T()` = Tex, `M()` = MathTex).
  - No title bars, subtitles, decorative boxes or paragraphs on screen.
  - A small chapter header with a `sub()` line per beat is fine for technical topics.
- **Code:** `code()` (Menlo `Text`, no escaping) for identifiers and commands, `code_col()` for multi-line
  code. Show real code and real values.
- **Color:** one color per concept for the whole film or series, from the `P_*` palette. `FOCUS` (yellow)
  only for "look here now"; `POS`/`NEG` for signed quantities.
- **Domain kits:** recurring domain objects (networks, circuits, molecules, trees) live in a small
  `scenes/kit_<domain>.py`, so they look identical everywhere. `kit_nn.py` is the example.
- **Motion:**
  - Transform, don't cut. Dim (`DIM` ≈ 0.18) instead of deleting.
  - Push the camera in for emphasis. Show sensitivity with `wiggle`.
  - Use live `ValueTracker` / `DecimalNumber` readouts and `always_redraw`.
  - Hold 0.5–1 s on every key reveal.
- **What-if demos, not statements:**
  - Drive a parameter to an extreme and watch the result respond.
  - Show a live estimate converging as the voice counts.
  - Run a seeded simulation for anything stochastic.
  - Build timelines and bars (`hbars`) from measured runs.
- **Data:** plot real data from sources or measured JSON, never made-up curves. If an illustration is
  schematic, say so on screen.

## Common mistakes

- **Audio drift.** Manim's audio track ends at the last sound, 1–2 s before the video, and a plain concat
  drops those tails. The voice ran ~10 s ahead after 15 min. `assemble.py` pads each chapter; never
  replace it with a simple concat.
- **Text and layout:**
  - `Write()` on a long Tex looks garbled mid-animation. Use `FadeIn` for sentences and `Write` only for short titles.
  - Overflow: `scale_to_fit_width` anything built from data, and keep x within ±6.9. Text on a filled
    shape must contrast with it (BLACK on bright fills).
  - `Text` drops leading spaces and blank lines, so use `code_col` for code.
- **Numbers:** ratios on screen ("≈20×") come from medians of unrounded runs.
- **Manim pitfalls:**
  - Animating a child of a group registers it on its own. Call `self.drop(group)` before re-adding, or
    you get ghost copies and dead updaters.
  - `ImageMobject` can't go in a `VGroup`; use `Group`.
  - `DecimalNumber.animate.set_value` crashes when the digit count changes. Use `ChangeDecimalToValue`.
- **Environment:**
  - Pillow ≥13 breaks Manim's image canvas. Keep the shim at the top of `common.py`.
  - LaTeX needs `\%`, `\_`, `\&`, `\$`; use `\texttt{}` for inline code.
  - `rng.choice` on a mobject list fails, so pick by index.
  - Brew ffmpeg has no `drawtext`, so contact sheets are unlabeled.
- **Gates:** never render the final until every contact sheet is clean and the ASR QA has passed.
- **Length:** clarity beats brevity. Accepted videos have run 12–32 min. Keep long ones navigable by
  segmenting them (planning §3).
