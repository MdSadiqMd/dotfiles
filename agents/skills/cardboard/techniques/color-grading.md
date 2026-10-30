# Color grade a project

A grade is `colorGrade` on an element in `timeline.tsx`. `timeline.d.ts` has its full typing. Every part is optional and
runs in this order: an input LUT, the wheels, the curves, `saturation`, then a look LUT. The older `colorGrading`
sliders (exposure, contrast, temperature…) still work and run before it.

"Warmer" and "cooler" mean color temperature unless the human is plainly talking about style. When a request could be a
grade or a bigger edit ("make it cooler", "make it pop"), make the grade only and offer the rest in words.

## Where the grade goes

- **One look for the video or a section**: an `<adjustment>` on a `kind="adjustment"` track listed before the video
  tracks it should grade. It grades every clip on the tracks after it while it is active. Span the requested range; use
  the whole timeline when no range is given.
- **Correcting or matching one shot**: `colorGrade` on that `<clip>` or `<image>`. Clip grades run first, then each
  adjustment above them, nearest track first, so a shot can be matched and the look still sits on top.

Keep one look adjustment per range. Change it in place rather than stacking a second one that fights it. When the
request names a kind of footage ("the underwater shots", "the interview"), grade only those clips and say which you left
alone.

```tsx
<track kind="adjustment" name="Grade">
  <adjustment
    name="Warm film"
    start={0}
    end={42}
    colorGrade={{
      wheels: { lift: { r: -0.02, b: 0.06 }, gain: { r: 0.05, b: -0.04 } },
      curves: {
        master: [
          [0, 0.04],
          [0.25, 0.22],
          [0.75, 0.8],
          [1, 0.96],
        ],
      },
      saturation: 0.9,
    }}
  />
</track>
```

## Reading the fields

- **Wheels** `lift` (shadows), `gamma` (mids), `gain` (highlights), `offset` (everything): `y` brightens or darkens that
  range, while `r`/`g`/`b` tint it. Values run from -1 to 1. Real grades stay small: 0.02–0.15 for a tint, 0.05–0.3 for
  `y`.
- **Tone curves** `master`, `red`, `green`, `blue` map input to output as `[x, y]` points from 0 to 1. The endpoints
  stay at (0,0) and (1,1) unless you place a point there. Lifting the (0, …) point fades the blacks, and a lower
  mid-shadow point with a higher mid-highlight point makes an S-curve for contrast.
- **Keyed curves** take an offset from -1 to 1, where 0 is neutral:
  - `hueVsSat`, `hueVsHue` and `hueVsLum` are keyed by hue: red 0, orange 0.08, yellow 0.17, green 0.33, cyan 0.5, blue
    0.67, magenta 0.83. Hue wraps around.
  - `lumVsSat` is keyed by luma.
  - Anchor a change with 0 on both sides so that only that hue moves. For example, muted greens:
    `hueVsSat: [[0.25, 0], [0.33, -0.5], [0.42, 0]]`.
- **`saturation`** scales color around luma: 1 is neutral, 0 is black and white.
- **`lut`** takes `{ preset }` (`cinematic`, `vintage`, `warm`, `cool`, `faded-film`, …) or `{ file }`, plus an optional
  `intensity` and `stage`. Use `stage: 'input'` for a camera log-to-Rec.709 LUT so the rest of the grade works on normal
  contrast; creative looks use the default `look` stage.

## Measure, don't guess

You cannot judge color from memory of a frame. `cb look --stats` measures the frames it renders, so read the numbers
before you grade and again after each change:

```
cb look <project> --at 4,18,31 --stats --compare --sheet grade.jpg --width 640
```

- **exposure** is the luma median and mean, 0–1. Well exposed footage usually sits at a median of 0.35–0.55.
- **blacks** and **whites** are the 1st and 99th luma percentiles; **contrast** is the 95th minus the 5th. Hazy, flat or
  underwater footage has high blacks, low whites and contrast under about 0.5.
- **clipped** is the share of crushed (luma ≤ 0.02) and blown (≥ 0.98) pixels. Do not push either past a few percent
  unless the look asks for it.
- **cast** per tonal zone: `temp` is red minus blue (positive warm), `tint` is green minus the red-blue mean (positive
  green). Under ±0.02 temp and ±0.015 tint reads as neutral.
- **saturation** is the mean and 90th percentile chroma; **hues** lists the main color bands with the share of the frame
  each covers and its HSV saturation (skin sits in red and orange). A near-grey frame lists none.

`--compare` renders each frame again with every grade, slider and LUT off (into `<out>/before`) and measures both; the
sheet puts them side by side. `--reference <media or path>` measures an image or video too, prints the distance to it
(lower is closer; colour work off is shown for comparison) and puts its still beside every frame on the sheet.

