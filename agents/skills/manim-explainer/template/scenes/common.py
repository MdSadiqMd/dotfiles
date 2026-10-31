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
P_GOLD = "#FFC857"
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
        # beat start times for tools/beat_review.py and tools/freeze_report.py; one file per beat, so chapters
        # rendering in parallel never race on a shared file
        log = ROOT / "review" / "beat_times"
        log.mkdir(parents=True, exist_ok=True)
        (log / f"{self.key}.txt").write_text(f"{self.start:.3f}")
        return self

    def t(self, frac):
        """A run_time that is `frac` of this beat's spoken length."""
        return max(0.15, self.dur * frac)

    def cue(self, i):
        """Hold until narration segment i (split by | in narration.py) starts, so the next animation lands on it."""
        lint(self.scene, f"{self.key}[{max(0, i - 1)}->]")
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
            lint(self.scene, f"{self.key}[end]")
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


SYM = {}  # symbol -> concept colour, e.g. SYM.update({"x": SECRET, "e": CHAL}); used by MC


def MC(*parts, size=44, colors=None, **kw):
    """MathTex split into parts; parts that are known symbols get their concept colour, `colors` maps index -> colour."""
    m = MathTex(*parts, font_size=size, **kw)
    for i, (sub, p) in enumerate(zip(m, parts)):
        if colors and i in colors:
            sub.set_color(colors[i])
        elif p.strip() in SYM:
            sub.set_color(SYM[p.strip()])
    return m


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


def panel(w, h, title=None, center=ORIGIN):
    """A framed work area with a small grey title inside its top-left corner (e.g. "Bob checks")."""
    box = RoundedRectangle(corner_radius=0.22, width=w, height=h, stroke_color=GREY_D, stroke_width=2.5,
                           fill_color=GREY_E, fill_opacity=0.35).move_to(center)
    g = VGroup(box)
    g.box = box
    if title:
        t = T(title, 24, GREY_B).move_to(box.get_corner(UL) + np.array([0.2, -0.22, 0]), aligned_edge=UL)
        g.add(t)
        g.title = t
    return g


def roadmap(steps, current=None):
    """The numbered roadmap ("1." "2." "3."): the current step lit, the others grey; all lit when current is None."""
    rows = VGroup()
    for i, text in enumerate(steps):
        lit = current is None or i == current
        rows.add(VGroup(T(f"{i + 1}.", 50, FOCUS if lit else GREY_D), T(text, 46, WHITE if lit else GREY_D))
                 .arrange(RIGHT, buff=0.45))
    return rows.arrange(DOWN, buff=0.55, aligned_edge=LEFT).move_to(ORIGIN)


def box_row(items, y, x=0.0, buff=0.3):
    """Lay out an equation of boxes and symbols on one line. Items with a `.body` (e.g. a padlock box) align on
    the body, not on their full bounding box, so a shackle on top doesn't push the box down."""
    g = VGroup(*items).arrange(RIGHT, buff=buff).move_to([x, y, 0])
    for m in items:
        anchor = m.body.get_center()[1] if hasattr(m, "body") else m.get_center()[1]
        m.shift(UP * (y - anchor))
    return g


# ------------------------------------------------------------------ layout lint
_TEXT_TYPES = None


def _text_units(mob, out):
    global _TEXT_TYPES
    if _TEXT_TYPES is None:
        _TEXT_TYPES = (SingleStringMathTex, Text, MarkupText, DecimalNumber, Integer)
    if isinstance(mob, _TEXT_TYPES):
        out.append(mob)
        return
    for sm in mob.submobjects:
        _text_units(sm, out)


def _bbox(m):
    return m.get_corner(DL)[:2], m.get_corner(UR)[:2]


def _visible(m):
    fam = [f for f in m.get_family() if isinstance(f, VMobject) and len(f.points)]
    if not fam:
        return False
    return max(max(f.get_fill_opacity(), f.get_stroke_opacity()) for f in fam) > 0.3


def _label(m):
    return (getattr(m, "tex_string", None) or getattr(m, "text", None) or type(m).__name__)[:28]


def lint(scene, where):
    """Write layout problems at a rest point (a cue or the end of a beat) to review/lint/<beat>.txt:
    anything outside the frame, two labels overlapping, a label half-covered by a filled shape, and a
    filled shape poking half out of another one."""
    tops = [m for m in scene.mobjects if m is not getattr(scene.camera, "frame", None)]
    texts = []
    for t in tops:
        _text_units(t, texts)
    text_ids = {id(f) for t in texts for f in t.get_family()}
    texts = [t for t in texts if _visible(t)]
    shapes = []
    for t in tops:
        for f in t.get_family():
            if (isinstance(f, VMobject) and not f.submobjects and len(f.points) and id(f) not in text_ids
                    and f.get_fill_opacity() >= 0.15 and f.width > 0.15 and f.height > 0.15):
                shapes.append(f)
    issues = []
    for t in tops:
        for f in t.get_family():
            if isinstance(f, VMobject) and not f.submobjects and len(f.points) and _visible(f):
                (x0, y0), (x1, y1) = _bbox(f)
                if x0 < -7.05 or x1 > 7.05 or y0 < -3.97 or y1 > 3.97:
                    issues.append(f"out of frame: {type(f).__name__} at ({(x0 + x1) / 2:.2f},{(y0 + y1) / 2:.2f})")
                    break

    def inter(a, b):
        (ax0, ay0), (ax1, ay1) = a
        (bx0, by0), (bx1, by1) = b
        w = min(ax1, bx1) - max(ax0, bx0)
        h = min(ay1, by1) - max(ay0, by0)
        return max(0, w) * max(0, h)

    def area(a):
        return (a[1][0] - a[0][0]) * (a[1][1] - a[0][1])

    def inside(a, b, tol=0.03):
        return a[0][0] >= b[0][0] - tol and a[0][1] >= b[0][1] - tol and a[1][0] <= b[1][0] + tol and a[1][1] <= b[1][1] + tol

    tb = [(t, _bbox(t)) for t in texts]
    for i in range(len(tb)):
        for j in range(i + 1, len(tb)):
            a, b = tb[i][1], tb[j][1]
            ov = inter(a, b)
            if ov > 0.12 * min(area(a), area(b)) and ov > 0.004:
                issues.append(f"labels overlap: '{_label(tb[i][0])}' / '{_label(tb[j][0])}'")
    sb = [(s_, _bbox(s_)) for s_ in shapes]
    for t, a in tb:
        for s_, b in sb:
            ov = inter(a, b)
            if ov > 0.08 * area(a) and ov > 0.004 and not inside(a, b):
                issues.append(f"label half-covered: '{_label(t)}' by {type(s_).__name__}")
    for i in range(len(sb)):
        for j in range(len(sb)):
            if i == j:
                continue
            a, b = sb[i][1], sb[j][1]
            if area(a) >= area(b) or area(a) < 0.04 or isinstance(sb[i][0], Triangle) or getattr(sb[i][0], 'lint_skip', False):
                continue
            ov = inter(a, b)
            if ov > 0.15 * area(a) and not inside(a, b, tol=0.04):
                issues.append(f"shape pokes out: {type(sb[i][0]).__name__} over {type(sb[j][0]).__name__} "
                              f"at ({(a[0][0] + a[1][0]) / 2:.2f},{(a[0][1] + a[1][1]) / 2:.2f})")
    if issues:
        out = ROOT / "review" / "lint"
        out.mkdir(parents=True, exist_ok=True)
        with open(out / f"{where.split('[')[0]}.txt", "a") as fh:
            for line in dict.fromkeys(issues):
                fh.write(f"{where}  {line}\n")
