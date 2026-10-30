# cb docs shader — GLSL shaders in the timeline

A `<shader>` item is a GLSL ES 3.00 fragment shader. For its time range it reads the composite of every track beneath it
and draws the frame that replaces it. Tracks above it draw over the result as usual, and several shaders stack in track
order. Where nothing is beneath it, the composite is transparent black, so a shader can draw a whole frame on its own.

```tsx
<track kind="video" name="FX">
  <shader
    name="RGB split"
    start={2}
    end={6}
    shaderComposition={{
      source:
        'void main() {\n  vec2 o = vec2(amount * u_progress, 0.0);\n  fragColor = vec4(texture(u_input, v_uv + o).r, texture(u_input, v_uv).g, texture(u_input, v_uv - o).b, 1.0);\n}',
      params: { amount: 0.02 },
      controls: { amount: { label: 'Split', min: 0, max: 0.05, step: 0.001 } },
    }}
  />
</track>
<track kind="video" name="V1">
  <clip src="dancer.mp4" start={0} end={8} />
</track>
```

## The contract

Write `void main()` and any helpers. Do not write `#version`, `precision`, or declarations for these names: the renderer
declares them before your source, and line numbers in errors are your own.

| Name           | Type        | Meaning                                                                                 |
| -------------- | ----------- | --------------------------------------------------------------------------------------- |
| `u_input`      | `sampler2D` | The composite of every layer beneath the shader                                         |
| `u_matte`      | `sampler2D` | Person matte of the video beneath, in frame space: white on the person, black elsewhere |
| `u_hasMatte`   | `float`     | `1.0` once a matte is ready, else `0.0`; the matte is black until then                  |
| `u_time`       | `float`     | Seconds since the shader started                                                        |
| `u_duration`   | `float`     | The shader's length in seconds                                                          |
| `u_progress`   | `float`     | `u_time / u_duration`, `0..1`                                                           |
| `u_resolution` | `vec2`      | Output size in pixels                                                                   |
| `v_uv`         | `vec2`      | Pixel position, `0..1`; `(0, 0)` is the bottom-left corner                              |
| `fragColor`    | `vec4`      | Your output                                                                             |

- `params` become uniforms of the same name: a number is a `float`, an array of 2, 3 or 4 numbers a
  `vec2`/`vec3`/`vec4`. The editor shows each number as a slider, so put anything a person may want to tune there.
- Give **every** param a control, keyed by param name: `{ label, min, max, step, format, toggle }`. It is what a person
  sees in the editor: a plain-words label and a range where every value looks right. `format` is `percent` (a 0–1 value
  shown as 0–100%), `seconds`, `number`, `color` (a `vec3`/`vec4` in 0–1, shown as a swatch) or `point` (a `vec2` in 0–1
  frame coordinates, (0, 0) bottom-left, shown as a position pad); `toggle: true` shows a 0/1 param as a switch.
  Applying a param without a control warns, and the editor falls back to its name and a guessed range.
- Every shader also takes four settings the renderer applies around your output, so do not rebuild them in GLSL:
  `amount` (0–1 blend over what is beneath, default 1), `fadeIn` and `fadeOut` (seconds to ramp in from the start and
  out to the end) and `region` (`all`, `subject` or `background`, masked by the person matte). They sit beside `source`
  in `shaderComposition`, and the editor shows them above the params.
- Built-in effects (grain, vignette, scanlines, halation, paper cutout) are shaders built this way in the desktop app:
  read one in `timeline.tsx` to see a full example, and edit its params or source like any other shader.
- The Effects panel's Stylize, Distort and Backgrounds presets (duotone, halftone, VHS, glitch, tilt shift,
  kaleidoscope, aurora, god rays and about 30 more) are shaders too. `cb docs shader-presets` lists them with their
  params, and `cb docs shader-presets/<id>` prints one as a ready `<shader>` element; start from one when it is close to
  the look you want rather than writing that effect from scratch.
- Every pixel must be a function of the inputs: no state carries from one frame to the next, so the same frame renders
  the same in preview, `cb look` and export. Animate with `u_time` or `u_progress`.
- `u_input` is premultiplied RGBA. Write `1.0` alpha for an opaque frame.
- Referencing `u_matte` asks the editor to prepare person mattes for the videos beneath, as `behind-subject` captions
  do. The first one takes about a minute; until it is ready `u_hasMatte` is `0.0`, so blend with it rather than assuming
  a matte.

## From a file

A shader kept in the bundle as a `.glsl` file is placed by path, relative to the bundle:
`shaderComposition={{ template: "recipe/shaders/grain.glsl", params: { strength: 0.015 } }}`. Apply reads the file as
the source and lints it like an inline one. A `shaders.json` beside it may describe the file, keyed by name:
`{ "grain": { "file": "grain.glsl", "params": { ... }, "controls": { ... } } }`; its `controls` fill in and its `params`
are defaults that the placement's `params` override. `timeline.tsx` prints the placement back in this short form.

## Checking a shader

Apply lints the shape before anything renders: a missing `void main()`, a `#version` line, a redeclared name above, or a
bad param is an error that keeps the timeline untouched. GLSL compile errors appear when the shader first renders:
`cb look` prints them under the frames, and the frames show what is beneath the shader. Check every shader with
`cb look <project> --at <times inside it> --sheet review.jpg` before calling it done.

## Where it renders

Shaders render everywhere a timeline renders: the editor preview, `cb look` and `cb export` with or without the app, and
cloud exports. Without the app, `cb` runs each shader in a headless Chrome page, so it needs Chrome or Chromium
installed (or `CARDBOARD_CODE_CLIP_BROWSER` pointing at one). Noise built on `fract(sin(x) * 43758.…)` keeps its look
but not its exact grain across renderers; use a hash without `sin` where the exact pattern matters.
