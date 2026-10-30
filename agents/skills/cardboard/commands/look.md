# cb look — see a frame

```
cb look <project> [--at <s>[,<s>...]] [--out <dir>] [--format png|jpeg] [--sheet <file>] [--width <px>]
cb look <project> --range <from,to> [--every <s>] [--out <dir>] [--format png|jpeg] [--sheet <file>] [--width <px>]
cb look <project> ... [--stats] [--compare] [--reference <media or path>]
```

Renders composited frames of the timeline: every track, effect, text, caption and code clip, exactly as the preview
shows them. Files land in `--out` (default `./look`) named by time (`frame-14_200.png`, `.jpg` with `--format jpeg`);
the command prints one row per frame with the time, size and path. `--at` defaults to the app's playhead and takes a
comma list (`--at 14.2,17.3,20.5`) when you want to check several beats in one call; `--range 0,10 --every 2` gives six
evenly spaced frames (`--every` defaults to 1). The app renders at most 240 frames per call. If a code clip fails to
render, a note on stderr names the graphic, the frame times and the error it threw, and those frames show the timeline
without it; fix the source rather than treating the graphic as absent from the timeline.

`--sheet review.jpg` tiles every rendered frame into one image, each cell captioned with its time, so a single file
answers "does the whole section look right". `--width 640` downsamples the frames (and the sheet's cells) so review
images stay small. Use both together when iterating on a graphic:
`cb look <project> --at 30.8,31.5,33 --width 640 --sheet review.jpg`.

Through MCP, inspection images share a response budget. Pictures that fit stay unchanged; larger pictures are compressed
as JPEG and downscaled when needed, with the delivered dimensions noted in the reply. The files on disk keep the
requested format and size. To inspect a small detail, ask for one frame instead of a large sheet.

When the app is running, frames come from its live renderer, in the project's own tab, without changing what the user
sees. When the app is closed, `cb` from a source checkout (`pnpm cli`) renders headlessly from the bundle (`--at` then
defaults to 0), slower and without playback-only effects; the `cb` the app installs asks you to open the app instead.

Frames come at the project's export size (1920x1080 for 16:9).

## Color

`--stats` measures the frames: exposure (luma median and mean), blacks, whites and contrast, the share of crushed and
blown pixels, the color cast of shadows, mids and highlights, saturation and the main hue bands. It prints them for all
frames pooled and a row per frame; `--json` has every number under `color`.

`--compare` renders every frame a second time with all grades, color sliders and LUTs off, into `<out>/before`, and
`--stats` measures both. On the sheet each row becomes before and after.

`--reference <media or path>` takes a project media name or id, or an image or video path. It is measured as well
(several frames across a video), the output gives the distance from the frames to it (lower is closer), and on the sheet
its still opens every row. It implies `--stats`.

`cb look <project> --at 4,18 --compare --reference ~/Desktop/ref.jpg --sheet grade.jpg --width 640` is one call that
answers "did the grade move it toward the reference". The method is in `cb docs color-grading`.
