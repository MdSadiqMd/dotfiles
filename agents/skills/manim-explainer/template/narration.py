"""Narration script: one entry per beat. Keys match docs/storyboard.md.

Voice: a teacher reasoning out loud, not reading. Questions come before answers,
each step says *why*, and on-screen labels are never read aloud verbatim.
Cue markers (see tools/make_voice.py):  " | " short pause + cue,  " || " long pause + cue.
Scenes call b.cue(i) to land an animation exactly on segment i.
Text is written to be spoken: numbers as words, no symbols.
"""

CHAPTERS = {
    "ch00": [
        ("c0_1", "Here's a small neural network. | Information comes in on the left and flows to the right."),
        ("c0_2", "But what decides how bright each circle gets? || The lines."),
    ],
}

ORDER = list(CHAPTERS)
