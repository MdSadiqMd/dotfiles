# cb voice — narration and the voices it speaks with

```
cb generate voice <project> "<text>" [--voice <id|name>] [--speed 0.5-2] [--stability 0-1] [--style 0-1]
                  [--language <code>] [--target-duration <s>] [--start <s>] [--track <name|id>] [--name <label>] [--json]
cb voice ls     [--owned] [--json]
cb voice search [text...] [--gender male|female|neutral] [--accent <name>] [--language <code>] [--cursor <token>] [--json]
cb voice show   <id> [--json]
cb voice clone  <name> <media|path>... [--project <project>] [--from <s>] [--to <s>] [--json]
cb voice rm     <id> --yes
```

`generate voice` speaks the text with an ElevenLabs v3 voice into a pending `<audio>` on `--track` (else the first audio
track, else a new `Voiceover` track) at `--start` (else after the track's last item), and waits for it. The word timings
are stored as the media's transcript, so `cb audio captions` and `cb audio search` work without transcribing. `--voice`
takes an ElevenLabs voice id or the exact name of one of the account's voices; without it, the voice the account spoke
with most recently.

Write the text as it should be heard: short sentences, punctuation for breath, tags like `[whispers]` or `[laughs]`.
`--stability` snaps to 0 (creative), 0.5 (natural, the default) or 1 (robust); `--style` sets how strongly it performs;
`--speed` sounds natural at about 0.9–1.1; `--target-duration <s>` nudges the pace towards a gap's length. `--json`
gives `{ id, status, mediaId, itemId, path, voice, durationSeconds, credits, transcriptStored }`.

## Picking a voice

`cb voice ls` lists the account's voices: favourites, the ones it spoke with recently, and its clones (`--owned` lists
only the clones). Keep a series or a returning narrator in one of these.

`cb voice search` searches the ElevenLabs library, most-used voices first. It needs text or a filter:

```
cb voice search calm british narrator --gender male
cb voice search --accent indian --language en
```

`USE 1Y` is how much the voice was used across ElevenLabs in the last year; a widely used voice that fits the brief is
the safe pick. `cb voice show <id>` adds the description and a preview URL to hand the human. When there are more
results, the last line gives the `--cursor` for the next page.

## Cloning

`cb voice clone "<name>" <sample>...` makes a clone and prints its id. Samples are audio or video paths, or, with
`--project`, media ids / file names from `cb media ls`. `--from`/`--to` apply to every sample, so pass one source when
you cut a stretch out of it. Give 30 seconds to 3 minutes of one person speaking, with no music or crosstalk. Each clone
is charged once: reuse it (`cb voice ls --owned`) rather than cloning again. `cb voice rm <id> --yes` deletes one.

## When it fails

- "None of your voices is named …": find the voice with `cb voice search` and pass its id.
- "No recent voice to default to": pass `--voice`.
- A refused clone sample (silent, too short, music or several speakers): cut a cleaner stretch with `--from`/`--to`.
