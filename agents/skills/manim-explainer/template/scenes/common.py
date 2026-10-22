"""Shared look, beat-synced narration, and the 3b1b-style network mobject.

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

# Fixed color semantics for the whole film (rename per project; keep fixed for the whole film, see docs/storyboard.md).
BG = "#000000"
FWD = "#FFE45C"       # forward signal / activations
LOSS = "#FC6255"      # loss, negative weights
POS = "#58C4DD"       # positive weights, structure
NEG = "#FC6255"
XCOL = "#5CD0B3"      # layer input x
GCOL = "#FF9F43"      # output error g
NOISE = "#B98CFF"     # randomness / the new method
BPROP = "#83C167"     # backprop / chain rule
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

    def fade_all(self, run_time=0.8):
        frame = getattr(self.camera, "frame", None)
        mobs = [m for m in self.mobjects if m is not frame]
        if mobs:
            self.play(*[FadeOut(m) for m in mobs], run_time=run_time)


class VoiceScene(VoiceMixin, MovingCameraScene):
    pass


class Voice3DScene(VoiceMixin, ThreeDScene):
    pass


class Net(VGroup):
    """Neurons as BLUE-stroked circles filled WHITE by activation; edges colored by weight sign."""

    def __init__(self, sizes, radius=0.17, layer_buff=1.7, neuron_buff=0.3, seed=1, **kw):
        super().__init__(**kw)
        rng = np.random.default_rng(seed)
        self.sizes = sizes
        self.radius = radius
        self.layers = VGroup()
        for n in sizes:
            col = VGroup(*[
                Circle(radius=radius, stroke_color=POS, stroke_width=3,
                       fill_color=WHITE, fill_opacity=0)
                for _ in range(n)
            ]).arrange(DOWN, buff=neuron_buff)
            self.layers.add(col)
        self.layers.arrange(RIGHT, buff=layer_buff)
        self.weights = [rng.normal(0, 1, (b, a)) for a, b in zip(sizes[:-1], sizes[1:])]
        self.edges = VGroup()
        for i, (left, right) in enumerate(zip(self.layers[:-1], self.layers[1:])):
            group = VGroup()
            for j, n2 in enumerate(right):
                for k, n1 in enumerate(left):
                    line = Line(n1.get_center(), n2.get_center(), buff=radius,
                                stroke_color=SOFT, stroke_width=1.4)
                    line.ij = (j, k)
                    group.add(line)
            self.edges.add(group)
        self.add(self.edges, self.layers)

    def weight_style(self, line, layer):
        j, k = line.ij
        w = self.weights[layer][j, k]
        return (POS if w > 0 else NEG), 0.5 + 2.4 * min(abs(w), 1.8) / 1.8

    def colored_edges(self):
        """A copy of the edges styled by weight, for Transform-ing into."""
        target = self.edges.copy()
        for li, group in enumerate(target):
            for line in group:
                color, width = self.weight_style(line, li)
                line.set_stroke(color, width, opacity=0.9)
        return target

    def color_edges(self):
        self.edges.become(self.colored_edges())
        return self

    def all_neurons(self):
        return VGroup(*[n for layer in self.layers for n in layer])

    def flash(self, i, color=FWD, backward=False, run_time=0.7, width=4):
        copy = self.edges[i].copy().set_stroke(color, width=width, opacity=1)
        if backward:
            for line in copy:
                line.reverse_points()
        return ShowPassingFlash(copy, time_width=0.55, run_time=run_time)

    def activate(self, i, acts):
        return [n.animate.set_fill(WHITE, float(a)) for n, a in zip(self.layers[i], acts)]

    def forward_sweep(self, acts_per_layer, run_time=0.6):
        """Animations, one per layer step: flash edges then light the next layer."""
        steps = [AnimationGroup(*self.activate(0, acts_per_layer[0]), run_time=run_time)]
        for i in range(len(self.edges)):
            steps.append(AnimationGroup(self.flash(i, run_time=run_time),
                                        *self.activate(i + 1, acts_per_layer[i + 1]),
                                        run_time=run_time))
        return steps


def T(s, size=36, color=WHITE):
    return Tex(s, font_size=size, color=color)


def M(s, size=40, color=WHITE, **kw):
    return MathTex(s, font_size=size, color=color, **kw)


def nudge_arrow(anchor, value, scale=0.55, color=GCOL):
    """3b1b-style arrow beside a neuron showing g there: up for +, down for -."""
    length = max(0.12, scale * abs(value))
    start = anchor + RIGHT * 0.32
    return Arrow(start, start + UP * length * np.sign(value), buff=0, color=color,
                 stroke_width=4, max_tip_length_to_length_ratio=0.45, tip_length=0.14)


def cell_grid(values, cell=0.42, vmax=None, buff=0.04):
    """Matrix as colored squares: BLUE positive, RED negative, opacity by magnitude."""
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


