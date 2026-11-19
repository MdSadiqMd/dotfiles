import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from common import *  # noqa: F401,F403
from kit_nn import Net  # noqa: E402
from kit_protocol import *  # noqa: F401,F403


class Ch99(VoiceScene):
    """Toolchain self-test, run by setup.py before a new Manim/Pillow/numpy/Kokoro is put in use. It touches every
    template helper once (text, LaTeX, Pango, cards, kits, trackers, camera, images, sound), so an upgrade that
    breaks one of them fails here and the previous toolchain stays in place."""

    def construct(self):
        ann = Avatar("Ann", P_BLUE, scale=0.7).move_to([-5.6, -2.2, 0])
        box = LockBox("7").move_to([-4.6, 2.3, 0])
        rule = card(grid([[T("side", 28, GREY_A), MC("s", "^2", size=32, colors={0: P_GOLD})],
                          [code("area()", 26), TC(("grows ", GREY_A), ("fast", P_RED), size=28)]]),
                    title="rule", center=[3.6, 2.1, 0])
        lines = code_col(["def f(x):", "    return x * x"], size=22).move_to([3.6, 0.0, 0])
        eq = box_row([label_box("a", 1.0, 0.6), M("+", 36), label_box("b", 1.0, 0.6, color=P_GREEN)], y=-1.4, x=3.6)
        with self.beat("c99_1") as b:
            self.play(FadeIn(ann), FadeIn(box), run_time=0.6)
            self.play(FadeIn(rule), Write(lines), run_time=b.span(0, 1, 0.6))
            b.cue(1)
            self.play(box.opened(), ann.look(box.get_center()), FadeIn(eq, shift=UP * 0.2), run_time=0.8)
            self.camera.frame.save_state()
            self.play(self.camera.frame.animate.scale(1.08), run_time=0.5)
            self.play(Restore(self.camera.frame), run_time=0.5)
        self.fade_except(ann)

        v = ValueTracker(0)
        num = always_redraw(lambda: DecimalNumber(v.get_value(), num_decimal_places=2, font_size=40, color=P_GOLD)
                            .move_to([-1.8, 2.6, 0]))
        mat = cell_grid([[0.5, -0.3], [-0.8, 1.0]]).move_to([-3.2, 0.4, 0])
        vec = vector_cells([0.2, 0.9, 0.4], P_PURPLE, decimals=1).move_to([-1.8, 0.4, 0])
        bars, parts = hbars([("one", 3, P_TEAL, "3"), ("two", 5, P_ORANGE, "5")], 5, width=2.6)
        bars.move_to([2.2, 2.3, 0])
        steps = roadmap(["one", "two"], current=1).scale(0.45).move_to([5.4, 2.4, 0])
        net = Net([2, 3, 2]).scale(0.55).move_to([1.6, -0.6, 0])
        img = still("selftest.png", height=1.1).move_to([5.3, 0.4, 0])
        tokens = VGroup(chip(3, P_ORANGE), answer_card(5, P_GREEN)).arrange(RIGHT, buff=0.3).move_to([-1.0, -2.4, 0])
        blender = Blender(scale=0.6).move_to([4.6, -2.2, 0])
        with self.beat("c99_2") as b:
            self.play(FadeIn(num), FadeIn(mat), FadeIn(vec), FadeIn(bars), FadeIn(steps), FadeIn(img), run_time=0.6)
            self.play(v.animate.set_value(4.76), run_time=b.span(0, 1, 0.6))
            b.cue(1)
            self.play(FadeIn(net), FadeIn(tokens), FadeIn(blender), run_time=0.4)
            for step in net.forward_sweep([[1, 0.3], [0.2, 0.9, 0.5], [0.7, 0.1]], run_time=0.3):
                self.play(step)
            send(self, tokens[0], [2.0, -2.4, 0], trail=P_ORANGE, run_time=0.5)
            self.play(ripple([2.0, -2.4, 0], P_ORANGE), run_time=0.4)
            swallow(self, [tokens[1]], blender, run_time=0.6)
        self.fade_all()
