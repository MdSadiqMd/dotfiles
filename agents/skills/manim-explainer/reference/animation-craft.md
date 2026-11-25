# Animation craft

Read before writing scenes. Lessons from the forking-lemma film: v3's animations were rated 4/10 ("minimal,
basic, no effort"), v5 was rated the worst of all after copying a reference image's style, and v6 (v4's look
plus precision fixes) was accepted as "great".

## Contents
- 1. The two failure modes
- 2. Every motion says a sentence
- 3. Precision: fit, align, stay in frame
- 4. Component recipes (scenes/kit_protocol.py)
- 5. State changes without glow
- 6. Timing
- 7. What the viewer liked

## 1. The two failure modes

- **Basic.** Everything enters with `FadeIn`, emphasis is `Indicate` / `Flash`, arrows just appear between boxes.
  Nothing on screen carries the argument, so the film looks like slides with transitions.
- **Imprecise.** Text spilling out of its card, a pill poking past its box, a box covering a label, a ghost copy
  overlapping the real token, a timeline cut off at the top edge, a stacked-stroke "glow". The user notices
  every one of these and reads them as carelessness, even when the story is good. **When the basics are wrong,
  a fancier look makes the film worse.**

**Reference images are for understanding, not for copying.** In v5 the user shared a polished dark
architecture diagram to show the *precision* they expected (everything fits, aligned, nothing overflows). The
agent replaced the whole look with that diagram's style (charcoal background, Inter/JetBrains fonts, pills,
cards) and the user rated it the worst version. Keep the film's established theme (black, 3b1b palette,
LaTeX, characters, the props the user liked) unless the user explicitly asks for a new look; take the
*qualities* from a reference (fit, alignment, consistency), not its skin. If unsure, ask.

## 2. Every motion says a sentence

Grant Sanderson: "Every movement on the screen should be deliberate, with an identifiable purpose." Before
adding a motion, write the sentence it says. If the answer is "it looks nice", cut it.

| Motion | What it says |
|---|---|
| a token pulls back, flies on an arc with a fading trail, settles with a slight overshoot (`send`) | a message was sent |
| a die tumbles along an arc, lands with a bounce, turns into a chip (`roll_die`) | a random challenge, chosen now |
| a number drops into an open padlock box, the shackle snaps shut (`lock_drop`) | the value is sealed / committed |
| eyes turn toward a token (`Avatar.look`) | who is paying attention to what |
| inputs spiral into the blender while its blades spin (`swallow`) | hashing |
| copies of a table value fly to an axis, guides grow, the point lands with a ripple (`plot_point`) | this answer becomes a point |
| a line pivots through one point with a live readout (`PivotLine`) | one point leaves the slope free |
| the line snaps onto two points, the slope flies into the public box, the shackle lifts (`opened`) | two answers reveal the secret |
| every move plays backwards along its own path, the first run dims to a "kept copy" | rewinding the program |
| a timeline trunk splits into two branches (`fork_paths`) | the fork: one past, two futures |
| strips grow across a square, off-diagonal cells dim | a probability as an area |
| a character walks off and another takes the seat | the role is replaced, the game stays |

Use `TransformFromCopy` when a value is *used* somewhere else (the 5 in Alice's notes becomes the 5 in the
sum), so the viewer sees where every number comes from.

## 3. Precision: fit, align, stay in frame

- **Size containers from their contents, never the reverse.** Table slots are sized from the largest token
  (the padlock box *with* its shackle) plus padding, and every token is centred on its slot (`Table.cell(r, c)`).
  A note pill gets a box that is measured around it (`notes_box`), never a fixed-size card.
