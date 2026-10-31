"""Domain kit: protocols, cryptography and anything with parties exchanging messages.

From the forking-lemma film (accepted as "great"). Everything here is drawn in the 3b1b style on black,
and every object carries a meaning (see reference/animation-craft.md):
- Avatar: a character with eyes that follow the action (`look`). kind="forger" adds a mask.
- LockBox / lock_drop: a value sealed in a padlock box (a commitment, a public key). The number shows faintly
  for the viewer only; `opened()` lifts the shackle (no glow).
- chip / card / R_box: a challenge, an answer and a small commitment box, all sized to fit a Table slot.
- Table: the transcript, one row per run, slots sized from the largest token, check column on the right.
- notes_box: a character's private values ("x = 7", "k = 5", a seed), instead of numbers floating near a head.
- send / roll_die / ripple / swallow: messages travel on an arc with a fading trail, dice tumble and land,
  a hash "blender" swallows its inputs.
- program_window, fork_paths, rewind_glyph: a party that is a program; a run that forks.
- AnswerPlot / plot_point / PivotLine: a value plotted from the table; a line whose slope follows a tracker.
Copy what you need; keep sizes consistent so tokens always fit their slots.
"""
from common import *  # noqa: F401,F403

SECRET, NONCE, CHAL, CHAL2, RESP, BAD = P_GOLD, P_TEAL, P_ORANGE, P_PURPLE, P_GREEN, P_RED
LEFT_SEAT = np.array([-5.45, -0.75, 0])
RIGHT_SEAT = np.array([5.45, -0.75, 0])
SYM.update({"x": SECRET, "k": NONCE, "R": NONCE, "e": CHAL, "e'": CHAL2, "s": RESP, "s'": CHAL2})


def seat(avatar, side):
    return avatar.move_to(LEFT_SEAT if side == "left" else RIGHT_SEAT)


class LockBox(VGroup):
    """A locked box: blue rounded square with a shackle, its number drawn faintly inside.

    The faint number is for the viewer only; nobody in the story can read it.
    """

    def __init__(self, content, size=40, color=P_BLUE, inner=WHITE, faint=0.6, min_w=0.85, min_h=0.72, r=0.17, leg=0.08,
                 **kw):
        super().__init__(**kw)
        self.content = M(content, size, inner) if isinstance(content, str) else content
        w = max(min_w, self.content.width + 0.42)
        h = max(min_h, self.content.height + 0.32)
        self.body = RoundedRectangle(corner_radius=0.12, width=w, height=h, stroke_color=color,
                                     stroke_width=3.5, fill_color=color, fill_opacity=0.16)
        top = self.body.get_top()
        legs = VGroup(Line(top + LEFT * r, top + LEFT * r + UP * leg), Line(top + RIGHT * r, top + RIGHT * r + UP * leg))
        arc = Arc(radius=r, start_angle=0, angle=PI).move_arc_center_to(top + UP * leg)
        self.shackle = VGroup(legs, arc).set_stroke(color, 3.5)
        self.content.move_to(self.body).set_opacity(faint)
        self.add(self.body, self.shackle, self.content)

    def opened(self):
        """Animation: shackle lifts and swings open, the content shows at full strength (no glow)."""
        lift = self.shackle.height * 0.55
        pivot = self.shackle.get_corner(DR) + UP * lift
        return AnimationGroup(self.shackle.animate.shift(UP * lift).rotate(0.55, about_point=pivot),
                              self.content.animate.set_opacity(1), run_time=0.6)

    def body_center(self):
        return self.body.get_center()


def lock_drop(scene, number_mob, box, run_time=1.2):
    """A number falls into an open box, then the lid snaps shut."""
    box.shackle.shift(UP * 0.18).rotate(0.5, about_point=box.shackle.get_right())
    scene.play(FadeIn(box.body), FadeIn(box.shackle), run_time=0.4)
    scene.play(number_mob.animate.move_to(box.content).set_opacity(box.content.get_fill_opacity()),
               run_time=run_time * 0.6)
    scene.remove(number_mob)
    scene.add(box.content)
    scene.play(box.shackle.animate.rotate(-0.5, about_point=box.shackle.get_right()).shift(DOWN * 0.18),
               run_time=run_time * 0.4, rate_func=rush_into)


