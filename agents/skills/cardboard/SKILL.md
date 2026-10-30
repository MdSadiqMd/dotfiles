---
name: cardboard
description: "Edit Cardboard video projects (.cardboard bundles) with the `cb` CLI and timeline.tsx: cut, arrange, caption, add titles and motion graphics, color grade or match a reference look, generate footage, narration, music or sound effects, import video links, and check the result with cb look. Use when a task mentions Cardboard or `cb`, or a .cardboard folder or timeline.tsx is in view."
---

# Cardboard

A Cardboard project is a folder, `<Name>.cardboard/`, whose **`timeline.tsx`** is a literal TSX mirror of the timeline
that Cardboard regenerates on every save. Edit it and save, and the project changes; an open app follows within ~200 ms
as one undo step.

`cb` (alias of `cardboard`) is on PATH once the app's **File › Install Agent Tools…** has run, or via `pnpm cli` in the
repo. Commands that work on a project take its **name, id or bundle path**, and every command accepts `--json`.
`cb docs <topic>` prints command documentation and techniques; the same files sit in `commands/` and `techniques/` next
to this skill. Follow the matching technique for titles and motion graphics (`cb docs motion-graphics`), synced captions
(`cb docs synced-captions`), behind-subject compositing (`cb docs behind-subject-compositing`), color grading and
matching a reference look (`cb docs color-grading`), and any 3D scene, object, character or 3D camera move, including
whether to build it in three.js or generate it (`cb docs 3d-scenes`).

## The loop

1. `cb project list`, then `cb source print <project>` (or open `timeline.tsx`). Read the header: aspect, duration, the
   **media table** (names to use as `src`), the cast, `diagnostics`, and `// cardboard:rev <n>`.
2. **Place before you fill.** Add every new element with its `name`, `start`, `end` and track, and `pending` in place of
   the content (`codeComposition` on `<code>`, `src` on `<clip>`/`<image>`/`<audio>`). Save. Pending elements show as
   labelled shimmering blocks, render as nothing in `look`, and block export, so the human sees the shape of the edit
   while you work. Even a single `<code>` graphic goes in this way.
3. **Fill.** Re-read the file, which now gives each placeholder an `id`. Keep the `id`, drop `pending`, add the content,
   save. One element per save.
4. App open: saving applies and toasts. App closed: `cb source apply <project>`. `cb source check <project> file.tsx`
   dry-runs a file. Over MCP (`cb mcp`), send `apply_timeline` small `edits` copied from `print_timeline`, not the whole
   file; see `cb docs source`.
5. Read back: the header lists `diagnostics` (what was rejected and why) and how many items are still `pending`; leave
   none. Then `cb verify <project>` and `cb look <project> --at <s>`.
6. Wrong turn? `cb history <project>` and `cb undo <project> [rev]`.

Items without an `id` are new and items you delete from the file are removed. Items you keep carry their `id`: leave it
as it is, since a changed `id` replaces the item and loses the human's undo trail. Only what you touched changes, so the
human's edits to other items survive.

`timeline.tsx` is parsed, never evaluated, so attribute values are literals: no variables, calls or spreads. For loops
and helpers, write a `.tsx` script and run `cb source apply <project> gen.tsx --eval`. Never write `project.json`.

A quoted attribute keeps backslashes literally, so `\n` or `\u201c` would show on screen. Type characters directly, or
use braces for escapes: `textContent={"Clocking in “early”\n10:30 am"}`.

```tsx
<track kind="video" name="Titles">
  <code name="Lower third" start={0.5} end={4} pending />
</track>
<track kind="video" name="B-roll">
  <clip name="Skyline" start={4} end={9} pending />
</track>
```

## Elements

```tsx
export default (
  <timeline aspect="16:9">
    <track kind="video" name="Titles">
      <text start={0.5} end={3} textContent="Hello" fontSize={72} color="#ffffff" />
    </track>
    <track kind="video" name="V1">
      <clip src="interview.mp4" start={0} end={12.5} in={3} out={15.5} />
      <image src="logo.png" start={0} end={3} transform={{ x: 640, y: -360, scale: 0.3, rotation: 0 }} />
    </track>
    <track kind="audio" name="A1">
      <audio src="music.mp3" start={0} end={12.5} volume={40} audioFadeOut={{ duration: 1 }} />
    </track>
  </timeline>
);
```

