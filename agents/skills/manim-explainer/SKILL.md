---
name: manim-explainer
description: >-
  Makes narrated 3Blue1Brown-style Manim explainer videos (dark mode, voiceover, beginner-friendly) on any topic:
  math, algorithms, systems, science, cryptography, papers, code or projects, as one video or a multi-episode
  series, optionally ending in question rounds. Use when asked for a "manim video", "explainer video", "3b1b style
  video", a video series, or to explain a topic, paper, thread or codebase as a video, and when iterating on such a
  video from feedback. Ships a template: Kokoro TTS with cue-synced animations, Whisper QA, a layout lint, per-beat
  review sheets, a frozen-frame report, domain kits, and loudness-mastered assembly with an A/V sync check.
---

# Manim Explainer (3b1b style, narrated)

Past videos were rejected for the reasons below. Every rule in this skill prevents one of them, so follow them
from the start:

| Rejection | Prevented by |
|---|---|
| "text overlapping", "objects not fitted", "cut off at the top" | containers sized from contents, `box_row`, safe area, **layout lint** (step 7) |
| "generic / basic animations" (4/10) | every motion says a sentence; physical props; what-if demos (animation-craft.md) |
| "explanation 5/10", jargon, no thread | premise first, ≤ 3 ideas, one running picture and example (story-and-continuity.md) |
| "good start, falls apart after 3–4 minutes" | one persistent stage, swap the players, chapters continue (story-and-continuity §3) |
| "too complex" / "just reading" | one idea per beat, ≤ 3 new elements; labels on screen, reasoning in the voice |
| "the glow sucks" | no glow ever; state changes are colour, `Circumscribe`, a label, an opened lock |
| "worst of all" after copying a reference image | a reference shows qualities to reach, not a style to copy; keep the theme |
| "bad audio" / "audio ahead of the video" | Kokoro + ASR QA + two-pass loudnorm; `assemble.py` pads and checks sync |

Terms: **episode** = one video of a series; **chapter** = one scene file and clip; **beat** = one narration line
(`with self.beat(key)`); **cue** = one ` | `-separated segment of a beat (`b.cue(i)`); **stage** = the persistent
scene the story plays on.

## Reference files (read when the step says so)

- [reference/story-and-continuity.md](reference/story-and-continuity.md): premise, few ideas, one running
  picture, one stage, plants and payoffs, misconceptions, content correctness. **Read before planning.**
- [reference/planning-and-cinematography.md](reference/planning-and-cinematography.md): learning goals,
  visual vocabulary per topic kind, arc, storyboard format, camera, focus, pacing. **Read before planning.**
- [reference/animation-craft.md](reference/animation-craft.md): motion grammar, precision rules, component
  recipes, what viewers liked. **Read before writing scenes.**
- [reference/clarity-and-flow.md](reference/clarity-and-flow.md): the three review passes. **Run at steps 4, 7, 8.**
- [reference/manim-pitfalls.md](reference/manim-pitfalls.md): opacity/fill, groups, paths, text, parallel
  rendering. **Read before writing scenes; check when something renders wrong.**
- [reference/series-code-quizzes.md](reference/series-code-quizzes.md): series, codebases, question rounds.

## Setup (once per machine, skip what exists)

```bash
P=<project-dir>; cp -r ~/.claude/skills/manim-explainer/template/. $P && cd $P
uv tool install manim                       # Manim CE 0.22; render.py calls the `manim` CLI
# LaTeX: TinyTeX at ~/Library/TinyTeX (render.py adds its bin to PATH). If the installer stalls,
# curl the tarball directly with retries and extract it by hand.
uv venv .kokoro --python 3.12
uv pip install -p .kokoro kokoro soundfile mlx-whisper jiwer \
  https://github.com/explosion/spacy-models/releases/download/en_core_web_sm-3.8.0/en_core_web_sm-3.8.0-py3-none-any.whl
```
Use `.kokoro/bin/python` for any helper script that needs numpy (system python3 has none).

Layout:
- `research/` (facts tables), `docs/storyboard.md`, `narration.py` (+ `script/epN.py` for a series).
- `scenes/chNN_name.py` (class `ChNN`); `scenes/common.py` (look, beats, lint, helpers); `scenes/kit_<domain>.py`
  (recurring objects: `kit_nn.py` networks, `kit_protocol.py` parties/locks/table/dice/hash/fork);
  `scenes/stage.py` (your builders that recreate the stage state each chapter starts from).