def die(pips=3, size=0.5, color=GREY_A):
    sq = RoundedRectangle(corner_radius=0.08, width=size, height=size, stroke_color=color, stroke_width=2.5)
    offs = {1: [(0, 0)], 2: [(-1, 1), (1, -1)], 3: [(-1, 1), (0, 0), (1, -1)],
            4: [(-1, 1), (1, 1), (-1, -1), (1, -1)], 5: [(-1, 1), (1, 1), (0, 0), (-1, -1), (1, -1)]}[pips]
    dots = VGroup(*[Dot(sq.get_center() + np.array([dx, dy, 0]) * size * 0.27, radius=size * 0.07, color=color)
                    for dx, dy in offs])
    return VGroup(sq, dots)


def R_box(value="5", color=NONCE):
    """Alice's commitment R as it sits in the table: a small locked box sized to fit a slot."""
    return LockBox(str(value), 32, inner=color, min_w=0.8, min_h=0.56, r=0.13, leg=0.06)


def chip(value, color, r=0.3, size=34):
    """A challenge: a round chip with the rolled number."""
    c = Circle(radius=r, stroke_color=color, stroke_width=4, fill_color=color, fill_opacity=0.18)
    n = M(str(value), size, color).move_to(c)
    g = VGroup(c, n)
    g.num = n
    return g


def card(value, color, size=34):
    """An answer: a small card with the number written on it."""
    n = M(str(value), size, color)
    c = RoundedRectangle(corner_radius=0.1, width=max(0.85, n.width + 0.35), height=0.62, stroke_color=color,
                         stroke_width=3.5, fill_color=color, fill_opacity=0.14).move_to(n)
    g = VGroup(c, n)
    g.num = n
    return g


def ticket(*tex, color=WHITE, size=38, pad=0.22):
    """A small framed note (a message, a signature, a question) that can travel between objects."""
    body = MC(*tex, size=size) if len(tex) > 1 else M(tex[0], size, color)
    frame = RoundedRectangle(corner_radius=0.1, width=body.width + 2 * pad, height=body.height + 2 * pad,
                             stroke_color=color, stroke_width=2.5).move_to(body)
    g = VGroup(frame, body)
    g.frame, g.body = frame, body
    return g


def check_lamp(ok=True):
    sym = M(r"\checkmark" if ok else r"\times", 44, RESP if ok else BAD)
    ring = Circle(radius=0.32, stroke_color=RESP if ok else BAD, stroke_width=3)
    return VGroup(ring, sym.move_to(ring))


def notes_box(items, title="private", width=1.7):
    """A small dashed box of private notes (what only this character knows), placed under its name."""
    rows_ = VGroup(*items).arrange(DOWN, buff=0.14, aligned_edge=LEFT)
    head = T(title, 20, GREY_B)
    inner = VGroup(head, rows_).arrange(DOWN, buff=0.14, aligned_edge=LEFT)
    w = max(width, inner.width + 0.4)
    box = DashedVMobject(RoundedRectangle(corner_radius=0.12, width=w, height=inner.height + 0.36, stroke_color=GREY_C,
                                          stroke_width=2), num_dashes=30)
    inner.move_to(box)
    g = VGroup(box, inner)
    g.box, g.head, g.rows = box, head, rows_
    return g


