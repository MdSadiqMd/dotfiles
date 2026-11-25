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
| a line, curve, dashed border or bar through a label; a label ruined by something that arrives later | lay out the fullest frame first, `place_label(avoid=…)`; the lint checks outlines after every play |
| numbers spilling out of their cells; text in its own cell's colour | `vector_cells` sizes cells from the numbers; lint checks fit and contrast |
| the dimmed stage showing through a panel | `card` / `panel` / `label_box` are opaque; lint flags ghosts behind labels |
| connectors that stop short of a box, run into it, or stay behind when it moves | `connect(a, b)`; lint checks both ends |
| a warning waved through as "deliberate" that the viewer then reported | a final render refuses to start until the lint is clean; exceptions are `allow(shape, label, why)` |
| "messy", "congested", "no clear spacing" (a title on its first row, labels across a panel border, ragged rows, a panel jammed against the stage) | `card()` / `grid()` / `TC()` build content first and size the box around it; lint checks padding and clearance (animation-craft §3) |
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

## Setup

```bash
P=<project-dir>; cp -r ~/.claude/skills/manim-explainer/template/. $P && cd $P
python3 ~/.claude/skills/manim-explainer/setup.py   # < 0.1 s: nix activation already built the toolchain
```
The toolchain is per machine, not per project, and nothing in it is pinned: `setup.py` keeps Manim, Kokoro,
Whisper and their Python on the newest stable releases (a daily job), swapping a new build in only after a
self-test renders a chapter that uses every template helper and its frames match the last accepted ones. It lives
in `~/.local/share/manim-explainer/` (`render/` venv, `voice/` venv, `versions.json`); LaTeX comes from nix. Never
create a `.kokoro` venv, `pip install` Manim, or install TinyTeX. Run every tool with plain `python3`;
`make_voice.py` and `qa_asr.py` move themselves into the voice venv. For an ad-hoc probe script that needs manim
or numpy, use `~/.local/share/manim-explainer/render/bin/python`. If a tool misbehaves after an upgrade, run
`python3 ~/.claude/skills/manim-explainer/setup.py --check` before debugging your scene.

Layout:
- `research/` (facts tables), `docs/storyboard.md`, `narration.py` (+ `script/epN.py` for a series).
- `scenes/chNN_name.py` (class `ChNN`); `scenes/common.py` (look, beats, helpers); `scenes/lint.py` (layout lint); `scenes/kit_<domain>.py`
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
   left on screen. For each beat also list its **fullest frame**: everything on screen at once at its busiest moment,
   including what arrives at the last cue. That list is what the layout must fit, not the first cue's.
4. **Narration as a teacher, not a reader** (`narration.py`):
   - Ask before answering: "So does Bob learn the slope? || He only sees one point."
   - Concrete case first ("five plus three times seven is twenty six"), then the name, then the rule.
   - Never read on-screen text aloud. Talk to the viewer ("you", "we", "notice"). Numbers as words.
   - ` | ` = short pause + cue, ` || ` = long pause + cue, wherever an animation should land.
   - Run **clarity-and-flow pass 1** (it includes the story-and-continuity checklist).
5. **Voice:** `python3 tools/make_voice.py` → `audio/*.wav`, `durations.json`, `cues.json` (only changed lines are
   re-voiced); then `python3 tools/qa_asr.py [prefix]` (only changed clips are re-transcribed). Mean WER < 0.05 with only number-formatting flags; respell
   mispronounced names and jargon, re-voice, re-check. Foreign names may stay anglicised; say so in the report.
