# cb docs code — JSX graphics in the timeline

A `<code>` item is a motion graphic written as one TSX function. Cardboard calls it once per frame with the clip-local
time and draws what it returns over the tracks below it.

```tsx
<code
  name="Hello reveal"
  start={4}
  end={9}
  codeComposition={{
    width: 1920,
    height: 1080,
    source:
      "export default function Graphic({ time, width, height }) {\n  const reveal = Math.min(1, time / 0.4);\n  return (\n    <div style={{ width, height, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'Inter, sans-serif' }}>\n      <div style={{ fontSize: 120, fontWeight: 500, color: '#F3EEE6', opacity: reveal, transform: `translateY(${(1 - reveal) * 40}px)` }}>Hello</div>\n    </div>\n  );\n}\n",
  }}
/>
```

`source` is the program. `width` and `height` are the composition's pixel size; a composition smaller or larger than the
frame is scaled to fit and centered. Leave the root background transparent so the footage shows through; a solid
background hides every track beneath the item. Without a `name` every graphic reads "Motion graphic" on the timeline.

To put a code graphic behind a person, set `captionComposition` on the `<code>` item:

```tsx
<code
  name="Headline"
  start={2}
  end={5}
  captionComposition={{ mode: 'behind-subject', fallback: 'front' }}
  codeComposition={{
    width: 1920,
    height: 1080,
    source:
      "export default function Graphic({ width, height }) { return <div style={{ width, height, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'Inter, sans-serif', fontSize: 120, color: '#F3EEE6' }}>Behind the speaker</div>; }",
  }}
/>
```

The editor prepares person mattes for overlapping visible video clips, then composites those people in front of the
graphic. The fallback keeps the graphic visible while a matte is unavailable.

## The contract

- Exactly one default export: a synchronous function taking one input object, `{ time, width, height, assets }`. `time`
  is seconds since the item started; it can arrive in any order (scrubbing, export, `cb look`), so every pixel must be a
  pure function of it. `assets` holds the project media declared in `codeComposition.assets` (see below); it is `{}`
  when none is declared.
- Module scope holds only imports, type declarations and the default export. Constants, helpers, easing functions and
  config objects all go inside the function body; a top-level `const` is rejected because it would persist between
  frames.
- Return native JSX (`div`, `span`, `svg`, ...) with inline `style` objects. The four components available are `Canvas`
  (`@react-three/fiber`), `Lottie` (`@cardboard/lottie`), `Sketch` (`@cardboard/p5`) and `Fragment` (`react`), each
  imported as a value from its module before use.
- Imports allowed: `three`, and from the other modules only their component (plus types): `Fragment` from `react`,
  `Canvas` from `@react-three/fiber`, `Lottie`, `Sketch`. Hooks such as `useFrame` or `useState` do not exist here.
- 3D: animate the camera through `Canvas`'s `camera` prop, computed from `time` like any other prop, e.g.
  `camera={{ position: [Math.sin(time) * 6, 2, Math.cos(time) * 6], fov: 40, lookAt: [0, 1, 0] }}`. It is applied on
  every frame. `lookAt` aims it; without `lookAt` or `rotation` it faces the origin.
- Globals allowed: `Math`, `Number`, `String`, `Boolean`, `BigInt`, `Object`, `Array`, `JSON`, `RegExp`, `Map`, `Set`,
  `WeakMap`, `WeakSet`, `Symbol`, `Error`, `TypeError`, `RangeError`, `parseInt`, `parseFloat`, `isFinite`, `isNaN`,
  `ArrayBuffer`, `DataView`, the typed arrays, `undefined`, `NaN`, `Infinity`.
- Fonts: `Inter` is the only family loaded in every renderer, so use it (`'Inter, sans-serif'`); any other named family
  resolves to whatever the machine has, and a monospace family is no exception. `-apple-system`, `system-ui`,
  `BlinkMacSystemFont`, `Segoe UI`, `Helvetica Neue` and the `ui-*` families are rejected because they draw differently
  on every machine, and a stack that leads with a bare generic (`sans-serif`) is rejected for the same reason.

## What the lint rejects

The source is linted when the file is applied. Errors keep the timeline untouched and appear in the regenerated header
as `error: <code> composition [<rule>]: <message> (source line L:C) (line N)`, where `line N` is the `<code>` element in
`timeline.tsx` and `L:C` the position inside the source. The same rules apply in the app and in `cb mcp`.