class Table(VGroup):
    """The game table: one row per run, columns commitment R / challenge e / answer s, and a check column.

    Slots are sized from the largest token (the locked box with its shackle) plus padding, and every token is
    centred on its slot, so nothing can poke out.
    """

    LABEL_W, COL_W, CHECK_W = 1.0, 1.9, 0.7
    SLOT_W, SLOT_H, PITCH, HEAD_H = 1.4, 0.92, 1.0, 0.42

    def __init__(self, rows=2, center=np.array([0, -2.5, 0]), **kw):
        super().__init__(**kw)
        w = self.LABEL_W + 3 * self.COL_W + self.CHECK_W + 0.3
        h = self.HEAD_H + rows * self.PITCH + 0.22
        self.top = RoundedRectangle(corner_radius=0.22, width=w, height=h, stroke_color=GREY_D, stroke_width=2.5,
                                    fill_color=GREY_E, fill_opacity=0.35).move_to(center)
        left = self.top.get_left()[0] + 0.15
        self.col_x = [left + self.LABEL_W + self.COL_W * (i + 0.5) for i in range(3)]
        self.check_x = left + self.LABEL_W + 3 * self.COL_W + self.CHECK_W / 2
        hy = self.top.get_top()[1] - 0.06 - self.HEAD_H / 2
        self.row_y = [hy - self.HEAD_H / 2 - self.PITCH * (i + 0.5) for i in range(rows)]
        heads = []
        for (name, sym, col), x in zip((("commitment", "R", NONCE), ("challenge", "e", CHAL), ("answer", "s", RESP)),
                                       self.col_x):
            hd = VGroup(T(name, 24, GREY_B), M(sym, 28, col)).arrange(RIGHT, buff=0.1, aligned_edge=DOWN)
            heads.append(hd.move_to([x, hy, 0]))
        self.names = VGroup(*heads)
        self.row_labels = VGroup(*[T(f"run {i + 1}", 24, GREY_B).move_to([left + self.LABEL_W / 2, y, 0])
                                   for i, y in enumerate(self.row_y)])
        self.slot_rows = [VGroup(*[DashedVMobject(RoundedRectangle(corner_radius=0.12, width=self.SLOT_W,
                                                                   height=self.SLOT_H, stroke_color=GREY_C,
                                                                   stroke_width=2), num_dashes=28).move_to([x, y, 0])
                                   for x in self.col_x]) for y in self.row_y]
        self.slots = self.slot_rows[0]
        self.add(self.top, self.names, self.row_labels, *self.slot_rows)

    def cell(self, r, c):
        return np.array([self.col_x[c], self.row_y[r], 0])

    def slot(self, i, r=0):
        return self.cell(r, i)

    def check_at(self, r):
        return np.array([self.check_x, self.row_y[r], 0])

    def slot_box(self, r, c):
        return self.slot_rows[r][c]


def send(scene, mob, target, arc=-0.6, run_time=1.0, trail=None, extra=()):
    """A message travels: small pull-back, arced flight with a fading trail, slight overshoot on arrival."""
    start = mob.get_center()
    target = np.array(target)
    away = start - target
    away = away / (np.linalg.norm(away) + 1e-9) * 0.15
    tr = None
    if trail is not None:
        tr = TracedPath(mob.get_center, stroke_color=trail, stroke_width=4, dissipating_time=0.45, stroke_opacity=[0, 0.8])
        scene.add(tr)
    scene.play(mob.animate.shift(away), run_time=0.18, rate_func=rate_functions.ease_out_quad)
    scene.play(mob.animate(path_arc=arc).move_to(target), *extra, run_time=run_time,
               rate_func=rate_functions.ease_out_back)
    if tr is not None:
        scene.wait(0.3)
        scene.remove(tr)


def ripple(point, color, radius=0.7):
    """An expanding ring that fades: 'something just landed here'."""
    ring = Circle(radius=0.08, stroke_color=color, stroke_width=4).move_to(point)
    return Succession(FadeIn(ring, run_time=0.01),
                      ring.animate(rate_func=rate_functions.ease_out_cubic, run_time=0.6).scale(radius / 0.08).set_stroke(opacity=0),
                      FadeOut(ring, run_time=0.01))


def roll_die(scene, start, land, value, color, run_time=1.1):
    """A die is thrown from `start`, tumbles along an arc, lands with a bounce, and turns into a chip."""
    d = die(5, size=0.62, color=WHITE).move_to(start)
    scene.play(FadeIn(d, scale=0.5), run_time=0.2)
    land = np.array(land)
    scene.play(d.animate(path_arc=-1.2).move_to(land + UP * 0.25).rotate(-2.5 * TAU),
               run_time=run_time * 0.7, rate_func=rate_functions.ease_in_quad)
    scene.play(d.animate.move_to(land).rotate(-0.25 * TAU), run_time=run_time * 0.3, rate_func=rate_functions.ease_out_bounce)
    c = chip(value, color).move_to(land)
    scene.play(ReplacementTransform(d, c), ripple(land, color), run_time=0.45)
    return c


