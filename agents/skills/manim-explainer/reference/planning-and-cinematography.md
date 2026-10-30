# Planning and cinematography

Read this before writing `docs/storyboard.md`. The plan decides whether the video is understandable.
Rendering can only polish what the plan already holds.

## Contents
- 1. Learning goals and misconceptions
- 2a. Visual vocabulary by kind of topic
- 2. The arc (video and chapter)
- 3. Segmenting and length
- 4. Storyboard format
- 5. Cinematography in Manim
- 6. Pacing and rhythm

## 1. Learning goals and misconceptions

- Write 3–5 goals as "the viewer can now explain ___ to a friend". Each goal needs a chapter that earns it.
  Content that serves no goal gets cut (coherence principle).
- For each goal, write the **wrong idea the viewer probably holds** (e.g. "heavier objects fall faster",
  "a hash table search is always O(1)", "a vaccine contains the disease"). Search "<topic> common
  misconceptions" if unsure. Plan a beat where that wrong idea is tried on screen and
  visibly fails. Muller's physics-video study found that plain, clear explanations left scores flat,
  while videos that confronted the misconception about doubled them.
- List the prerequisites. Name the parts before showing the process: give a 20–40 s primer on the
  vocabulary and pieces, then the mechanism (pre-training principle). Never open on definitions.
  A definition is the *conclusion* of an explanation.

## 2a. Visual vocabulary by kind of topic

Pick the picture before writing the narration. For each idea ask: "what could the viewer *watch* change?"

| Topic kind | Core objects | What moves (the teaching motion) |
|---|---|---|
| math | graphs, shapes, vectors, number lines, equations | transform one form into another; drag a parameter (`ValueTracker`) and watch the result |
| algorithms / data structures | arrays as cells, trees, graphs, pointers | step the algorithm on a tiny input; highlight the compared/moved element; live counters of steps |
| systems / backend / networks | boxes for components, arrows for calls, dots for messages/packets, queues as cell rows | messages travel along arrows; queues fill and drain; timelines (`hbars`) from measured runs |
| ML / statistics | points, distributions, matrices (`cell_grid`), networks (`kit_nn.py`) | fit or train live on seeded data; a slider moves the decision boundary or estimate |
| physics / engineering | bodies, vectors, fields, plots against time | simulate with real equations and `rate_func=linear`; plot the trace as it moves |
| biology / chemistry | schematic cells, molecules as simple shapes, pathways as chains | assemble the process step by step; zoom from organism to molecule |
| history / economics / processes | timelines, maps (real images in `assets/stills`), flows, stacked bars | events appear on a timeline in order; quantities flow between boxes |
| code / tools | `code_col()` snippets, the real output beside them | the input → output change after each line or hop |

If a domain needs the same objects in many chapters, write a small kit, `scenes/kit_<domain>.py`, built
on `common.py`. The template's `kit_nn.py` (neural networks) is the example.

## 2. The arc (video and chapter)

Every video, and every chapter in miniature, follows this arc:

