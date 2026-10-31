# Clarity and flow review

A feedback loop that runs three times: on the script, on the contact sheets, and on the assembled
preview. Fix what it finds and run it again. Move on only when every item passes.

## Pass 1: script (after `narration.py`, before voicing)

Read the narration alone, with no visuals.

- [ ] It reads as an argument a friend could follow by ear, and every term is explained before it is used.
- [ ] Each video and chapter opens on a concrete question or puzzle, not a definition or an agenda.
- [ ] Between consecutive beats, "but" or "therefore" fits. Fix every "and then".
- [ ] Every abstract idea comes after a tiny worked example with real numbers.
- [ ] Each learning goal has a misconception beat: the wrong idea is tried and fails.
- [ ] The tone is conversational ("you", "we", "notice that"). No formal lecture voice and no reading of labels.
- [ ] Questions are followed by ` || ` before the answer, and long sentences are split.
- [ ] Every number matches the facts table.
- [ ] The story-and-continuity.md §7 checklist passes (premise first, ≤ 3 ideas, one stage, plants and payoffs).

## Pass 2: frames (after each `render.py`)

Three checks, in this order:
1. **Layout lint.** `render.py` prints the chapter's lint warnings (from `review/lint/`). Fix each one or confirm
   it is a deliberate overlap.
2. **Contact sheet** `review/chNN.png`: the frames alone, with no audio (the checklist below).
3. **Beat sheet** `python3 tools/beat_review.py chNN`: one frame per narration segment next to its words
   (`review/beats_chNN.png` + `.md`). For every segment ask: does this frame show what this sentence says, is the
   newest thing the thing being named, and is anything misfitted (overflowing, half-covered, cut off, ghosted)?
   Check suspicious spots at full resolution: `ffmpeg -ss T -i media/videos/<ch>/1080p60/ChNN.mp4 -frames:v 1 x.png`.

- [ ] You can tell what the chapter is about from the frames alone.
- [ ] Each frame has one obvious focal point; everything else is dimmed or gone.
- [ ] Nothing overlaps, clips at the edges or sits unreadable on a fill. No frames are empty for more than ~1 s.
- [ ] Labels sit next to their objects. No sentence-length text on screen.
- [ ] Colors and places match the semantics in the storyboard.
- [ ] Each beat shows motion (transform, grow, dim, push in). No static slides.
- [ ] Every token fits its slot or box with padding; nothing pokes out, overflows a card, or covers a label.
- [ ] No glow, no stray copies left behind after a move, nothing within 0.3 of the frame edge.

## Pass 3: cold watch (the assembled `-q l` preview, at 1×, start to finish)

Watch it as the viewer would. Note the timestamp of every moment you'd rewind, get lost, or get bored.

An agent can't watch at 1×. Its substitute, all three required:
- beat sheets for every chapter (pass 2, step 3), read in order as one story;
- `python3 tools/freeze_report.py` on the assembled preview: every stretch ≥ 4.5 s where the picture sits still
  while the voice talks, mapped to its sentence (fix with motion that shows that sentence, then re-check);
- the sync line from `assemble.py`.
Then say plainly in the report that the film was reviewed through frames, and ask the user for timestamps.

- [ ] Each animation lands on the word that names it, with no drift (`assemble.py` prints its sync check).
- [ ] After each reveal there is a moment to absorb it before the voice moves on.
- [ ] The roadmap visual returns between parts, so you always know where you are.
- [ ] The ending returns to the hook and resolves it.
- [ ] Each noted timestamp is fixed at its root (script, storyboard or scene), and you re-watch that chapter.

The common causes of "confusing", and their fixes:

| Symptom | Fix |
|---|---|
| a term lands with no meaning | pre-train it: show the part and its name before the process uses it |
| "just reading" | cut the on-screen sentence and leave a label; the voice explains *why* |
| "generic animations" | replace the fade-in of a box with a what-if demo on real data |
| lost in a long part | bring back the roadmap chain; add a one-line recap |
| too complex | split the beat; one new idea per beat, ≤3 new elements |
| looks right but feels flat | the beats are joined by "and then"; reorder into but/therefore |
| good start, falls apart after 3–4 min | each chapter starts on a fresh screen with new icons; keep one stage and swap the players (story-and-continuity §3) |
| "animations are basic" | motions don't carry the argument; give every motion a sentence (animation-craft §2) |
| "things don't fit / overlap / cut off" | size containers from contents, align on bodies, run the lint (animation-craft §3) |
