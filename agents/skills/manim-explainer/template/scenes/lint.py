"""Layout lint: geometry checks on what is drawn, after every `play` and `wait`. Topic-neutral: it knows labels,
outlines, boxes and connectors, nothing about what they mean. common.py calls it; scenes only ever need `allow`.

Why after every play and not once per cue: a label that was clear when it was placed gets crossed by something that
arrives later, and is gone again before the beat ends. Why outlines and not bounding boxes: a thin bar, a dashed
border, a curve and 24 tiny cells each cover only a few percent of a label's box, so every area threshold passed them.

Distances are in scene units. A problem is reported when it stays on screen for HOLD seconds."""
import numpy as np
from manim import Cross, ImageMobject, Line, Rectangle, ThreeDScene, Triangle, Underline, VMobject

HOLD = 0.5        # shorter than this is an object passing through
READABLE = 0.25   # brightness (opacity x colour) from which a label must be readable and a shape counts as solid
FAINT = 0.06      # brightness below which nothing is noticed on black (a stage faded by 0.95 or more)
PAD, CELL_PAD = 0.1, 0.03
LINK_GAP = 0.2    # a connector ends this close to the box it points at
CONTRAST = 3.0    # WCAG's minimum for large text


def _types(*names):
    """The Manim classes among `names` that this Manim version has (a renamed class just drops out)."""
    import manim
    return tuple(c for c in (getattr(manim, n, None) for n in names) if isinstance(c, type))


TEXT = _types("SingleStringMathTex", "Text", "MarkupText", "DecimalNumber", "Integer")
MARKS = (Cross, Underline)  # drawn through or against a label to say something about it


def allow(shape, label, why):
    """Accept one overlap that is the point of the picture (a strike-through, a cursor on a word): `shape` may touch
    `label`, and only that label. The reason is printed with every lint report."""
    ids = {id(f) for f in label.get_family()}
    for f in shape.get_family():
        f.lint_ok = [*getattr(f, "lint_ok", []), (ids, why)]
    return shape


def _rgb(color):  # None: a mobject built without a stroke or fill colour
    return np.zeros(3) if color is None else np.array(color.to_rgb(), dtype=float)


def _luma(rgb):
    lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    return float(lin @ np.array([0.2126, 0.7152, 0.0722]))


def bounds(points):
    lo, hi = points.min(axis=0), points.max(axis=0)
    return np.array([lo[0], lo[1], hi[0], hi[1]])


def outline(m):
    """A mobject's own outline as straight pieces (N, 4): one per straight bezier, eight per curved one."""
    n = len(m.points) // 4
    c = np.asarray(m.points)[:n * 4, :2].reshape(n, 4, 2)
    chord, off = c[:, 3] - c[:, 0], c[:, 1:3] - c[:, :1]
    bend = np.abs(chord[:, None, 0] * off[..., 1] - chord[:, None, 1] * off[..., 0])
    curved = bend.max(axis=1) > 0.02 * (np.hypot(*chord.T) + 1e-9)
    t = np.linspace(0, 1, 9)[None, :, None]
    b = c[curved][:, None, :, :]
    p = (1 - t) ** 3 * b[:, :, 0] + 3 * (1 - t) ** 2 * t * b[:, :, 1] + 3 * (1 - t) * t ** 2 * b[:, :, 2] + t ** 3 * b[:, :, 3]
    bent = np.concatenate([p[:, :-1], p[:, 1:]], axis=2).reshape(-1, 4)
    return np.concatenate([np.concatenate([c[~curved][:, 0], c[~curved][:, 3]], axis=1), bent])


class Leaf:
    """One drawn VMobject: its own points (a Square that holds a number as a submobject still draws its border)."""
    __slots__ = ("m", "box", "top", "order", "fill", "fill_rgb", "stroke_v", "fill_v", "unit", "mark", "_segs")

    def __init__(self, m, top, order, unit, mark):
        self.m, self.top, self.order, self.unit, self.mark = m, top, order, unit, mark
        pts = np.asarray(m.points)
        n = len(pts) // 4
        self.box = bounds(np.concatenate([pts[0:n * 4:4, :2], pts[3:n * 4:4, :2]]))
        self.fill, self.fill_rgb = float(m.get_fill_opacity()), _rgb(m.get_fill_color())
        self.fill_v = self.fill * self.fill_rgb.max()
        self.stroke_v = float(m.get_stroke_opacity()) * _rgb(m.get_stroke_color()).max() if m.get_stroke_width() > 0 else 0.0
        self._segs = None

    @property
    def v(self):
        return max(self.stroke_v, self.fill_v)

    @property
    def segs(self):
        if self._segs is None:
            self._segs = outline(self.m)
        return self._segs


