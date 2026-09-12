# Draw the geometry, borrow the glyphs, let CSS do the colour

Twenty-five cosmetic assets were specified: four border shapes across three metal tiers, a level badge, eight card banners and twelve accolade glyphs. They are **seventeen files, and five things anyone has to draw**.

| | | |
|---|---|---|
| 4 border shapes + 1 level plaque | **hand-written SVG** | a single `<path>` each, 198–272 bytes |
| 8 card banners | **no files at all** | `linear-gradient()` over tokens the app already has |
| 12 accolade glyphs | **Lucide (ISC)** | one notice for the set, in `app/assets/images/accolades/NOTICE` |

**Colour lives outside the file.** An SVG referenced with `<img src>` is a separate document in secure static mode and cannot be recoloured from the page. That single fact is what turns four shapes into twelve tiers: the shape is the file, the metal is a `linear-gradient()` in the stylesheet, and bronze/silver/gold cost nothing but three class names.

**`mask-image`, not `currentColor`.** A mask source's colour is discarded by definition, so the background behind it can be the gradient a metal tier wants. `currentColor` can only ever be one flat colour, and a gold tier that cannot have a gradient is not a gold tier.

**Every border is a ring with a circular hole.** A pointed shape cannot enclose a 38px portrait inside a 48px slot — the arms of a star that big cover the face. So the hole is a circle at every tier and the shape is what changes around it: circle, shield, octagon, star, each in three metals, one game to about three hundred.

## Considered options

**Generate the set with an image model** — rejected, and *not* on licensing, which is fine. Rejected because it produces raster where a recolourable vector is required, because Gemini's SynthID watermark cannot be disabled, and because prompt-only output has no copyright for a vendor to assign. Twenty-four primary sources: [`research/art-generation.md`](../research/art-generation.md).

**Draw the twelve glyphs too** — rejected. A glyph is only ever seen in the profile showcase, at one size, and an ISC set costs a single notice file. The geometry is hand-written because it is the thing that has to be a ring of an exact diameter around an exact portrait, which no icon set ships.

**One file per tier (twelve border images)** — rejected: it is the same four shapes rendered three times, and it puts colour back inside the file where it cannot be themed.

## Consequences

Adding a fifth shape adds three tiers for one file. Adding a metal adds one class and re-tiers every shape at once.

A glyph inherits Lucide's stroke geometry, so the set is visually consistent with itself but not with the app's own hand-drawn icons (the try, the assist arrow, the flame). They never appear together: the glyphs live in the profile showcase and nowhere else.

Whether four shapes are **distinguishable at 38px in peripheral vision** is still open. Nothing in the specification addresses legibility, and it is a five-minute check on a real phone rather than something to settle in a stylesheet.