- The **first track is the top layer** for every element kind, `<code>` included. To put an image over a graphic, list
  the image's track first.
- `start`/`end` are timeline seconds; `in`/`out` are source seconds. `src` is a name from the header, a media id, or a
  path, which is ingested on apply.
- A `<clip>` or `<image>` added without a `transform` fills the frame on apply: a 16:9 clip in a 9:16 timeline is scaled
  to the frame's height and centred, and marked `autoReframe`. Changing `aspect` refills those clips on the first video
  track. `autoReframe={false}` or a `transform` of its own keeps a clip as written; `transform.x` moves the centred crop
  sideways, and `cb look` shows what is in frame.
- `<code>` is a JSX motion graphic: one pure function of `{ time, width, height, assets }`, linted on apply. Read
  `cb docs code` before writing one. Name every graphic after what it shows.
- `<shader>` is a GLSL fragment shader that redraws every track beneath it for its time range, with the person matte of
  the video beneath as a texture. Reach for it for per-pixel looks (distortion, color, glitch, inside or outside the
  subject) instead of rendering frames in Python. Read `cb docs shader` before writing one: give every param a labelled
  control, and use `amount`, `fadeIn`/`fadeOut` and `region` rather than coding blends, ramps or masks yourself.
- `cb docs source` has the element and attribute table; `timeline.d.ts` beside the file has the typings.

## Seeing

You cannot watch the video; look at frames and numbers instead.

| Question                              | Command                                                           |
| ------------------------------------- | ----------------------------------------------------------------- |
| What is in this file?                 | `cb media probe <project> <file>`                                 |
| Where do scenes change?               | `cb media scenes <project> <file>`, or `filmstrip --count 12`     |
| What is at 12.5s in the source?       | `cb media grab <project> <file> --at 12.5`                        |
| Mask out the subject                  | `cb media matte <project> <file> --from 12 --to 18` (hosted GPU)  |
| What does the timeline look like now? | `cb look <project> --at 3,7.5,12 --sheet review.jpg --width 640`  |
| How does a section move?              | `cb look <project> --range 10,14 --every 0.5 --sheet review.jpg`  |
| How is it graded, and did it change?  | `cb look <project> --at 3,12 --stats --compare --sheet grade.jpg` |
| Does this graphic render?             | `cb code check graphic.tsx --duration 6 --sheet review.jpg`       |
| Does the timeline hold together?      | `cb verify <project>`                                             |
| What is the human looking at?         | `cb app context <project>` (playhead, selection, exporting)       |

Times given to `media *` and `audio *` are **source** seconds; times given to `look`, `seek` and items are **timeline**
seconds.

## Hearing

You cannot listen either; read the transcript and the levels.

| Question                                 | Command                                                                    |
| ---------------------------------------- | -------------------------------------------------------------------------- |
| What is being said, and when?            | `cb audio transcribe <project> <file> --format words`                      |
| Where does "robot dog" land in the edit? | `cb audio search <project> "robot dog"` (source and timeline times)        |
| Caption the edit                         | `cb audio captions <project> --apply` (or without `--apply` to edit first) |
| Where is the dead air?                   | `cb audio silence <project> <file>`                                        |
| Is this clip too quiet / too hot?        | `cb audio loudness <project> <file>`                                       |
| Where is the beat?                       | `cb audio levels <project> <file> --json --points 100`                     |

## New footage, voice and sound

Read `cb docs generate` before the first run; models, lengths, credits, prompting and casting live there.

- `cb generate video <project> "<prompt>" --start <s>` places a pending clip and fills it when the model returns.
  `--quality standard` for b-roll and anything you might redo, `best` for the shot that carries the video.
- `cb generate image <project> "<prompt>" --start <s>` places a still the same way; `--quality best` for lettering and
  fine detail, `--image <media|path>` to redraw an image you have.
- A still that exists only to start a clip goes on the clip: `generate video --first-frame "<still prompt>"`, so the
  user confirms one generation, not a still and then a clip.
- Both come out in the project's aspect, or the closest the model renders; `--aspect` sets another frame.
- A multi-scene story under 30 seconds, from nothing: one `--model wan-3.0 --duration 30` run with every scene listed in
  order.
- A person who recurs across clips is a cast member: `@Name` in the prompt, plus `--character "Name: look"` on first
  use. Cast everyone who recurs, kids included.
