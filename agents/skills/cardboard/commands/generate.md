# cb generate — make media with hosted models

```
cb generate video <project> "<prompt>" [--quality standard|best] [--model <id>]
                  [--duration <s>] [--aspect 16:9|9:16|1:1] [--image <media|path>] [--ref <media|path>]... [--audio]
                  [--resolution 480p|720p|1080p] [--negative <text>] [--seed <n>]
                  [--character "<Name>: <description>"]... [--motion <text>]
                  [--first-frame "<prompt>" [--first-frame-model <id>] [--first-frame-image <media|path>]...]
                  [--start <s>] [--track <name|id>] [--name <label>] [--no-wait] [--json]
cb generate image <project> "<prompt>" [--quality standard|best] [--model <id>] [--aspect 16:9|9:16|1:1|4:3|3:4]
                  [--image <media|path>]... [--duration <s>] [--start <s>] [--track <name|id>] [--name <label>]
                  [--no-wait] [--json]
cb generate music <project> "<prompt>" [--duration <s>] [--section "<s>:<prompt>"]... [--auto] [--dry-run]
                  [--start <s>] [--track <name|id>] [--name <label>] [--json]
cb generate sfx   <project> "<prompt>" [--duration <s>] [--start <s>] [--track <name|id>] [--name <label>] [--json]
cb generate character <project> <Name> "<description>" [--json]
cb generate status <id> [--wait] [--cancel]
cb generate models [--json]
```

`generate video` places a pending clip on the timeline **before** the model runs and fills that same clip when the file
arrives. Narration (`cb generate voice`) is in `cb docs voice`.

- The placeholder goes on `--track` (else the first video track, else a new `Generated` track) at `--start` (else right
  after the track's last clip). Attributes you set on it meanwhile (opacity, transforms) carry over.
- The finished mp4 lands in the bundle as a normal media row with a `generation` record, and the clip is named after the
  prompt. A failed or cancelled run keeps its placeholder and reason visible until you remove it.
- Credits are charged once, when the model finishes; a run that fails at any step costs nothing.

## Tiers and models

| Pick                        | Model                  | Lengths (s)  | Aspects       | Sound                   | Use for                                           |
| --------------------------- | ---------------------- | ------------ | ------------- | ----------------------- | ------------------------------------------------- |
| `standard` (default)        | Kling 2.5 Turbo Pro    | 5, 10        | 16:9 9:16 1:1 | none                    | b-roll, establishing shots, anything redone       |
| `best`                      | Veo 3.1, 720p or 1080p | 4, 6, 8      | 16:9 9:16     | `--audio`, ~2x the cost | the shot that carries the video                   |
| `--model wan-3.0`           | Wan 3.0                | any, 2 to 30 | 16:9 9:16 1:1 | `--audio`, free         | a story in one take, a long single shot           |
| `--model minimax-h3`        | MiniMax H3, 768p       | any, 5 to 15 | 16:9 9:16 1:1 | always on               | the cheapest sound, the fastest return            |
| `--model gemini-omni-flash` | Gemini Omni Flash 1.1  | 3 to 8       | 16:9 9:16     | always on               | sound cheaper than Veo                            |
| `--model kling-3-standard`  | Kling 3.0 Standard     | 3 to 10      | 16:9 9:16 1:1 | `--audio`               | a bridge from one frame to another (`--image`)    |
| `--model seedance-2.5`      | Seedance 2.5           | any, 4 to 30 | 16:9 9:16 1:1 | `--audio`, free         | a long take; works from `--ref` stills and videos |
| `--model seedance-2.0`      | Seedance 2.0           | any, 4 to 15 | 16:9 9:16 1:1 | `--audio`, free         | text only, no `--image`                           |
| `--model grok-imagine-1.5`  | Grok Imagine 1.5       | any, 1 to 15 | 16:9 9:16 1:1 | always on               | sound in under a minute, a 1-3 s insert           |

Each model has its own default length: 5 s on Kling 2.5, Wan 3.0, H3, both Seedances, Grok, Kling 3 Standard and Kling 3
Pro, 6 s on Hailuo 02, 8 s on Veo and Gemini. `--seed` works on Veo and Wan 3.0; `--negative` on Kling 2.5, Veo, Kling 3
Standard and Kling 3 Pro. Either flag on another model is refused.

`--resolution` picks the size on the models that offer more than one: 480p, 720p or 1080p on Wan 3.0, both Seedances and
Grok; 720p or 1080p on Veo and Gemini. Every one of them renders 720p when it is not given. Each size costs its own rate
(1080p runs 1.5 to 2.5 times 720p; Veo charges the same for both), so ask for 1080p only when the shot needs it. The
other models render one fixed size and refuse the flag.

`--model` wins over `--quality`. `cb generate models` lists every id with lengths, aspects, audio, image and reference
input, resolutions and credits per second at each. `--duration` must be one of the model's lengths. Without `--aspect` a
clip takes the project's aspect, or the closest one the model renders when it has no such frame (a 4:5 project gets 1:1,
a 1:1 project on Veo or Gemini gets 16:9), and a note says so. Pass `--aspect` for any other frame, such as a 9:16
insert on a 16:9 edit. A shot from `--image` takes its frame from the still instead.