## Recipes

Starting points for relative requests. When the element already has a grade, change those values in place rather than
adding a second adjustment that fights it. Scale up for "much", down for "a touch", then measure.

| Request            | `colorGrade` change                                                                                                                                         | Measure                                             |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| Warmer             | `gain: { r: 0.04, b: -0.04 }`, `gamma: { r: 0.02, b: -0.02 }`                                                                                               | mids and highlights `temp` up 0.02–0.05             |
| Cooler             | `gain: { r: -0.03, b: 0.04 }`, `lift: { b: 0.03 }`                                                                                                          | `temp` down 0.02–0.05                               |
| Brighter / darker  | `gamma: { y: 0.15 }` / `gamma: { y: -0.12 }`                                                                                                                | median ±0.03–0.08, clipping unchanged               |
| More contrast      | S-curve straddling the median: `master: [[0.25, 0.2], [0.75, 0.8]]` near 0.5, `[[0.1, 0.07], [0.4, 0.46]]` near 0.2                                         | contrast up, blown and crushed under 2%             |
| Softer, faded      | `master: [[0, 0.05], [0.25, 0.27], [0.75, 0.76], [1, 0.95]]`, `saturation: 0.9`                                                                             | blacks up about 0.05, whites down                   |
| Moody              | `gamma: { y: -0.1 }`, `lift: { b: 0.04 }`, `saturation: 0.85`, the contrast S-curve                                                                         | median down 0.05–0.1, shadows cooler                |
| Golden hour        | `gain: { r: 0.08, g: 0.03, b: -0.08 }`, `gamma: { r: 0.03, b: -0.03 }`, `saturation: 1.08`                                                                  | mids and highlights `temp` up 0.05–0.1              |
| Teal and orange    | `lift: { g: 0.02, b: 0.08 }`, `gain: { r: 0.06, b: -0.05 }`, `hueVsHue: [[0.25, 0], [0.33, 0.1], [0.45, 0]]`                                                | shadows cooler, mids warmer, skin intact            |
| Bleach bypass      | `saturation: 0.55`, `master: [[0.2, 0.13], [0.8, 0.87]]`                                                                                                    | saturation mean roughly halved                      |
| More vivid / muted | `saturation: 1.15` / `saturation: 0.8`; `hueVsSat` for one band                                                                                             | saturation mean ±15–20%                             |
| Black and white    | `saturation: 0`, plus a contrast curve                                                                                                                      | saturation mean 0                                   |
| Day for night      | `gamma: { y: -0.45, r: -0.12, g: -0.04, b: 0.15 }`, `lift: { b: 0.08 }`, `gain: { r: -0.2, b: 0.08 }`, `master: [[0.5, 0.28], [1, 0.6]]`, `saturation: 0.3` | median 0.12–0.18, whites ≤ 0.5, mids `temp` ≤ -0.03 |
| Film               | `lut: { preset: "faded-film" }` or a project `.cube`, `intensity` 0.6–0.9                                                                                   | blacks lifted, contrast lower                       |

## Correct underwater or tinted footage

Water swallows red with depth, so underwater shots come out blue-green, hazy and flat. Correct each shot on its own
`<clip>`: the cast depends on depth and light, so one adjustment over every shot is wrong for most of them.

1. Find the shots: `cb look <project> --range 0,<end> --every 2 --stats` and pick the ones whose mids are `cool green`
   with `temp` below about -0.05, or whose hues are mostly cyan and sky blue.
2. Measure one shot at a few times and write a first correction on its `<clip>`. Put red back where it is missing:
   `gain.r` and `gamma.r` about one to two times the size of the mids `temp` (a mids `temp` of -0.15 starts near
   `gain: { r: 0.25, b: -0.05 }`, `gamma: { r: 0.15, g: -0.03 }`), pull green with a little negative `g` when `tint` is
   above 0.03, and lower the black point a little with `master: [[0.06, 0], [0.5, 0.48], [1, 1]]` when blacks sit above
   0.08. Write half of that first: red pushed past neutral turns sand and rock into red and orange speckles.
3. `cb look --at <s>,<s> --stats --compare --sheet uw.jpg` and iterate until mids `temp` is around -0.03 (a touch cool:
   the water should stay blue, the subject should not), blacks drop toward 0.05 and nothing new clips. Check the hues
   line: skin, fish and coral should show up as red, orange or yellow bands again. Stop before mids turn warm.
4. Repeat for each shot, then compare their stats side by side so neighbouring shots land on similar numbers.

The same method fixes any color cast: measure, correct per shot, verify.

## Grade like a reference