class Label:
    """A text object that reads as one unit, with the boxes of its glyphs."""
    __slots__ = ("m", "name", "box", "glyphs", "v", "opacity", "rgb", "bg", "order", "top", "ids")

    def __init__(self, m, leaves):
        self.m, self.top, self.ids = m, leaves[0].top, {id(f) for f in m.get_family()}
        text = getattr(m, "tex_string", None) or getattr(m, "text", None)
        if text is None:
            text = f"{m.get_value():g}" if hasattr(m, "get_value") else type(m).__name__
        self.name = f"'{str(text).replace('minipage', '')[:28]}'"
        self.glyphs = np.array([lf.box for lf in leaves])
        self.box = np.concatenate([self.glyphs[:, :2].min(axis=0), self.glyphs[:, 2:].max(axis=0)])
        self.v = max(lf.v for lf in leaves)
        lead = max(leaves, key=lambda lf: lf.fill)
        self.opacity, self.rgb, self.bg = lead.fill, lead.fill_rgb, np.zeros(3)
        self.order = max(lf.order for lf in leaves)

    def at(self):
        return f"{self.name} at ({(self.box[0] + self.box[2]) / 2:.2f},{(self.box[1] + self.box[3]) / 2:.2f})"


def _at(b):
    return f"({(b[0] + b[2]) / 2:.2f},{(b[1] + b[3]) / 2:.2f})"


def _meets(a, b, tol=0.0):
    return a[0] < b[2] + tol and b[0] < a[2] + tol and a[1] < b[3] + tol and b[1] < a[3] + tol


def _in(a, b, tol=0.0):
    return a[0] >= b[0] - tol and a[1] >= b[1] - tol and a[2] <= b[2] + tol and a[3] <= b[3] + tol


def _gap(a, b):
    return max(b[0] - a[2], a[0] - b[2], b[1] - a[3], a[1] - b[3])


def hits(segs, boxes):
    """Does any segment pass through any box? Slab test of every segment against every box at once."""
    if not len(segs) or not len(boxes):
        return False
    p, d = segs[:, None, :2], (segs[:, 2:] - segs[:, :2])[:, None, :]
    with np.errstate(divide="ignore", invalid="ignore"):
        t1, t2 = (boxes[None, :, :2] - p) / d, (boxes[None, :, 2:] - p) / d
    flat = np.abs(d) < 1e-9
    within = (p >= boxes[None, :, :2]) & (p <= boxes[None, :, 2:])
    lo = np.where(flat, np.where(within, -np.inf, np.inf), np.minimum(t1, t2))
    hi = np.where(flat, np.where(within, np.inf, -np.inf), np.maximum(t1, t2))
    return bool((np.maximum(lo.max(axis=2), 0) <= np.minimum(hi.min(axis=2), 1)).any())


def _core(t):
    """Glyph boxes shrunk by a hair (touching is not crossing), widened inside the label to close its word gaps."""
    g = t.glyphs + np.array([-0.08, 0.015, 0.08, -0.015])
    g[:, 0], g[:, 2] = np.maximum(g[:, 0], t.box[0] + 0.015), np.minimum(g[:, 2], t.box[2] - 0.015)
    return g[(g[:, 2] > g[:, 0]) & (g[:, 3] > g[:, 1])]


