# cb audio — hear a project's media

```
cb audio transcribe <project> <media> [--format text|words|json|srt|vtt] [--language xx] [--force] [--timeline]
cb audio search <project> "<phrase>"
cb audio captions <project> [--words <n>] [--preset <id>] [--language xx] [--name <track>] [--apply]
cb audio waveform <project> <media> [--width <px>] [--height <px>] [--out <file>]
cb audio levels <project> <media> [--points <n>]
cb audio silence <project> <media|path> [--threshold <dB>] [--min <seconds>]
cb audio loudness <project> <media|path>
```

Every command reads the audio stream of any media, video or not. `<media>` is an id or a file name, as in
`cb media probe`.

## Transcripts

`transcribe` returns the whole transcript with per-word timings in seconds, through the same transcription the editor
uses. Only the audio stream is sent, so a video costs the same as its soundtrack. The result is cached in the bundle for
every later call and for the editor's captions; `--force` transcribes again.

Formats: `text` (paragraphs, default), `words` (`[mm:ss.mmm] word` lines for exact cut points), `srt`, `vtt`, `json`
(segments with word timings). `--language` is a BCP-47 code; without it the language is detected and shown in the
`TRANSCRIPT` column of `cb media ls` (`✓ en`, `pending`, `-`).

`--timeline` maps every word through the clips that play this media (`start`, `in`, `out`, `playbackSpeed`), so times
are timeline seconds and words outside any clip are dropped. Use it to find where a sentence lands in the edit; use the
default for where it sits in the source before you write `in`/`out`.

`search` matches a phrase, ignoring case and punctuation, across every media that already has a transcript, and prints
both source times per file and timeline times per clip. It never transcribes; run `transcribe` first.

## Captions

`captions` builds a `<track kind="caption">` for the current timeline from the transcripts of every audible clip,
transcribing the ones not cached yet. It prints the JSX to paste into `timeline.tsx`; `--apply` adds the track to the
timeline instead, above the footage. The first `<track>` draws on top, so a caption track pasted after the footage draws
under it and does not show. `--words` sets words per caption (default 5), `--preset` picks one of the editor's caption
styles, `--name` the track name (default `Captions`). Each item carries `captionText` and `captionWordTimings`, so the
editor can restyle or retime them afterwards.

## Levels

- `waveform` draws the audio as an image.
- `levels` prints peak and RMS (0-1) sampled at `--points` positions across the track (default 200), for finding beats
  or the loudest moment; `--json` gives `{ duration, step, peaks[], rms[] }`.
- `silence` lists stretches below `--threshold` dB (default -30) lasting at least `--min` seconds (default 0.5); an
  empty list means no such stretch. Good for trimming dead air before you cut.
- `loudness` measures integrated loudness (LUFS), loudness range, true peak, and mean/max volume, for matching levels
  between clips or checking a mix against a delivery target (-14 LUFS for most platforms).

`silence` and `loudness` also accept a path to a file that is not in the project. Media without audio refuses all of
these. Shot detection for video is `cb media scenes`.

## Online and offline

`transcribe`, and `captions` for any media without a cached transcript, go online and bill credits; exit 4 means the
account has no transcription capacity left. The rest run offline.