`--image` makes a still the first frame: a project image (id or name from `cb media ls`) or a png, jpg or webp path
under 8 MB, such as a frame from `cb media grab`. A shot from a still routes to the models that animate one faithfully
rather than the text-to-video tiers: `standard` is Hailuo 02 (6 or 10 s, silent) and `best` is Kling 3 Pro (3 to 10 s;
describe only the motion, since the still already carries the scene). `--model` still wins, except on Seedance, which
takes no `--image`; give it the still as a `--ref` instead, unless it shows a real-looking person (below).

`--first-frame "<prompt>"` draws that first frame in the same run instead, then animates it: one call, so the user
confirms and pays once, at the still's price plus the clip's. Use it whenever a still exists only to start a clip (an
opening frame, a product placed into a scene); `cb generate image` and then `--image` asks the user twice for what they
asked for as one clip. `--first-frame-image` (repeatable) is a picture the frame is drawn from, the base first, as
`generate image --image` takes it; `--first-frame-model` picks the image model (Nano Banana by default). The frame is
not checked before the clip runs, so put everything it must show in its prompt. It refuses `--image` and cast shots.

## References

`--ref` (repeatable) gives the model stills and videos to work from rather than start on: a product to put in the scene,
a place, a look, a move to copy. Name each in the prompt by kind and order, `@Image1`, `@Image2` for stills and
`@Video1` for videos, counting each kind in the order the flags give them:

```
cb generate video proj "@Image1 spins slowly on a marble counter, then the camera moves like @Video1" \
  --model seedance-2.5 --duration 8 --ref mug.png --ref "orbit.mp4#2-8"
```

A ref is a project image or video (id or file name) or a path. A video takes `#from-to` for a stretch of it in source
seconds; without one it goes whole. Stills are downsized to 1024 px and videos cut, fitted within 1280 px and uploaded
before the clip is placed. A prompt that names `@Image3` with two stills is refused.

| Model                  | Stills   | Videos                    | Price                                                                  |
| ---------------------- | -------- | ------------------------- | ---------------------------------------------------------------------- |
| `--model seedance-2.5` | up to 9  | up to 3, 2 to 30 s in all | stills free; with a video, every second sent or made at ~0.6x the rate |
| `--model minimax-h3`   | up to 5  | none                      | free                                                                   |
| `--model wan-3.0`      | up to 10 | none                      | free                                                                   |

A run with reference videos bills the seconds of video sent as well as the clip's, so a 6 s ref on a 5 s clip bills 11 s
at the video-ref rate (`cb generate models` lists it); give a range to send only what the shot needs. `--ref` refuses
`--image` and `--first-frame`.

Seedance refuses any ref that shows a real-looking person, generated ones and cast sheets included, and says so only
after its queue (a minute or more; the run costs nothing). Illustrated and cartoon characters go through. So it takes no
cast members: keep people for H3 or Wan 3.0, where cast members go with `--ref`, their sheet stills numbered after yours
so `@Image1` stays yours.

## Prompting

Say what is in frame, how it moves, and how the camera moves, in that order: "A ceramic mug on a wooden desk, steam
curling up, slow push-in, soft morning light". Name the style if it matters ("hand-drawn", "35 mm film"). Kling, Veo, H3
and Gemini hold one shot per clip; a cut inside one looks wrong. Wan 3.0 is the exception: it cuts between listed scenes
cleanly (below). `--negative` lists what to avoid; `--seed` reproduces a Veo or Wan 3.0 run.

