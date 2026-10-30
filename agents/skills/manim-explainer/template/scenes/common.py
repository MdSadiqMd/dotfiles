"""Shared look, beat-synced narration, and topic-neutral building blocks.

Every chapter scene subclasses VoiceScene and wraps animations in
`with self.beat("c3_7") as b:` so visuals land inside the spoken line.
"""
import json
from pathlib import Path

import numpy as np
from manim import *
from PIL import Image as _PILImage

# Manim CE 0.22 builds its image canvas with Image.fromarray(np.zeros((h, w)), mode="RGBA"),
# which Pillow 13 rejects. Serve that one call with the transparent canvas it intends.
_pil_fromarray = _PILImage.fromarray


def _fromarray_compat(obj, mode=None):
    if mode == "RGBA" and getattr(obj, "ndim", 0) == 2:
        h, w = obj.shape
        return _PILImage.new("RGBA", (w, h), (0, 0, 0, 0))
    return _pil_fromarray(obj, mode) if mode else _pil_fromarray(obj)


_PILImage.fromarray = _fromarray_compat

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "audio"
DUR = json.loads((ROOT / "durations.json").read_text())
CUES = json.loads((ROOT / "cues.json").read_text())
STILLS = ROOT / "assets/stills"  # real frames/screenshots produced by tools/measure_*.py

# Palette (3b1b hues). Give each concept ONE color for the whole film or series, write the mapping in
# docs/storyboard.md, and alias it here, e.g. INPUT = P_TEAL, ERROR = P_RED. Keep FOCUS for "look here now".
BG = "#000000"
FOCUS = "#FFE45C"
P_BLUE = "#58C4DD"
P_RED = "#FC6255"
P_TEAL = "#5CD0B3"
P_ORANGE = "#FF9F43"
P_PURPLE = "#B98CFF"
P_GREEN = "#83C167"
POS, NEG = P_BLUE, P_RED  # signed quantities
DIM = 0.18
SOFT = GREY_B

config.background_color = BG


class Beat:
    """Plays a narration clip and holds the scene until the clip has finished."""

    def __init__(self, scene, key, gap):
        self.scene, self.key, self.gap = scene, key, gap
        self.dur = DUR[key]

    def __enter__(self):
        self.start = self.scene.renderer.time
        self.scene.add_sound(str(AUDIO / f"{self.key}.wav"))
        return self

    def t(self, frac):
        """A run_time that is `frac` of this beat's spoken length."""
        return max(0.15, self.dur * frac)

    def cue(self, i):
        """Hold until narration segment i (split by | in narration.py) starts, so the next animation lands on it."""
        target = self.start + CUES[self.key][i]
        rem = target - self.scene.renderer.time
        if rem > 0.03:
            self.scene.wait(rem)

    def span(self, i, j=None, frac=0.85):
        """A run_time filling `frac` of the time between cue i and cue j (or the end of the line)."""
        cues = CUES[self.key]
        end = cues[j] if j is not None else self.dur
        return max(0.2, (end - cues[i]) * frac)

    def left(self):
        return self.start + self.dur - self.scene.renderer.time

    def __exit__(self, kind, *_):
        if kind is None:
            rem = self.left()
            if rem > 0.03:
                self.scene.wait(rem)
            if self.gap > 0:
                self.scene.wait(self.gap)


class VoiceMixin:
    def beat(self, key, gap=0.35):
        return Beat(self, key, gap)

    def drop(self, *mobs):
        """Remove mobjects and every submobject; animating children registers them individually."""
        self.remove(*[f for m in mobs for f in m.get_family()])

    def fade_except(self, *keep, run_time=0.5):
        """Clear the stage between beats but keep e.g. the chapter header."""
        frame = getattr(self.camera, "frame", None)
        kept = {id(f) for k in keep for f in k.get_family()}
        mobs = [m for m in self.mobjects if m is not frame and id(m) not in kept]
        if mobs:
            self.play(*[FadeOut(m) for m in mobs], run_time=run_time)

    def fade_all(self, run_time=0.8):
        frame = getattr(self.camera, "frame", None)
        mobs = [m for m in self.mobjects if m is not frame]
        if mobs:
            self.play(*[FadeOut(m) for m in mobs], run_time=run_time)


