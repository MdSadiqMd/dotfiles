"""Shared look, beat-synced narration, and topic-neutral building blocks.

Every chapter scene subclasses VoiceScene and wraps animations in
`with self.beat("c3_7") as b:` so visuals land inside the spoken line.
"""
import json
from pathlib import Path

import numpy as np
from manim import *
from PIL import Image as _PILImage

# Manim CE 0.22.0 builds its image canvas with Image.fromarray(np.zeros((h, w)), mode="RGBA"), which Pillow 13
# rejects (fixed in 0.22.1). Serve that one call with the transparent canvas it intends; other calls pass through.
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
        self.start = self.scene.time
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
        rem = target - self.scene.time
        if rem > 0.03:
            self.scene.wait(rem)

    def span(self, i, j=None, frac=0.85):
        """A run_time filling `frac` of the time between cue i and cue j (or the end of the line)."""
        cues = CUES[self.key]
        end = cues[j] if j is not None else self.dur
        return max(0.2, (end - cues[i]) * frac)

    def left(self):
        return self.start + self.dur - self.scene.time

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


def TC(*parts, size=36):
    """One line of prose in several colours: TC(("default input is ", GREY_A), ("Bluetooth", CALL)).
    A single Tex, so every part shares one baseline. Never build a coloured line from separate T() pieces
    arranged with aligned_edge=DOWN: a word with a descender ("output") then sits higher than its neighbours."""
    m = Tex(*[t for t, _ in parts], font_size=size)
    for sub, (_, c) in zip(m, parts):
        sub.set_color(c)
    return m


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


# Menlo Text at a given font_size has 1.7x the x-height of Tex at the same font_size (measured), so a code() and
# a T() of the same nominal size looked mismatched (a "17" label beside a "21" value read as twice the size).
MONO_SCALE = 1 / 1.7


def code(s, size=26, color=GREY_A):
    """Monospace code/identifier text: no LaTeX escaping. Same visual size as T() at the same `size`."""
    return Text(s, font="Menlo", font_size=size * MONO_SCALE, color=color)


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


def grid(rows, col_align=None, h_buff=0.45, v_buff=0.3):
    """A table of mobjects with aligned columns: rows = [[label, value, ...], ...]. Column widths come from the
    widest cell, so nothing is placed at hand-picked x coordinates. col_align is one of l/c/r per column."""
    cells = [m for row in rows for m in row]
    ncol = len(rows[0])
    return VGroup(*cells).arrange_in_grid(rows=len(rows), cols=ncol, buff=(h_buff, v_buff),
                                          col_alignments=col_align or "l" * ncol)


def card(content, title=None, pad=0.32, gap=0.26, center=ORIGIN, min_width=0):
    """A panel sized from its contents: title on top, `content` (one mobject, e.g. a grid() or a VGroup of
    rows arranged DOWN) below it after `gap`, and the box `pad` outside both. Content is built first and the box
    is measured around it, so a title can never collide with the first row and no label can cross the border.
    Add rows later with card.fit() after changing content (it re-measures the box)."""
    body = VGroup(content)
    if title:
        t = T(title, 24, GREY_B)
        body = VGroup(t, content).arrange(DOWN, buff=gap, aligned_edge=LEFT)
    box = RoundedRectangle(corner_radius=0.22, width=max(min_width, body.width + 2 * pad),
                           height=body.height + 2 * pad, stroke_color=GREY_D, stroke_width=2.5,
                           fill_color=GREY_E, fill_opacity=0.35).move_to(body)
    g = VGroup(box, body).move_to(center)
    g.box, g.content, g.title = box, content, (body[0] if title else None)
    return g


def panel(w, h, title=None, center=ORIGIN):
    """A framed work area with a small grey title inside its top-left corner (e.g. "Bob checks"). Use it only for
    an area that is filled and emptied over time (a side computation). For anything whose contents are known when
    it appears (a rule, a table, a log, measurements) use card(), which is sized from its contents."""
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
def _types(*names):
    """The Manim classes among `names` that this Manim version has (a renamed class just drops out)."""
    import manim
    return tuple(c for c in (getattr(manim, n, None) for n in names) if isinstance(c, type))


_TEXT_TYPES = None


def _text_units(mob, out):
    global _TEXT_TYPES
    if _TEXT_TYPES is None:
        _TEXT_TYPES = _types("SingleStringMathTex", "Text", "MarkupText", "DecimalNumber", "Integer")
    if isinstance(mob, _TEXT_TYPES):
        out.append(mob)
        return
    for sm in mob.submobjects:
        _text_units(sm, out)


def _bounds(m):
    """(x0, y0, x1, y1) from the points Manim itself uses for get_corner (anchors of every VMobject in the family)."""
    pts = m.get_points_defining_boundary()
    if len(pts) == 0:
        return (0.0, 0.0, 0.0, 0.0)
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    return (lo[0], lo[1], hi[0], hi[1])


def _bbox(m):
    x0, y0, x1, y1 = _bounds(m)
    return (x0, y0), (x1, y1)


