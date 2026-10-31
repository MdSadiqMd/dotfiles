# Story and continuity

Read with planning-and-cinematography.md before writing `narration.py`. These rules come from a film that
went through six cuts (forking lemma, Oct 2026): v1 "generic", v2 "explanation 5/10, jargon, no thread",
v3 "good start, falls apart after 3–4 minutes", v4 "story 8/10", v6 accepted as "great". Each rule below names
the cut it fixed.

## Contents
- 1. Premise first
- 2. Few ideas, one running picture
- 3. One stage for the whole film
- 4. Just-in-time ideas, plants and payoffs
- 5. Misconceptions and objections
- 6. Correctness of the content
- 7. Script checklist

## 1. Premise first (fixed v2)

The first 30–60 s answer three questions, in this order:
1. **What is the situation?** A concrete scene, not a topic ("This is a message from Alice. This is her signature.").
2. **What is the question?** Phrase it so the viewer feels the gap ("How could we ever be sure nobody *can* forge it?").
3. **What will we achieve, and how?** The goal in one sentence, then a numbered roadmap: `1.` `2.` `3.`
   (with full stops). Show the roadmap again at the start of each act with the current step lit (`roadmap()`).

Never open on definitions, history or an agenda slide.

## 2. Few ideas, one running picture (fixed v2)

- A ~10 min film carries **at most three core ideas**, one per act. Write them down before anything else.
  v2 had ~25 ideas in 13 minutes (a "machine" metaphor, box arithmetic, a curve aside, two failed-forger
  demos, video-game seeds, a grid simulation, log bars, credit cards…) and lost the viewer.
- Find **one picture that carries the maths** through the whole film and come back to it every act.
  Forking lemma: the answer `s = k + e·x` as a line (challenge across, answer up). One point leaves the slope
  free (a pivoting line); two points fix it (the slope is the secret). The real-world bug (Sony PS3) and the
  proof's trap were then *the same picture*.
- One running example with real numbers (secret 7, random 5, challenge 3 → answer 26; second challenge 8 → 61),
  used in every chapter. Numbers are small enough to check in your head.
- Cut anything that doesn't serve a goal, however nice. Write the cut list in the storyboard.

## 3. One stage for the whole film (fixed v3)

v3's chapters were each clear, but each started on an empty screen with new abstract icons (a "?" box, a blank
machine, dice). After minute 3 the thread the viewer was holding (Alice and Bob) disappeared, and attention
collapsed. The fix that made v4 work:

- **One stage, persistent from the first chapter to the last.** Fixed screen geography: a character left,
  a character right, the shared object (here the transcript table) between them at the bottom, the public value
  top-left, the idea area above the table. The plot, panels and demos appear in the idea area and leave again.
- **Swap the players, keep the stage.** Act I: Alice and Bob play the game. Act II: Bob walks off and a hash
  machine takes his seat. Act III: a forger takes Alice's seat (inside a program window, "on our computer")
  and *we* become the machine. The viewer re-uses everything they learned about the stage.
- **Chapters continue, never restart.** Each chapter rebuilds the exact state the previous one ended in,
  instantly, with a `stage.py` of builders (`game_stage(scene, rows=[...])`, `trap_stage(...)`), and the
  previous chapter ends by settling into that state. Cuts between chapters become invisible.
- **Private state lives with its owner.** A character's secret values sit in a small dashed "private" box
  under its name (`notes_box`), not floating near its head. When the forger takes the seat its box shows
  `x = ?` and receives the seed.
- Full clears (`fade_all`) only at real act boundaries or for a short case-study panel that dims the stage.

## 4. Just-in-time ideas, plants and payoffs

- **But/therefore chain.** Every chapter starts with "But…" or "So…" pointing at the last image. If only
  "and then" fits, the chapter isn't motivated yet.
- **Introduce an abstraction only when the story needs it, and give it a visible reason.** v3 introduced a
  "referee with a notebook" for the random oracle a chapter early; it read as a random new character. v4 brought
  it in inside the trap: "whenever it needs a challenge it must ask the machine. In the proof, *we* are the
  machine." Name it afterwards ("this is called the random oracle model").
- **Plant early, pay off later.** End the PS3 chapter with "Keep this picture in mind: two answers, one box.
  It's going to come back as a weapon." The trap's climax then says "We forced it into Sony's mistake."
- Keep **one name per thing** for the whole film (box / commitment R, challenge, answer). Don't rename.
- Recap at act ends in one line, reusing the act's visual tokens ("one answer: safe · two answers, one box: leak").
- The payoff returns to the opening image (Alice's signed message, now stamped "unforgeable").

## 5. Misconceptions and objections

- Each act gets one "you might think…" beat where the wrong idea is shown and visibly fails (v2/v3 lesson,
  backed by Muller's misconception research). Forking lemma: "any two signatures leak the key" (no: different
  boxes give different lines, the "slope" between them is nonsense); "the proof guesses which question to fork"
  (no: it forks where the forger actually asked).
- Say the viewer's obvious objection out loud and answer it: "Is rewinding cheating? Not here. Nobody rewinds a
  real person. This is a thought experiment about a program, and programs can always be run again."

## 6. Correctness of the content

- Verify every claim of the source material against primary sources before planning. The source thread for the
  forking-lemma film misattributed its central formula (ε(ε/q − 1/h) is Bellare–Neven 2006, not
  Pointcheval–Stern 1996), called discrete log "unsolvable" (it is believed infeasible classically; Shor breaks
  it), and skipped the same-random-tape detail. Report corrections to the user and use the corrected version.
- PDFs that WebFetch can't parse: save them and extract text with `uvx --from pypdf python -I -c ...`.
- Pick toy examples that keep the maths valid: modular examples need a prime group order (3^x mod 17 has order
  16, so a division can fail; 2 mod 23 with order 11 works).
- An explanation that is "simple" but wrong (v1 said the 1/q loss comes from guessing the index) is worse than
  a slightly longer correct one. Keep honest caveats short and at the end of the act ("as long as discrete log
  stays hard, hashes behave like the ideal machine, and no large quantum computer exists").

## 7. Script checklist (add to clarity-and-flow pass 1)

- [ ] Situation, question, goal and numbered roadmap within the first minute.
- [ ] ≤ 3 core ideas, one running picture, one running example.
- [ ] The same stage from start to finish; each chapter starts where the last ended.
- [ ] Every new abstraction arrives when the story needs it, with a visible reason, named afterwards.
- [ ] At least one plant → payoff, one misconception beat per act, the obvious objection answered.
- [ ] Every claim checked against a primary source; corrections to the source reported.
