# Progression and field-based stat entry

The spec for the bundle charted in [#14](https://github.com/LeviBreakwell/touchline/issues/14): a new stat entry screen, two new stat types, a linked event model, XP and accolades, a three-tab navigation, and a rebuilt career page.

Every decision here came from a ticket; each section names the one that owns it. Where a decision reversed something the codebase already believed, the reversal is stated rather than glossed. Nothing in this document has been built.

---

## 1. The data model — #15, #18

`GameStat` is two concepts welded together: an **appearance record** and a **tally**. Only the tally is replaced.

```
Touchdown                        Play                       Appearance
  fixture_id                       fixture_id                 fixture_id     (was GameStat)
  scorer_player_id    (nullable)   player_id                  player_id
  assister_player_id  (nullable)   kind                       unique(fixture, player)
  created_at                       created_at
```

**The row is a try, not a stat.** An assist is a nullable *column on the try it produced*, not a sibling row. `CONTEXT.md`'s own domain expert had already said why — *"every assist is a pass for a try that was actually scored"* — and modelling it that way makes **"assists ≤ tries" impossible to violate by shape** rather than by validation. That deletes the assist-vs-cap check from three places.

**At most one assister per try.** The A→B drag is one line, and the ceiling rule `entered_assists ≤ our_score` is only sound at 0..1 — allow two and a legitimate 5-try game could honestly record 8 assists and be rejected as `over_official`.

**`scorer_player_id` is nullable in exactly one case**: an assist migrated from the old counters, whose try was never recorded and cannot be recovered. A null scorer is therefore its own marker for imported history. It costs one filter — `Fixture#entered_tries` must count only rows with a scorer — and nothing else, because a row with no scorer matches no player's try count.

> Consequence: **"assists ≤ tries" is structural only for rows entered since the change.** For imported history it holds in fact, because the old ceiling enforced it.

**`Appearance` has no `played` column.** The row's existence is the fact; the sideline toggle inserts and deletes it. The old boolean existed to record "named on the sheet but did not play", and the only thing that ever read it was re-rendering a rejected `StatSheet` — which §4 retires.

**Opposition tries are never stored.** A `Touchdown` is always our try; assisting the opposition is a `Play`.

**Ordering is `created_at`.** No sequence number, no match clock. [ADR 0002](adr/0002-aggregate-game-stats-not-individual-stat-records.md) deleted a whole model to be rid of `game_time` and was right to — nobody knows the clock on the drive home.

### Migration — one way

| Old | New |
|---|---|
| `tries: 3` | 3 Touchdowns — scorer set, assister null |
| `assists: 2` | 2 Touchdowns — assister set, **scorer null** |
| `played: true`, 0/0 | Appearance row |
| `played: false` | **nothing** |

The last line is deliberate. Those rows came from `UPDATE game_stats SET played = (tries > 0 OR assists > 0)` — a 2026 migration guessing at 2025 games — so they assert absences nobody observed. Dropping them means the app has no record either way, which is the truth. Anyone who was there can open that fixture and tick the sideline.

---

## 2. The stat set — #16

| Gesture | Stat | Points |
|---|---|---|
| Tap | Try | **+2** |
| Drag A→B | Assist | **+1** |
| Menu | **Bomb catch** | **+1** |
| Menu | **Dropped bomb** | **−1** |
| Menu | **Opposition assist** | **−2** |

`Play.kind ∈ { bomb_catch, dropped_bomb, opposition_assist }`.

**A dropped bomb is the kick-off drop specifically**, not a general-play spill. TRL calls the general version *"spilt milk"* and we deliberately do not record it: a kick-off drop is one moment with one culprit that everyone still agrees on hours later, while open-play spills are frequent, forgettable and arguable. TRL has no name for the kick-off drop, so the app names it — and names it after the **bomb**, TRL's own word for the kick, so the scope lives inside the name.

**Bomb catch exists because the set would otherwise punish catching.** Charging −1 for a drop while paying nothing for a catch makes standing back the rational play. A scoresheet that discourages the brave act is worse than no scoresheet. The pair also yields a **catch rate** for free, since every contested kick-off produces exactly one or the other.

**Opposition assist is any error they scored directly from**, and *"directly from"* is **a judgement call with no rule behind it** — whoever enters the sheet decides. Accepted knowingly: a Team's own sheet is entered by people who were there. It is the only stat in the app with no objective definition, and §3 explains what follows from that.

**Stats stack.** A dropped bomb the opposition scores from is **−1 and −2**. Both facts are true, and a career page reading "dropped bombs: 5" has to mean five.

> A `Play` can be **positive**, which is why the table is not called `Infringement`.

---

## 3. Verification and the Social league — #17

**The field screen writes immediately.** Each gesture inserts or deletes a row and recomputes `stats_verified`. There is no atomic sheet, no submit, and no work-in-progress to preserve — there are only rows.

**`StatSheet` is retired**, and with it the hard refusal. Going over the official score now flags the fixture **`over_official`** — the path the app already took when TRL corrected a score downward. Two mechanisms become one.

The decisive fact: during a live game TRL has published nothing, so `official_tries` is `nil` and **there is no ceiling to enforce**. The refusal could only ever fire on a game TRL had already scored — never on the field.

**The Social league ranks on Touchdowns only.** Plays are Team-local.

| Stat | Lifts you by | Ceiling | Policeable? |
|---|---|---|---|
| Try +2 | over-reporting | `our_score` | **yes** |
| Assist +1 | over-reporting | structural (§1) | **yes** |
| Bomb catch +1 | over-reporting | `our_score + 2`, soft | barely |
| Dropped bomb −1 | **under**-reporting | — | **no** |
| Opposition assist −2 | **under**-reporting | — | **no** |

There *is* a ceiling on opposition assists — one per opposition try, and `opponent_score` is published — and it is **worthless**. A ceiling bounds over-reporting, and nobody games a leaderboard by adding penalties to themselves. The real exposure runs the other way: a team simply stops recording its drops. No ceiling detects an omission; that needs a floor, and there isn't one.

**MVP** is the most points in a Fixture, **Plays included**, and is **Team-local**. The Social league has no MVP concept — it cannot, since it does not count Plays.

### What this deletes

`StatSheet` · `StatSheet#fits_official_result?` · the two-pass write · `GameStat#within_official_result` · the controller's re-render-with-your-numbers path · `game_stats#bulk`.

`stats_verified` keeps its exact meaning and all three `stats_status` states, now computed from Touchdowns alone.

---

## 4. The entry screen — #19

**A live ladder of player cards. Not a pitch.** A pitch spends most of a 390px screen on turf; the same space as full-width cards buys a **live match ladder**, so entering a stat and watching the standing move are the same act.

```
[rank] [avatar + border]  Name            [T][A][C][E]   [PTS]
                          Title
```

| | |
|---|---|
| **Tap** a card | a try |
| **Drag** card → card | an assist for the source, a try for the target |
| **Long-hold, 400ms** | the Play menu; slide onto an item and release to pick |
| **Sideline** | who played / who didn't — everyone defaults to played |

**Confirmed by hand, not chosen on paper:** 400ms, superseding the `~3s` fixed at charting.

- **Reordering is automatic and animated over 340ms.** The card that caused the change pulses, so movement has a visible cause. Without the animation the row under your thumb silently becomes somebody else's.
- **A live line follows the finger while dragging** — dashed grey over nothing, solid blue over a target — with a chip naming the outcome: `Bec → Jed · assist +1 · try +2`.
- **Completed assists** draw as arcs down a 32px left gutter, thickening the more often a pair connect.
- **Only the icon receives a press.** A card is a column of icon and name, so its box is as wide as the widest child.
- **Claimed is normal; roster-only is dashed, dimmed, no cosmetics**, reading *"Roster only · no account"*.

**Colour means one thing each:** green = try / positive points · blue = assist, pass, drag · red = negative · orange = positive play · neutral = touch feedback not yet committed.

**Columns** are `T A C E PTS`, with `G` added at season scope. Each header letter carries its column's colour, so the header teaches the palette. `E` collapses both negatives, which stack, so it can exceed the count of distinct incidents.

**One component, scope-dependent column set** — the same card serves the match ladder, the Team leaderboard and the career page.

Prototype: <https://claude.ai/code/artifact/af327457-b9b0-4ecc-9d62-eb87b6115944>

---

## 5. Progression — #20, #21, #22

### XP measures participation

| | XP |
|---|---|
| Appearance | **10** |
| Any stat recorded, **sign ignored** | **+1** |
| MVP | **4** |
| Accolade | **2 / 6 / 20** by tier |

A dropped bomb earns the same XP as a try and still costs 2 points. **Points measure performance; XP measures participation.**

**Curve: `cost(n) = 10 + 2(n−1)`, cumulative `L(L + 9)`.**

| Level | 1 | 4 | 10 | 20 | 30 | 40 |
|---|---|---|---|---|---|---|
| **Games played** | 1 | 4 | 15 | 46 | 94 | 157 |

**Always in games, never seasons.** A season's length depends on how many teams are in the competition — about 5 games to about 26 — so a threshold quoted in seasons means something different in every league.

**No cap, no soft cap, no diminishing returns.** Four games of merely turning up is worth twice anyone's best possible single game; eleven games is worth 5.5×. There is nothing to cap and no rule waiting to fire on somebody's best night. A taper was considered and rejected: it buys a slightly better curve with a rule the flat rate does not need.

Play settles at **~69% of lifetime XP**.

### Accolades — there are no challenges

Two shapes of one thing.

| | |
|---|---|
| **Tiered** | a total crossing a rung — monotonic, once per rung, never lost |
| **Repeatable** | an event that recurs — pays XP each time, carries a count (*Grand Final ×3*) |

The threshold-vs-condition split leaked immediately: *"score in five straight games"* is a condition that can be broken, belonging cleanly to neither.

**Awarded as rows, never computed.**

```
accolade_awards
  user_id
  key          "tries_25"
  awarded_at
```

Three forces point the same way: repeatables need somewhere to keep occurrences; a corrected sheet must not silently take back an accolade somebody was shown yesterday; and **claiming a roster entry writes everything the banked history earned, at once** — the payoff the claim flow exists for.

**Ladders are scaled per stat.** A shared ladder cannot work: the same rungs are wildly different achievements.

| Stat | Rungs | Tiers |
|---|---|---|
| Appearances | 5 · 15 · 25 · 60 · 120 | c c u u r |
| Tries | 5 · 15 · 25 · 50 · 100 | c c u u r |
| Assists | 3 · 10 · 15 · 25 · 50 | c c u u r |
| Bomb catches | 10 · 15 · 30 · 75 · 150 | c c u u r |
| Dropped bombs | 2 · 3 · 10 · 15 · 30 | c c u u r |
| Opposition assists | 1 · 2 · 3 · 10 · 15 | c c u u r |

**Repeatables:** MVP · Hat-trick · Full house · Undefeated season · Win a grand final · Finish top of the ladder.

**"Full house" is scoped to one fixture's appearances** — not the roster — which deletes the changing-roster problem rather than solving it.

**Negatives are genuine accolades**, on the same footing as anything else. That is only safe because **titles are player-chosen**: "Butterfingers" is funny worn on purpose and unpleasant pinned on somebody.

**XP tiers are fixed, never bespoke**, so adding accolade #40 stays data entry rather than an economy change.

### Cosmetics

| Slot | Source | Chosen? |
|---|---|---|
| **Icon border** | Level | **No — automatic, highest reached** |
| **Title** | Accolade | Yes |
| **Card banner** | Rare accolade | Yes |

**The border climbs by shape as well as colour**, because colour alone runs out after about four distinguishable steps:

```
Circle    bronze silver gold    levels  1   3   6
Shield    bronze silver gold           10  14  19
Octagon   bronze silver gold           24  30  36
Star      bronze silver gold           43  50  58
```

**Twelve tiers from four pieces of art**, spanning 1 game to 324. A fifth shape adds three tiers for one asset.

A border is a **rank**: it must mean the same thing on every card, for everybody. Border is what you *are*; title is what you choose to *say* about it.

**There is no tagline.** The card has one line under the name and the title earned it. It would also have been the app's only unmoderated free-text field, eventually sitting beside strangers' names in the Social league.

**Accolades never appear on a ladder card.** They surface as a title, and as a **showcase of three** on the profile — the only place accolade art appears at all.

**Claiming lands in one consolidated screen.** A three-season veteran arrives at level 13 with 16 accolades and a whole border era at once. One screen: level, what the history earned, what is unlocked, pick a title. It doubles as the onboarding for the entire system, taught once at the only moment anyone is interested.

Prototype: <https://claude.ai/code/artifact/ac5e6784-756e-4643-85d9-09096da82b3a>

---

## 6. Art — #23

**Draw the geometry, borrow the glyphs, let CSS do the colour.**

| | | |
|---|---|---|
| 4 border shapes + 1 level badge | **hand-written SVG** | single `<path>`, 165–210 bytes |
| 8 card banners | **no files** | `linear-gradient()` over existing tokens |
| 12 accolade glyphs | **Lucide (ISC) or Iconoir (MIT)** | one notice line for the set |

**25 assets become 17 files, and 5 things anyone has to draw.**

**Served from `app/assets/images`, painted with `mask-image`.** An SVG referenced with `<img src>` is a separate document in secure static mode and **cannot be recoloured** — which is exactly why colour must live outside the file, and therefore why four shapes really are twelve tiers. `mask-image` beats `currentColor` because a mask source's colour is discarded by definition, so the background can be the gradient a metal tier wants.

**AI generation rejected — not on licensing**, which is fine. Rejected because it produces raster where a recolourable vector is required, Gemini's SynthID cannot be disabled, and prompt-only output has no copyright for a vendor to assign.

Evidence, 24 primary sources: [`research/art-generation.md`](research/art-generation.md).

---

## 7. Navigation — #25

**Three tabs are three scopes of one component, not three screens.**

| Tab | Is | Scope control |
|---|---|---|
| **Team** | the leaderboard | dropdown — All time + each season |
| **Season** | that season's matches | dropdown — each season |
| **Profile** | level, showcase, slots, career | — |

**A dropdown, not chips** — two seasons a year means seven chips after three years, wrapping across a phone.

**The match ladder takes over the screen.** No tabs while entering: the ladder wants every pixel, and drags happen between cards in a vertical list, so a 56px bottom nav sits exactly where a drag toward the last card ends.

**Team is global context**, switched from the Team tab header — which **offers connecting another team when you only have one**, so the control is never dead.

**Admin is one settings screen behind a gear**, admins only: roster, invite link, join requests, Spawtz, sync. A fourth tab would break the map's fixed three-tab constraint.

| Now | Becomes |
|---|---|
| `teams#show` | Team tab; chips → dropdown |
| `players#index` | absorbed into Team settings as the roster |
| `players#show` | survives — the player career page |
| `memberships#index` · `spawtz_setup` · `regenerate_invite` · `sync` | Team settings |
| `seasons#show` | Season tab |
| `fixtures#show` | the match ladder — full-screen takeover |
| `game_stats#bulk` | **gone** |
| `/profile` | Profile tab + badge, showcase, slot tiles |

**The leaderboard does not replace the roster** — only Players with an appearance are ranked, so an unplayed signing is invisible on the Team tab.

---

## 8. The career page — #24

**The indicator compares you against yourself**, because nothing else has data: your team is n=13 (7.7 percentile points per rank), and *competition* and *app-wide* have no data source at all.

**An arrow and a colour, three states, no new numbers** — up, level, down against your career, with a dead band.

**Polarity-aware:**

| Up is good | Up is bad |
|---|---|
| tries · assists · bomb catches · appearances · catch rate · MVP · points | dropped bombs · opposition assists |

**A distinct muted marker** below 3 games either side — an absent arrow reads as "level", not "we can't tell".

```
identity · level badge · title · border
showcase — 3 accolades
[Border]  [Title]  [Banner]
── THIS SEASON ──   per game, every arrow lives here · catch rate 88% ↑
── CAREER ──        totals · games · MVP ×6
── BY SEASON ──     a row per season
```

**This season leads** — it is the comparison the indicator makes, so it should not be below the fold. **Catch rate finally has a home.**

The page shows the **Team-inclusive** point total and **must label it**, since #17 left every player with two.

---

## 9. Build order

### Wave 0 — ship now, independent of everything

**Fix the finals cell shift in `SpawtzScraper`.** This is a live bug corrupting production data today: a finals row has six cells to an ordinary row's five, the parser reads one place left, and `Time.parse` accepts the shifted string rather than rejecting it. Every finals match ever played is stored **at midnight, with the court name as the opponent, and no score** — `awaiting_result` forever, and `prune_withdrawn` will not clean it up.

Fixing it *is* "win a grand final". Add a cell-count assertion while there: a row is 5 cells or 6, and anything else means Spawtz changed.

### Wave 1 — the foundation, sequential and unavoidable

1. **Schema**: `touchdowns`, `plays`, `appearances`. `Touchdown.scorer_player_id` nullable.
2. **Migration** per §1. One way.
3. **Rewrite the readers**: `StatLine`, `Leaderboard`, `Fixture#entered_tries` (**must filter `scorer_player_id IS NOT NULL`**), `Player`'s delegators.
4. **Retire `StatSheet`** and the hard refusal; `over_official` becomes the only mechanism.

Nothing else can start until the reads come off the new tables.

### Wave 2 — parallel

- **Navigation** (§7) — touches no stat code.
- **Ladder scrape + division capture** (§9 notes) — independent of the app's own model.
- **Art** (§6) — 5 SVGs and a notices line.

### Wave 3 — the entry screen

The ladder (§4). Depends on wave 1 for the model and wave 2 for where it sits.

### Wave 4 — progression

XP and levels first (§5), then accolades on top of them, then cosmetics on top of accolades. Each needs the one before it.

### Wave 5 — the career page

§8. Wants levels, accolades and cosmetics to exist before it can show them.

---

## 10. ADRs owed

1. **Supersede [ADR 0002](adr/0002-aggregate-game-stats-not-individual-stat-records.md)** — record that its two objections still stand and were *answered* rather than defied: `game_time` stays gone, and the GROUP BY stays confined to `StatLine`/`Leaderboard`, which already aggregate per-appearance in Ruby.
2. **Retiring `StatSheet`** — a deliberate loosening of an invariant the codebase defended in three places.
3. **The asset decision** — `mask-image`, hand-written geometry, borrowed glyphs. Evidence in `research/art-generation.md`.

---

## 11. Bugs found along the way

Not part of this bundle; found while reading, and real.

- 🔴 **The finals cell shift** — §9 wave 0. Corrupting data now.
- 🟡 **`official_tries = our_score` is false in Mixed.** TRL scores a female try as 2 points, so a 4-try Mixed team publishes 6 and a sheet claiming 6 tries verifies — the ceiling **fails open**. Deferred by decision. #27 removed the reason it looked unsolvable: Spawtz names the division on a page the app already reads. It still cannot know a scorer's gender.
- 🟡 **`Season` has no date column.** `teams_controller.rb:35` orders by `created_at` — when the app first *synced* a season, not when it was played. The new dropdowns make it wrong the moment Spawtz backfills. Needs `MAX(fixtures.date)`.
- 🟡 **The scraper discards `DivisionId`**, passing `0`. One league holds both a Mixed and a Men's division.
- ⚪ **`app/views/pwa/service-worker.js` is entirely commented out** — no precache; assets rely wholly on HTTP caching.

---

## 12. Deliberately left open

- **A non-gesture entry path.** Retiring `StatSheet` leaves tap-and-drag as the only writer: no keyboard route, no screen-reader route, no way to type up a backlog from a laptop. Every prototype variant required a pointer. **This needs a decision.**
- **How Mixed verification should work**, given the app can know the division but not a scorer's gender.
- **The Social league's grouping key** — almost certainly `DivisionId`, unconfirmed.
- **Whether four border shapes are distinguishable at 38px in peripheral vision.** No specification addresses legibility; the #22 prototype renders all twelve tiers at real size, so it is a five-minute check on a phone.
- **Seasonal reset / prestige** — whether XP and level are career-permanent.
- **What a shared profile shows** to someone on a different team.
- **Level-up announcement** — where, and whether anything is pushed.
