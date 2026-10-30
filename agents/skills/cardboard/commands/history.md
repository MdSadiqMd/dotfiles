# cb history / cb undo — timeline revisions

```
cb history <project> [--json]
cb undo <project> [rev]
```

The library keeps the last 20 timeline snapshots, one each time the timeline changes, whichever client changed it (the
app, `cb source apply`, `cb generate`); a save that leaves the timeline as it was adds none. Revisions are numbered by
their time in milliseconds, the same `rev` the `timeline.tsx` header carries.

`cb undo <project>` restores the snapshot before the current one; `cb undo <project> <rev>` restores a specific one from
`history`. Restoring is itself a save, so it shows up as a new revision and can be undone again.

`history` lists revisions newest first with the save time, track and item counts, and duration. Only the timeline
(tracks, items, aspect) is restored; media stays as it is.