- `tools/`: `make_voice.py`, `qa_asr.py`, `render.py`, `beat_review.py`, `freeze_report.py`, `assemble.py`.
- `assets/data/*.json`, `assets/stills/` (measured or sourced). Outputs in `audio/ media/ review/`; final at
  `final.mp4` (or `final/epN.mp4`). Keep earlier cuts in `v1/ v2/ …` (final + scenes + narration) when iterating.
- The template's `ch00_intro.py` is a working sample. Run the pipeline on it once, then replace it.

## Workflow

Copy this checklist into your reply and tick it off as you go:

```
- [ ] 1 Research → research/*.md facts table; source claims verified, corrections noted
- [ ] 2 Plan: situation/question/goal, ≤3 ideas, running picture + example, the stage, arc
- [ ] 3 Storyboard: stage geography, shot list per beat (motion = a sentence)
- [ ] 4 Narration + flow review pass 1
- [ ] 5 Voice + ASR QA
- [ ] 6 Scenes (kit + stage builders)
- [ ] 7 Render per chapter + review pass 2: lint, contact sheet, beat sheet (loop until clean)
- [ ] 8 Preview assembly + review pass 3: beat sheets in order, freeze report, sync
- [ ] 9 Final render + assembly, sync/LUFS verified, frames checked
```