## Stories in one take

A sequence of scenes that fits in 30 seconds and starts from nothing is one Wan 3.0 run, not a run per scene: it cuts
between the scenes itself and keeps the people the same across them. Name each recurring person once with their look,
then list the scenes in order:

```
cb generate video proj "A dad, late thirties, short dark hair, green henley, jeans, and his two kids, a girl of seven \
with braids and a pink backpack and a boy of five in a striped shirt. Scene 1: he greets them at the school gate and \
they hug. Scene 2: the three make sandwiches at the kitchen counter. Scene 3: on a park field he shows them how to kick \
a soccer ball. Warm afternoon light." --model wan-3.0 --duration 30 --audio --start 0
```

It is 720p unless `--resolution` says otherwise, one clip (changing one scene regenerates all of them), keeps no
reference for a later video, and a 30 s take waits about twelve minutes. Use cast members instead when a person has to
come back in another video, when a scene has to be redone or retimed on its own, or when the story runs past 30 seconds.
For a shorter story, `--model gemini-omni-flash --duration 8` holds four or five scenes in eight seconds for about a
third of the price. On the team's bench of twelve stories, one Wan 3.0 take kept its people in eleven at about $3 a
story; cast shots at `best` kept them in six at about $4; cast shots at `standard` in one.

## Images

`generate image` draws one still and places it as an image item, the same way: a pending still first (5 s, or
`--duration`), filled when the file arrives.

| Pick                      | Model                  | References | Use for                                                   |
| ------------------------- | ---------------------- | ---------- | --------------------------------------------------------- |
| `standard` (default)      | Nano Banana            | up to 6    | backgrounds, inserts, anything you might redraw           |
| `best`                    | GPT Image 2.5 Sunburst | up to 4    | fine detail and lettering: title cards, signage, diagrams |
| `--model seedream-5-lite` | Seedream 5.0 Lite      | up to 10   |                                                           |
| `--model nano-banana-2.1` | Nano Banana 2.1        | up to 10   | design and edits that keep a subject; ~2x Nano Banana     |

`--image` (repeatable) is a still to redraw or take from: a project image (id or file name) or a png, jpg or webp path.
Say what to keep and what to change ("this mug on a beach at dawn, same label"). References are downsized to 1024 px
before they go up. On Sunburst a redraw from references costs more than drawing from text; `cb generate models` lists
both prices. `--aspect` defaults to the project's, or the closest one the model draws (3:4 on a 4:5 project). Quote any
words the image has to spell. Sunburst has not been through the team's bench yet; Nano Banana is the model the cast
sheets are drawn with.

## Cast members

A person described in words is a different person in every clip. Anyone who appears in more than one shot is a **cast
member**, written `@Name` in the prompt:

```
cb generate video proj "@Maya pours coffee in a sunlit kitchen, slow push-in" --start 0 \
  --character "Maya: a South Asian woman in her early thirties, shoulder-length black hair, red wool scarf over a charcoal coat"
cb generate video proj "@Maya walks down a rainy street at night, handheld" --start 6
```

The first shot that uses a name passes `--character "Name: description"`. It draws a reference sheet (three stills of
the person, kept in the project and listed by `cb media ls --all`), then the video with the sheet as its reference
images. Every later `@Name` reuses the sheet; the `timeline.tsx` header lists the cast. An unknown `@Name` without
`--character` is an error. `cb generate character <project> <Name> "<description>"` draws the sheet alone, to check the
look before any shot.

Two recipes sit behind this, and the tier picks between them. `standard` (MiniMax H3) and the two-person `best` (Wan
3.0) send the sheet stills straight into a **reference-to-video** model: one step after the sheet, the whole prompt
drives the clip. The one-person `best` (Kling 3 Pro) draws a **keyframe** of the shot with the person copied from the
sheet, then runs image-to-video from that frame.

- **Describe the action, not the person.** The look lives on the member; repeating it in the prompt fights the sheet.
- **Cast everyone who comes back**, kids included. A shot with more than one `@Name` goes to `best` (Wan 3.0, which held
  both faces in every two-person casting the bench ran) unless you pass `--quality` or `--model`.