| Finding                      | Cause                                                                                                                                                             | Fix                                                         |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| `syntax-error`               | The source does not parse                                                                                                                                         | Fix the syntax                                              |
| `composition-contract`       | Not one default export; not a function of one input; async; named exports or other module-level code; an unknown capitalised component, or one imported type-only | `export default function Graphic({ time, width, height })`  |
| `async-code`                 | An `async` function or `await` anywhere                                                                                                                           | Compute synchronously                                       |
| `nondeterministic-font`      | OS font family, or a stack led by a generic family                                                                                                                | `fontFamily: 'Inter, sans-serif'`                           |
| `blocked-global`             | `Date`, `window`, `document`, `performance`, timers, `fetch`, `crypto`, `Function`, `eval`, `require`                                                             | Derive the value from `time`                                |
| `blocked-constructor`        | `new Date()`, `new Function()`, three.js clocks and loaders                                                                                                       | Derive the value from `time`                                |
| `unsupported-global`         | Any identifier not in the allowed list (`console`, `localStorage`, `Intl`, ...)                                                                                   | Compute it yourself or drop it                              |
| `nondeterministic-random`    | `Math.random()`, or `seededRandom()` without a seed                                                                                                               | `THREE.MathUtils.seededRandom(seed)` with a literal seed    |
| `nondeterministic-three-api` | `THREE.Clock`, `AnimationMixer`, loaders, `generateUUID`, `THREE.MathUtils.rand*`                                                                                 | Derive motion from `time`                                   |
| `persistent-state`           | Module-scope `const`/`let`; hooks; any property assignment or `delete`; `Object.assign`/`defineProperty`/`setPrototypeOf`; `ref` or `on*` attributes              | Build every value fresh inside the function                 |
| `unsupported-react-api`      | Any `react` import other than `Fragment`, or React's imperative APIs                                                                                              | Author elements as JSX                                      |
| `unsupported-r3f-api`        | Any `@react-three/fiber` import other than `Canvas` (so no `useFrame`)                                                                                            | Drive the scene from `time`                                 |
| `unsupported-lottie-api`     | Any `@cardboard/lottie` import other than `Lottie`                                                                                                                | Use `<Lottie>`                                              |
| `unsupported-p5-api`         | Any `@cardboard/p5` import other than `Sketch`                                                                                                                    | Use `<Sketch>`                                              |
| `self-timed-animation`       | CSS `animation`/`transition` properties or `@keyframes`                                                                                                           | Interpolate the style from `time`                           |
| `external-asset`             | A string that is wholly an `http(s)://`, `blob:` or `data:` URL, or CSS `url(...)`; text, `url(#id)` and asset URLs pass                                          | Declare project media in `assets` and use `assets.name.url` |
| `unstable-object-identity`   | Elements or fragments built in an array without a `key`; `<primitive>`                                                                                            | `key={i}` or a key from the data                            |
| `unsupported-import`         | Any other module, or dynamic `import()`                                                                                                                           | Use the allowed libraries                                   |
| `runtime-owned-prop`         | `frameloop` or `dpr` on `Canvas`, or the renderer's own source-id attribute                                                                                       | Remove them                                                 |
| `runtime-owned-name`         | Identifiers starting with `__cardboard`                                                                                                                           | Rename them                                                 |
| `escape-hatch`               | `constructor` or `.prototype` access                                                                                                                              | Remove them                                                 |

## Project media inside a graphic

A graphic can draw the project's own images and videos. Declare them in `codeComposition.assets` and read them from the
`assets` input; every entry arrives as `{ url, width, height, kind, duration? }`.

```tsx
<code
  start={12}
  end={20}
  codeComposition={{
    width: 1920,
    height: 1080,
    assets: { drake: 'drake.jpg', broll: { src: 'b-roll.mp4', in: 12, loop: true } },
    source:
      "export default function Graphic({ time, width, height, assets }) {\n  return (\n    <div style={{ width, height, position: 'relative' }}>\n      <img src={assets.drake.url} style={{ position: 'absolute', left: 120, top: 90, width: 700, height: 500, objectFit: 'contain' }} />\n      <img src={assets.broll.url} style={{ position: 'absolute', right: 80, bottom: 80, width: 480, height: 270, objectFit: 'cover', borderRadius: 16 }} />\n    </div>\n  );\n}\n",
  }}
/>
```

