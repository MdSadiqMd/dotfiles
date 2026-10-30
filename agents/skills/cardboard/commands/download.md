# cb download — the video behind a link

```
cb download "<urls...>" [--out <path>] [--max-height <px>] [--audio-only] [--browser <name>] [--cookies <file>]
cb download --update ["<urls...>"]
cb media add <project> "<urls...>" [--max-height <px>] [--audio-only] [--browser <name>] [--cookies <file>]
```

`download` fetches what a link points at (YouTube, X, Instagram, TikTok, Vimeo, a plain file URL, or any other site
yt-dlp knows) and prints one row per file: site, title, duration, path. `cb media add` takes the same links in place of
file paths and copies the result into the bundle, ready to cut when it returns.

**Quote the link.** Unquoted, the `?` and `&` in a watch URL make zsh fail with `no matches found` and bash drop
everything after the `&`, and neither error mentions the URL.

One link is one video: a link that also names a playlist takes the video, and a playlist or channel link takes its first
video.

## Output

The best video and audio merged into one mp4, preferring h264/aac when a site offers the same size in several codecs.

- `--out` is a folder (existing, ending in `/`, or a name without an extension) that gets `<title> [<id>].mp4` (a plain
  file link keeps its own name, without the query), or a file name for a single link. The extension follows what came
  down: `--audio-only --out talk.mp4` lands `talk.m4a`. Without `--out`, files land in the working directory.
- `--max-height 1080` caps the height (a 1080x1920 reel counts as 1920 tall); a site with nothing under the cap gives
  its best size instead.
- `--audio-only` takes the audio alone, as m4a.
- Private posts, age-gated videos and most of Instagram need a signed-in browser's cookies:
  `--browser chrome|safari|firefox|edge|brave`, or `--cookies <file>` in Netscape format. When a site refuses, the error
  says what it wants.

## The downloader

Downloads run through yt-dlp, which installs itself on first use and updates itself when a site has changed.
`cb download --update` updates it by hand (then downloads any links given), `cb doctor` shows the copy in use, and
`CARDBOARD_YT_DLP=/path/to/yt-dlp` uses your own.