When the human gives a still, a frame or a clip to match (an attached file's path, or media already in the project),
write `match` into the `colorGrade` of the element whose range should change and apply. The apply measures, fits and
writes real wheels, curves, `saturation`, and `hueVsSat`/`hueVsHue` for the color bands both share, in its place, so the
file you read back has numbers you can tune.

1. Look at the reference first: `cb look <project> --at <s>,<s> --stats --reference <ref> --sheet ref.jpg`. Read where
   it differs (exposure, contrast, cast per zone, saturation, hues) and decide the scope: the whole video or a section
   is one `<adjustment>`, a single shot is its `<clip>`.
2. Write `match` and apply. The `matched:` line shows the distance before and after.
3. Verify with `cb look ... --stats --compare --reference <ref> --sheet match.jpg`: the reference sits beside each
   before and after. Check faces and anything the human named.
4. Refine by hand in the wheels and curves the fit wrote, for what it cannot know: the human's words ("but keep the skin
   natural", "less green"), and frames whose content differs from the reference.

```tsx
<track kind="adjustment" name="Grade">
  {/* Everything on the tracks below, from 12s to 40s, toward a still. */}
  <adjustment start={12} end={40} colorGrade={{ match: { reference: "~/Desktop/ref.jpg", strength: 0.8 } }} />
</track>
<track kind="video">
  {/* One shot toward how the timeline looks at 42.5s: shot-to-shot matching. */}
  <clip id="c7" src="broll.mp4" start={50} end={56} colorGrade={{ match: { frame: 42.5 } }} />
</track>
```

- **What it measures** is what the grade will act on. A `<clip>` or `<image>` is sampled on its own source over the part
  it plays. An `<adjustment>` is sampled on the topmost visible clip beneath it across its `start`–`end`, graded by
  everything between them, including grades this apply fitted lower down. Either way the element's own `colorGrading`
  sliders and an input-stage `lut` come first, as they render. So the range is the element's span, the layers are the
  tracks below it, and one shot is its own `colorGrade`.
- **`reference`** is a media name or id, or a path to an image or video (8 frames across it; `at` picks one second).
  **`frame`** is a timeline second: the topmost clip there, as graded, is the reference, leaving out any adjustment that
  also grades the matched element (it sits on both after the fit). A bare string is `{ reference }`.
- `cb source check` measures without writing: each `matched:` line shows the color distance to the reference before and
  after the fit (lower is closer).
- To match several shots, put the same `match` on each (an `--eval` loop does it in one apply). Prefer one adjustment
  when they should share a look. Matches in one apply are fitted from the bottom track up, so a matched adjustment over
  matched clips only corrects what is left.
- Matching assumes similar content. If the reference is a sunset and the clip is noon, use `strength` 0.6–0.8, then
  finish by hand in the wheels and curves. Artwork, animation, or a different time of day (night from a day shot) is a
  starting point at 0.5 or less; the recipes above carry the rest.
- A reference that is mostly one subject (a face close-up, a product shot) pulls the whole frame toward that subject's
  color. Match at about 0.5 and check that walls and whites stay neutral.
- A black-and-white or near-grey reference fits `saturation: 0` and a tone curve, nothing else.
- Pass the reference by path; it does not need to be in the project's media.
- The fit replaces the element's wheels, curves and `saturation` and keeps its `lut`. Reset `colorGrading` sliders if
  they fight the result.

## LUT files

Write a path to a `.cube` file as `lut.file` (absolute, or starting with `./`, `../` or `~/`); the apply checks that it
parses, copies it into the project's `luts/` and rewrites the path. The header of `timeline.tsx` lists the project's
LUTs; reuse one by its `luts/…` path. Anything else in `lut.file` is an error. An import stays in `luts/` even when
another error keeps the timeline unchanged.

```tsx
colorGrade={{ lut: { file: "~/Downloads/Kodak2383.cube", intensity: 0.8 } }}
// after apply: { file: "luts/kodak2383-1a2b3c4d.cube", intensity: 0.8 }
```

## Check it

1. `cb look <project> --at <s>,<s>,<s> --stats --compare --sheet grade.jpg` on frames with faces, skies and shadows:
   before and after side by side, with the numbers that changed.
2. Read the warnings `cb source check|apply` print (also written into the header's diagnostics): a malformed
   `colorGrade` is reported with its path and still applies, so the bad part does nothing until you fix it.

Keep skin natural: avoid `hueVsHue` and heavy `hueVsSat` near orange (0.03–0.12) unless the look asks for it. Grade
subtly unless the human asks for something dramatic, and describe the result in words ("warmer highlights, softer
blacks, greens pulled back"), not numbers.