def _collect(scene):
    frame = getattr(scene.camera, "frame", None)
    tops = [m for m in scene.mobjects if m is not frame]
    units, drawn, images, seen = {}, [], [], set()

    def walk(m, top, unit, mark):
        mark = mark or isinstance(m, MARKS)
        if unit is None and isinstance(m, TEXT):
            unit = m
        if id(m) not in seen:
            seen.add(id(m))
            if isinstance(m, ImageMobject):
                images.append((m, top))
            elif isinstance(m, VMobject) and len(m.points) >= 4:
                drawn.append((m, top, unit, mark))
        for s in m.submobjects:
            walk(s, top, unit, mark)

    for t in tops:
        walk(t, t, None, False)
    drawn.sort(key=lambda d: d[0].z_index)  # stable, as Manim draws
    leaves = [Leaf(m, top, k, unit, mark) for k, (m, top, unit, mark) in enumerate(drawn)]
    leaves = [lf for lf in leaves if np.isfinite(lf.box).all()]
    for lf in leaves:
        if lf.unit is not None:
            units.setdefault(id(lf.unit), (lf.unit, []))[1].append(lf)
    labels = [Label(m, ls) for m, ls in units.values()]
    return leaves, labels, images


def _ok(m, label, allowed):
    for ids, why in getattr(m, "lint_ok", []):
        if ids & label.ids:
            allowed.add(f"allowed on {label.name}: {why}")
            return True
    return False


