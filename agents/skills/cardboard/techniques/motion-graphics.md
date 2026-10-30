# Motion graphics without the tells

Read this before you design any title, explainer, callout or end card, whether it is a `<code>` graphic or a `<text>`
item. Each rule below is a default that makes a graphic look machine-made. Leave it out unless the brief, the brand or
the footage asks for it.

## One continuous piece, not slides

Do not build a motion graphic as a slideshow: a scene appears, holds, fades out to an empty background, and the next
scene starts from nothing with its own centred heading and its own layout. The viewer sees the seams, and the empty beat
between scenes reads as the video stopping.

Plan the piece as one shot that keeps moving. Each scene should grow out of the one before it:

- Carry something across every change of scene. The leaf from the last scene becomes the frame you zoom into, a number
  becomes the bar it describes, a dot travels to where the next idea starts.
- Move from one idea to the next with a motivated transition (a push in, a pan across, one shape turning into another, a
  cut on matching shapes) rather than a fade to nothing. Overlap them, so the next scene is already arriving while the
  last one leaves.
- Keep one ground, one camera and one set of colors for the whole piece, so it feels like a single place.
- Let narration-style text change in place instead of giving every scene a new heading.

Scenes that share elements belong in one `<code>` graphic, where those elements can stay on screen across beats. When
scenes are separate items, overlap them on the timeline rather than placing them end to end.

## Uppercase labels and breadcrumbs

Do not put small uppercase labels above headings ("THE INGREDIENTS", "STEP 1 · LIGHT REACTIONS", "01 — INPUTS"), and do
not run breadcrumbs or section names in the top-left corner. They tend to multiply: one per scene, one per corner, the
same treatment on every element, until the frame is mostly labels.

The headline already says what the scene is about. If the viewer needs to know where they are in a sequence, say it in
the headline ("Next, the plant makes sugar") or show progress once, in one place. Write text in sentence case unless the
word itself is uppercase (an acronym, a brand that styles itself that way).

## Horizontal lines and underlines

Do not draw horizontal rules: a line under a title, a divider between heading and body, a short accent dash beside a
label, an underline or swoosh under a highlighted word, a line that wipes across before the text appears. They are the
quickest way to make a frame look "designed" and they say nothing.

Separate heading from body with size and space. Emphasize a word with weight or color, or give it its own beat. A line
belongs on screen only when it carries information: a chart's axis or baseline, a timeline the viewer reads.

## Grid lines in the background

Do not fill the background with graph-paper grids, dot grids, faint rules or network lines joining dots. They read as
"technical" decoration and add texture behind text without saying anything.

Use a plain ground, a gradient taken from the footage, or the footage itself. Value gridlines on a chart are fine.

## Orange and purple

Do not use orange or purple, alone or as a gradient, unless something in the request needs them: a brand color, a
sunset, a fire, the subject's own color. Orange accent words and purple glows are the two colors these graphics reach
for when no one chose a palette.

Take the palette from the footage (wardrobe, walls, light) or from the subject. With nothing to go on, use a neutral
ground and one accent from somewhere else on the wheel, and keep it the same across every scene.

## Typefaces and weight

Do not use Instrument Serif, for titles, quotes or anything else. It has become the default "elegant" face for this kind
of work.

Avoid Inter where you have a choice, and never set it bold or extra bold (`fontWeight` 700 and up). Heavy Inter
headlines are the most common look in generated graphics.

- `<text>` items: set `fontFamily` to another sans such as `Satoshi` or `Manrope`, at weight 400 to 500.
- `<code>` graphics: `Inter` is the only face that renders the same everywhere (see `cb docs code`), so use it at 400 to
  500 and build hierarchy from size and spacing. When a headline needs a different face, put it in a `<text>` item on a
  track above the graphic.

## Before you finish

Check your last `cb look` sheet against this page, frame by frame: look at every change of scene for an empty frame and
for what carries across, count the uppercase labels, look for lines under or between text and behind it, name every
color you used and why, and list each font and weight on screen. Sample the changes of scene closely (`--range` around
each one, `--every 0.25`), since a coarse sheet skips them. Fix what you find and look again.