1. **Hook: a concrete puzzle**, not an agenda. Open with the key example or exercise ("a 4 GB movie
   streams over a phone connection, but how?", "why does 0.1 + 0.2 not equal 0.3?"). Curiosity needs a gap of the right size: the
   viewer knows enough to care and not enough to answer. Prime it with a partial answer.
2. **Map.** Give a one-line roadmap, then turn it into a recurring visual: a chain of boxes that lights up
   as each part is done (e.g. the hops of a request through a system, or the steps of a proof). Bring it back between parts so
   the viewer always knows where they are.
3. **Body: a chain of BUT / THEREFORE**, never AND THEN. Each beat answers the question the previous one
   raised, or breaks the previous idea. Test: put "but" or "therefore" between consecutive beats. If only
   "and then" fits, reorder, merge, or add the missing question.
4. **Concrete → abstract** inside each idea:
   - First a tiny worked case with real numbers.
   - Then the name ("this is called…").
   - Then the general rule.
5. **Misconception beat.** Show the tempting answer, let a what-if demo break it, then show the fix.
6. **Payoff.** Go back to the hook visual, now fully explained, and give a one-line takeaway.
7. **Retrieval** (series or interview prep): ask questions, give 5 s of silence, then the answer. Recall beats rereading.

## 3. Segmenting and length

- One idea per chapter, 1–3 min. Each chapter opens with its own question and ends on a resolved state,
  so it works as a standalone segment.
- Guo et al. (6.9 M edX views) found that engagement drops past ~6 min per video. Longer videos
  (15–30 min) work if the user accepts them. In that case, make the *chapters* behave like short videos: give each a clear
  start, a visual reset, and a one-line recap.
- Between chapters, do a full clear (`fade_all`). Within a chapter, keep the header and clear the rest
  (`fade_except(header)`), or better, transform the last object into the next beat's first object.

## 4. Storyboard format

`docs/storyboard.md` keeps the goals, misconceptions and facts table at the top, then one row per beat:

| Beat | Question it answers | Narration gist | Focal object | Motion | Lands on (cue) | Left on screen |
|---|---|---|---|---|---|---|
| c2_3 | why does doubling the side quadruple the area? | the square gains a strip on two sides plus a corner | the square | copy it 4× into a 2×2 grid | "four copies" | grid, old square dimmed |

Rules:
- **Motion** is a verb (transform, grow, flash, dim, push in, drive to 0). If a beat has no motion verb,
  it is a slide: redesign it as a demo.
- If a beat answers no question, cut it or add the question to the previous beat.
- **Left on screen** sets up the next beat's continuity and prevents clutter build-up.

## 5. Cinematography in Manim

- **One focal point at a time.** The eye follows the newest motion, so move one thing at a time unless
  you are comparing two things. Dim everything else to `DIM` (0.18); don't delete what will return.
- **Continuity over cuts.** Objects persist and transform. Build new objects from the thing they come
  from (`TransformFromCopy`, `ReplacementTransform`) so the viewer sees their origin.
- **Shot scale.**
  - Open each chapter wide (the whole system) as the establishing shot.
  - Push in (`self.camera.frame.animate.scale(0.6).move_to(part)`) on the part being explained.
  - Pull back to reconnect it to the whole. A wide → close → wide rhythm keeps context.
- **Screen geography is fixed.** Inputs on the left, outputs on the right, the header on top, source notes at
  the bottom right. A concept keeps its color *and* its place across chapters and episodes.
- **Contiguity.**
  - Put the label next to its object, not in a legend (spatial contiguity).
  - Make the object appear on the word that names it, via `b.cue` (temporal contiguity).
- **Density.** At most ~3 new elements per beat. Labels are short phrases. Never put on screen the sentence
  the voice is saying (redundancy).
- **2D blackboard by default.** Use 3D only when depth *is* the idea; then pan the camera slowly so depth reads.
- **Color for distinction.** Yellow and blue separate well; blue and teal blur. Comparisons get starkly
  different hues. Use shades of one hue for "same family".
- **Real motion for real dynamics.** Use `rate_func=linear` and a runtime matched to the real process when
  time itself is the point (a queue draining, a render timeline). Smoothing would hide the real behavior.

## 6. Pacing and rhythm

- Motions take 0.5–1.0 s. Hold 0.5–1 s after every key reveal, before the next sentence.
- Put a ` || ` long pause between a question and its answer, so the viewer has time to guess.
- Alternate dense beats with breathing beats, such as a recap line or a slow push-in. Never stack three
  reveals without a hold.
- The narration carries the reasoning and the screen carries the object. If a beat needs both a long
  sentence and a busy frame, split it in two.

Sources: Mayer, *Multimedia Learning* (coherence, signaling, redundancy, contiguity, segmenting,
pre-training, modality, personalization); 3Blue1Brown FAQ ("concrete before abstract", "never start with
definitions", "avoid pointless animations"); Sanderson's Manim demo with Ben Sparks (2D by default, linear
time for dynamics, contrast colors); Muller, PhD thesis, Univ. of Sydney (misconception videos);
Guo, Kim & Rubin, L@S 2014 (video length); Loewenstein (information-gap curiosity); Parker & Stone
("but/therefore").