def check(scene):
    """Problems on screen now: {key: message}. Keys leave out positions, so a moving object stays one problem."""
    out, allowed = {}, set()
    leaves, labels, images = _collect(scene)
    filled = [lf for lf in leaves if lf.unit is None and lf.fill >= 0.15 and not lf.mark]
    for t in labels:
        for lf in filled:
            if lf.order < t.order and _in(t.box, lf.box, 0.02):
                t.bg = t.bg * (1 - lf.fill) + lf.fill_rgb * lf.fill
    # black text on a bright chip is as readable as white text on black
    readable = [t for t in labels if t.v >= READABLE or (t.opacity >= 0.3 and t.bg.max() >= READABLE)]
    read_ids = {id(t.m) for t in readable}
    shapes = [lf for lf in leaves if lf.v >= FAINT and (lf.unit is None or id(lf.unit) not in read_ids)]
    flat = not isinstance(scene, ThreeDScene)  # screen geometry isn't scene geometry under a 3D camera
    opaque = [lf for lf in leaves if lf.unit is None and lf.fill >= 0.9]

    frame = getattr(scene.camera, "frame", None)
    home = np.array([-7.05, -3.97, 7.05, 3.97])
    view, zoomed = home, False
    if frame is not None:
        zoomed = abs(frame.width - 14.222) > 0.05 or np.abs(frame.get_center()[:2]).max() > 0.05
        if zoomed:
            c, w, h = frame.get_center(), frame.width / 2, frame.height / 2
            view = np.array([c[0] - w, c[1] - h, c[0] + w, c[1] + h])
    for t in readable:
        if not _in(t.box, view) and (not zoomed or _meets(t.box, view)):
            out[("frame", t.name)] = f"out of frame: {t.at()}"
    if not zoomed:
        for lf in shapes:
            if lf.unit is None and lf.v >= READABLE and not _in(lf.box, home):
                out[("frame", type(lf.m).__name__)] = f"out of frame: {type(lf.m).__name__} at {_at(lf.box)}"

    for i, a in enumerate(readable):
        for b in readable[i + 1:]:
            if not _meets(a.box, b.box, 0.06):
                continue
            x = np.minimum(a.glyphs[:, None, 2:], b.glyphs[None, :, 2:]) - np.maximum(a.glyphs[:, None, :2], b.glyphs[None, :, :2])
            if (x > 0.005).all(axis=2).any():
                out[("labels", a.name, b.name)] = f"labels overlap: {a.at()} / {b.at()}"
                continue
            across = min(a.box[2], b.box[2]) - max(a.box[0], b.box[0])
            up = max(b.box[1] - a.box[3], a.box[1] - b.box[3])
            if across > 0.3 * min(a.box[2] - a.box[0], b.box[2] - b.box[0]) and -0.05 < up < 0.06:
                out[("labels", a.name, b.name)] = f"labels touch: {a.at()} / {b.at()}"
    if not flat:
        return out, allowed

    for t in readable:
        # whatever is behind an opaque plate that holds the whole label can't disturb it
        floor = max([o.order for o in opaque if o.order < t.order and _in(t.box, o.box, 0.02)], default=-1)
        crossing, core = {}, _core(t)
        for lf in shapes:
            if lf.order < floor or lf.mark or lf.unit is t.m or not _meets(lf.box, t.box):
                continue
            if hits(lf.segs, core) and not _ok(lf.m, t, allowed):
                kind = type(lf.unit or lf.m).__name__
                crossing.setdefault((kind, lf.v < READABLE), []).append(lf)
        for (kind, dim), ls in crossing.items():
            what = f"{len(ls)} x {kind}" if len(ls) > 1 else kind
            out[("cross", t.name, kind)] = (f"label crossed by {'dimmed ' if dim else ''}{what}: {t.at()}, "
                                            f"outline at {_at(ls[0].box)}")
        for o in opaque:
            if o.order > t.order and o.fill >= 0.9 and _in(t.box, o.box) and id(o.m) not in t.ids and not _ok(o.m, t, allowed):
                out[("hidden", t.name)] = f"label hidden behind {type(o.m).__name__}: {t.at()}"
        for im, _ in images:
            b = np.array([*im.get_corner([-1, -1, 0])[:2], *im.get_corner([1, 1, 0])[:2]])
            if _meets(t.box, b, -0.02) and not _in(t.box, b):
                out[("cross", t.name, "image")] = f"label crossed by image edge: {t.at()}"
        if t.bg.any() and not images:
            ink = t.rgb * t.opacity + t.bg * (1 - t.opacity)
            hi, lo = sorted((_luma(ink), _luma(t.bg)), reverse=True)
            if (ratio := (hi + 0.05) / (lo + 0.05)) < CONTRAST:
                out[("contrast", t.name)] = f"low contrast ({ratio:.1f}): {t.at()}"

    solid = [lf for lf in shapes if lf.v >= READABLE and lf.unit is None]
    rects = [lf for lf in solid if isinstance(lf.m, Rectangle) and lf.box[2] - lf.box[0] > 0.2 and lf.box[3] - lf.box[1] > 0.2]
    boxes = [(lf, [t for t in readable if _in(t.box, lf.box)]) for lf in rects]
    boxes = [(lf, inside) for lf, inside in boxes if inside]
    for lf, inside in boxes:
        b = lf.box
        need = PAD if min(b[2] - b[0], b[3] - b[1]) > 0.6 else CELL_PAD
        for t in readable:
            if t in inside:
                pad = min(t.box[0] - b[0], t.box[1] - b[1], b[2] - t.box[2], b[3] - t.box[3])
                if pad < need - 1e-6:
                    out[("cramped", t.name)] = f"label cramped in box at {_at(b)}: {t.at()} (pad {pad:.2f}, needs {need})"
            elif 0 <= (g := _gap(t.box, b)) < PAD - 1e-6 and not _ok(lf.m, t, allowed):
                out[("crowds", t.name)] = f"label crowds box at {_at(b)}: {t.at()} (gap {g:.2f})"
        for other in solid:
            if (other is lf or isinstance(other.m, (Line, Triangle)) or getattr(other.m, "lint_skip", False)
                    or _in(other.box, b) or _in(b, other.box) or len(other.m.points) < 4):
                continue
            w, h = other.box[2] - other.box[0], other.box[3] - other.box[1]
            same = abs(w - (b[2] - b[0])) < 0.02 or abs(h - (b[3] - b[1])) < 0.02  # neighbours in a grid or stack
            if w * h >= 0.03 and not same and 0 <= _gap(other.box, b) < PAD - 1e-6 and isinstance(other.m, Rectangle):
                out[("butts", type(other.m).__name__, _at(b))] = f"{type(other.m).__name__} at {_at(other.box)} butts into box at {_at(b)}"
        if lf.fill < 0.9:
            for g in shapes:
                if (g.v < READABLE and g.unit is None and g.order < lf.order and g.top is not lf.top and _meets(g.box, b, -0.05)
                        and not _in(_top_box(g.top), b) and hits(g.segs, b[None] + np.array([.05, .05, -.05, -.05]))):
                    out[("ghost", _at(b), type(g.top).__name__)] = (
                        f"dimmed {type(g.top).__name__} at {_at(g.box)} shows through box at {_at(b)}: fade it out or use card()/panel()")

    for a in solid:
        area = (a.box[2] - a.box[0]) * (a.box[3] - a.box[1])
        if a.fill < 0.15 or area < 0.04 or isinstance(a.m, (Line, Triangle)) or getattr(a.m, "lint_skip", False):
            continue
        for b in solid:
            if b.fill < 0.15 or b is a or not _meets(a.box, b.box):
                continue
            big = (b.box[2] - b.box[0]) * (b.box[3] - b.box[1])
            ov = (min(a.box[2], b.box[2]) - max(a.box[0], b.box[0])) * (min(a.box[3], b.box[3]) - max(a.box[1], b.box[1]))
            if area < big and ov > 0.15 * area and not _in(a.box, b.box, 0.04):
                out[("poke", type(a.m).__name__, type(b.m).__name__, _at(b.box))] = (
                    f"shape pokes out: {type(a.m).__name__} over {type(b.m).__name__} at {_at(a.box)}")

    cells = [lf for lf, _ in boxes if any(o is not lf and -0.05 < _gap(o.box, lf.box) < 0.02 and
                                          np.abs((o.box[2:] - o.box[:2]) - (lf.box[2:] - lf.box[:2])).max() < 0.02
                                          for o in rects)]  # arrows between the cells of a table end inside them
    _links(solid, [lf for lf, _ in boxes if lf not in cells], out)
    return out, allowed


