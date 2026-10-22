import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from common import *  # noqa: F401,F403


class Ch00(VoiceScene):
    def construct(self):
        rng = np.random.default_rng(0)
        net = Net([4, 6, 6, 4], seed=2)
        acts = [rng.uniform(0.2, 1.0, n) for n in net.sizes]

        with self.beat("c0_1") as b:
            self.play(LaggedStart(*[GrowFromCenter(n) for n in net.all_neurons()], lag_ratio=0.03), run_time=1.2)
            self.play(Create(net.edges), run_time=0.8)
            b.cue(1)
            for step in net.forward_sweep(acts, run_time=b.span(1, None, 0.8) / len(net.sizes)):
                self.play(step)

        with self.beat("c0_2", gap=0) as b:
            b.cue(1)
            self.play(Transform(net.edges, net.colored_edges()), run_time=1.2)
        self.fade_all()
