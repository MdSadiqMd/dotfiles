# cb source — the timeline as a file

`timeline.tsx` in every bundle is a literal TSX projection of the timeline, regenerated on every save. An apply parses
it, diffs it against the revision it was printed from, and changes only the items you touched.

```
cb source print <project>                     canonical timeline.tsx on stdout
cb source check <project> [file|-] [--eval]   parse + report the ops, write nothing
cb source apply <project> [file|-] [--eval]   apply onto the project
       --prefer file|editor                   who wins an item changed on both sides (default: file)
```

`<project>` is a name, id, or bundle path. With no file argument the bundle's own `timeline.tsx` is used, so
`cb source apply Demo` re-applies a file you edited while the app was closed. `-` reads stdin.

## Over MCP

`cb mcp` serves the same surface as `print_timeline`, `check_timeline` and `apply_timeline`. `apply_timeline` changes
the timeline through `edits` rather than the whole file:

```
apply_timeline({ project, rev, edits: [{ oldText, newText }] })
```

- Each `oldText` is copied exactly from `print_timeline`, whitespace included, and occurs there exactly once: the
  smallest unique span that names the target, such as an attribute only one item has, or the run from its `id` to the
  attribute that changes. Edits in one call do not overlap.
- `newText: ""` deletes. An insert replaces a unique anchor with the anchor plus the new JSX.
- `rev` is the `cardboard:rev` from the header you copied from. The edits apply to the timeline as it was then, and what
  the app changed since merges in item by item, as for a saved file. Without `rev` they apply to the current timeline.
- Text outside the edits is untouched. An edit that matches nothing or more than once applies nothing; a fresh
  `print_timeline` has the current text to copy from.
- `source` (the whole file) is for rewriting most of the timeline. Every apply sends all of it, so it costs tokens in
  proportion to the project.

## Rules

- **Literals only.** Attribute values must be string, number, boolean, array or object literals; the file is parsed,
  never executed. Comments are not kept.
- **Escapes need braces.** A quoted attribute is JSX text, not a JS string: `textContent="a\nb"` stores a backslash and
  an `n`. Write `textContent={"a\nb"}` for a line break or `\u` escapes; a quoted attribute holding one warns
  `literal-escape`.
- **Loops go through `--eval`.** `cb source apply <project> gen.tsx --eval` transpiles and runs the file in the CLI
  process (your trust domain) with a JSX factory that produces the same tree the parser would. `key` props are ignored.
  Stdin works too: `... apply <project> - --eval`.
- **`src`** is a media file name from the header (`clip.mp4`, or `clip` when unambiguous), a media id, or a path. A path
  is absolute or starts with `./`, `../` or `~/` (a bare `dir/clip.mp4` reads as a name); paths are ingested on apply
  and rewritten to the media id.
- **Item-level merge.** The `rev` in the header pins the document the file was printed from. Your changes are diffed
  against that revision and applied onto the current document, so GUI edits to other items survive. If the same item
  changed on both sides, the file wins and the apply result lists the conflict; `--prefer editor` keeps the GUI's values
  instead.
- **Stacking.** The first `<track>` is the top layer, for `<code>` graphics too; `zIndex` overrides track order.
- Errors keep the timeline untouched. Warnings apply and are listed in the header; a clip that runs past its source
  warns and holds its last frame.
- **Placeholders.** `pending` stands in for content that is not written yet: the item renders as nothing, blocks export,
  and `cb verify` lists it. Filling one keeps its `id` and drops `pending`. Items whose content is ready, such as
  `<text>` titles, a `<code>` graphic with its source or a `<clip>` with its `src`, need no placeholder: they apply
  complete, several in one apply. Placeholders placed first show the shape of an edit on an open app's timeline while
  their content is written, and filling one per save shows each as it lands.
- **Framing.** Apply frames visual clips as the editor does when a clip is dropped on it. A `<clip>` or `<image>` added
  without a `transform`, without `x`/`y`/`scale` keyframes and without `autoReframe={false}` gets `autoReframe`, and
  when its media is wider than the frame (a 16:9 clip in a 9:16 timeline) a `transform` that scales it to the frame's
  height, centred, with the sides cropped; the printed file shows both. A changed `aspect` refills the `autoReframe`
  clips on the first video track and on layout tracks, except clips whose `transform` or keyframes the same apply
  changes; an aspect the media already fits sets them back to `scale: 1`. `autoReframe={false}` or a `transform` of its
  own keeps a clip as written, and `transform.x` moves the crop sideways. The crop is centred: it does not follow the
  subject.

## Elements

