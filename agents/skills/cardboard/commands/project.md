# cb project — bundles in the library

Projects are directory bundles, `<Name>.cardboard/`, holding `project.json`, `timeline.tsx`, media, and a `cache/` of
derived files, in a library per signed-in account; `cb project show` prints a bundle's path. Every command takes
`--json`.

```
cb project create <name> [--open]        empty project; --open opens it in Cardboard
cb project list                          id, name, media count, updated
cb project show <project>                one project
cb project open <project> [--focus]      open in Cardboard
cb project save-as <project> <file>      write one shareable .cbproj, media included
cb project reveal <project>              show the bundle in Finder
cb project rename <project> <name>       new display name; the bundle folder keeps its name
cb project rm <project> --yes            moves the bundle to the Trash
cb doctor                                library and config paths, ffmpeg/ffprobe, yt-dlp, project count
```

`<project>` is a name (case-insensitive, must be unique), an id, or a path to a `.cardboard` bundle or `.cbproj` file.
`project show` prints the bundle path; the timeline file is `<bundle>/timeline.tsx`. A bundle is named once, when the
project is created: a rename changes only the name in `project.json`, so the folder an agent works in never moves.

`project open` and `create --open` talk to the running app and return once the editor has loaded the project, in a tab
behind the one in front; `--focus` brings it forward. With no app running they launch the installed Cardboard on macOS.
A bundle path outside the library is opened as an imported copy, and so is a `.cbproj`. `cb doctor` exits 1 when ffmpeg
or ffprobe is missing.

`save-as` writes the project as one file rather than a directory, because a bundle uploaded to Drive, attached to mail,
or copied to Windows arrives as a folder of loose parts. Media the project referenced in place is copied in and
regenerable bytes (`proxies/`, `cache/`, `.revs/`) are left out, so the file opens on a machine that has never seen the
footage. Footage that was already missing is named in the result rather than failing the write; whoever opens it is
asked to relink.
