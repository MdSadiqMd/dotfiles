# Series, code/project explainers and question rounds

Read the section that matches the request.

## Series (several videos)

- Plan the episode count first, using the user's cap if they give one. Each episode gets one theme, and
  earlier episodes act as the pre-training for later ones.
- Delete the sample `CHAPTERS` in `narration.py` and write `script/ep1.py`, `script/ep2.py`, …, each defining
  its own `CHAPTERS`. `narration.py` merges them and fills `EPISODES` automatically.
- Prefix keys per episode: chapter `e1c03`, scene `scenes/e1c03_name.py`, class `E1c03`, beats `e1c03_2`.
- Work per episode:
  - `qa_asr.py e1`
  - `render.py ep1 -q p`
  - `assemble.py ep1 -q p` → `final/ep1.mp4`
- Fix the color semantics and screen geography once for the whole series.
- To add to a finished episode:
  - Insert the new chapters and renumber the later keys (file, class and narration).
  - Update the hook and outro that list the parts.
  - Re-voice, re-render and re-assemble only that episode.

## Code / project explainers (a repo, library, tool, system)

- Clone into `repos/` (read-only) and note the commit.
- Trace the real flow hop by hop: what the user does → each file/function it passes through → what comes
  out. Give each hop a `file:function` source in `research/<project>.md`.
- **Measure, don't quote.** Write `tools/measure_<project>.py`, which drives the project's own code and writes
  `assets/data/<project>.json`. Save real outputs (frames, screenshots, logs) to `assets/stills/`.
  - Load the JSON at the top of `common.py`; every number on screen comes from it.
  - Show a small source note in a fixed corner ("measured: <machine>, median of 3").
  - Label numbers taken from the project's README or comments as "project's own measurement".
- Show real code with `code_col()`: the few lines that matter, never a whole file.
- End each project with an honest "what I'd change" beat (limits, security, failure modes).
- Any algorithm shown in the video gets a runnable self-check in `tools/` (an assert-based `__main__`).

## Question rounds (interview prep, exam practice, end-of-chapter quizzes)

Use `InterviewScene` from `scenes/common.py`:

```python
QA = [(r"Why does \texttt{X} fail when Y?", ["first key point", "second key point", "the fix"])]

class Ch09(InterviewScene):
    def construct(self):
        self.intro("c9_intro", title="Practice round")
        for i, (q, a) in enumerate(QA, start=1):
            self.qa(i, f"c9_q{i}", f"c9_a{i}", q, a, len(QA))
```

- Narration per round:
  - `c9_intro` has 2 segments.
  - Each `c9_qN` is the question, spoken once.
  - Each `c9_aN` has one ` | ` segment per answer line, giving the reasoning behind each keyword.
- Flow per question: the question fades in and is spoken → 5 s silent countdown → keyword bullets land one per cue.
- Use real questions people in the field get asked (search for interview or exam questions on the topic),
  not repeats of the lesson. Mix in "why", "what breaks when…" and "design/derive this" questions.
