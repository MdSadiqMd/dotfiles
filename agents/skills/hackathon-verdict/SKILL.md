---
name: hackathon-verdict
description: Pressure-test a hackathon idea against the clock, the stack, and the jury, and emit a tables-only verdict — verdict line, scorecard table, and a ranked breakers table. Use when asked to validate, vet, compare or sanity-check hackathon ideas, decide what to build in a time-boxed event, or answer "will this survive demo day / what breaks this / which of these should we build".
---

# Hackathon Verdict

Judge whether a hackathon idea survives contact with a fixed clock, a sponsor stack, and a jury watching its fortieth demo. Output is **tables only** — built to be pasted into a team chat and acted on without discussion.

This is the time-boxed sibling of `feasibility-check`. Same discipline, different constraint: there, the binding constraint is validation; here, it is **wall-clock time and what the jury actually sees**.

## Input

Accepts any of:

- a pasted idea, or several ideas to compare
- a path to a document (problem statement, notes, a shortlist)
- a link to the event page, plus an idea
- a verbal description in the conversation

Before judging, establish these. Ask only if they are not inferable — never stall the verdict on details you can reasonably assume:

| Input | Why it's needed |
|---|---|
| **Hours on the clock** | The single most binding constraint. Everything is judged against it |
| **Team size and skills** | Four people is three parallel workstreams plus integration; two is one |
| **Sponsor stack + credits** | Whether the sponsor's tech is load-bearing or decorative decides half the score |
| **Judging criteria** | Quote them if published. "Real-world adoption" and "technical depth" reward opposite ideas |
| **Jury composition** | Sponsor engineers reward tooling that helps them. VCs reward a company. Academics reward a finding |
| **Data/API access at the venue** | Anything requiring a download, an approval, or a signup is a critical-path risk |

## How to run the evaluation

Work in this order. It deliberately front-loads clock and demo risk, because teams over-index on whether the idea is *good* and under-index on whether it will *exist* by 18:00.

1. **State the demo in one sentence.** Literally: what the judge sees and hears at the demo. If you cannot write that sentence, the idea has no demo, and that is finding #1.

2. **Work backwards from the freeze.** Freeze is one hour before demo. Subtract rehearsal and integration. What remains is real build time — usually 60–70% of the advertised hours. Judge scope against *that* number, not the headline.

3. **Find the critical path.** The one thing that, if it fails at hour 3, kills the demo — usually data access, an API tier, or a model capability nobody verified. Name it explicitly.

4. **Check whether the sponsor's stack is load-bearing.** Could this be built on any other provider with a find-and-replace? If yes, it will score as a wrapper regardless of how good it is.

5. **Predict the room.** How many of the other teams build roughly this? An idea that is good and common loses to one that is decent and singular.

6. **Hunt breakers in this order** — clock, critical-path access, demo legibility, sponsor fit, differentiation, adoption story. Stop when you run out of *specific* ones.

7. **Test every candidate breaker:** name a concrete failure — what fails, at what hour, leaving what on screen. If you cannot, drop it.

8. **Write the cut order.** What gets dropped first, second, third if the team is behind — and the one thing that must never be cut. This is the most-used line in the whole output.

## Output format

Emit **only** what follows. No preamble, no summary of the idea back at the author, no closing encouragement.

---

`# Hackathon Verdict — <idea name>`

**Verdict: `<BUILD | RESCOPE | SWAP | DON'T>`** — one line, nothing more.

| Verdict | Means |
|---|---|
| **BUILD** | Survives the clock and has a demo. Start |
| **RESCOPE** | Right idea, too big. A named smaller version ships |
| **SWAP** | The idea is fine but wrong for this event — stack, jury or format mismatch |
| **DON'T** | No version of this has a demo by the freeze |

### Scorecard

Always these six dimensions, always this table, so ideas stay comparable when several are run:

| Dimension | Rating | Note |
|---|---|---|
| Ships in the time box | | Against real build time, not advertised hours |
| Critical-path risk | | The one dependency that kills it, and when you'd know |
| Demo strength | | What the judge sees in 3 minutes. Playable, visible, surprising? |
| Sponsor-stack fit | | Is their tech load-bearing, or find-and-replaceable? |
| Differentiation vs the room | | How many other teams build roughly this |
| Adoption story | | Who pays for this on Monday, and for what |

Ratings: **Strong · Adequate · Weak · Very weak**. One line per note. Rate dimensions separately even when they disagree — "strong demo, very weak sponsor fit" is the most useful thing the table can show.

### What breaks it

Ranked worst-first:

| # | Breaker | The specific failure | Severity | Fix |
|---|---|---|---|---|
| 1 | Short label | What fails, at roughly what hour, leaving what on screen at demo time | Blocker | What resolves it, or what to cut |

Severity:

- **Blocker** — no working demo at the freeze
- **High** — you demo, but it lands badly or reads as a wrapper
- **Medium** — real and worth fixing, survivable if time runs short

Keep cells to one or two sentences. If a row genuinely needs more nuance, add one short prose line below the table rather than bloating the cell.

Close with exactly two one-line footers:

- **Blockers:** how many, and whether each is fixable by scope, by preparation the night before, or not at all.
- **Cut order:** first → second → third, then `Never cut: <the one thing>`.

---

## Rules

- **Tables only.** The verdict line, the two tables, and the two footers. Nothing else unless `--full` is passed, which adds prose sections: what's solid, the killer question, and the hour-by-hour plan.
- **Judge against real build time.** Advertised hours minus integration minus rehearsal. Teams lose on this arithmetic more than on ideas.
- **Every breaker names an hour.** "Might be tight" is not a breaker; "IndicVoices download is gated, you find out at hour 2, and there is no fallback corpus" is.
- **Demo legibility outranks technical depth.** A jury cannot grade what it cannot see in three minutes. An elegant idea with no visible artifact scores below a crude one with a playable moment.
- **Name the room.** Always estimate how many other teams build the same thing. It is the most-ignored and most-decisive variable.
- **Separate wrong from different.** "This does not work" and "I would build it differently" belong in different places — the latter goes in the fix column, never the failure column.
- **Don't inflate the count.** Three real breakers beat eight padded ones.
- **When comparing several ideas**, emit one scorecard row per idea in a single table first, then a full breakers table for the top two only.
- **Assume the reader is the team, at 08:00, deciding.** Direct, unhedged, no moralising, no motivational close.
