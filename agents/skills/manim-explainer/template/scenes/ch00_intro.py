import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from common import *  # noqa: F401,F403

SIDE = P_TEAL   # concept colors, as fixed in docs/storyboard.md
AREA = P_ORANGE


class Ch00(VoiceScene):
    """Sample chapter: a what-if demo driven by a live value, landing on narration cues. Replace it."""

    def construct(self):
        s = ValueTracker(1)
        sq = always_redraw(lambda: Square(s.get_value() * 1.6, stroke_color=SIDE, fill_color=AREA,
                                          fill_opacity=0.25).move_to(LEFT * 2.5))
        side = always_redraw(lambda: VGroup(T("side", 30, SIDE), DecimalNumber(s.get_value(), font_size=36, color=SIDE))
                             .arrange(RIGHT).move_to(RIGHT * 3 + UP * 0.6))
        area = always_redraw(lambda: VGroup(T("area", 30, AREA), DecimalNumber(s.get_value() ** 2, font_size=36, color=AREA))
                             .arrange(RIGHT).move_to(RIGHT * 3 + DOWN * 0.6))

        with self.beat("c0_1") as b:
            self.play(FadeIn(sq), run_time=0.8)
            b.cue(1)
            self.play(FadeIn(side), FadeIn(area), run_time=0.5)
            self.play(s.animate.set_value(1.5), run_time=b.span(1, None, 0.4))
            self.play(s.animate.set_value(1), run_time=b.span(1, None, 0.3))

        with self.beat("c0_2", gap=0) as b:
            self.play(s.animate.set_value(2), run_time=1.2)
            b.cue(1)
            self.play(Indicate(area, color=FOCUS), run_time=0.8)
        self.fade_all()