6. **Scenes.** Subclass `VoiceScene` / `Voice3DScene` / `InterviewScene` from `scenes/common.py`.
   - Wrap each beat in `with self.beat("c1_2") as b:`; `b.cue(i)` right before the animation for segment i;
     `b.span(i, j, frac)` fills the time between cues.
   - Build recurring objects from the domain kit; size containers from their contents; lay out box equations
     with `box_row`; roadmap with `roadmap(steps, current)`; side computations in `panel(w, h, title)`.
   - Anything with text in a box (a rule, a table, a log, measurements) is a `card(content, title)`: rows via
     `grid()` (aligned columns) or `VGroup(...).arrange(DOWN, aligned_edge=LEFT)`, coloured lines and numbered
     items via `TC()` (one baseline). Never `move_to` hand-picked coordinates for rows inside a box.
   - Each chapter starts with a `stage.py` builder that recreates where the last chapter ended; the previous
     chapter ends by settling into that state. `fade_all()` only at act boundaries.
   - **Lay out the fullest frame, then reveal it.** Build every object of the beat first, `arrange` them together
     (the caption and the group it captions are one `VGroup(...).arrange(DOWN)`), and only then animate them in, cue by
     cue. A label typed into a gap with `move_to([0, 3.35, 0])` is a guess about things that aren't there yet.
   - A label beside anything another shape will share space with: `place_label(label, target, avoid=[...])`, with the
     later arrivals in `avoid`. It raises when nothing is free: then make room (scale or shift the group; the group
     keeps its brightness), and only if it must sit over a busy field, `backed(label)`.
   - Every line or arrow between two objects: `connect(a, b)`. Never interpolate between centres.
   - The layout lint runs by itself after every `play` and `wait`. Alias concept colours at the top (`SECRET = P_GOLD`).
7. **Render + review pass 2:** first `python3 tools/render.py ch03 ch04 --lint` (or `all`, or `ep1`): it plays the
   chapters to their end states without drawing frames, so it takes seconds (45 chapters of a 69-minute series: 39 s, unchanged ones skipped), and prints every
   problem with its beat, time, how long it stays, and position. Fix until clean, then render.
   `python3 tools/render.py ch03 ch04` renders the chapters side by side at 480p
   and, per chapter, prints its **lint warnings** (with positions) and writes the contact sheet `review/ch03.png`
   and the beat sheet `review/beats_ch03.png` + `.md` (one frame per narration segment beside its words). After
   a fix, the frames that changed are tiled into `review/beats_ch03_changed.png` (the output names them): review
   that, not the whole sheet again; unchanged frames are byte-identical to ones you already checked. Fix until
   lint is clean and every beat frame shows what its sentence says. A warning is a fault until you have looked at that
   second of video at full size; only then, if the overlap *is* the picture (a strike-through, a cursor on a word),
   write `allow(shape, label, why)`. Never reword it as "deliberate" in a report: checked against the frames of
   a finished series, nearly every warning was a visible fault, and the few harmless patterns are built into the lint. For 1080p checks, `render.py ch03 -q p` then `python3 tools/beat_review.py ch03 --hd 05 12`
   (beat-frame numbers from the `.md`), and look at **every card and stage panel at 1080p at its fullest
   moment**: 480p sheets hid all the spacing faults the user later flagged.
   `render.py` skips chapters whose inputs haven't changed, so `render.py all` is cheap; `--force` redoes one.
   Each LaTeX string is compiled once per machine and shared across chapters and projects.
