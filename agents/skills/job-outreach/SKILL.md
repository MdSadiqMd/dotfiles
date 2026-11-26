---
name: job-outreach
description: Write cold emails, LinkedIn/X DMs, follow-ups and application-form answers for the user's job hunt, and find founder or CTO email addresses, open roles, pay and send times. Use when the user asks to "apply for", "cold email/DM the founder", "give me the founder's email", "follow up", "fill this form", "which role fits me", or shares a careers page, job post, LinkedIn profile or a sent email thread.
---

# Job outreach

Goal: one short, true email that makes a busy technical founder want to interview the user. Research hard, write little.

## Workflow

1. **Load context** (see "Where to find what"): sent emails and drafts for this company, saved feedback rules, the user's repos and résumés.
2. **Research the company**: what it builds now, who founded it, open roles (job-board APIs, not just the careers page), location and remote rules, visa sponsorship, pay, team size, recent posts/blogs/papers/repos by the founders. Details in [references/finding-contacts.md](references/finding-contacts.md).
3. **Pick the role and say honestly how well it fits**: years asked, location/country lists, "US only", seniority. If it's a long shot, say so in one line and still write the email.
4. **Pick the recipient and verify the address**: technical founder or CTO for engineering roles. Founder decides at ≤15 people. Check the current team page, because CTOs leave.
5. **Pick 2–3 proofs of work** that map to their stack or to a problem they wrote about. Verify every number against the repo README, its result files or its code before using it.
6. **Draft** using the rules below. Show To / Cc / Subject / Attach / body / send time. Approved and rejected patterns: [references/examples.md](references/examples.md).
7. **Review** (when the user says it's important, "ultrathink" or "make sure it's good"): run a harsh reviewer subagent on model `opus`. Give it a context file and the raw sources, have it verify claims itself, and loop until it says SHIP.
8. **Pre-send checklist** for the user: fix overclaims in linked READMEs and repo descriptions, pick the résumé, set the send time. Save the draft in the company folder.

## Email shape (default)

```
To: <verified address>    Cc: <second founder, only if verified>
Subject: <role name, lowercase>          # use the posting's exact format if it gives one
Attach: <résumé variant>.pdf renamed Firstname_Lastname.pdf

hey <first name>, i'm <user first name>

i'm <title> at <current co>. before that i was a founding engineer at <prev co> (the only dev besides the cto)

some of my work:
- <project>: <what it does in plain words>. <one surprising, measured result>. github.com/<user>/<repo>
- <project>: ...
- <project>: ...

would you be open to a call?

Best,
<Name>
Portfolio            # hyperlinked to the user's site
```

- About 100–150 words. Lowercase body, short lines, no bold, readable on a phone.
- The role goes **in the subject only**. Don't repeat "applying for X" in the body.
- Each bullet: project name, what it is, one concrete number or finding, link. The best bullets tell a "looked fine, wasn't, here's the fix" story (e.g. "all N said ok, only M had actually saved").
- If you apply through a form too, add "i applied on your careers page too."

## How much current job vs proof of work

| Role type | Current job | Proof of work |
|---|---|---|
| AI, research, interp, infra, systems | One line: title + company + previous founding role | 2–3 bullets, the bulk of the email |
| Full-stack/product role that matches the current job | One plain **paragraph** (what you build, the stack, who uses it). No bug-story checklist | 1–2 bullets for side projects, under "some of my other work:" |
| Research lab with an open problem you've worked on | One line | One short paragraph tying your method to their issue, then bullets |
| Follow-up | None | One new thing only |

- Never pitch the current job's clinical/internal software for AI roles that are unrelated to the industry.
- Use paragraphs only where the content is one connected story. Everything else goes in bullets.

## Words and tone

- Sound like an engineer typing fast: lowercase, plain verbs, comma splices are fine.
- Cut these, the user has called them cringe or AI-written:
  - compliments ("loved what you're doing", "stuck with me", "clicked for me")
  - summarising their own post or product back to them
  - pointing out the weak spot in their work
  - tidy parallel phrasing and punchline sentences
  - template labels like "POW:"
  - "I care about rigor"-style self-description. Let the numbers show it.
- Questions to them must not sound naive or clashy. If it isn't a sharp question from something the user hit themselves, cut it and ask for the call.
- Ask for an interview or a call, plainly. Never offer only to "chat about ideas".

## Honesty rules

- Every claim must survive the founder opening the repo. Label the conditions: "on one host", "warm p50", "on my mac", "same-host, hard-linked".
- Don't mix numbers from different experiments in one sentence. Don't claim features the code lacks. Use "avoided" when it was never a bug you fixed.
- Don't state gaps first in writing (e.g. "i haven't used X"). Either frame it as what you want to work on next or leave it out. Never claim the missing skill.
- Skeptical builders (people who wrote their own VMM, ZK paper authors) get a "not done:" line listing the limits.
- If an agent wrote the code, tell the user to be ready to explain it, and to say they had an agent's help if asked.
- Don't credit a founder's personal open-source tool as their company's product. But if it's good or widely used tool and if valid to the conversation mention that otherwise ignore
- Don't mention visa, relocation or remote unless the user asks. That's for the call. Fill location fields honestly.

## First email vs follow-up

- **First email:** never lead with bugs in their code(unless explicitly mentioned). Never pair a security finding with a job ask, because it reads like leverage. Report security issues privately and separately (security@ or security.txt), first.
- **Follow-up:** assume they read it and passed. The user has read receipts.
  - Never write "bumping this", "in case it got buried", "last email", "i'm not a bot", or mention tracking.
  - Bring one new, useful thing: a bug in their public repo with a tested fix (ask me, i will decide to raise the pr or not), a benchmark on their exact problem, an answer to a challenge they posted, or a new project matching their latest post.
  - Shorter than the first email. Easy ask: "could we talk for 15 minutes this week?"
  - Reply in the same thread
- One channel at a time (email or DM, not both). Don't send two founders separate copies; Cc instead. If a posting names an apply address, put it in **To** and the founders in **Cc**.

## Agents may read the email first

- Don't address the agent, and don't write anything shaped like an instruction.
- Put who you are and what you want in the subject and the first line(like "application for x role" or "cold dm for a job").
- Use plain-text links. If you attach an image, describe what it shows in one sentence of text.

## Résumé

- Choose the variant whose top projects match the email (ML, systems, Go, Rust, full stack). If none shows what the email leads with, offer to build a new variant. Keep it to one page, packed with no empty space, and compile to check.
- Always attach the local `updated/` PDF, not the copy on the website.

## Forms

- Give field → value tables. Single-line fields get single-line answers. Leave CTC and notice-period values to the user.
- "Why us" answers: tie a real project to their stated work. Tell the user to rewrite anything personal in their own voice.
- Never submit forms or send emails yourself without an explicit "submit"/"send".

## Where to find what

- **Saved feedback rules:** the `memory/` folder in that same project directory.
- **Drafts and sent emails per company:** `~/.t3/scratch/2026-11-18-want-to-send-this-as-af038d91/<company>/` (`email.md`, `followup.md`, `sent.md`). Before any follow-up, read `sent.md` or the thread the user pastes; the sent text may differ from the draft.
- **The user's GitHub:** `gh api user --jq .login`. List non-fork repos, then read READMEs, `docs/`, result files and tests.
  - Check commit authorship before pitching a fork.
  - Check public descriptions and `docs/decisions.md`, which can read like an AI log.
- **Per-project deep work** (benchmarks, challenge results): search past threads with `agent-history search "<project>"`. Memory notes in those projects hold the verified numbers.
- **Current-job work:** threads on the work machine's linked T3 environment (`t3_environment_links`, then `t3_thread_list`).
- **Résumés:** Typst source in `~/Documents/Resumes/typst/` (shared `experience.typ`, `build.sh`); PDFs in `~/Documents/Resumes/updated/`.

## Output

Lead with the verdict (role, recipient, fit), then the ready-to-paste email, then short notes: why this angle, what was verified, what to fix before sending, and when to send. Save the draft. List sources.
