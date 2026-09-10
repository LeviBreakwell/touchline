# How the 25 cosmetic assets get made

There was no `docs/research/` directory. This file creates it. `docs/adr/` stays for decisions; this is the reading behind one.

The set is fixed (CONTEXT.md, #21/#22): 4 border shapes, 8 card banners, 1 level badge frame, 12 accolade glyphs. Border colours are CSS tokens, not art. This document is about how those pieces come into being, not what they look like.

## 1. Format

Nothing in any spec promises SVG renders well at 30–38px. What the spec offers is a hint. SVG 1.1 §11.7.3 defines `shape-rendering: crispEdges` as "the user agent shall attempt to emphasize the contrast between clean edges of artwork over rendering speed and geometric precision. To achieve crisp edges, the user agent might turn off anti-aliasing for all lines and curves or possibly just for straight lines which are close to vertical or horizontal. Also, the user agent might adjust line positions and line widths to align edges with device pixels" ([w3.org/TR/SVG11/painting.html](https://www.w3.org/TR/SVG11/painting.html)). Every verb there is "might". SVG has no hinting mechanism the way a font does, and the default `auto` gives "geometric precision more importance than speed and crisp edges" — which is the opposite of what a 2px stroke at 38px wants.

That matters less than it sounds, because the target is a phone. `devicePixelRatio` is defined as CSS pixel size divided by device pixel size ([CSSOM View](https://www.w3.org/TR/cssom-view-1/)), and on a 3× phone a 38px border is 114 device pixels. Sub-pixel geometry is not the failure mode at that density; silhouette is. A shield and an octagon differ by four corners and that difference has to survive at thumbnail size regardless of format.

Raster loses on a different axis. To cover 38px and 88px across 1×/2×/3× you ship six exports per shape, or one 264px master downscaled. Measured on this repo: `public/icon-192.png` is 13,406 bytes and `public/apple-touch-icon.png` is 12,588 bytes for a single icon. A stroked shield path written by hand is 180 bytes, an octagon 165, a star 210. One raster icon costs more than the whole vector set.

The recolouring question decides it. Three ways to put an SVG on the page, and they are not equivalent:

**`<img src="shield.svg">`** cannot be recoloured. SVG referenced by an HTML `img` element uses the animated or static image document referencing mode, which "must use the secure animated processing mode" / "secure static processing mode", and in both of those the feature table reads `external references: no`, `script execution: no` ([SVG Integration §2, §3.4, §3.6](https://www.w3.org/TR/svg-integration/)). It is a separate document; the host page's cascade, including custom properties, does not reach it. Nothing in the file can be driven from CSS.

**Inline SVG** can. SVG 2 says the `color` property "is used to provide a potential indirect value, currentColor, for the fill, stroke, stop-color, flood-color and lighting-color properties", and gives the case of "the inherited value of the color property from an HTML document" setting colour "in an inline SVG fragment" ([SVG 2 painting](https://www.w3.org/TR/SVG2/painting.html)). The cost is that the bytes go into every HTML response — a dozen borders on a leaderboard is a dozen copies, uncached and undigested.

**`mask-image`** gets recolour without inlining. The property "sets the mask layer image of an element" and accepts "a URL reference to a mask element … or to a CSS image"; `mask-mode: alpha` means "the alpha values of the mask layer image should be used as the mask values", `luminance` the luminance values ([CSS Masking 1](https://www.w3.org/TR/css-masking-1/)). The source's own colour is discarded entirely — the element's background paints the shape. One cached, digested file, any colour, including a gradient. Baseline reports Masks as widely available since 2026-06-07, first available 2023-12-07, with Safari 15.4 (2022-03-14) and Chrome 120 (2023-12-05) ([api.webstatus.dev/v1/features/masks](https://api.webstatus.dev/v1/features/masks)).

So: SVG, and the choice between inline and mask is a caching choice, not a fidelity one.

## 2. Generation options

### AI image generation

**OpenAI** (Terms of Use, Effective January 1, 2026, [openai.com/policies/terms-of-use](https://openai.com/policies/terms-of-use/)): "As between you and OpenAI, and to the extent permitted by applicable law, you (a) retain your ownership rights in Input and (b) own the Output. We hereby assign to you all our right, title, and interest, if any, in and to Output." The "if any" is doing work — see the Copyright Office note below. Also: "Due to the nature of our Services and artificial intelligence generally, output may not be unique and other users may receive similar output from our Services." No clause restricts redistributing Output inside a product.

**Midjourney** (Terms of Service, Version Effective Date: May 27, 2026, [docs.midjourney.com](https://docs.midjourney.com/hc/en-us/articles/32083055291277-Terms-of-Service)): "You own all Assets You create with the Services to the fullest extent possible under applicable law." Two exceptions bite. "If you are a company or any employee of a company with more than $1,000,000 USD a year in revenue, you must be subscribed to a 'Pro' or 'Mega' plan to own Your Assets." And you grant Midjourney "a perpetual, worldwide, non-exclusive, sublicensable no-charge, royalty-free, irrevocable copyright license to reproduce, prepare derivative works of, publicly display, publicly perform, sublicense, and distribute … any Assets produced by You through the Service", plus "By default, Your Content is publicly viewable and remixable" unless Stealth is bought. Fine for a free app; the ownership survives cancelling.

**Google**: the Generative AI Additional Terms are dead — "We updated the Google Terms of Service on May 22, 2024 to cover AI-related topics. As of that date, these Generative AI Additional Terms of Service no longer apply" ([policies.google.com/terms/generative-ai](https://policies.google.com/terms/generative-ai)). The main Terms (Effective July 30, 2026, AU version, [policies.google.com/terms](https://policies.google.com/terms)) say "Your content remains yours, which means that you retain any intellectual property rights that you have in your content" but that clause is about content you provide; the document never assigns output. It does prohibit "misleading others into thinking that generative AI content was created by a human" and "using AI-generated content from our services to develop machine learning models or related AI technology". Separately, Gemini stamps every image: the visible-watermark toggle "only controls the visible watermark. It doesn't affect SynthID watermarks or Content Credentials for media you create with Gemini Apps" ([support.google.com/gemini/answer/17405358](https://support.google.com/gemini/answer/17405358)).

**Stability AI** (Community License Agreement, Last Updated: July 5, 2024, [stability.ai/community-license-agreement](https://stability.ai/community-license-agreement)): "Ownership of Outputs. As between You and Stability AI, You own any outputs generated from the Models or Derivative Works to the extent permitted by applicable law." Commercial use is free below "US $1,000,000 … annual revenue" but "If You are using or distributing the Stability AI Materials for a Commercial Purpose, You must register with Stability AI." The attribution clause attaches to distributing "the Stability AI Materials or a Derivative Work to a third party, or a product or service that uses any portion of them", and then requires a Notice file and to "prominently display 'Powered by Stability AI'". Whether shipping only generated PNGs counts as a product "that uses any portion of them" is not resolved by the text.

**Adobe Firefly**: the Generative AI User Guidelines say "You must not remove, alter, or disable any Content Credentials" ([adobe.com/legal/licenses-terms/adobe-gen-ai-user-guidelines.html](https://www.adobe.com/legal/licenses-terms/adobe-gen-ai-user-guidelines.html)). The commercial-use grant lives in the Product Specific Terms, which would not serve — see the last section.

The common problem is upstream of all of them. The US Copyright Office holds that "when an AI technology receives solely a prompt from a human and produces complex written, visual, or musical works in response, the 'traditional elements of authorship' are determined and executed by the technology — not the human user … these prompts function more like instructions to a commissioned artist … When an AI technology determines the expressive elements of its output, the generated material is not the product of human authorship. As a result, that material is not protected by copyright and must be disclaimed in a registration application" ([Copyright Registration Guidance: Works Containing Material Generated by Artificial Intelligence](https://www.copyright.gov/ai/ai_policy_guidance.pdf), pp. 4). Every ToS assignment above is of whatever rights the vendor has, which by that reading is nothing. For a free app with no licensing ambitions this costs nothing in practice; it does mean "we own the art" is false however the ToS is worded.

The practical objection is simpler: all five produce raster. A border shape needs a clean vector outline, and a traced raster is worse than a hand-written path plus the tracing step.

### Programmatic SVG

The four border shapes are a circle, a rounded polygon, a regular octagon and a five-point star. All are closed paths from a handful of vertices. Measured, written by hand: shield 180 bytes, octagon 165, star 210, each a single `<path>` with `stroke="currentColor"`. That is the whole cost — under an hour of work for the four, and a fifth shape is another twenty minutes, which is exactly the extensibility CONTEXT.md asks for.

Libraries exist and are not needed at this size. `victor` (MIT, v0.5.0, 1,315,226 downloads, "Build SVG images with ease", [rubygems.org/gems/victor](https://rubygems.org/gems/victor)) builds SVG from Ruby; for four static files an ERB partial or a checked-in file is less machinery. CSS can do part of it without any file: `polygon()` takes "`[<'fill-rule'>]? [ round <length> ]? , [ <length-percentage> <length-percentage> ]#`" where "Each `<length-percentage>` pair specifies a vertex of the polygon, as a horizontal and vertical offset from the left and top edges of the reference box" ([CSS Shapes 1](https://www.w3.org/TR/css-shapes-1/)). But `clip-path` clips, it does not stroke — a border is an outline, so this only helps if the border is a coloured box clipped to the shape with the avatar clipped inside it. Workable, fiddly, and it costs the ability to vary stroke weight.

The eight banners need no asset at all. A low-opacity gradient across a card is a `linear-gradient()`, eight CSS classes over the existing tokens, zero files, zero bytes over the wire beyond the stylesheet.

### Bought asset packs

None of the major sets forbids redistribution inside a public app. They split on how much attribution costs.

**Heroicons** — MIT, "Copyright (c) Tailwind Labs, Inc.": "Permission is hereby granted, free of charge, to any person obtaining a copy of this software … to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies", conditioned on "The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software" ([LICENSE](https://github.com/tailwindlabs/heroicons/blob/master/LICENSE)).

**Lucide** — ISC, "Copyright (c) 2026 Lucide Icons and Contributors": "Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies." Icons derived from Feather carry MIT, "Copyright (c) 2013-present Cole Bemis" ([LICENSE](https://github.com/lucide-icons/lucide/blob/main/LICENSE)).

**Iconoir** — MIT, "Copyright (c) 2021 Luca Burgio", same conditions as Heroicons ([LICENSE](https://github.com/iconoir-icons/iconoir/blob/main/LICENSE)).

Those three cost one notice, once, anywhere — a `NOTICES` file or an about-page line. Nothing per icon, nothing per author, and modification is unrestricted and unlabelled.

**Font Awesome Free** — split licence: "The Font Awesome Free download is licensed under a Creative Commons Attribution 4.0 International License and applies to all icons packaged as SVG and JS file types", SIL OFL for the font files, MIT for the rest, and "Attribution is required by MIT, SIL OFL, and CC BY licenses. Downloaded Font Awesome Free files already contain embedded comments with sufficient attribution, so you shouldn't need to do anything additional when using these files normally" ([LICENSE.txt](https://github.com/FortAwesome/Font-Awesome/blob/6.x/LICENSE.txt)). The escape hatch is the embedded comment, and stripping an icon to a bare path for masking removes it. CC BY 4.0 §3(a) then requires retaining "identification of the creator(s)", "a copyright notice", "a notice that refers to this Public License", "a notice that refers to the disclaimer of warranties", "a URI or hyperlink to the Licensed Material to the extent reasonably practicable", and separately to "indicate if You modified the Licensed Material and retain an indication of any previous modifications" ([legal code](https://creativecommons.org/licenses/by/4.0/legalcode.en)). It is satisfiable — the same section allows satisfying the conditions "in any reasonable manner based on the medium, means, and context" and says "it may be reasonable to satisfy the conditions by providing a URI or hyperlink to a resource that includes the required information" — but it is a standing obligation that survives every edit.

**game-icons.net** — "Creative Commons 3.0 BY license", "you can use them freely as long as you credit the original author in your creation", with the suggested form "Icons made by {author}. Available on https://game-icons.net" ([about](https://game-icons.net/about.html)). Authorship is per icon. Twelve glyphs from that library plausibly means several named authors, each credited, forever. It has by far the best sport-and-achievement vocabulary of the six, and by far the highest ongoing cost.

**The Noun Project** — free downloads are CC BY 3.0: "This license allows you to use the Icon for free through the Services, as long as you attribute it to the Icon creator." Paying removes it: "If an Icon is provided pursuant to the CC BY 3.0 License, you may pay a License Fee and use the Icon without providing attribution to the Icon creator." Resale is separately gated — "Unless an Icon is in the Public Domain, you may only obtain Icons for use on items for resale: 1) by paying a License Fee … 2) by providing full attribution in legible font on the item for resale … or 3) through paid access to our API", capped at "up to 1,000 units of such item for each license purchased" ([terms of use](https://thenounproject.com/legal/terms-of-use/)). A free app is not resale, so that clause is inert here. Noun Pro is listed at "$3.33/month (paid yearly)" with "No attribution required" ([pricing](https://thenounproject.com/pricing/)).

### Commissioned work

The only first-party price list that survives fetching is a marketplace one. 99designs Australia lists fixed contest packages at "Bronze A$449, Silver A$739, Gold A$1,299, Platinum A$1,899", "Prices exclude Sales Tax", each including "Full copyright ownership" ([99designs.com.au/pricing](https://99designs.com.au/pricing)). That price is one design brief, not a 25-piece family, so treat it as a floor for "get a designer involved at all" rather than a quote.

The IP terms are the standard worth knowing. 99designs' Design Transfer Agreement (revised September 3, 2024) §5.1: "Effective as of the Effective Date, and subject to Section 5.2 below, Designer hereby assigns to Client all of Designer's right, title and interest in and to the Transferred Design, including all worldwide intellectual property rights that Designer owns or otherwise holds in the Transferred Design" ([DTA](https://99designs.com.au/legal/design-transfer-agreement)). Full assignment on payment, with a carve-out where the designer built on third-party IP. That is the shape to insist on in any direct commission too.

## 3. Theming

The app is dark-committed: `body` sets `color-scheme: dark` over `--gray-50: #0d1117`, with `--white: #161b22` as the card ground ([app/assets/stylesheets/application.css](../../app/assets/stylesheets/application.css)). Bronze is the tier at risk — it is the darkest of the three metals sitting on the darkest ground, and it has to stay separable from silver in peripheral vision at 38px.

Of the three recolouring mechanics, two work and one does not.

`currentColor` on inline SVG works and gives exactly one colour per element, since it resolves to that element's `color` (SVG 2 painting; CSS Color 4 describes it as "not an absolute color" because "the value … depends on the value of the color property", [css-color-4](https://www.w3.org/TR/css-color-4/)). Two-tone art needs CSS custom properties written into `fill`/`stroke`, which again only works inline.

`mask-image` works and is strictly more capable for a one-colour shape, because the background behind the mask can be any CSS image — a flat token, or a `linear-gradient` that reads as metal. Colour information in the mask file is thrown away by definition.

CSS filters do not work for tiering. `hue-rotate()` "applies a hue rotation … the number of degrees around the color circle the input samples will be adjusted", `saturate()` and `brightness()` are proportional and linear multipliers, and all of them operate in sRGB on rendered pixels ([Filter Effects 1](https://www.w3.org/TR/filter-effects-1/)). You cannot rotate a bronze onto a specified gold; you land near it. A tier system whose colours are tokens cannot be driven by filters.

Arbitrary team colours only reach one slot. The border is Level-gated and "has to mean the same thing on every card, for everybody" (CONTEXT.md), so it must never take a team colour — that is a domain constraint, not a rendering one. The banner is the surface that can. Keeping it a low-opacity CSS gradient means a team colour enters as a gradient stop and never as text or chip colour, so the four stat chips keep their own contrast regardless of what colour a team picks.

## 4. Asset reuse

Yes, and the arithmetic in CONTEXT.md holds. One file per shape plus a CSS colour is genuinely sufficient, on one condition: the colour must be applied from outside the file. Both working mechanics do that — `currentColor` because the file names no colour at all, `mask-image` because the file's colour is discarded. Four files give twelve tiers; a fifth shape gives three more tiers for one file.

The thing that would force twelve files is baking colour in: a raster export, or an `<img>`-referenced SVG, where secure static mode's `external references: no` and the document boundary make the file the only place colour can live. That is the whole reason `<img>` is the wrong element here.

The one wrinkle is that metals rarely read as flat fills. If bronze/silver/gold want a gradient, `mask-image` handles it with no change to the file — `background: linear-gradient(...)` under the mask — whereas `currentColor` would need a `<linearGradient>` with custom-property stops inside each inline copy. That is an argument for masking, not for more files.

## 5. Where they live in Rails 8

The repo runs Rails 8.0.4 with Propshaft 1.3.1 and importmap, no bundler (Gemfile.lock).

**Propshaft** is the fit. "in Propshaft, all assets from the paths configured in `config.assets.paths` are available for serving and will be copied into the `public/assets` directory", fingerprinted, with "the `.manifest.json` file … automatically generated during the asset precompilation process" mapping names to digests. CSS references are rewritten: `background: url("/bg/pattern.svg")` becomes `url("/assets/bg/pattern-2169cbef.svg")` ([Rails 8 asset pipeline guide](https://guides.rubyonrails.org/asset_pipeline.html)). So `mask-image: url("borders/shield.svg")` in `application.css` resolves to a digested URL for free, which is exactly what the far-future caching in `config/environments/production.rb` ("Cache assets for far-future expiry since they are all digest stamped") assumes.

**Active Storage** is the wrong tool. It "facilitates uploading files to a cloud storage service like Amazon S3 … and attaching those files to Active Record objects", and needs three tables plus a `config/storage.yml` service ([Active Storage guide](https://guides.rubyonrails.org/active_storage_overview.html)). These assets ship with the code, never vary per record, and would gain a database round-trip and a redirect per icon.

**Inline in templates** is the one real trade-off. It buys `currentColor`; it costs a cached, digested URL. On a leaderboard with a dozen borders visible the same path is serialised a dozen times into an uncacheable HTML response. For the profile showcase — three glyphs, once — inlining is harmless.

On size: no spec or first-party document defines a PWA asset budget, so the only honest numbers are measured ones. Seventeen hand-written SVGs at 165–210 bytes each is roughly 3KB before compression, against `public/icon-192.png`'s 13,406 bytes for one icon. Nothing here is near a budget. Worth noting that `app/views/pwa/service-worker.js` is entirely commented out — there is no precache today, so every asset depends on HTTP caching of digested URLs, which Propshaft already provides.

## Recommendation

Draw the geometry, borrow the glyphs, and let CSS do the colour.

**Four border shapes and the level badge frame: hand-write them.** They are regular polygons and a rounded shield — five single-`<path>` files under 250 bytes each, an afternoon's work, no licence, no attribution, no watermark, and a fifth shape later is twenty minutes. Any other route buys nothing for geometry this simple.

**Eight banners: no files.** `linear-gradient()` over the existing tokens, eight CSS classes. This is the one place a team colour can enter, and keeping it in CSS keeps it away from the stat chips.

**Twelve accolade glyphs: take them from Lucide or Iconoir.** ISC and MIT respectively, one notice line for the whole set, modification unrestricted and unlabelled. Reject game-icons.net despite its far better vocabulary, and Font Awesome Free despite its breadth: both are CC BY, both require per-creator identification plus a modification indication, and the glyphs will be modified — stripped to a bare path so they can be masked. Trading a permanent per-author credit list for a better matching icon is a bad trade on twelve pieces of art that appear three at a time on a profile. Reject the Noun Project free tier for the same reason; its paid tier removes attribution but costs money for something MIT already gives away.

**Serve all seventeen from `app/assets/images` and paint them with `mask-image`.** This is the only mechanic that gets both a cached digested URL and arbitrary CSS colour, including the gradient a metal tier wants. It also settles §4: colour lives outside the file, so four shapes really are twelve tiers.

**Reject AI generation for this set.** Not on licensing — OpenAI assigns Output outright and Midjourney grants ownership to anyone under $1M revenue, and neither restricts shipping the result. Reject it because it produces raster where the requirement is a recolourable vector; because Gemini output carries a SynthID watermark and Content Credentials that cannot be turned off; and because, per the Copyright Office, prompt-only output has no copyright for a vendor to assign in the first place, so the assignment clauses are quieter than they look.

Total cost: nothing, plus an afternoon, plus one line in a notices file.

## Not established from a primary source

- **Adobe Firefly's commercial-use grant.** The User Guidelines page carries the Content Credentials prohibition but not the commercial-use sentence; the Generative AI Product Specific Terms (effective 23 April 2026) would not serve over HTTP on either its `adobe.com/go/` shortlink or the direct legal URL. Adobe is therefore unassessed on the question that matters.
- **Whether Stability's "Powered by Stability AI" obligation attaches to shipping outputs only.** The clause is written around distributing "the Stability AI Materials or a Derivative Work … or a product or service that uses any portion of them", and "Derivative Work" expressly excludes model output. Shipping only PNGs is arguably outside it. The text does not say.
- **The Australian position on copyright in AI output.** The Copyright Office guidance quoted above is US. No equivalent first-party Australian statement was located, and the app's users are Australian.
- **A rate band for an individual illustrator commissioned for a 25-piece set.** The only first-party pricing found is 99designs' contest packages, which price one brief. Freelance day rates are not published on any primary source.
- **The exact `-webkit-mask-image` prefix requirement per browser version.** Baseline gives Safari 15.4 and Chrome 120 for the unprefixed masking group; which older versions need the prefix, and whether the prefixed form is still required anywhere in the target audience, was not established.
- **Any defined PWA asset size budget.** No spec or first-party document states one. The byte counts above are measurements of this repo, not compliance with a published limit.
- **Whether four shapes are actually distinguishable at 38px in peripheral vision.** No specification addresses legibility, and no amount of reading will settle it. It needs a mock leaderboard on a real phone.
