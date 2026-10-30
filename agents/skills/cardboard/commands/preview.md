# cb preview — a playable file of the latest edit

```
cb preview <project> [--out <file.mp4>] [--no-fast]
```

Renders the timeline as it is on disk to a small 720p, 30 fps MP4 with sound and prints its path. It never needs the
app: it reads the bundle, plays video from its proxies where they exist, and draws on this machine, so nothing is
uploaded and no export is spent. Run it after an edit when the human cannot see the app, and share the file in the chat
so they can watch the change; use `cb look` to check frames yourself.

The timeline is cut into segments of at most 1.5 seconds at its cuts, and each segment is kept in the bundle's
`cache/preview/`. The next preview re-renders only the segments an edit changed and copies the rest, so a title or clip
change comes back in about two seconds and a sound-only change in about one; a `<code>` graphic takes about five, since
Chromium draws it frame by frame. An edit that moves everything after it (a ripple delete or trim) re-renders only
around the edit, as long as it moves the rest by whole frames, as tenths of a second do. The first preview of a project
renders it all, about a quarter of the timeline's length. Segments from the last two previews are kept, so undoing an
edit finds its old segments again.

`--out` writes the file elsewhere (default `cache/preview/latest.mp4` in the bundle); the file is replaced in one step,
so a player already holding the last preview never reads half a file. `--no-fast` draws every frame on the canvas, as a
local export does, instead of letting ffmpeg draw plain cuts and simple overlays: slower, for checking a frame the fast
path drew. Pending items render as nothing and are counted on stderr.

stdout gets the path, size and work done
(`Preview at <path> (60.0s, 5.7 MB, 3 of 47 segments rendered (4.0s), 44 reused, 1.6s)`, then the path inside the
project's folder) or, with `--json`,
`{ path, inProject, bytes, duration, segments, rendered, renderedSeconds, audioReused, fastPathSegments, timings }`,
where `timings` holds `planMs`, `renderMs`, `audioMs`, `muxMs` and `totalMs`. Progress goes to stderr.

`cb mcp` serves the same render as the `preview` tool, which returns the same fields. A call waits up to 170 seconds; a
longer first render keeps going, and calling `preview` again waits for the rest.

Only the standalone `cb` and a source checkout render previews; the `cb` inside the app does not offer the command or
the tool. A preview is not an export: it is always 720p from proxies and is meant for checking the edit, not for
delivery. Use `cb export` when the human asks for the video file.
