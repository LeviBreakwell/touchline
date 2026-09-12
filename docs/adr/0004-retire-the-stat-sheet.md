# Retire the StatSheet and its refusal

A `StatSheet` was every `GameStat` for one Fixture, saved as a unit, and it was the only writer. That is what made TRL's published scoreline enforceable: a sheet claiming more tries than TRL recorded was **refused outright** and handed back with the Member's own numbers in it. The sheet is now retired, the refusal with it, and going over the official score **flags the Fixture `over_official`** instead.

This is a deliberate loosening of an invariant the codebase defended in three places — `StatSheet#fits_official_result?`, `GameStat#within_official_result`, and the controller's re-render-with-your-numbers path.

The decisive fact is *when*. During a live game TRL has published nothing, so `official_tries` is nil and **there is no ceiling to enforce**. The refusal could only ever fire on a game TRL had already scored — never on the field, which is where the app is now used. Meanwhile the app already had a second mechanism for exactly this situation: when TRL corrects a score downward a week later, the Fixture goes `over_official` and somebody fixes it. Two mechanisms for one condition, one of which cannot fire when it matters.

The entry screen also stopped being a sheet. Each gesture inserts or deletes one row, so there is no atomic unit to accept or reject, no submit, and no half-entered game to preserve — the only reason the sheet re-rendered a Member's numbers back at them was that a refusal could lose them.

## Considered options

**Keep the refusal on the sheet-shaped path only** — rejected: there is no sheet-shaped path left, and adding one back to hold a rule that cannot fire on the field is the wrong way round.

**Refuse a single row that would push the fixture past TRL** — rejected: it fires half-way through entering a game (move a try from one player to another and the receiving row is written first), which is the two-pass write the old sheet needed in order to work around itself.

## Consequences

A Fixture can now hold more tries than TRL published. It is visibly flagged, it stays out of the Social league until somebody fixes it, and the Team's own board counts it either way — which was already true of every fixture TRL corrected downward.

Verification is now computed from Touchdowns alone. `stats_verified` keeps its exact meaning and all three `stats_status` states. Plays never affect it: a ceiling bounds over-reporting, and nobody games a leaderboard by adding penalties to themselves.

The only writer is now the gesture-driven ladder. There is no keyboard route and no screen-reader route to entering a stat — see "Deliberately left open" in the progression spec.