- A value takes the same forms as `src`, or `{ src, in?, loop? }`.
- `kind` is `'image'` or `'video'`. Audio and text media are rejected with an error on apply.
- For a video, `url` is the exact frame for the current `time`: media time is `in + time`, `loop` wraps at the media's
  duration, otherwise the last frame holds. The graphic never seeks or plays anything; it stays a pure function of
  `time`. Apply warns when `in` lies past the end of the media, and when a non-looping asset is shorter than the item.
- Video assets are silent. Put the sound on an `<audio>` element or a `<clip>` on another track.
- Lay out media inside the graphic with `width`/`height` and `objectFit` (`cover`, `contain`) on the `<img>`, or as a
  CSS `backgroundImage` built from `assets.name.url` (the only `url(...)` the lint accepts). Media shown alongside a
  graphic belongs inside it: a `clip-path` hole does not reveal the tracks beneath.
- Images are inlined into the sandbox: at most 8 MB per image and 32 MB per graphic. Above that the graphic fails to
  build with a clear message; use a smaller export of the image.
- Every distinct `assets` map, like every distinct `source`, is its own media row and sandbox.

## Data-driven graphics

For lyric videos, captions, counters and other repeated graphics, write one template and stamp it with a config object
per item from a generator script, then apply with `--eval`:

```tsx
// gen.tsx, run with: cb source apply <project> gen.tsx --eval
import { readFileSync } from 'node:fs';

// graphic.tsx: `export default function Graphic({ time, width, height }) { const cfg = __CFG__; ... }`
const template = readFileSync('graphic.tsx', 'utf8');
const lines = JSON.parse(readFileSync('lines.json', 'utf8')) as Array<{ start: number; end: number; text: string }>;

export default (
  <timeline aspect="16:9">
    <track kind="video" name="Lyrics">
      {lines.map(line => (
        <code
          name={`Lyric: ${line.text}`}
          start={line.start}
          end={line.end}
          codeComposition={{
            width: 1920,
            height: 1080,
            source: template.replace('__CFG__', JSON.stringify({ text: line.text, style: 'pop' })),
          }}
        />
      ))}
    </track>
  </timeline>
);
```

Each generated item costs its own sandbox while rendering, so one item applied and checked with `cb look` shows a
template's problems before there are dozens.

## Checking a graphic

`cb code check` tests the source on its own, before it goes on a timeline:

```
cb code check graphic.tsx [--width 1920 --height 1080] [--duration 5] [--frames 6] [--out dir] [--sheet review.jpg]
cb code check graphic.tsx --asset drake=./drake.jpg --asset broll=./b-roll.mp4,in=12,loop
cb code check graphic.tsx --no-render        # lint and compile only
cat graphic.tsx | cb code check -
```

`check` runs the same lint the apply uses (findings carry `line:col` and the rule code), compiles the source, then
rasterizes `--frames` evenly spaced frames across `--duration` seconds with the pinned `Inter` font. Frames render in
the running Cardboard app's own Chromium, so the `cb` the app installs renders them too; with the app closed, rendering
needs a source checkout (`pnpm cli`), as does `--asset`. If the graphic throws, the check fails with its error message.
Every frame reports whether anything was painted; `--sheet` tiles them into one labelled image. It exits 1 on a lint
error, a compile error, a throw at render time, or when every sampled frame is empty. With the app open it also runs the
editor's determinism probe, the one a graphic must pass before the timeline takes it: each sampled frame (and the
editor's own probe moments) renders twice out of order, and a frame that comes out differently after another fails the
check as `nondeterministic-render`, usually state kept between frames or list items sharing a `key`. With the app closed
the report says the probe did not run. `unshipped-font` and `uncovered-script` warnings mark text that renders
differently per host: fonts other than `Inter`, and scripts `Inter` has no glyphs for; draw those as outlines. `--json`
returns the findings, frame paths, sheet and `deterministic`. The command needs no project. A graphic that reads
`assets` needs one `--asset name=path[,in=<seconds>][,loop]` per name; the file stands in for the project media (video
needs `ffprobe`).

On the timeline, `cb look` shows the graphic composited. Output from a headless render should match the app's; if it
does not, the composition depends on something outside its inputs.