class Blender(VGroup):
    """The hash machine: a jar with blades on a base, and a print slot on its side."""

    def __init__(self, color=WHITE, scale=1.0, **kw):
        super().__init__(**kw)
        jar = Polygon([-0.7, 0.85, 0], [0.7, 0.85, 0], [0.5, -0.45, 0], [-0.5, -0.45, 0],
                      stroke_color=color, stroke_width=4, fill_color=GREY_E, fill_opacity=0.6)
        lid = RoundedRectangle(corner_radius=0.06, width=1.6, height=0.16, stroke_color=color, stroke_width=3,
                               fill_color=color, fill_opacity=0.3).next_to(jar, UP, buff=0.02)
        base = RoundedRectangle(corner_radius=0.12, width=1.3, height=0.6, stroke_color=color, stroke_width=4,
                                fill_color=GREY_E, fill_opacity=0.9).next_to(jar, DOWN, buff=0.0)
        self.hub = Dot(jar.get_center() + DOWN * 0.15, radius=0.06, color=color)
        self.blades = VGroup(*[Line(ORIGIN, RIGHT * 0.42).rotate(a, about_point=ORIGIN).shift(self.hub.get_center())
                               for a in (0, PI / 2, PI, 3 * PI / 2)]).set_stroke(color, 4)
        self.label = M("H", 34, color).move_to(base)
        self.jar, self.lid, self.base = jar, lid, base
        self.add(jar, lid, base, self.blades, self.hub, self.label)
        self.scale(scale)

    def mouth(self):
        return self.lid.get_center()

    def spin(self, turns=2.0, run_time=1.0):
        return Rotate(self.blades, angle=-TAU * turns, about_point=self.hub.get_center(), run_time=run_time,
                      rate_func=rate_functions.ease_in_out_cubic)


def swallow(scene, mobs, blender, run_time=1.0):
    """Inputs spiral down into the blender and vanish while the blades spin."""
    anims = [m.animate(path_arc=-1.5).move_to(blender.hub).scale(0.15).set_opacity(0) for m in mobs]
    scene.play(*anims, blender.spin(1.5, run_time), run_time=run_time)
    scene.remove(*mobs)


class Avatar(VGroup):
    """A character: head with eyes that can look around, shoulders, name. kind="forger" adds a mask."""

    def __init__(self, name, color, kind="person", scale=1.0, **kw):
        super().__init__(**kw)
        self.color = color
        self.head = Circle(radius=0.42, stroke_color=color, stroke_width=4, fill_color=color, fill_opacity=0.22)
        self.body = Sector(radius=0.78, angle=PI, stroke_color=color, stroke_width=4, fill_color=color,
                           fill_opacity=0.22).next_to(self.head, DOWN, buff=0.1)
        self.eyes = VGroup(*[Circle(radius=0.085, stroke_width=0, fill_color=WHITE, fill_opacity=1)
                             .move_to(self.head.get_center() + np.array([dx, 0.06, 0])) for dx in (-0.15, 0.15)])
        self.pupils = VGroup(*[Dot(e.get_center(), radius=0.042, color=BLACK) for e in self.eyes])
        parts = [self.head, self.body]
        if kind == "forger":
            self.mask = RoundedRectangle(corner_radius=0.08, width=0.78, height=0.24, stroke_width=0,
                                         fill_color=BLACK, fill_opacity=0.9).move_to(self.eyes)
            parts.append(self.mask)
        parts += [self.eyes, self.pupils]
        self.name = T(name, 36, color).next_to(self.body, DOWN, buff=0.15)
        self.add(*parts, self.name)
        self.scale(scale)

    def look(self, target):
        """Animation: pupils shift toward a point (or back to centre when target is None)."""
        moves = []
        for e, pu in zip(self.eyes, self.pupils):
            if target is None:
                to = e.get_center()
            else:
                d = np.array(target) - e.get_center()
                d[2] = 0
                to = e.get_center() + (d / (np.linalg.norm(d) + 1e-9)) * e.width * 0.28
            moves.append(pu.animate.move_to(to))
        return AnimationGroup(*moves, run_time=0.3)