class VoiceScene(VoiceMixin, MovingCameraScene):
    pass


class Voice3DScene(VoiceMixin, ThreeDScene):
    pass


def T(s, size=36, color=WHITE):
    return Tex(s, font_size=size, color=color)


def M(s, size=40, color=WHITE, **kw):
    return MathTex(s, font_size=size, color=color, **kw)


def cell_grid(values, cell=0.42, vmax=None, buff=0.04):
    """Matrix/table of numbers as colored squares: POS / NEG by sign, opacity by magnitude."""
    values = np.asarray(values)
    vmax = vmax or np.max(np.abs(values)) + 1e-9
    rows, cols = values.shape
    grid = VGroup()
    for r in range(rows):
        for c in range(cols):
            v = values[r, c]
            sq = Square(cell, stroke_width=1, stroke_color=GREY_D,
                        fill_color=POS if v >= 0 else NEG,
                        fill_opacity=0.15 + 0.8 * min(1, abs(v) / vmax))
            grid.add(sq)
    grid.arrange_in_grid(rows=rows, cols=cols, buff=buff)
    return grid


def vector_cells(values, color, cell=0.42, direction=DOWN, buff=0.04, decimals=None):
    """A labelled vector as a strip of cells in one color, optional decimals inside."""
    cells = VGroup()
    for v in values:
        sq = Square(cell, stroke_width=1.5, stroke_color=color,
                    fill_color=color, fill_opacity=0.12 + 0.55 * min(1, abs(v)))
        cells.add(sq)
    cells.arrange(direction, buff=buff)
    if decimals is not None:
        for sq, v in zip(cells, values):
            d = DecimalNumber(v, num_decimal_places=decimals, font_size=22, color=WHITE)
            d.move_to(sq)
            sq.add(d)
    return cells


def code(s, size=26, color=GREY_A):
    """Monospace code/identifier text: no LaTeX escaping."""
    return Text(s, font="Menlo", font_size=size, color=color)


def code_col(lines, size=20, color=GREY_A, buff=0.1):
    """Monospace lines that keep their indentation; Text drops leading spaces and blank lines have no box."""
    advance = code("M" * 10, size).width / 10
    rows = VGroup()
    for s in lines:
        row = code(s.strip() or ".", size, color)
        if not s.strip():
            row.set_opacity(0)
        row.indent = len(s) - len(s.lstrip(" "))
        rows.add(row)
    rows.arrange(DOWN, aligned_edge=LEFT, buff=buff)
    for row in rows:
        row.shift(RIGHT * advance * row.indent)
    return rows


def label_box(text, w=2.4, h=0.8, color=POS, size=28, fill=0.12, text_color=WHITE, mono=False):
    """A rounded box with a label shrunk to fit; .box and .label for animating parts."""
    box = RoundedRectangle(corner_radius=0.12, width=w, height=h, stroke_color=color, stroke_width=3,
                           fill_color=color, fill_opacity=fill)
    lab = code(text, size, text_color) if mono else T(text, size, text_color)
    if lab.width > w - 0.2:
        lab.scale_to_fit_width(w - 0.2)
    lab.move_to(box)
    g = VGroup(box, lab)
    g.box, g.label = box, lab
    return g


def hbars(rows, vmax, width=6.0, height=0.5, gap=0.35, size=26):
    """Horizontal bars from real numbers. rows = [(label, value, color, value_text)]; returns (group, [(bar, text)])."""
    g, parts = VGroup(), []
    for i, (lab, v, c, vt) in enumerate(rows):
        y = -i * (height + gap)
        name = T(lab, size, GREY_A).move_to([0, y, 0])
        name.align_to([-0.2, 0, 0], RIGHT)
        bar = Rectangle(width=max(0.03, width * v / vmax), height=height, stroke_width=0, fill_color=c, fill_opacity=0.85)
        bar.move_to([0, y, 0], aligned_edge=LEFT)
        val = T(vt, size, c).next_to(bar, RIGHT, buff=0.15)
        g.add(VGroup(name, bar, val))
        parts.append((bar, val))
    return g, parts