- `cb generate voice <project> "<text>" --voice <id|name> --start <s>` places narration with its transcript; see
  `cb docs voice`.
- `cb generate music <project> "<style>" --auto` composes a music bed for the whole timeline on a `Music` track, with
  sections planned from cached speech and visible titles; `--dry-run` first to see the sections.
  `cb generate sfx <project> "<sound>" --start <s>` places one sound effect on an `SFX` track. Both are in
  `cb docs generate`.
- `cb music search "<vibe>"` and `cb sfx search "<sound>"` find tracks and sound effects in Cardboard's own library,
  free, with each track's sections and the stretches quiet enough for speech; `cb media add <project> "<link>"` brings
  one in.
- `cb media add <project> "<link>"` imports a YouTube, X or Instagram video ready to cut; see `cb docs download`. The
  human is responsible for what they have the right to use.
- `cb capture "<link>" --project <project>` imports a screenshot of a web page for explainers and product showcases: the
  first screen by default, `--full-page` for the whole page, `--selector "<css>"` for one element; see
  `cb docs capture`.

Projects live in the signed-in account's library, so `cb` needs the sign-in the desktop app shares. Exit 3 means nobody
is signed in (`cb auth login`), or, for commands that need the app, that it is not running or the project has no tab.
Exit 4 means out of credits; the human tops up in Settings › Usage. Other failures say what to fix.

## Color

Grading, matching a reference, fixing a cast or "make it look like this" starts with `cb docs color-grading`: the
method, recipes and how to measure frames instead of guessing. "Warmer" and "cooler" mean color temperature unless the
human is plainly talking about style; when a request could be a grade or a bigger edit, make the grade and offer the
rest. Match an attached reference by its path; do not add it to the project's media.

## The app

`cb app context|open|seek|play|pause`, `cb screenshot <out.png>` and `cb export <project> <out.mp4>` talk to the running
app. "Cardboard is not running" is a normal answer: editing, `verify`, `media *` and `audio *` work on the bundle alone,
while `look` and `export` need the app unless `cb` is the standalone install or a source checkout. Do not launch the app
yourself. Pass the project to every `app` command and `screenshot`, so you act on your tab and not the one the human is
looking at. A project with no tab gets one from `cb app open <project>`, behind the tab in front; every command works
there, and playback in it is silent. The human decides which tab is in front: add `--focus` only when they ask to see
the project.

An export encodes the whole video for minutes into a file you cannot watch either, and the human already sees the edit
in the app. Export when they ask for the video file, or when the task itself needs one (a file to upload, attach or hand
to another tool).

## Without the app: show every edit in the chat

When `cb` came with the Cardboard plugin (it lives in `~/.cardboard`) or you have a `preview` tool, the human has no
Cardboard app open and sees your work only in this chat. After each edit you report, show it:

1. Render a preview: `cb preview <project>`, or the `preview` tool. It draws a small 720p MP4 on this machine in a few
   seconds and never uses up an export, so preview every edit.
2. Share that file in this chat so it plays here, the way your app shows a local file: send or attach it, or link its
   path. In the Claude app, your code runs in the cloud: share the file from the folder the person added, at the path
   the tool gives inside the project's folder.
3. Then say in a sentence what changed.

Preview once a change is in place, not after each placeholder or fill of a multi-step build. If a long first preview
returns before it is done, call it again. With neither `~/.cardboard` nor a `preview` tool, the human watches the edit
in the app: do not preview.

## Habits

- Small edits, then `verify` and `look`; that is how an edit is checked. Do not rewrite a timeline you were asked to
  trim.
- Change `timeline.tsx` with targeted edits to the elements you mean, or a `--eval` script for many; a regex rewrite of
  the whole file drops elements. The apply prints `removed N items` when one went missing: `cb undo <project>` puts it
  back.
- `cb audio transcribe` returns word timings the editor, captions and search all share from one cached transcript, and
  `cb generate` places its footage and speech on the timeline itself. A local speech model, or media made with another
  tool and `media add`ed, has none of that, so use these.
- Report changes in terms of items, briefly: "moved the title to 0.5-3s, trimmed clip 2 by 1.2s". Leave out the
  commands, scripts and file paths behind them unless the human asked for a file or has to act on one.