def program_window(avatar):
    """The forger as a program: a window frame with a title bar, sized to wrap the avatar and its name."""
    frame = RoundedRectangle(corner_radius=0.15, width=2.4, height=avatar.height + 0.62, stroke_color=GREY_A,
                             stroke_width=3)
    frame.move_to(avatar.get_center() + UP * 0.22)
    bar = Line(frame.get_corner(UL) + DOWN * 0.38, frame.get_corner(UR) + DOWN * 0.38).set_stroke(GREY_A, 2)
    dots = VGroup(*[Dot(radius=0.05, color=c) for c in (BAD, SECRET, RESP)]).arrange(RIGHT, buff=0.1)
    dots.move_to(frame.get_corner(UL) + RIGHT * 0.35 + DOWN * 0.19)
    g = VGroup(frame, bar, dots)
    g.frame = frame
    return g


def key_icon(color=SECRET, scale=1.0):
    """A plain key: ring, shaft, two teeth. Used for 'secret key' in the hook and the payoff."""
    ring = Circle(radius=0.22, stroke_color=color, stroke_width=5)
    shaft = Line(ring.get_right(), ring.get_right() + RIGHT * 0.75).set_stroke(color, 5)
    teeth = VGroup(*[Line(shaft.get_end() + LEFT * d, shaft.get_end() + LEFT * d + DOWN * 0.16).set_stroke(color, 5)
                     for d in (0.02, 0.22)])
    return VGroup(ring, shaft, teeth).scale(scale)


def message_card(text=r"Pay Bob 10 coins", signer="Alice", width=4.2):
    """A signed message: the text, a green signature scrawl, and the signer's name."""
    frame = RoundedRectangle(corner_radius=0.15, width=width, height=2.4, stroke_color=GREY_A, stroke_width=3)
    msg = T(text, 40).move_to(frame.get_top() + DOWN * 0.6)
    scrawl = FunctionGraph(lambda t: 0.13 * np.sin(6 * t) * np.exp(-0.5 * t) + 0.04 * np.sin(17 * t),
                           x_range=[0, 1.9], color=RESP, stroke_width=4)
    scrawl.move_to(frame.get_bottom() + UP * 0.8 + RIGHT * 0.4)
    name = T(r"--- " + signer, 30, GREY_B).next_to(scrawl, DOWN, buff=0.12).align_to(scrawl, RIGHT)
    g = VGroup(frame, msg, scrawl, name)
    g.frame, g.msg, g.scrawl, g.name = frame, msg, scrawl, name
    return g


def branch(a, b, color, width=5):
    """A smooth S-curve from a to b; the shape of one branch of the fork."""
    a, b = np.array(a, dtype=float), np.array(b, dtype=float)
    pull = RIGHT * abs(b[0] - a[0]) * 0.45
    return CubicBezier(a, a + pull, b - pull, b).set_stroke(color, width)


def fork_paths(start, fork, end1, end2, width=5):
    """Trunk (shared history) plus two branches: run 1 in CHAL, run 2 in CHAL2."""
    trunk = Line(start, fork).set_stroke(GREY_A, width)
    return trunk, branch(fork, end1, CHAL, width), branch(fork, end2, CHAL2, width)


def rewind_glyph(size=60, color=WHITE):
    tri = VGroup(*[Triangle(fill_color=color, fill_opacity=1, stroke_width=0).scale(0.22).rotate(PI / 2) for _ in range(2)])
    tri.arrange(RIGHT, buff=-0.05)
    return tri.scale(size / 60)


def strike(mob, color=BAD, width=6):
    return Line(mob.get_corner(DL) + LEFT * 0.1, mob.get_corner(UR) + RIGHT * 0.1).set_stroke(color, width)