def _visible(m):
    fam = [f for f in m.get_family() if isinstance(f, VMobject) and len(f.points)]
    if not fam:
        return False
    return max(max(f.get_fill_opacity(), f.get_stroke_opacity()) for f in fam) > 0.3


def _label(m):
    """'text' at (x,y): the position saves working out which of several copies the warning means."""
    x, y = m.get_center()[:2]
    return f"'{(getattr(m, 'tex_string', None) or getattr(m, 'text', None) or type(m).__name__)[:28]}' at ({x:.2f},{y:.2f})"


class _Leaf:
    """One drawn VMobject, measured once per lint pass."""
    __slots__ = ("m", "box", "visible", "fill", "_wh")

    def __init__(self, m):
        self.m = m
        self.box = _bounds(m)
        self.fill = m.get_fill_opacity()
        self.visible = max(self.fill, m.get_stroke_opacity()) > 0.3
        self._wh = None

    @property
    def wh(self):  # Manim's width/height count curve handles too, unlike the boundary; ask Manim, once
        if self._wh is None:
            self._wh = (self.m.width, self.m.height)
        return self._wh


def _pairs(a, b):
    """Overlap area and the inputs of every test below, for all pairs of boxes a[i], b[j] at once.
    Same float operations, in the same order, as the scalar formulas they replace, so results are identical."""
    ax0, ay0, ax1, ay1 = (a[:, k][:, None] for k in range(4))
    bx0, by0, bx1, by1 = (b[:, k][None, :] for k in range(4))
    w = np.minimum(ax1, bx1) - np.maximum(ax0, bx0)
    h = np.minimum(ay1, by1) - np.maximum(ay0, by0)
    return np.maximum(0, w) * np.maximum(0, h), (ax0, ay0, ax1, ay1), (bx0, by0, bx1, by1), w


def _inside(a, b, tol):
    """a inside b (+tol), for broadcast box coordinates."""
    (ax0, ay0, ax1, ay1), (bx0, by0, bx1, by1) = a, b
    return (ax0 >= bx0 - tol) & (ay0 >= by0 - tol) & (ax1 <= bx1 + tol) & (ay1 <= by1 + tol)