def _top_box(m):
    p = m.get_points_defining_boundary()
    return bounds(p) if len(p) else np.zeros(4)


def _links(solid, boxes, out):
    """A straight connector whose two ends both aim at a label box must reach both: ends that stop in mid-air or run
    on into the box come from placing lines by the boxes' centres, or from moving a box and not its line."""
    for lf in solid:
        if not isinstance(lf.m, Line) or getattr(lf.m, "lint_skip", False):
            continue
        p, q = lf.m.get_start()[:2], lf.m.get_end()[:2]
        n = float(np.hypot(*(q - p)))
        if n < 0.3:
            continue
        u, ends = (q - p) / n, []
        for end, d in ((p, -u), (q, u)):
            best = None
            for b in boxes:
                if _in([*end, *end], b.box, -0.02):  # inside: how far has it run in?
                    reach = -min(end[0] - b.box[0], end[1] - b.box[1], b.box[2] - end[0], b.box[3] - end[1])
                    both = _in([*p, *p], b.box) and _in([*q, *q], b.box)
                    if not both and (b.fill < 0.9 or b.order < lf.order):
                        best = (reach, b)
                        break
                    continue
                with np.errstate(divide="ignore", invalid="ignore"):
                    t1, t2 = (b.box[:2] - end) / d, (b.box[2:] - end) / d
                lo, hi = np.nanmax(np.minimum(t1, t2)), np.nanmin(np.maximum(t1, t2))
                if 0 <= lo <= hi and lo < 0.8 and (best is None or lo < best[0]):
                    best = (float(lo), b)
            ends.append(best)
        if None in ends or ends[0][1] is ends[1][1]:
            continue
        for reach, b in ends:
            if reach > LINK_GAP + 0.1 or reach < -0.04:
                how = f"stops {reach:.2f} short of" if reach > 0 else f"runs {-reach:.2f} into"
                out[("link", _at(b.box))] = f"connector {how} box at {_at(b.box)}: use connect(a, b)"


class Watch:
    """Follows one scene: how long each problem stays on screen, per beat."""

    def __init__(self):
        self.now, self.held, self.text, self.when, self.allowed = {}, {}, {}, {}, set()

    def step(self, scene, seconds):
        before = self.now
        self.now, allowed = check(scene)
        self.allowed |= allowed
        for k, msg in self.now.items():
            if k in before:
                if k not in self.held:
                    self.when[k] = scene.time - seconds / 2
                self.held[k] = self.held.get(k, 0) + seconds
            self.text[k] = msg

    def flush(self, path):
        """Append what held long enough since the last flush to the beat's file."""
        lines = [f"@{self.when[k]:.1f}s for {self.held[k]:.1f}s  {self.text[k]}" for k in self.held if self.held[k] >= HOLD]
        lines += [f"-  {a}" for a in sorted(self.allowed)]
        self.held, self.allowed = {}, set()
        if lines:
            path.parent.mkdir(parents=True, exist_ok=True)
            with open(path, "a") as fh:
                fh.write("\n".join(lines) + "\n")