| Element        | Track kind | Content                             | Notes                                                                                                          |
| -------------- | ---------- | ----------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `<timeline>`   | —          | —                                   | `aspect`: `16:9` `4:3` `3:4` `9:16` `1:1` `4:5`                                                                |
| `<track>`      | —          | —                                   | `kind`: `video` (default), `audio`, `caption`, `adjustment`, `layout`; `name`, `locked`, `visible`, `muted`    |
| `<clip>`       | video      | `src`, `start`, `end`               | video media; sound props apply                                                                                 |
| `<image>`      | video      | `src`, `start`, `end`               |                                                                                                                |
| `<audio>`      | audio      | `src`, `start`, `end`               | `volume` 0–200, `muted`, `audioFadeIn/Out`, `playbackSpeed`                                                    |
| `<text>`       | video      | `start`, `end`, `textContent`       | font, color, align, stroke, shadow, background, `textAnimation`                                                |
| `<caption>`    | caption    | `start`, `end`                      | `captionSegments`, preset, position, colors                                                                    |
| `<code>`       | video      | `start`, `end`, `codeComposition`   | `{ source, width, height, assets? }`; give each a `name` for the timeline; linted on apply, see `cb docs code` |
| `<adjustment>` | adjustment | `start`, `end`                      | `lutPresetId`, `lutIntensity`, `colorGrading`, `colorGrade`                                                    |
| `<shader>`     | video      | `start`, `end`, `shaderComposition` | `{ source \| template, params? }`: GLSL that redraws every track beneath it; see `cb docs shader`              |

Apply checks that `start` and `end` are numbers and lints the `codeComposition` of every `<code>` and the
`shaderComposition` of every `<shader>` that is not `pending`. The rest of the Content column is not checked: a `<clip>`
without `src` or a `<text>` without `textContent` applies with nothing to show, while an unfilled item marked `pending`
is counted by `cb verify`.

Common item attributes: `id`, `name` (the clip's timeline label), `start`, `end` (timeline seconds), `in`, `out` (source
seconds; default `in=0`, `out=in+(end-start)`), `pending` (placeholder), `transform`, `crop`, `opacity`, `hidden`,
`zIndex`, `blendMode`, `keyframeTracks`, `transitionIn`, `transitionOut`, `effects`, `borderRadius`, `gaussianBlur`,
`colorGrade` (clip, image, adjustment; see Color below), `captionComposition`
(`{ mode: 'front' | 'behind-subject', fallback: 'front' | 'hide' }`). Behind-subject composition can be set on
`<caption>` or `<code>` items; the editor prepares mattes for overlapping visible video clips. `transform` is
`{ x, y, scale, rotation, flipX? }` in pixels from the centre; `keyframeTracks` animate `x`, `y`, `scale`, `rotation`,
`opacity`, `gaussianBlur`, `borderRadius`, with `easing` on the track. Unknown keys inside these objects warn and do
nothing; unknown attributes round-trip untouched so nothing the GUI wrote is lost. `timeline.d.ts` beside the file has
the full typings.

## Color

`colorGrade` holds wheels, curves, `saturation` and a `lut`; `timeline.d.ts` has the typing and `cb docs color-grading`
the method. Two values resolve on apply, like a path in `src`:

- `lut: { file: "~/Downloads/film.cube" }`: a path to a `.cube` (absolute, `./`, `../` or `~/`) is checked, copied into
  `luts/` and rewritten to its `luts/…` path. The header lists the project's LUTs; any other `file` is an error. The
  copy stays in `luts/` even when another error refuses the apply.
- `match: "<media or path>"`, `{ reference, at?, strength? }` or `{ frame, strength? }`: fits wheels, curves and
  `saturation` that move the element toward a reference image, video, media item, or the timeline at `frame` seconds
  (less any adjustment that also grades the element), and writes them in its place. A clip is measured on its own
  source; an `<adjustment>` on the clips beneath it across its span; both after the element's `colorGrading` and an
  input-stage `lut`. Matches are fitted from the bottom track up. `check` measures without writing.

## Output

Text mode prints one line per diagnostic, then a summary such as `Applied 1 addTrack, 3 addItem (rev 1788620626855)`,
conflicts, ingested media, imported LUTs (`imported LUT: <name> (<file>)`, printed even when the apply is refused) and
matched grades (`matched: <name> (<id>) <before> -> <after>`, the color distance to the reference). `check` lists paths
it would ingest as `would ingest` and `.cube` paths it would import as `would import LUT: <path>`, not errors, and a
file it would not apply ends with `Would not apply: N errors, M warnings`. `--json` prints
`{ applied, ops, conflicts, diagnostics, ingested, wouldIngest, matched, importedLuts, wouldImportLuts, rev, summary: { errors, warnings, ops } }`.
`check` and `apply` exit 1 when an error kept the timeline untouched (and when an `--eval` script fails to run); a file
that changes nothing applies with exit 0.
