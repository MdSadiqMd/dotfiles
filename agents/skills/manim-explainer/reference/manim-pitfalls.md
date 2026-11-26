# Manim CE pitfalls (each one cost a render)

## Opacity and fill
- `set_opacity(x)` sets fill *and* stroke. On outline shapes (`Circle`, `RoundedRectangle`, `Triangle`) it
  turns the fill on: a dimmed outline becomes a solid red/white blob, an outline die becomes a white square.
  Dim with `.fade(a)` and restore with `save_state()` + `Restore()`. Give outline shapes `fill_opacity=0`.
- Hand-built paths (`VMobject()` with `add_line_to`, routes, curves) must be created with `fill_opacity=0`,
  or dimming fills them into triangles.
- `FadeOut(mob)` restores the mobject's opacity after removing it. Animating it again later (a `Rotate` on
  blender blades) brings it back at full opacity. After a fade-out that should be permanent, remove the part
  from its parent (`H.remove(H.blades)`).
- An object that should appear later: build it, `parent.remove(part)`, and `add` it back when needed. Don't
  hide it with `set_opacity(0)` and bring it back with `set_opacity(1)` (see above).

## Groups and scene membership
- Animating a child of a group registers it on its own. Call `self.drop(group)` before re-adding, or you get
  ghost copies and dead updaters.
- `VGroup(*self.mobjects)` fails (the scene holds non-VMobjects); filter with `isinstance(m, VMobject)`.
- `ImageMobject` can't go in a `VGroup`; use `Group`.
- `always_redraw` objects have no stable identity: clear updaters before transforming them.

- Draw order is the order things were first animated in, not their order in the group. An opaque box faded in after
  one of its rows would hide it, so `card`/`panel`/`label_box` raise their contents by `z_index` 0.5. Do the same for
  contents you add to a `panel` before showing it.
- `set_color` on a group recolours the text inside it too: numbers end up in their own cell's colour. Rebuild instead.
- `Indicate(m, color=…)` paints fills as well: on an opaque card it is a blank slab over its own text. Use
  `pulse(m)`. The lint looks at rest points, so only the frames show this one.
- `TransformFromCopy` / `ReplacementTransform` between two *different* texts shows half-morphed letters. Use
  `arrive(card, source)`, or fade one out and the other in.
- `self.remove(*[m for m in self.mobjects if m not in keep])` also removes the split-up parts of a character whose eyes
  were animated. Remove what you created by name.
- A submobject widens its parent's bounding box: cells holding wider numbers then `arrange` with uneven gaps.

## Paths and motion
- `MoveAlongPath` on a path with two identical consecutive points raises "Not sure how you reached here".
  Drop duplicate points when building a route.
- `mob.animate(path_arc=a).move_to(p)` gives arced travel; `TracedPath(mob.get_center, dissipating_time=0.45)`
  gives a fading trail (remove it after the move).
- Easing functions beyond `smooth` need the module prefix: `rate_functions.ease_out_back`.
- `DecimalNumber.animate.set_value` crashes when the digit count changes; use `ChangeDecimalToValue`.

## Text
- `Write()` on a long Tex looks garbled mid-animation; `FadeIn` sentences, `Write` only short titles.
- LaTeX needs `\%`, `\_`, `\&`, `\$`; use `\texttt{}` for inline code. In Python strings use raw strings or
  `\\` (a `"\cdot"` in a normal string triggers an invalid-escape warning).
- `Text` drops leading spaces and blank lines; use `code_col` for code.
- `Text` (Pango) and `Tex` use different size scales: Menlo `Text` at `font_size` n has 1.7x the x-height of
  `Tex` at n (measured). Use `code()`, which corrects for it, so a label and its value at the same size match.
- Separate text mobjects in a row align by bounding box, not baseline (`arrange` centres them,
  `aligned_edge=DOWN` aligns descenders). Put everything that reads as one line in one `Tex` (`TC`/`MC`).
- Custom fonts: `manimpango.register_font(path)` before creating `Text`. Fonts are rarely needed: the 3b1b look
  is LaTeX.

## Rendering
- The toolchain upgrades itself to new Manim releases, so use only Manim's public API: `self.time`, not
  `self.renderer.time` (Manim 0.22 began moving rendering into a `Manager`); no private `_attributes`.
- Parallel chapter renders race on the shared Tex and Text caches ("ParseError: no element found"); the
  template's `render.py` gives each chapter its own `tex_dir` and `text_dir` under `media/cache/`. Never put a
  folder inside `media/Tex`: Manim's LaTeX cleanup unlinks everything there that isn't an .svg, and crashes.
- Anything shared between parallel renders (logs, timing files) must be one file per beat or chapter.
- Pillow ≥13 breaks Manim's image canvas; keep the shim at the top of `common.py`.
- Brew ffmpeg has no `drawtext`, so contact sheets are unlabeled; `beat_review.py` writes the matching text to
  a `.md` beside the sheet.
- `rng.choice` on a mobject list fails; pick by index.
