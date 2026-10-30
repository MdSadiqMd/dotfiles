# cb media — a project's media

```
cb media add <project> <files-or-links...> [--no-copy] [--no-wait] [--res 720p|1080p] [--fps n]
cb media ls <project> [--all]
cb media rm <project> <media...>
cb media relink <project> <media> <path>
cb media relink <project> --folder <dir>
cb media proxy <project> [media...] [--force] [--res 720p|1080p] [--fps n]
cb media probe <project> <media|path>
cb media grab <project> <media|path> [--at <s> | --fps <n> [--from <s>] (--to <s> | --count <n>)] [--crop x,y,w,h] [--width <px>] [--height <px>] [--filter <name>] [--format <f>] [--quality <0-1>] [--out <file|->]
cb media filmstrip <project> <media|path> [--count <n> | --every <s> | --at <s,s,…>] [--columns <n>] [--tile-width <px>] [--out <file>]
cb media sheet <project> [media...] [--grid] [--columns <n>] [--tile-width <px>] [--out <file>]
cb media levels <project> <media|path> [--at <s>]
cb media scenes <project> <media|path> [--threshold <0-1>]
cb media matte <project> <media|path> [--from <s>] [--to <s>] [--occlusion] [--fast] [--out <file>] [--force]
cb media cutout <project> <media|path> [--fast] [--force] [--out <file>]
```

`add` probes each file, copies it into the bundle, and generates thumbnails, waveforms and (when the codec needs it)
playback proxies on device with the bundled ffmpeg. It prints one row per file: type, file name, duration, storage, id.
`--no-wait` prints rows as soon as posters exist and finishes the rest before exiting. `--res` and `--fps` size the
playback proxy (default 1080p), not the imported file; `proxy` makes proxies for the named media, or every video, where
the codec needs one (`--force` for all).

A link argument is downloaded first and imported like a file; see `cb docs download`. A link that cannot be downloaded
is listed as skipped with the reason, and the other files and links still import.

The bundle's copy is what the project uses, so the original may be moved, overwritten or deleted afterwards. On APFS the
copy is a clone and takes no extra space. `--no-copy` references the files in place instead; such a file must then stay
where it is for the project to keep working. Files under a temp dir (`/tmp`, `$TMPDIR`) or inside the library are always
copied. The `STORAGE` column says which happened. Paths written into `timeline.tsx` are copied in on apply, so `add` is
optional for them. `<media>` is an id or a file name from the media table.

`ls` shows on-disk status (present, missing, proxy state) and a `TRANSCRIPT` column (`✓ en`, `pending`, `-`); `--all`
adds the cast reference-sheet stills it leaves out otherwise. `ls --json` and `probe --json` include each file's `path`,
so there is never a reason to read `project.json` to find one. `relink` repairs missing items; with `--folder` it
matches every missing item by file name. `rm` deletes bundle-owned bytes and caches; remove the items that use the media
from `timeline.tsx` first.

## Seeing the media

These read the source file, not the timeline. Use them to decide where to cut before writing `in`/`out`.

- `probe` prints kind, duration, size, frame rate, codec and audio; a path (not yet added) works too. `--json` gives the
  full probe record.
- `grab` (also `frame` and `frames`) saves one frame at `--at` as PNG, or JPEG from a `.jpg` `--out`; images always grab
  at 0, and a time past a video's end gives its last frame. Without `--out` it writes `./<name>-<time>.<ext>`, the
  extension following `--format` (`png`, `jpg`, `rgba`, `rgb`, `gray`). With `--fps` it reads a run of a video's frames
  instead, from `--from` (default 0) to `--to` or for `--count` frames. See [Reading pixels](#reading-pixels).
- `filmstrip` tiles evenly spaced frames into one image and prints which source time each tile shows, left to right then
  down. `--at` takes a comma list of source times instead, one tile each, in that order.
- `sheet` tiles photos and videos into one image, each captioned with its file name, to compare them side by side
  (default: every photo and video in the project). `--grid` rules each picture every 0.1, heavier at 0.5, so positions
  can be read off as fractions.
- `levels` prints how bright a photo is, or a video at `--at` (default its middle; past the end, its last frame): the
  luma at each tenth of its pixels, darkest first.
- `scenes` lists shot changes as source seconds. `--threshold` (default 0.4) is how different two frames must be; lower
  it for slow dissolves, raise it for noisy handheld footage. Results are cached per media and threshold.

`filmstrip` and `scenes` need a video; `grab` also takes an image.

## Reading pixels

`grab` also hands a build the pixels it measures itself (where a face is, how bright a region is, a crop for a card).
`--crop x,y,w,h` keeps a region of the upright picture, in its pixels; `--width` and `--height` size the result (one
alone keeps the aspect, rounded), and `--filter area|bicubic|lanczos` says how to resize. `--format png|jpeg` encodes
one frame (`--quality 0-1` for JPEG, default best, refused for any other format); `rgba|rgb|gray` gives raw rows, top to
bottom. `--out -` writes the bytes to stdout; with a file, `--json` prints the size.

A run (`--fps`) is raw (default `rgb`), its frames back to back, and needs `--out`; `--json` with a file prints the
size, `from`, `fps` and how many frames came out, fewer than asked when the video ends first. `--at` and `--quality` are
for one frame only.

## Separating the subject

`matte` sends a video stretch or an image to Cardboard's GPU matting service and prints the path of the matte it gets
back: a grayscale file, white where the subject is and black elsewhere. A video matte is an H.264 MP4 at the source
frame rate whose first frame is source time `--from` (default 0); an image matte is a PNG. Mattes are at most 1920x1080,
so scale one to the source's size before combining the two.

- Video mattes find people; image mattes find the main subject, whatever it is.
- The default is a soft matte with edge detail (hair, motion blur), for cutting the subject out. `--fast` uses a lighter
  model that skips still frames.
- `--occlusion` gives a hard mask of the person, for putting text or graphics behind them. Frames where no one is
  confidently found are black, and the result reports the share of frames with a subject.
- One run covers at most 5 minutes of video; use `--from`/`--to` to pick the stretch the edit uses. Only that stretch is
  uploaded, silent and downscaled, and it is billed per minute matted.
- Mattes of project media are cached per media, stretch and mode, so asking again is free; `--force` makes a new one.
  `--out` also writes the file elsewhere. A path outside the project writes `./<name>-matte.<ext>` instead.

`cutout` puts the subject of a photo on a transparent background (a PNG, default `./<name>-cutout.png`), from its matte.
It costs credits unless the matte is cached, and it refuses a video before any matte is made.

`matte` and `cutout` cost credits unless the matte is already cached.

The timeline has no matte attribute yet, so combine a matte with ffmpeg and add the result as media. For example, a
title behind the speaker over 12-18s of a 1920x1080 clip:

```
ffmpeg -ss 12 -t 6 -i interview.mp4 -i <matte.mp4> -i title.png -filter_complex \
  "[1:v]scale=1920:1080,format=gray[m];[0:v]split[bg][fg];[fg][m]alphamerge[cut];[bg][2:v]overlay[titled];[titled][cut]overlay" \
  -c:v libx264 -pix_fmt yuv420p behind.mp4
```