- **Open medium or closer, on one action.** The face must be large enough to read for the video to keep it; cut to the
  wide shot as a separate clip.
- **`--motion "<text>"`** applies to the keyframe recipe only (`--quality best` with one person, or `--model` naming a
  model that starts from an image): the full prompt shapes the first frame, `--motion` alone drives the video. On the
  reference recipe the whole prompt drives the clip and `--motion` is refused.
- The name is one word (`Maya`, `Theo_2`); the description is 20 to 1200 characters: age, build, hair, skin tone,
  wardrobe, and anything distinctive.

Cast shots route to models that keep a face: `standard` is MiniMax H3 from the sheet (5 to 15 s, 16:9 / 9:16 / 1:1,
sound included; the bench's cheapest cast recipe and the one a human liked in every clip rated so far), `best` is Kling
3 Pro from a keyframe for one person (3 to 10 s, `--audio` available) and Wan 3.0 from the sheet for two (2 to 30 s).
`--model` still wins, but it has to be a model that starts from an image or takes references. A cast shot draws its own
first frame or references and refuses `--image`. A first-use shot costs the video plus three stills (four on the
keyframe recipe) and takes 20 to 30 seconds longer.

## Music and sound effects

`generate music` composes instrumental music with Sonilo onto a pending `<audio>` on `--track` (else a `Music` track,
created if missing; a range already taken there goes on `Music 2`, `Music 3`…) at `--start` (else 0), and waits for it;
a track takes from a few seconds to about four minutes. `--duration` is whole seconds, 5 to 360, and defaults to
`--start` to the end of what is on screen (sound, hidden items and placeholders do not count; a sound-only timeline uses
its full length). Sonilo bills at least 10 s. The prompt is the overall style ("modern tech product launch,
instrumental").

`--section "<s>:<prompt>"` (repeatable) changes the mood at seconds into the track, not timeline seconds: the first at
0, each at least 5 s after the one before, the last at least 5 s before the end, at most 30, each prompt up to 200
characters. A section that breaks a rule is refused before anything is placed or charged.

`--auto` builds the sections from the timeline instead, at whole seconds within the rules above: quiet where speech
fills most of a section (cached transcripts; run `cb audio transcribe` first), full energy elsewhere, an accent where a
section starts on a visible title, and a clean ending. Changes too close together are dropped. With no speech or titles
in range it sends the prompt alone. `--dry-run` prints the duration and sections it would send and generates nothing,
free:

```
cb generate music proj "modern tech product launch, instrumental" --auto --dry-run
cb generate music proj "lo-fi, warm" --duration 30 --section "0:soft piano intro" --section "12:drums enter, brighter"
```

`generate sfx` makes one sound effect with ElevenLabs onto a pending `<audio>` on `--track` (else an `SFX` track) at
`--start` (else after the track's last item). `--duration` is 0.5 to 30 seconds, default 5. Place one per moment, with
`--start` at the timeline second it belongs to: "fast cinematic whoosh into an impact" at a title's entrance.

Both are charged per second once the server has the audio, and a run that fails before then costs nothing. If the
download or placement fails after that, the charge stands and the error names the audio's URL. `--json` gives
`{ id, mediaId, itemId, path, durationSeconds, credits }`, and a dry run `{ dryRun, durationSeconds, sections }`.

## Waiting or not

`video` and `image` wait and print the placed item; `--json` gives
`{ id, status, mediaId, itemId, path, model, credits, cast }` with `model` as `{ id, label, tier }`. A failed or
cancelled run exits 1 with `{ id, status, error, model, credits: 0 }`. `--no-wait` prints
`{ id, status, itemId, model, credits }` at once, and `cb generate status <id> --wait` finishes the placement later from
any `cb`. `status <id>` alone shows state and output URL; `--cancel` stops the run. A failed or cancelled placeholder
stays visible until you remove it, so the failure is not lost. If saving the completed file takes more than two minutes,
`--wait` returns with instructions to try `status <id> --wait` again. The server keeps the job; this does not start
another paid run.

## When it fails

Exit 4 (not enough credits) names the estimate. "Video generation is not configured on this host" (or music, or sound
effect) leaves nothing to do on your side. Anything the model rejected (length, aspect, a refused prompt) is reported
verbatim; adjust and rerun.
