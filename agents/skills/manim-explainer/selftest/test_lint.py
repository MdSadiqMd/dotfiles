"""Every layout fault a viewer reported must be flagged, and its fixed version must not be.

  <render venv>/bin/python selftest/test_lint.py <project dir>     # a project: anything with scenes/ and durations.json
setup.py runs it before a new Manim is put in use: the lint reads Manim's geometry, so an upgrade can blind it."""
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(sys.argv[1]).resolve()
sys.path.insert(0, str(ROOT / "scenes"))
sys.path.insert(0, str(ROOT / "tools"))
os.environ["PATH"] = __import__("env").tool_path()
from common import *  # noqa: E402,F401,F403
from lint import check  # noqa: E402


def box(text, at):
    return label_box(text, 2.0, 0.7).move_to(at)


def note_grid():
    return VGroup(*[RoundedRectangle(corner_radius=0.03, width=0.17, height=0.22, stroke_width=1, stroke_color=GREY_C,
                                     fill_color=GREY_E, fill_opacity=0.8) for _ in range(150)]).arrange_in_grid(10, 15, buff=0.05)


def loose_cells():  # fixed-size cells, numbers wider than them
    return VGroup(*[Square(0.5, stroke_color=P_GOLD).add(DecimalNumber(v, num_decimal_places=3, font_size=26))
                    for v in (-0.039, 0.05)]).arrange(RIGHT, buff=0.3)


def regions(buff):
    a, b, c = [box(t, [x, 0, 0]) for t, x in (("A", -4), ("B", 0), ("C", 4))]
    w = DashedVMobject(SurroundingRectangle(VGroup(a, b), color=P_GREEN, buff=0.15), num_dashes=60)
    r = DashedVMobject(SurroundingRectangle(VGroup(b, c), color=P_BLUE, buff=buff), num_dashes=60)
    return a, b, c, w, r