1. **Research.** Primary sources first: papers with appendices, official docs and specs, the code, textbooks,
   datasets (save PDFs and extract with `uvx --from pypdf`). Web search fills gaps and finds what learners get
   wrong. When the user asks for deep research, use the deep-research skill (pedagogy for this kind of topic,
   the topic's best teaching order, a verified facts table).
   - Save `research/<topic>.md` as a facts table (claim → exact source) *before* planning; every on-screen
     number comes from it.
   - **Verify the source material too** (a thread, an article): misattributions and overstatements are common.
     Tell the user what you corrected.
   - Be honest: show where a method loses, what is extrapolated, what is unknown. For code, measure by running it.
2. **Plan** (story-and-continuity.md, planning §1–3): the situation → question → goal of the first minute and
   a numbered roadmap; at most three core ideas (one per act); one running picture and one running example with
   small real numbers; the misconception and the obvious objection for each act; the stage and who sits where in
   each act; plants and payoffs; a cut list.
3. **Storyboard** (`docs/storyboard.md`): fix the stage geography and the concept → colour map, then one row per
   beat: question it answers, focal object, motion and the sentence it says, the cue phrase it lands on, what is
   left on screen.
4. **Narration as a teacher, not a reader** (`narration.py`):
   - Ask before answering: "So does Bob learn the slope? || He only sees one point."
   - Concrete case first ("five plus three times seven is twenty six"), then the name, then the rule.
   - Never read on-screen text aloud. Talk to the viewer ("you", "we", "notice"). Numbers as words.
   - ` | ` = short pause + cue, ` || ` = long pause + cue, wherever an animation should land.
   - Run **clarity-and-flow pass 1** (it includes the story-and-continuity checklist).
5. **Voice:** `.kokoro/bin/python tools/make_voice.py` → `audio/*.wav`, `durations.json`, `cues.json`; then
   `.kokoro/bin/python tools/qa_asr.py [prefix]`. Mean WER < 0.05 with only number-formatting flags; respell
   mispronounced names and jargon, re-voice, re-check. Foreign names may stay anglicised; say so in the report.
6. **Scenes.** Subclass `VoiceScene` / `Voice3DScene` / `InterviewScene` from `scenes/common.py`.
   - Wrap each beat in `with self.beat("c1_2") as b:`; `b.cue(i)` right before the animation for segment i;
     `b.span(i, j, frac)` fills the time between cues.
   - Build recurring objects from the domain kit; size containers from their contents; lay out box equations
     with `box_row`; roadmap with `roadmap(steps, current)`; side computations in `panel(w, h, title)`.
   - Each chapter starts with a `stage.py` builder that recreates where the last chapter ended; the previous
     chapter ends by settling into that state. `fade_all()` only at act boundaries.
   - The layout lint runs by itself at every cue and beat end. Alias concept colours at the top (`SECRET = P_GOLD`).
7. **Render + review pass 2:** `python3 tools/render.py ch03` (480p) prints the chapter's **lint warnings** and
   writes `review/ch03.png`. Then `python3 tools/beat_review.py ch03`: one frame per narration segment beside
   its words. Fix until lint is clean (or every remaining warning is a deliberate overlap) and every beat frame
   shows what its sentence says. Check suspect frames at 1080p with `ffmpeg -ss T -i … -frames:v 1 x.png`.
   Chapters can render in parallel (`xargs -P 4`); each has its own Tex and Text cache.
8. **Preview + pass 3:** `python3 tools/assemble.py [ep] -q l`, then `python3 tools/freeze_report.py` and the
   beat sheets of all chapters read in order. Fix every frozen stretch with motion that shows its sentence.
9. **Final:** `python3 tools/render.py all -q h && python3 tools/assemble.py -q h` (1080p60; `-q p` = 1080p30 for
   long films). Assembly does a two-pass loudnorm to −16 LUFS and **fails unless decoded audio length equals video
   length** (±0.15 s). Report the duration, LUFS and the sync line, and show full-resolution frames of the spots
   the user flagged and of the last chapter.

## Iterating on feedback

- Fix exactly what was flagged, at the root (the shared helper, not one call site), and **keep what the user
  liked**. Ask yourself what else shares the flagged flaw and fix those too.
- Never change the theme, palette or typography unless asked. A reference image shows a quality (precision,
  fit, alignment); reach that quality in the existing look. If you are unsure which is meant, ask.
- Archive each cut (`v1/ …`) before rebuilding, so a regression can be compared and rolled back.
- Report honestly: what changed per flagged point, what the lint still flags and why it's intended, and that an
  agent reviews through frames, not at 1×. Ask for timestamps of anything still off.

## Visual rules (3b1b look)

- **Background and text:** pure black; LaTeX for prose and maths (`T()` = Tex, `M()` = MathTex, `MC()` for
  coloured parts). No title bars, subtitles, decorative boxes, paragraphs or section titles ("THE TABLE").
  Numbered lists use "1." "2." "3.".
- **Colour:** one colour per concept for the whole film or series from the `P_*` palette; `FOCUS` yellow only for
  "look here now"; `POS`/`NEG` for signs.
- **Characters and props:** characters with eyes that follow the action; one physical prop per abstract concept
  (padlock box = sealed/one-way, dice = random, blender = hash, program window = code we control).
- **Motion:** every motion says a sentence (animation-craft.md §2). Transform, don't cut; `TransformFromCopy`
  shows where each value comes from. Dim with `fade` + `Restore`. Live `ValueTracker` readouts. Hold 0.5–1 s on
  each reveal. One thing moves at a time unless comparing.
- **Never:** glow (stacked strokes), decorative camera drift, a `FadeIn`-only beat, stacked ghost copies,
  anything within 0.3 of the frame edge, text or tokens overflowing their container.
- **What-if demos, not statements:** drive a parameter to an extreme; a live estimate converging; a seeded
  simulation for anything stochastic; timelines and bars from measured runs.
- **Data:** real data from sources or measured JSON; label schematic illustrations as schematic.

## Common mistakes (details in manim-pitfalls.md)

- **Audio drift:** Manim's audio ends at the last sound; `assemble.py` pads each chapter. Never plain-concat.
- **`set_opacity` fills outline shapes**, and `FadeOut` restores opacity so a later animation resurrects the
  part. Use `fade` / `save_state` / `Restore`; remove parts that should stay gone.
- **Paths:** build with `fill_opacity=0`; drop duplicate points before `MoveAlongPath`.
- **Groups:** `self.drop(group)` before re-adding; filter `isinstance(m, VMobject)` before `VGroup(*self.mobjects)`.
- **Text:** `Write` only short titles; escape LaTeX specials; `code_col` for code.
- **Gates:** no final render until lint, beat sheets and ASR QA are clean.
- **Length:** clarity beats brevity (accepted films ran 9–32 min); segment long ones (planning §3).

Worked examples (if they still exist): `~/Developer/dust-video` (12 chapters, ML paper) and
`~/.t3/scratch/2026-10-30-here-is-the-thread-regarding-a1de122b` (forking lemma: research notes, storyboard,
`stage.py`, v1–v6 history in `v*/`).
