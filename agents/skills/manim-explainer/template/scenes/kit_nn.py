"""Example domain kit: neural networks drawn the 3b1b way.

Neurons are POS-stroked circles filled WHITE by activation; edges are POS (+) / NEG (-) with width
by |w|; the forward pass is a FOCUS ShowPassingFlash. Copy this pattern for other domains: one small
file of reusable mobjects per topic (scenes/kit_<domain>.py), built on common.py.
"""
from common import *  # noqa: F401,F403


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

    def flash(self, i, color=FOCUS, backward=False, run_time=0.7, width=4):
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


def nudge_arrow(anchor, value, scale=0.55, color=P_ORANGE):
    """3b1b-style arrow beside a neuron showing g there: up for +, down for -."""
    length = max(0.12, scale * abs(value))
    start = anchor + RIGHT * 0.32
    return Arrow(start, start + UP * length * np.sign(value), buff=0, color=color,
                 stroke_width=4, max_tip_length_to_length_ratio=0.45, tip_length=0.14)