- **Boxes with text are built content-first.** Rejected frames (Bluetooth film): a panel title sitting on its
  first row, socket labels straddling a panel's bottom border, a rule card whose numbers floated far from their
  lines with uneven row gaps, and that card jammed into the gap between the chapter tag and the stage. All of
  them came from one habit: a fixed `panel(w, h)` and every row `move_to`'d to a hand-typed coordinate. Do this
  instead:
  - `card(content, title)`: the box is measured around title + content with `pad` 0.32 and `gap` 0.26.
  - Rows: `grid([[label, value, ...], ...], col_align="ll…")` for anything with columns (built on
    `arrange_in_grid`), else `VGroup(rows).arrange(DOWN, buff=0.22, aligned_edge=LEFT)`. Equal row gaps, always.
  - One line in several colours, or a numbered item: one `TC((r"1.\quad ", FOCUS), ("text ", GREY_A),
    ("word", CALL))`. Separate `T()` pieces arranged with `aligned_edge=DOWN` put a word with a descender
    ("output") above its neighbours; a separate number mobject sits off the text's baseline.
  - A number and its unit are one string (`code("0.18 s")`), never a big number with a tiny unit beside it.
  - Labels belong to their container: a socket's label goes *inside* the box, and the box is sized to hold it.
  - Leave the stage alone: a card goes where it has ≥ 0.15 clearance from every stage object (the lint flags
    < 0.1). If the idea area is too small for the card, dim or move the stage, or split the card over two beats;
    never shrink the gap.
  - Type: at most two sizes per card (title 24, body 20). `code()` and `T()` at the same number now match.
- **Align on the meaningful part.** A padlock box's centre is its body, not its bounding box (the shackle sits on
  top). Lay out equations of boxes with `box_row`, which aligns on `.body`.
- **Safe area.** Keep everything, labels included, inside x ±6.9 and y ±3.7. Anything placed near the top edge
  (a timeline with labels above its upper branch) gets clipped: put it in the idea area instead.
- **No unnecessary chrome.** No section titles like "THE TABLE"; the column headers are enough. A small grey
  title is fine for a work panel that appears and leaves ("Bob checks").
- **Two runs are two rows, never stacked ghosts.** v4 shrank run-1 tokens into slot corners when run 2 arrived
  (overlapping ghosts). v6 gives each run its own table row and wraps the shared column with one outline.
- **Lay out for the fullest moment.** Rejected frames (Thine series), all from placing each object when its cue came,
  by hand-typed coordinates, against whatever was on screen *then*:
  - a region label sat clear of its own dashed box, then a second, larger dashed box arrived and cut through it;
  - a sentence was placed at the top of the frame, where a 300-box grid already reached: the gap never existed;
  - a label went above a token that then moved beside a bar, so the bar covered its middle;
  - a label was set at the top right of a panel where the curve's tallest peaks were.
  Build all of it first, arrange it, reveal it in order. Two overlapping regions: labels on opposite sides, or flush
  with the end that is not shared (`place_label` finds it).
- **No room? Make room.** Shrink or shift the group a little, at full brightness, and give the label its own band.
  Don't dim what the viewer is meant to see. `backed(label)` is the last resort.
- **What is dimmed is still there.** A stage faded to 10–18% reads clearly behind a transparent panel or a thin label.
  Dim what sits *beside* the new content; fade out (`FadeOut`, or `fade(0.96)`) what sits *behind* it. Hand-built
  panels with a 0.35 fill let it through; `card`/`panel`/`label_box` don't.
- **Connectors belong to what they connect.** `connect(a, b)`. A label about the link sits on the side of the box
  away from the line.
- **Run the layout lint** (`scenes/lint.py`; no code in scenes; `render.py … --lint` for lint alone). After every
  `play` and `wait` it checks what is drawn and reports what stays ≥ 0.5 s:
  - an **outline through a label**: any stroke or fill edge (line, curve, dashes, thin bar, cell border, tiny boxes,
    dimmed stage, image edge) that passes through its glyphs, unless an opaque plate lies between them;
  - labels overlapping, touching, hidden under an opaque shape, outside the frame, or under 3:1 contrast with their fill
    (black text on a bright chip counts as a label too);
  - a label with < 0.1 padding in its box (0.03 in a small cell), or < 0.1 from a box it is not in;
  - the dimmed stage showing through a box; boxes butting into each other; a shape poking out of another;
  - a straight connector that stops short of, or runs into, a box it aims at.
  It replaced a lint that compared bounding boxes by area at each cue. That one was blind to all strokes (a dashed
  border, a waveform), to anything covering < 8% of a long label (a 0.18-wide bar, 25 small boxes), to anything dimmed
  under 0.3, to a cell that holds its number as a submobject, and to what arrived between cues; its noise (grid cells,
  arrow tips "crowding" boxes) taught the agent to wave warnings through. It said nothing about five of the seven chapters
  the user flagged, and the agent dismissed it on the other two.

