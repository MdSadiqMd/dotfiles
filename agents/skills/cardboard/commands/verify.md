# cb verify — timeline lint

```
cb verify <project> [--json]
```

Runs the same lint the editor's agent uses over the saved timeline and reports errors and warnings: zero-length and
overlapping items, gaps on video tracks, items that read past the end of their media, placeholders still `pending`,
items on tracks that no longer exist, text blocks that overlap or are too small to read, captions out of frame, b-roll
hidden behind the main video, music that does not cover the picture, and colour grades off an adjustment track. It reads
`project.json`, so run `cb source apply` first when the app is closed.

Text output is a numbered list with a suggested fix per issue; `--json` prints `{ id, errors, warnings, issues }`. Exit
code 1 when there is at least one error.

It also warns about motion-graphic and text media rows no item renders any more; the next `cb source apply` drops them,
so there is nothing to fix by hand.
