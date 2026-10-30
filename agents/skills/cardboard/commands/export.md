# cb export — render the project to a file

```
cb export <project> <out> [--res 720p|1080p|4k] [--fps <n>] [--format mp4|webm|mov|mkv]
                          [--quality very low|low|medium|high|very high] [--no-wait]
cb export <project> [out] --cloud [--res ...] [--fps <n>] [--format ...] [--quality ...] [--no-wait]
```

Writes the finished video to `<out>`. Run it when the human asks for the file or a task needs one; to check an edit, use
`cb look` and `cb verify`, which answer in seconds without encoding the whole video. Defaults: the aspect's default
resolution preset, frame rate picked from the media (30 when rendering headlessly), `mp4`, `high` quality. An `<out>`
without an extension gets the format's. Progress goes to stderr; stdout gets one line (`Exported to <path>`) or, with
`--json`, the job record `{ jobId, state, progress, status, out, error?, logPath?, startedAt, finishedAt? }`. Exit code
1 when the export failed or was cancelled.

The account's plan decides the size and the count: `--res 4k` needs Creator or higher, and Lite includes three exports.
An export the plan does not cover is refused before anything renders, with a message naming the plan that would allow it
(exit code 4 when rendering from the bundle, 1 when the app runs it); do not retry it at the same size. With `--root`
and nobody signed in there is no plan to ask, so exports stop at 1080p.

Every export the app runs keeps a diary at `logPath`: phases with timings, the encoder, code-clip sandbox boots and
retries, warnings, and the outcome. A failure message ends with `(log: <path>)`; read that file before retrying.

When the app is running the export uses its encoder and writes straight to `<out>`, in the project's own tab, without a
save dialog or changing what the user sees. `--no-wait` returns after the export has started; poll
`cb app context <project>` until `exporting` clears. One export runs per project at a time, so starting another while it
runs fails with "already running"; different projects can export at once.

When the app is closed, `cb` from a source checkout (`pnpm cli`) renders headlessly from the bundle with ffmpeg;
`--no-wait` has no effect there and `--json` prints `{ path, duration, renderMs }`. The `cb` the app installs asks you
to open the app instead.

`--cloud` renders in Cardboard's export pool instead of on this machine, from the originals in Cardboard's storage. `cb`
sends the timeline; every clip it uses must already be uploaded to the project, or the export is refused with the media
ids that are missing. The finished file stays in Cardboard's storage; `<out>`, when given, also saves it here. Progress
goes to stderr; `--json` prints `{ exportId, status, downloadUrl, error, path }`, and `--no-wait` returns once the pool
has the export. The plan's size and count rules apply as above (exit code 4).