# name -> (expected words in a warning, or None for clean; mobjects in draw order)
def cases():
    wave = FunctionGraph(lambda x: 0.4 * np.sin(8 * x), x_range=[-4, 4], color=P_TEAL)
    yield "curve through a label", "crossed by FunctionGraph", [wave, T("next slice")]
    ghost = wave.copy().fade(0.85)
    frame = RoundedRectangle(width=4, height=2, stroke_color=GREY_D, fill_color=GREY_E, fill_opacity=0.35)
    yield "dimmed stage shows through a panel", "shows through", [ghost, frame, T("note", 24).move_to([0, 0.7, 0])]
    yield "card hides the dimmed stage", None, [ghost, card(T("a note"))]
    yield "stage faded out enough", None, [wave.copy().fade(0.96), T("note")]
    yield "numbers wider than their cells", "crossed by Square", [loose_cells()]
    yield "vector_cells fits its numbers", None, [vector_cells([-0.039, 0.05, 0.88], P_GOLD, decimals=3, size=26, direction=RIGHT)]
    yield "numbers recoloured like their cells", "low contrast", [vector_cells([0.9], P_ORANGE, decimals=2, text_color="#8A5A2A")]
    yield "label over a field of small boxes", "crossed by", [note_grid(), T("one long label over them all", 26)]
    yield "the same label on a plate", None, [note_grid(), backed(T("one label over them", 26))]
    a, b, c, w, r = regions(0.3)
    yield "a later region's border through a label", "crossed by", [a, b, c, w, T("write: W = 2", 24, P_GREEN).next_to(w, UP, buff=0.1), r]
    yield "the label placed clear of both", None, [a, b, c, w, r, place_label(T("write: W = 2", 24, P_GREEN), w, avoid=[a, b, c, w, r])]
    bar = Rectangle(width=0.18, height=1.1, stroke_width=0, fill_color=P_PURPLE, fill_opacity=0.9).move_to([1, 0, 0])
    yield "thin bar over a long label", "crossed by Rectangle", [T("waits until storage returns", 24), bar]
    n1, n2 = box("one", [-3, 1.5, 0]), box("two", [3, -1, 0])
    d = n2.get_center() - n1.get_center()
    stub = Line(n1.get_center() + 0.21 * d, n2.get_center() - 0.21 * d, stroke_color=P_BLUE)
    yield "connector stops short", "short of box", [n1, n2, stub]
    yield "connector runs into a box", "into box", [n1, n2, Line(n1.get_center() + d * 0.05, n2.get_center() - d * 0.2)]
    line = connect(n1, n2)
    n1.shift(RIGHT)
    line.update()
    yield "connect() follows a moved box", None, [n1, n2, line]
    yield "connect() arrow", None, [n1, n2, connect(n1, n2, arrow=True)]
    yield "dark label on a bright chip, crossed", "crossed by Line", [
        Rectangle(width=3, height=0.6, stroke_width=0, fill_color=GREY_B, fill_opacity=0.9), T("lunch", 30, BLACK), Line(UP, DOWN)]
    yield "label under an opaque shape", "hidden behind", [T("gone"), Square(3, stroke_width=0, fill_color=P_BLUE, fill_opacity=1)]
    yield "label off the frame", "out of frame", [T("wide").move_to([7, 0, 0])]
    yield "labels overlap", "labels overlap", [T("one"), T("two").shift(RIGHT * 0.1)]
    yield "label cramped in its box", "cramped", [RoundedRectangle(width=T("tight").width + 0.06, height=0.8, stroke_color=WHITE), T("tight")]
    yield "label crowds a box", "crowds", [n2, T("below", 24).next_to(n2, DOWN, buff=0.04)]
    word = T("wrong")
    yield "strike-through (Cross)", None, [word, Cross(word)]
    strike = Line(word.get_corner(DL), word.get_corner(UR))
    yield "allow() is for one label only", "crossed by Line", [T("other").next_to(word, RIGHT, buff=-0.02).shift(DOWN * 2),
                                                               word.copy().shift(DOWN * 2), strike.copy().shift(DOWN * 2)]
    yield "allow() with a reason", None, [word, allow(strike, word, "struck out on purpose")]
    cells = VGroup(*[Square(0.8, stroke_color=GREY_C) for _ in range(4)]).arrange_in_grid(2, 2, buff=0)
    nums = VGroup(*[M(str(k), 30).move_to(q) for k, q in enumerate(cells)])
    yield "arrow between table cells", None, [cells, nums, Arrow(nums[0].get_corner(DR), nums[3].get_corner(UL), buff=0.05)]
    ax = Axes(x_range=[0, 4], y_range=[0, 2], x_length=4, y_length=2, tips=False).add_coordinates()
    yield "axis numbers", None, [ax]
    yield "stock helpers", None, [roadmap(["one", "two"], current=0).scale(0.5).to_edge(LEFT), box_row([box("a", ORIGIN), M("+"), box("b", ORIGIN)], y=2),
                                  hbars([("one", 3, P_TEAL, "3"), ("two", 5, P_ORANGE, "5")], 5, width=2)[0].move_to([2, -1.5, 0])]


def main():
    failed = 0
    with tempfile.TemporaryDirectory() as tmp, tempconfig({"dry_run": True, "verbosity": "ERROR", "media_dir": tmp}):
        for name, want, mobs in cases():
            scene = VoiceScene()
            scene.add(*mobs)
            found = list(check(scene)[0].values())
            ok = any(want in f for f in found) if want else not found
            if not ok:
                failed += 1
                print(f"FAIL {name}: wanted {want or 'clean'}, got {found or 'clean'}")
        cells = [T("yes", 28), T("hard", 28), T("(one) user", 28)]
        grid([cells], col_align="lll")
        lines = [m[0][k].get_bottom()[1] for m, k in zip(cells, (1, 0, 1))]  # e, h, o all sit on the baseline
        if max(lines) - min(lines) > 0.012:
            failed += 1
            print(f"FAIL grid() rows share a baseline: {lines}")
        m = label_box("x", color=P_GOLD)
        a = pulse(m, color=P_RED)
        a.begin()
        a.interpolate(0.5)
        mid = m.box.get_stroke_color()
        a.interpolate(1)
        if mid != ManimColor(P_RED) or m.box.get_stroke_color() != ManimColor(P_GOLD):
            failed += 1
            print(f"FAIL pulse() returns to the box's own colour: {mid}, {m.box.get_stroke_color()}")
    if failed:
        raise SystemExit(f"{failed} lint cases failed")
    print("lint cases passed")


main()
