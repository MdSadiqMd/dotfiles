# Patterns from emails the user approved or rejected

Placeholders only: fill them from the user's repos and the research.

## Approved shapes

**Infra/AI cold email** (the default shape in SKILL.md). The hook line before the bullets is optional and only works when it quotes something specific *they* wrote:
```
<their post> says <specific claim>. i built <thing> on the same <api/problem>:
- <project>: ...
```

**Full-stack role matching the current job:**
```
hey <a>, <b>, i'm <name>

i'm <title> at <co>, where <one-line what the co does>. most of my work there is full stack: i build <systems> that <users> use every day, with <stack>. i built <feature>, <feature> and <feature>.

before that i was a founding engineer at <prev> (the only dev besides the cto), where i built <app> and its llm features.

some of my other work:
- <side project>: ...
- <side project>: ...

would you be open to a call?
```

**Research lab with a matching open issue:** one paragraph naming their issue or paper and what the user built that hits the same problem, then the rest as bullets. End with "would you be open to interviewing me? my résumé is attached."

**Follow-up with a gift** (same thread, about a week later):
```
hey <name>,

i read through <their repo> and found <bug> on main (<sha>):
- <repro in one line>
- <cause in one line>
- my fix: <what it does>, about N lines, your existing tests pass

want me to open a pr? and could we talk for 15 minutes this week?
```

**Follow-up answering their public challenge:** restate their challenge in one line, give 3–4 measured bullets, add a "not done:" line, then the link and the ask.

**Intro request to an incubator or VC partner:**
- Subject: `intro to <person>`.
- Body: two lines, what you want to join and one link, then "would you be open to introducing me to her/him?"

**Strict posting the user doesn't fully meet:** admit the gap in one line, give infra proof, and offer the paid trial/test week ("let the work decide"). Send it once.

## Rejected, and why

| Draft text | User's reaction | Rule |
|---|---|---|
| Paragraph explaining their product to them | "why are we explaining him his own product" | Never describe their product back to them |
| "your post found X, but most Y had no error bars…" | "very cringe" | Don't summarise or critique their work |
| "the part that stuck with me…", "…clicked for me" | "very ai written and wantedly written" | Cut framing; facts plus a direct ask |
| A closing technical question to the founder | "sounds clashy" | Ask for the call instead |
| "i haven't worked on kvm or virtio directly" | "why are we mentioning that" | Don't lead with gaps |
| Bugs in their tool in the first email | "don't talk about bugs in first email" | Bugs only in follow-ups |
| Clinical/internal current-job work in an AI pitch | "doesn't help… don't bring it back" | The current job goes in one line for AI roles |
| Current-job work as a bulleted list of bug stories | "not like a checklist, wording too cringy" | Use one plain paragraph |
| "i'd like to apply for <role>" in the body | "mention role in subject, no need in body" | Role in the subject only |
| Remote/visa lines | "ignore remote, will discuss in call" | Keep logistics out |
| "last one from me", "i'm not a bot" | "don't mention it's last one" | No meta-commentary |
| Ask for "a call" when the goal was a job | "the ask is for interview" | Make the ask about the job |
| Scope limited to one of their projects | "iam not gonna just work on this right?" | Name their wider areas |

## Reviewer prompt (for the `fable` review loop)

> You are a harsh, high-bar reviewer of a cold-outreach email. The bar: <recipient>, a busy, slop-allergic founder, <state: hasn't replied / first contact>. Would this make them read to the end and reply, and think better of the sender? Anything that would make an experienced founder wince fails. Read <context.md> and the raw sources it points to, and verify every claim yourself. Don't trust the summary. Judge: (1) every claim true and defensible, (2) adds something new, (3) sounds like a real engineer, so flag any phrase that smells generated, (4) length and scannable on a phone, (5) the ask is right. Verdict: SHIP or REVISE, with exact line edits.

For each new round, list the previous round's findings so the reviewer checks they're fixed. Apply the edits, then rerun until it says SHIP.
