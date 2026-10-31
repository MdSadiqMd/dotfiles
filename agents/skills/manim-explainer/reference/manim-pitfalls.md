# Manim CE 0.22 pitfalls (each one cost a render)

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
- Custom fonts: `manimpango.register_font(path)` before creating `Text`. Fonts are rarely needed: the 3b1b look
  is LaTeX.

## Rendering
- Parallel chapter renders race on the shared Tex and Text caches ("ParseError: no element found"); the
  template's `render.py` gives each chapter its own `tex_dir` and `text_dir`.
- Anything shared between parallel renders (logs, timing files) must be one file per beat or chapter.
- Pillow ≥13 breaks Manim's image canvas; keep the shim at the top of `common.py`.
- Brew ffmpeg has no `drawtext`, so contact sheets are unlabeled; `beat_review.py` writes the matching text to
  a `.md` beside the sheet.
- `rng.choice` on a mobject list fails; pick by index.
