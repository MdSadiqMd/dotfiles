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

## Pass 2: contact sheets (after each `render.py`)

Look at the frames alone, with no audio.

- [ ] You can tell what the chapter is about from the frames alone.
- [ ] Each frame has one obvious focal point; everything else is dimmed or gone.
- [ ] Nothing overlaps, clips at the edges or sits unreadable on a fill. No frames are empty for more than ~1 s.
- [ ] Labels sit next to their objects. No sentence-length text on screen.
- [ ] Colors and places match the semantics in the storyboard.
- [ ] Each beat shows motion (transform, grow, dim, push in). No static slides.

## Pass 3: cold watch (the assembled `-q l` preview, at 1×, start to finish)

Watch it as the viewer would. Note the timestamp of every moment you'd rewind, get lost, or get bored.

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
