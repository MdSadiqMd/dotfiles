# cb capture — a screenshot of a web page

```
cb capture "<urls...>" [--out <path>] [--full-page] [--selector <css>] [--width <px>] [--height <px>] [--scale <n>]
           [--theme <light|dark|force-dark|system>] [--wait <seconds>] [--full-motion] [--project <project>]
```

`capture` opens each link in a headless browser and writes one image per link, printing its size, page title and path.
With `--project` the images are imported into that project instead, ready to place, and the table shows their media ids.
**Quote the link**, for the same reason as `cb download`.

## What it captures

- By default, the first screen: a 1440x900 viewport at 2x, so a 2880x1800 image that stays sharp when zoomed in the
  edit.
- `--full-page` captures the whole scrollable page the way someone scrolling it sees it: one screen at a time, stitched,
  so sticky scroll sections and blocks that appear on scroll come out filled in rather than blank. Headers and footers
  that stay on screen appear once, at the top and bottom. It takes a few seconds more per screen of page. A page too
  tall for one image at 2x is captured at a lower scale (down to 1x) rather than cut; only a page past 16384px at 1x is
  cut at the bottom, and a note on stderr says so. Write long pages as `.jpg`: a full-page PNG often runs past 10 MB.
- `--selector "<css>"` captures only the first matching element: a hero, a pricing table, a chart.
- `--width` / `--height` set the viewport in CSS pixels (try `--width 390 --height 844` for a phone-width layout);
  `--scale` sets the pixel ratio, 1 to 4.
- `--theme` picks the color scheme, `light` by default whatever the machine is set to:
  - `dark` asks for the site's own dark theme; a site without one stays light.
  - `force-dark` also has Chrome darken a page that has no dark theme of its own.
  - `system` follows this Mac's appearance.

  A site that keeps its theme behind its own toggle rather than the system setting shows its default either way.

- Pages are asked for reduced motion and entrance animations are waited out, so a still does not catch text or cards
  halfway in. Animation a site runs in a loop regardless (a rotating headline, a typing effect) can still be caught
  mid-way; capture again or add `--wait`. `--full-motion` keeps the page's own motion, for a site that hides something
  under reduced motion.
- `--wait 2` gives late content that many more seconds after load.

The page loads with no cookies, so it shows what a signed-out first visit shows, cookie banners included. Pages behind a
login cannot be captured. A page that answers with an HTTP error is still captured, with a note on stderr and its
`status` in `--json`; check the image before using it.

## Output

- `--out` is a folder (existing, ending in `/`, or a name without an extension) that gets `<host>-<path>.png`, e.g.
  `stripe.com-pricing.png`, or the image path itself for a single link. A `.jpg`, `.jpeg` or `.webp` extension picks
  that format; anything else is PNG. Without `--out`, images land in the working directory; an existing file of the same
  default name gets a `-2` suffix rather than being overwritten.
- `--out` and `--project` do not combine.

## The browser

`capture` runs a Chromium headless, with a throwaway profile, so no window opens and the browser you have open is
untouched. It uses the first of:

1. `CARDBOARD_BROWSER=/path/to/binary`, when set.
2. Google Chrome, Chromium, Edge, Brave or Dia, from their usual install locations.
3. Headless Chrome, downloaded from Google once (about 100 MB) on the first capture that finds none of the above, and
   reused after that.
4. Cardboard's own Chromium, when that download fails and `cb` came with the app.

Safari cannot be used. `cb doctor` shows the browser in use.