def lint(scene, where):
    """Write layout problems at a rest point (a cue or the end of a beat) to review/lint/<beat>.txt:
    anything outside the frame, two labels overlapping or touching, a label half-covered by a filled shape, a
    filled shape poking half out of another one, and for every box that holds a label: a label crossing its edge,
    a label with < 0.1 padding inside it, and anything outside it closer than 0.1.

    Every mobject is measured once and the pair tests run as numpy matrices (a 600-cell grid is 360k shape pairs
    per rest point); issues come out in the same order as the nested loops they replace."""
    frame = getattr(scene.camera, "frame", None)
    tops = [m for m in scene.mobjects if m is not frame]
    fams = [t.get_family() for t in tops]
    texts = []
    for t in tops:
        _text_units(t, texts)
    text_ids = {id(f) for t in texts for f in t.get_family()}
    texts = [t for t in texts if _visible(t)]
    leaves = {}  # id -> _Leaf, for every VMobject leaf with points
    for fam in fams:
        for f in fam:
            if id(f) not in leaves and isinstance(f, VMobject) and not f.submobjects and len(f.points):
                leaves[id(f)] = _Leaf(f)
    issues = []
    for fam in fams:
        for f in fam:
            lf = leaves.get(id(f))
            if lf is not None and lf.visible:
                x0, y0, x1, y1 = lf.box
                if x0 < -7.05 or x1 > 7.05 or y0 < -3.97 or y1 > 3.97:
                    issues.append(f"out of frame: {type(f).__name__} at ({(x0 + x1) / 2:.2f},{(y0 + y1) / 2:.2f})")
                    break
    shapes = [lf for fam in fams for f in fam
              if (lf := leaves.get(id(f))) is not None and id(f) not in text_ids and lf.fill >= 0.15
              and lf.wh[0] > 0.15 and lf.wh[1] > 0.15]
    T = np.array([_bounds(t) for t in texts], dtype=float).reshape(-1, 4)
    S = np.array([lf.box for lf in shapes], dtype=float).reshape(-1, 4)
    t_area = (T[:, 2] - T[:, 0]) * (T[:, 3] - T[:, 1])
    s_area = (S[:, 2] - S[:, 0]) * (S[:, 3] - S[:, 1])
    upper = np.triu(np.ones((len(T), len(T)), dtype=bool), 1)

    ov_tt, ta, tb, _ = _pairs(T, T)
    min_area = np.minimum(t_area[:, None], t_area[None, :])
    for i, j in np.argwhere(upper & (ov_tt > 0.12 * min_area) & (ov_tt > 0.004)):
        issues.append(f"labels overlap: {_label(texts[i])} / {_label(texts[j])}")

    ov_ts, ta_s, sb_s, _ = _pairs(T, S)
    hit = (ov_ts > 0.08 * t_area[:, None]) & (ov_ts > 0.004) & ~_inside(ta_s, sb_s, 0.03)
    for i, j in np.argwhere(hit):
        x0, y0, x1, y1 = S[j]
        issues.append(f"label half-covered: {_label(texts[i])} by {type(shapes[j].m).__name__} "
                      f"at ({(x0 + x1) / 2:.2f},{(y0 + y1) / 2:.2f})")

    ov_ss, sa, sb, _ = _pairs(S, S)
    row_ok = np.array([s_area[i] >= 0.04 and not isinstance(lf.m, Triangle) and not getattr(lf.m, "lint_skip", False)
                       for i, lf in enumerate(shapes)], dtype=bool)
    hit = (row_ok[:, None] & (s_area[:, None] < s_area[None, :]) & (ov_ss > 0.15 * s_area[:, None])
           & ~_inside(sa, sb, 0.04))
    np.fill_diagonal(hit, False)
    for i, j in np.argwhere(hit):
        x0, y0, x1, y1 = S[i]
        issues.append(f"shape pokes out: {type(shapes[i].m).__name__} over {type(shapes[j].m).__name__} "
                      f"at ({(x0 + x1) / 2:.2f},{(y0 + y1) / 2:.2f})")

    # Stacked labels that touch: horizontally overlapping and less than 0.06 apart vertically (a panel title sitting
    # on its first row). The area test above misses these because the overlap is a thin sliver.
    (ax0, ay0, ax1, ay1), (bx0, by0, bx1, by1) = ta, tb
    ho = np.minimum(ax1, bx1) - np.maximum(ax0, bx0)
    vg = np.maximum(by0 - ay1, ay0 - by1)
    t_w = T[:, 2] - T[:, 0]
    hit = upper & (ho > 0.3 * np.minimum(t_w[:, None], t_w[None, :])) & (vg < 0.06) & (ov_tt <= 0.12 * min_area)
    for i, j in np.argwhere(hit):
        issues.append(f"labels touch: {_label(texts[i])} / {_label(texts[j])}")

    # Containers: any visible rectangle that holds a label, whatever its fill (a 0.12-fill panel was invisible to
    # every check above, so labels straddling its border passed). A label must sit inside with >= 0.1 padding,
    # and nothing outside may come within 0.1 of the box (a panel butting into the stage below it).
    rects = [lf for fam in fams for f in fam
             if (lf := leaves.get(id(f))) is not None and isinstance(f, Rectangle) and lf.visible
             and lf.wh[0] > 0.6 and lf.wh[1] > 0.4 and not getattr(f, "lint_skip", False)]
    if rects and len(T):
        R = np.array([lf.box for lf in rects], dtype=float)
        holds = _inside(*_pairs(T, R)[1:3], 0).any(axis=0)
        boxes = [(lf, R[k]) for k, lf in enumerate(rects) if holds[k]]
    else:
        boxes = []
    near = [lf for fam in fams for f in fam
            if (lf := leaves.get(id(f))) is not None and lf.visible and id(f) not in text_ids
            and (lf.box[2] - lf.box[0]) * (lf.box[3] - lf.box[1]) >= 0.03]
    L = np.array([lf.box for lf in near], dtype=float).reshape(-1, 4)
    for box, cb in boxes:
        bx0, by0, bx1, by1 = cb
        name = f"box at ({(bx0 + bx1) / 2:.2f},{(by0 + by1) / 2:.2f})"
        x0, y0, x1, y1 = T[:, 0], T[:, 1], T[:, 2], T[:, 3]
        ins = (x0 >= bx0) & (y0 >= by0) & (x1 <= bx1) & (y1 <= by1)
        pad = np.minimum(np.minimum(x0 - bx0, y0 - by0), np.minimum(bx1 - x1, by1 - y1))
        ov = np.maximum(0, np.minimum(x1, bx1) - np.maximum(x0, bx0)) * np.maximum(0, np.minimum(y1, by1) - np.maximum(y0, by0))
        gap = np.maximum(np.maximum(bx0 - x1, x0 - bx1), np.maximum(by0 - y1, y0 - by1))
        for i in range(len(T)):
            if ins[i]:
                if pad[i] < 0.1:
                    issues.append(f"label cramped in {name}: {_label(texts[i])} (pad {pad[i]:.2f})")
            elif ov[i] > 0:
                issues.append(f"label crosses edge of {name}: {_label(texts[i])}")
            elif gap[i] < 0.1:
                issues.append(f"label crowds {name}: {_label(texts[i])}")
        x0, y0, x1, y1 = L[:, 0], L[:, 1], L[:, 2], L[:, 3]
        skip = (((x0 >= bx0) & (y0 >= by0) & (x1 <= bx1) & (y1 <= by1))
                | ((bx0 >= x0) & (by0 >= y0) & (bx1 <= x1) & (by1 <= y1)))
        gap = np.maximum(np.maximum(bx0 - x1, x0 - bx1), np.maximum(by0 - y1, y0 - by1))
        for k in np.flatnonzero(~skip & (gap < 0.1)):
            if near[k] is not box:
                issues.append(f"{type(near[k].m).__name__} crowds {name}")
    if issues:
        out = ROOT / "review" / "lint"
        out.mkdir(parents=True, exist_ok=True)
        with open(out / f"{where.split('[')[0]}.txt", "a") as fh:
            for line in dict.fromkeys(issues):
                fh.write(f"{where}  {line}\n")