8. **Preview + pass 3:** `python3 tools/assemble.py [ep] -q l` (seconds: the preview skips loudness mastering, the
   final doesn't), then `python3 tools/freeze_report.py` and the beat sheets of all chapters read in order. Fix every frozen stretch with motion that shows its sentence.
9. **Final:** `python3 tools/render.py all -q h && python3 tools/assemble.py -q h` (run it in the background) (1080p60; `-q p` = 1080p30 for
   long films). It lints first and won't start while any chapter has a warning; don't work around it. Assembly does a two-pass loudnorm to −16 LUFS and **fails unless decoded audio length equals video
   length** (±0.15 s). Report the duration, LUFS and the sync line, and show full-resolution frames of the spots
   the user flagged and of the last chapter.

## Working fast

Measured over eleven past videos: about two thirds of the time went to the model thinking and writing, and
rendering was a small part. So:
- Don't read template sources to learn the API: use the index below. Open a kit only to copy one helper
  (`grep -n "def name" -A25 scenes/kit_protocol.py`). Read the reference files once, when the step says so.
- Plan in the storyboard, then write each scene file directly. Don't draft scene code in your thinking and then
  write it again.
- Place things with `arrange`, `next_to`, `place_label`, `card`, `grid`, `box_row`, `connect`, not hand-computed
  coordinates. The lint prints positions, so move what it names, and re-check with `--lint`, not a render.
- Render the chapters you've written in one `render.py` call, read their sheets, and fix everything you found in
  one edit pass before rendering again.
- Every image you read stays in context for the rest of the session: after a fix read `*_changed.png`, and a
  1080p still only for a specific suspect.
- Long commands (final render, assembly) go in the background; never poll with `sleep`.

## Template API (`scenes/common.py`, `from common import *`)

- Scenes: `VoiceScene`, `Voice3DScene`, `InterviewScene` (`intro`, `qa`). `self.beat(key, gap=0.35)` → `b` with
  `b.cue(i)`, `b.span(i, j=None, frac=0.85)`, `b.t(frac)`, `b.left()`. `self.drop(*mobs)`,
  `self.fade_except(*keep)`, `self.fade_all()`.
- Text: `T(s, size=36, color)` Tex; `M(s, size=40, color)` MathTex; `MC(*parts, size=44, colors={i: c})` with
  `SYM` symbol colours; `TC((text, color), ...)` one line in several colours; `code(s, size=26)`,
  `code_col(lines, size=20)` monospace.
- Containers: `card(content, title=None, pad=0.32, gap=0.26, center)` sized from contents (`.box`, `.content`,
  `.title`); `grid(rows, col_align="lcr", h_buff, v_buff)`; `panel(w, h, title, center)` for areas filled over time;
  `label_box(text, w, h, color)`; `box_row(items, y, x=0, buff=0.3)`; `roadmap(steps, current)`. All are opaque
  (`tint(color, amount)` is the fill), so what is behind them never shows through.
- Layout: `place_label(label, target, avoid, sides=(UP, DOWN, RIGHT, LEFT), buff)`; `connect(a, b, color, arrow=False,
  cls=None)` (edge to edge, follows moves); `backed(label)` (opaque plate); `allow(shape, label, why)` (lint exception).
- Data: `cell_grid(values)`, `vector_cells(values, color, decimals, text_color)` (recolour by rebuilding), `hbars(rows, vmax)` → (group, [(bar, text)]),
  `still(name, height, width)` (ImageMobject), `countdown(scene, seconds)`.
- Palette: `P_BLUE P_RED P_TEAL P_ORANGE P_PURPLE P_GREEN P_GOLD`, `FOCUS`, `POS`/`NEG`, `DIM`, `SOFT`.
- `kit_protocol.py`: `Avatar(name, color, kind)` + `.look(target)`, `seat(avatar, side)`, `LockBox(content)` +
  `.opened()`, `lock_drop`, `die`, `roll_die`, `chip`, `answer_card`, `R_box`, `ticket`, `check_lamp`,
  `notes_box(items)`, `Table(rows)` + `.cell/.slot/.check_at/.slot_box`, `send(scene, mob, target, arc)`,
  `ripple`, `Blender` + `swallow`, `program_window`, `key_icon`, `message_card`, `branch`, `fork_paths`,
  `rewind_glyph`, `strike`, `AnswerPlot` + `plot_point`, `PivotLine`.
- `kit_nn.py`: `Net(sizes)` + `.flash/.activate/.forward_sweep/.color_edges`, `nudge_arrow(anchor, value)`.

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
- **Text:** `Write` only short titles; escape LaTeX specials; `code_col` for code. `code()` is scaled so its size
  matches `T()` at the same number (raw Menlo `Text` is 1.7x bigger); in kit code, never call `Text(font="Menlo")`
  directly. At most two sizes inside one card (title + body).
- **Gates:** no final render until lint (enforced by `render.py`), beat sheets and ASR QA are clean. Read every
  chapter's beat sheet: the worst frame of one series was in the one chapter whose sheet nobody opened.
- **`lint_skip`** only silences shape-on-shape checks. Nothing about a label can be skipped, only `allow`ed.
- **Length:** clarity beats brevity (accepted films ran 9–32 min); segment long ones (planning §3).

Worked examples (if they still exist): `~/Developer/dust-video` (12 chapters, ML paper) and
`~/.t3/scratch/2026-10-30-here-is-the-thread-regarding-a1de122b` (forking lemma: research notes, storyboard,
`stage.py`, v1–v6 history in `v*/`).
