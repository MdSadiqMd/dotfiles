# cb app — the running editor

These commands talk to the running desktop app. When it is closed they fail with exit code 3 and
`Cardboard is not running`, which you can treat as a signal to use the bundle commands instead.

```
cb app context [project] [--json]  open tabs, and for one tab: project, route, playhead, playing,
                                   duration, aspect, selection, zoom, track/item counts, exporting
cb app open <project> [--focus]    open a project in its own tab, behind the one in front
cb app seek <seconds> [project]    move the playhead
cb app play [project]              start playback
cb app pause [project]             pause playback
cb screenshot <out.png> [project]  a tab's whole window area, chrome included
```

The app shows every open project in its own tab, each with its own editor and renderer. Commands that take an optional
`[project]` act on that tab, whether or not it is in front; without it they act on the tab the user is looking at. A
project that has no tab answers `not open in a tab` (exit code 3); `cb app open` gives it one, behind the tab in front,
so the human and other agents keep what they are looking at. Only the tab in front is heard: playing a tab behind it is
silent. `--focus` brings the tab forward; use it only when the human asked to see the project. `context` lists every tab
with its name, whether it is active, exporting, or asleep (unloaded to save memory; any command targeting it wakes it).

`app context --json` prints `{ running: false }` when the app is closed, so a script can branch without parsing an
error.

Editing `timeline.tsx` needs none of this. Use `app` to move the playhead, watch playback, or read what the user has
selected.