class AnswerPlot(VGroup):
    """The running picture: challenge e (across) vs answer s (up). Alice's answers lie on s = k + e x."""

    E_MAX, S_MAX = 10, 80

    def __init__(self, width=6.4, height=4.6, **kw):
        super().__init__(**kw)
        self.axes = Axes(x_range=[0, self.E_MAX, 1], y_range=[0, self.S_MAX, 10], x_length=width, y_length=height,
                         axis_config={"stroke_color": GREY_B, "stroke_width": 2.5, "include_tip": False,
                                      "tick_size": 0.06})
        self.e_lab = T(r"challenge", 30, GREY_A).next_to(self.axes.x_axis, DOWN, buff=0.25)
        self.s_lab = T(r"answer", 30, GREY_A).next_to(self.axes.y_axis, UP, buff=0.15)
        self.add(self.axes, self.e_lab, self.s_lab)

    def p(self, e, s):
        return self.axes.c2p(e, s)

    def dot(self, e, s, color, r=0.11):
        return Dot(self.p(e, s), radius=r, color=color)

    def line(self, k, slope, color, width=4):
        """The part of s = k + slope*e that lies inside the plot box."""
        es = [e for e in np.linspace(0, self.E_MAX, 401) if 0 <= k + slope * e <= self.S_MAX]
        return Line(self.p(es[0], k + slope * es[0]), self.p(es[-1], k + slope * es[-1])).set_stroke(color, width)

    def tick(self, e=None, s=None, color=GREY_A, size=28):
        """A number on an axis at e (across) or s (up)."""
        if e is not None:
            return M(str(e), size, color).next_to(self.p(e, 0), DOWN, buff=0.12)
        return M(str(s), size, color).next_to(self.p(0, s), LEFT, buff=0.12)


def plot_point(scene, plot, e_mob, s_mob, e, s, color, run_time=0.9):
    """Copies of the challenge and answer fly to the axes, guides grow, and the point lands with a ripple."""
    ex = M(str(e), 30, e_mob.num.get_color() if hasattr(e_mob, "num") else color)
    sy = M(str(s), 30, s_mob.num.get_color() if hasattr(s_mob, "num") else color)
    ex.next_to(plot.p(e, 0), DOWN, buff=0.12)
    sy.next_to(plot.p(0, s), LEFT, buff=0.12)
    src_e = (e_mob.num if hasattr(e_mob, "num") else e_mob).copy()
    src_s = (s_mob.num if hasattr(s_mob, "num") else s_mob).copy()
    scene.play(src_e.animate(path_arc=-0.5).move_to(ex).match_height(ex), run_time=run_time)
    scene.play(src_s.animate(path_arc=0.5).move_to(sy).match_height(sy), run_time=run_time)
    scene.remove(src_e, src_s)
    scene.add(ex, sy)
    gv = DashedLine(plot.p(e, 0), plot.p(e, s), color=GREY_C, dash_length=0.07)
    gh = DashedLine(plot.p(0, s), plot.p(e, s), color=GREY_C, dash_length=0.07)
    scene.play(Create(gv), Create(gh), run_time=0.6)
    dot = plot.dot(e, s, color)
    scene.play(FadeIn(dot, scale=3), ripple(plot.p(e, s), color), run_time=0.6)
    return VGroup(dot, ex, sy, gv, gh)


class PivotLine(VGroup):
    """A line through (e0, s0) whose slope follows a ValueTracker, with a live slope readout."""

    def __init__(self, plot, e0, s0, slope=7.0, color=GREY_A, **kw):
        super().__init__(**kw)
        self.plot, self.e0, self.s0 = plot, e0, s0
        self.k = ValueTracker(slope)
        self.line = always_redraw(lambda: plot.line(s0 - e0 * self.k.get_value(), self.k.get_value(), color, 4))
        self.add(self.line)

    def readout(self, at):
        lab = T(r"steepness", 30, GREY_A)
        val = DecimalNumber(self.k.get_value(), num_decimal_places=1, font_size=40, color=SECRET)
        val.add_updater(lambda m: m.set_value(self.k.get_value()))
        g = VGroup(lab, val).arrange(RIGHT, buff=0.25).move_to(at)
        val.add_updater(lambda m: m.next_to(lab, RIGHT, buff=0.25))
        return g
