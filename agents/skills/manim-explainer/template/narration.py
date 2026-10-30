"""Narration script: one entry per beat. Keys match docs/storyboard.md.

Voice: a teacher reasoning out loud, not reading. Questions come before answers,
each step says *why*, and on-screen labels are never read aloud verbatim.
Cue markers (see tools/make_voice.py):  " | " short pause + cue,  " || " long pause + cue.
Scenes call b.cue(i) to land an animation exactly on segment i.
Text is written to be spoken: numbers as words, no symbols.

Single film: write CHAPTERS here (the sample below is a placeholder; replace it).
Series: delete the sample and put each episode's CHAPTERS in script/ep1.py, script/ep2.py, ...
They are merged below, and EPISODES lets render.py / assemble.py / qa_asr.py work per episode.
"""
import importlib
from pathlib import Path

CHAPTERS = {
    "ch00": [
        ("c0_1", "Here's a square with sides of one. | Stretch the side, and watch what the area does."),
        ("c0_2", "So if we double the side, what happens to the area? || It doesn't double. It quadruples."),
    ],
}

EPISODES = {}
for path in sorted((Path(__file__).parent / "script").glob("ep*.py"), key=lambda p: int(p.stem[2:])):
    module = importlib.import_module(f"script.{path.stem}")
    EPISODES[path.stem] = list(module.CHAPTERS)
    CHAPTERS.update(module.CHAPTERS)

ORDER = list(CHAPTERS)