def still(name, height=None, width=None):
    """A real frame from assets/stills (ImageMobject: group it with Group, not VGroup)."""
    img = ImageMobject(str(STILLS / name))
    if height:
        img.height = height
    if width:
        img.width = width
    return img


def countdown(scene, seconds=5, center=ORIGIN, radius=0.7, color=FOCUS):
    """Silent think-timer: a ring that empties while the number counts down."""
    t = ValueTracker(0)
    ring_bg = Circle(radius=radius, stroke_color=GREY_D, stroke_width=6).move_to(center)
    ring = always_redraw(lambda: Arc(radius=radius, start_angle=PI / 2,
                                     angle=-TAU * max(1e-3, 1 - t.get_value() / seconds),
                                     stroke_color=color, stroke_width=8).move_to(center))
    num = always_redraw(lambda: Integer(max(1, int(np.ceil(seconds - t.get_value() - 1e-6))),
                                        font_size=48, color=color).move_to(center))
    think = T("think", 26, GREY_B).next_to(ring_bg, DOWN, buff=0.2)
    scene.play(FadeIn(ring_bg), FadeIn(think), run_time=0.3)
    scene.add(ring, num)
    scene.play(t.animate.set_value(seconds), run_time=seconds - 0.3, rate_func=linear)
    scene.remove(ring, num)
    scene.play(FadeOut(ring_bg), FadeOut(think), run_time=0.3)


class InterviewScene(VoiceScene):
    """Spoken question -> 5 s silent countdown -> keyword answer lines, one per narration cue.

    Narration: an intro beat with 2 segments, then per question a `q` beat (the question) and an `a` beat
    with one ` | ` segment per answer line (None in `answers` skips a line but keeps the cue count).
    """

    def intro(self, key, title="Interview round"):
        heading = T(title, 60, FOCUS)
        sub = T("pause, answer out loud, then compare", 30, GREY_B).next_to(heading, DOWN, buff=0.35)
        with self.beat(key) as b:
            self.play(Write(heading), run_time=1.0)
            b.cue(1)
            self.play(FadeIn(sub, shift=UP * 0.2), run_time=0.8)
        self.play(FadeOut(VGroup(heading, sub)), run_time=0.5)

    def qa(self, n, qkey, akey, question, answers, total):
        tag = T(f"Q{n} / {total}", 28, FOCUS).to_corner(UL, buff=0.4)
        q = Tex(r"\begin{minipage}{11.5cm}\raggedright " + question + r"\end{minipage}", font_size=40)
        if q.width > 12:
            q.scale_to_fit_width(12)
        q.move_to(UP * 0.4)
        # FadeIn, not Write: a long question written letter by letter looks garbled mid-animation.
        with self.beat(qkey, gap=0) as b:
            self.play(FadeIn(tag), FadeIn(q, shift=UP * 0.2), run_time=min(1.0, b.dur * 0.4))
        countdown(self, 5, center=DOWN * 2.2)
        head = q.copy().scale(0.75)
        head.next_to(tag, DOWN, buff=0.2).to_edge(LEFT, buff=0.9)
        self.play(Transform(q, head), run_time=0.7)
        rule = Line(LEFT * 6.3, RIGHT * 6.3, stroke_color=GREY_D, stroke_width=2).next_to(q, DOWN, buff=0.25).set_x(0)
        self.play(Create(rule), run_time=0.4)
        lines = VGroup()
        with self.beat(akey) as b:
            for i, a in enumerate(answers):
                if a is None:
                    continue
                b.cue(i)
                bullet = Dot(radius=0.06, color=P_GREEN)
                txt = Tex(r"\begin{minipage}{11.2cm}\raggedright " + a + r"\end{minipage}", font_size=32)
                row = VGroup(bullet, txt).arrange(RIGHT, buff=0.25, aligned_edge=UP)
                bullet.shift(DOWN * 0.12)
                if len(lines):
                    row.next_to(lines, DOWN, buff=0.28, aligned_edge=LEFT)
                else:
                    row.next_to(rule, DOWN, buff=0.4).to_edge(LEFT, buff=0.9)
                lines.add(row)
                self.play(FadeIn(row, shift=RIGHT * 0.2), run_time=0.6)
        self.wait(0.6)
        self.play(FadeOut(VGroup(tag, q, rule, lines)), run_time=0.6)