## 4. Component recipes (scenes/kit_protocol.py)

The template's `kit_protocol.py` holds the accepted components: `Avatar` (eyes that `look`), `LockBox` /
`lock_drop` / `R_box`, `chip` (challenge), `card` (answer), `Table` (rows per run, check column), `notes_box`,
`send`, `ripple`, `roll_die`, `Blender` / `swallow`, `program_window`, `fork_paths`, `rewind_glyph`,
`message_card`, `key_icon`, `check_lamp`, `AnswerPlot` / `plot_point` / `PivotLine`. Patterns worth copying
to other domains:

- **Characters** are a head with two eyes, shoulders and a name in the character's colour. Eyes that follow the
  action cost nothing and make the stage feel alive.
- **Physical props for abstract operations**: a padlock box for "sealed/one-way", dice for "random", a blender
  for "hash", a program window for "this party is code we control". One prop per concept, used all film.
- **The table as the transcript**: column headers name the move and its symbol ("commitment R"), rows are runs,
  a ✓ column shows verification. Light the column being played (header colour + slot border) while its move
  happens, then return it to grey.
- **A work panel** (`panel(w, h, "Bob checks")`) for a side computation: the boxes are built in one row with
  `box_row`, combined step by step (3 × [7] → [21], [5] + [21] → [26]), re-centred to "[26] = [26] ✓", and the
  ✓ then travels into the table's check column.
- **A case study** dims the stage to ~12% and opens a panel over it; restoring the stage afterwards uses
  `save_state` / `Restore`.
- **The fork** is drawn as a timeline (question nodes on a trunk, a fork dot, two branches labelled with their
  challenge and answer). Zoom the camera in on it for "one shared past, two futures", then back out.

## 5. State changes without glow

- **Never use a stacked-stroke glow** (several copies with growing width and low opacity). It looks cheap.
  Emphasis is a colour change, a `Circumscribe`, a lit column, or a label sliding in ("x = 7").
- `Indicate`, `Flash`, `Wiggle` at most a few times per film, and only where "look here" is the sentence.
- Revealing a secret: the value flies into the box, the shackle lifts (`LockBox.opened`), the number comes up
  to full brightness, and a short label appears beside it. No halo.
- Dimming and restoring: `mob.save_state()`, `mob.animate.fade(0.7)`, later `Restore(mob)`. Never
  `set_opacity(1)` to restore (it fills shapes; see manim-pitfalls.md).

## 6. Timing

- Every motion starts on the word that names it (`b.cue(i)`), and holds 0.5–1 s after a reveal.
- One thing moves at a time unless two things are being compared (two branches flashing together is a
  comparison).
- Durations: small state changes ~0.3–0.4 s, entrances ~0.5 s, travel 0.7–1.0 s (longer for longer distances),
  a die roll ~1 s. UI motion tokens (IBM Carbon, Material) are tuned for interfaces; in narrated video, hold
  longer after each change so the viewer can read.
- Long narration over a still frame reads as frozen. Fill it with motion that shows what the sentence says
  (a probe dot tracing the line while "if Bob had rolled a different number…"). A slow camera drift was tried
  as filler and removed as decorative. `tools/freeze_report.py` lists the stretches.

## 7. What the viewer liked (keep these)

- The 3b1b look: black background, LaTeX type, the palette with one colour per concept.
- The padlock box for a public value ("loveee it").
- The transcript table with run rows and the outline on the repeated column.
- The probability square: two strips crossing, then only the matching-question cells lit.
- Alice and Bob avatars with eyes; the forger with a mask inside a program window.
