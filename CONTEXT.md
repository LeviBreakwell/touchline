# Touchline

A free, public Rails app for TRL (Touch Rugby League) teams to track player tries and assists across a season, with fixtures and results synced automatically from TRL Australia's Spawtz platform.

## Language

**Team**:
A TRL team registered in the app by a User who becomes its Admin. Linked to Spawtz via venue, league, and season IDs stored directly on the Team.
_Avoid_: Club, group, account

**Player**:
A named roster member of a Team whose tries and assists are tracked per Season. Optionally linked to a User account.
_Avoid_: Athlete, member (member means something specific here — see TeamMembership)

**User**:
A person with an account in the app. Joins Teams via TeamMemberships. Not automatically a Player.
_Avoid_: Account, member (use TeamMembership role instead)

**TeamMembership**:
The link between a User and a Team. Has a role (admin or member) and a status (pending or accepted). Controls who can enter stats.
_Avoid_: Subscription, access, role (role is a field on TeamMembership, not a synonym for it)

**Admin**:
A TeamMembership role. The first User to create a Team is automatically its Admin. Can accept or deny join requests and manage the Player roster.
_Avoid_: Owner, captain, manager

**Member**:
A TeamMembership role with accepted status. Can enter GameStats for any Player on the Team.
_Avoid_: User, player, contributor

**Season**:
A named competition period (e.g. "Summer 2025") synced from Spawtz. Fixtures belong to a Season. A Leaderboard is scoped to one Season or to all time.
_Avoid_: Competition, round, year

**Fixture**:
A scheduled game in a Season against an opponent. Date, opponent name, and result are sourced from Spawtz — never entered manually. GameStats are recorded against a Fixture.
_Avoid_: Game, match, event

**Official score**:
The scoreline Spawtz publishes for a Fixture. TRL scores a touchdown as one point, so `our_score` is exactly how many tries the team is credited with — and therefore the ceiling on what a StatSheet may claim, for assists as well as tries. Nil until TRL publishes, which is what allows early entry.
_Avoid_: Result (result is win/loss/draw), points, final score

**Verified**:
A Fixture whose official score has arrived and whose Touchdowns fit inside it. Plays never affect it (#17) — verification exists to stop a Team lifting itself above another, a ceiling bounds only over-reporting, and nobody inflates their own penalties. The real exposure on a Play is a Team quietly *not* recording its drops, which no ceiling can detect.

⚠️ **Known broken, deferred:** TRL scores a **female try as 2 points in Mixed**, so `our_score` is not the try count and the ceiling fails open there — a 4-try Mixed team publishes 6 and a sheet claiming 6 tries verifies. Parked by owner decision; recorded in the map's fog. Every ceiling in the app inherits it. A Fixture is unverified either because TRL has not published yet (awaiting result) or because the sheet claims more than TRL recorded (over official). Verification does **not** gate a Team's own Leaderboard or its Players' StatLines — those count every appearance the moment it is entered. It gates the Social league, where one team's unchecked sheet would distort everyone else's standing.
_Avoid_: Approved, confirmed, locked, official (a Fixture is verified; the *score* is official)

**Social league** _(planned — not built)_:
A Leaderboard spanning every Team that plays the same competition: one location, one day of the week. Unlike a Team's own board it ranks strangers against each other, so only **verified** Fixtures may count towards it — a Team cannot lift itself above another by entering stats TRL never recorded. It ranks on **Touchdowns only** (#17): Plays are Team-local, because a Team that quietly omits its drops climbs, and no ceiling can detect an omission. A Player therefore has two point totals, and any surface showing one must say which. This is the sole reason Fixture carries `stats_verified`. Open question: whether the grouping key is the Team's `spawtz_league_id` (TRL's own notion of a competition) or location plus weekday derived separately — Season names like "Bardon Mondays - 2026 Winter" suggest TRL already models it.
_Avoid_: Global leaderboard, public league, ladder (a ladder is TRL's team standings, not ours)

**GameStat** _(being replaced — see Touchdown, Play, Appearance)_:
A Player's performance in a single Fixture: whether they played, plus tries and assists as integer columns. Points = (tries × 2) + (assists × 1) — see **Points**, which since #16 also counts Plays and can be negative. Entered post-game by any Member, always through a StatSheet.

Two concepts welded together: an **Appearance** record and a tally. Decided (#15) that the tally becomes counted rows — a **Touchdown** per try, a **Play** per one-player stat — and what is left of the row keeps only `played` and is renamed **Appearance**. Nothing is cached: tries and assists are counted, never stored. Until that lands, GameStat is still what the app writes.
_Avoid_: Stat, score, record

**Touchdown** _(decided — not built)_:
One try, as a row: the Fixture, the Player who scored it, and optionally the Player who assisted it. A try with no assist has a null assister; a try can carry at most **one**, because every assist is a pass for a try that was actually scored. A Touchdown is always the Team's own try — the opposition's are never stored, so assisting them is a Play instead. Ordered by when it was entered; the app records no match clock, because stats are recalled after the game, not timed during it.

The **scorer** is null in exactly one case (#18): an assist migrated from the old counters, where the try it belonged to was never recorded and cannot be recovered. A null scorer is therefore its own marker for imported history. It costs one filter — `entered_tries` must count only rows with a scorer — and nothing else, because a row with no scorer matches no Player's try count. It does mean **"assists ≤ tries" is guaranteed by shape only for rows entered since**; for imported history it is true in fact, because the old ceiling enforced it.
_Avoid_: Score, scoring event, event (a Fixture is the event), try record

**Play** _(decided — not built)_:
One stat by one Player in one Fixture that is not a try: the Fixture, the Player, and a kind. A row per occurrence, so undoing one is deleting it. Unlike a Touchdown, a Play is never measured against the official score — TRL publishes nothing to check one against. The starter kinds (#16) are **Bomb catch**, **Dropped bomb** and **Opposition assist**. A Play may be worth more than nothing or less than nothing, which is why it is not called an infringement.
_Avoid_: Stat, event, incident, infringement (a Play may be good or bad)

**Bomb**:
The kick-off. TRL restarts with a "must take" bomb kick — at the start of each half, and again after every try, so a team receives four or five in a game. Catching one is the most frequent thing worth recording in a game of TRL; scoring is not.
_Avoid_: Kick-off catch, high ball, restart

**Bomb catch** _(decided — not built)_:
A Play: the Player caught the kick-off cleanly. Worth **+1**. It exists because without it the stat set punishes going up for the ball and rewards standing back — a scoresheet that discourages the brave act is worse than no scoresheet. Together with Dropped bomb it gives a Player a catch rate, since every kick-off a Player contests produces exactly one or the other.
_Avoid_: Take, mark, reception

**Dropped bomb** _(decided — not built)_:
A Play: the Player dropped the kick-off, handing the opposition the ball. Worth **−1**. Deliberately narrow — this is *not* a general-play spill, which TRL calls spilt milk and which nobody recalls accurately hours later. A dropped bomb is one moment, one culprit, seen by everyone and still agreed on by the time the sheet is entered. The name carries the scope so a general spill cannot be filed under it.
_Avoid_: Drop ball, knock-on, error, spilt milk (spilt milk is any spill in open play — a different thing we do not record)

**Opposition assist** _(decided — not built)_:
A Play: the Player made an error the opposition scored directly from. Worth **−2**. Any error qualifies, not only an intercepted pass. **"Directly from" is a judgement call** — there is no set-of-six rule and no next-play rule; whoever enters the sheet decides. This is the one stat in the app with no objective definition, accepted knowingly (#16) on the grounds that a Team's own sheet is entered among people who were there. It follows that it can never be verified — see Verified.

Stats stack: a Dropped bomb the opposition scores from is a Dropped bomb **and** an Opposition assist, −3 in total. Both are true, and a career page reading "dropped bombs: 5" has to mean five.
_Avoid_: Own goal (TRL has no such concept — a touchdown is scored by the attacking team, full stop), turnover, error

**Points**:
A Player's tally, and what a Leaderboard ranks on. Try **+2**, assist **+1**, bomb catch **+1**, dropped bomb **−1**, opposition assist **−2**. Since #15 this spans two tables — Touchdowns and Plays — so it is no longer one row's arithmetic, and a Player's points can go down.
_Avoid_: Score (the official score is TRL's), result, rating

**StatSheet** _(retired — see #17)_:
Every GameStat for one Fixture, saved as a unit. The only writer of GameStats, which is what makes the official score enforceable: a sheet totalling more tries — or more assists — than TRL published is refused outright and handed back with the Member's own numbers in it.

Retired because its whole justification was that enforcement, and the enforcement is gone. During a live game TRL has published nothing, so there is no ceiling to check — the refusal could only ever fire on a game TRL had already scored. Going over now flags the Fixture **over official**, which is the path the app already took when TRL corrected a score downward. One mechanism instead of two. The field screen writes each Touchdown and Play as it is entered; there is no sheet, no submit, and no half-entered game to preserve.
_Avoid_: Form, entry, submission, bulk update

**MVP** _(decided — not built)_:
The Player with the most points in a Fixture, counting Plays as well as Touchdowns. A Team's own award, decided by the people who were at the game. The Social league has no MVP — it cannot, since it does not count Plays. Career MVP counts stand on a Player's profile; they are simply not a cross-team ranking input.
_Avoid_: Player of the match, best on ground, man of the match

**Appearance**:
The Player took the field in that Fixture. Only appearances count towards games played and every average derived from it. Recording a try, an assist or a Play implies an appearance.

Decided (#15): it becomes its own record, which is the whole of what survives GameStat once the tally moves to counted rows. It cannot be derived from Touchdowns and Plays — a Player who took the field and did nothing leaves no other row anywhere, and that game still counts.

**The row's existence is the fact** (#18) — there is no `played` column. The sideline toggle inserts and deletes it. The old boolean existed to record "named on the sheet but did not play", and the only thing that ever read it was re-rendering a rejected StatSheet; #17 retired the sheet. Dropping it also stops the app asserting absences nobody observed: the `played` backfill set `played = (tries > 0 OR assists > 0)`, which marked every scoreless appearance in old data as an absence. Those rows are not migrated. The app has no record either way, which is the truth, and anyone who was there can tick the sideline on that fixture and fix it.
_Avoid_: Attendance, cap, selection

**StatLine**:
A tally of tries, assists, appearances and seasons over some set of games, plus the per-game and per-season averages that fall out of it. Counted from GameStats today; from Touchdowns, Plays and Appearances once #15 lands, which is also where points stops being one table's arithmetic — a try is +2 and an assist +1 on a Touchdown, while a Play may be worth less than nothing. The same object serves a Player's season, their career, or any slice between. Counts every appearance, verified or not; `StatLine.unconfirmed` breaks out the slice TRL has not checked, for the Player to see and for the Social league to subtract.
_Avoid_: Summary, totals, record

**Leaderboard**:
A ranking of Players ordered by points (then tries, then assists as tiebreakers), scoped either to one of a Team's Seasons or to all time across every Season. Only Players with at least one appearance are ranked, and an appearance counts as soon as it is entered — see Verified.
_Avoid_: Table, standings, rankings

**Spawtz**:
The third-party platform TRL Australia uses to publish fixtures and results. The app scrapes Spawtz to sync Fixtures and game results — there is no official API.
_Avoid_: TRL website, external API, feed

## Relationships

- A **Team** has many **Players**, many **TeamMemberships**, and many **Seasons**
- A **Team** stores Spawtz venue/league/season IDs directly (no separate model)
- A **Season** has many **Fixtures**
- A **Fixture** has many **GameStats**
- A **GameStat** belongs to exactly one **Player** and one **Fixture**
- A **StatSheet** covers one **Fixture** and writes all of its **GameStats** together

Once #15 lands, GameStat is replaced by three:

- A **Fixture** has many **Touchdowns**, many **Plays**, and many **Appearances**
- A **Touchdown** belongs to one **Fixture** and one scoring **Player**, and optionally to one assisting **Player**
- A **Play** belongs to one **Fixture** and one **Player**, and carries a kind
- An **Appearance** belongs to one **Fixture** and one **Player**, at most one pair of each
- A Player's tries and assists are **counted from Touchdowns**, never stored
- A **Fixture** carries a stored `stats_verified` flag, recomputed whenever a GameStat is written or Spawtz lands a score
- A **User** has many **TeamMemberships** (and through them, many Teams)
- A **Player** is optionally linked to one **User**

## Example dialogue

> **Dev:** "Can a Member update the opponent score after a game?"
> **Domain expert:** "No — the opponent score and result come from Spawtz only. Members enter GameStats: which Players played, how many tries, how many assists."

> **Dev:** "A player was on the sheet but never came on. Do they get a game?"
> **Domain expert:** "No. Untick them and it's not an appearance — it shouldn't drag their per-game averages down."

> **Dev:** "We played last night, TRL hasn't posted the result. Can I enter the stats?"
> **Domain expert:** "Enter them, and they're on the board straight away. That's the whole point of doing it on the drive home — you want to see it land. TRL just hasn't checked them yet."

> **Dev:** "So why track whether TRL confirmed it at all?"
> **Domain expert:** "For the social league — everyone at your venue on your night, ranked together. Against your own mates your own numbers are fine; against strangers they have to be checked, or someone types in ten tries and tops the table."

> **Dev:** "TRL has us at 5. Someone wants to record a sixth try."
> **Domain expert:** "Then one of the other five is wrong. You can't score a try TRL has no record of — fix the sheet, don't add to it."

> **Dev:** "Can there be more assists than tries?"
> **Domain expert:** "No. Every assist is a pass for a try that was actually scored. Some tries have no assist, so it's a ceiling, not a match."

> **Dev:** "Two players combined for one — how do we record who passed it?"
> **Domain expert:** "Drag one onto the other. One try for the finisher, one assist for the passer, and it remembers it was *that* pass for *that* try — not two numbers that happen to add up."

> **Dev:** "Can a try have two assists? The pass, and the pass before it."
> **Domain expert:** "One. The last pass is the assist. Nobody remembers the second-last one on the drive home anyway."

> **Dev:** "Our bloke threw one straight to their winger and they scored. Whose try is that?"
> **Domain expert:** "Nobody's. We don't record the other team's tries — only ours. That's a Play against him, and it costs him."

> **Dev:** "A player took the field and did nothing at all. What's in the database?"
> **Domain expert:** "An appearance and nothing else. That's still a game he played, and it should pull his averages down like any other."

> **Dev:** "Why record catching the kick-off? Nothing happened."
> **Domain expert:** "Because if dropping it costs you and catching it earns you nothing, nobody goes up for it. You'd have blokes letting it bounce to protect their numbers. That's the opposite of what you want."

> **Dev:** "Someone spilled it in open play and we lost the ball. Is that a dropped bomb?"
> **Domain expert:** "No. A dropped bomb is the kick-off. Open play spills happen all game and nobody agrees how many by the time you're in the car — record those and you've got a made-up number."

> **Dev:** "Their try came two plays after our mistake. Opposition assist or not?"
> **Domain expert:** "Your call. You were there. It's the one thing on the sheet we don't have a rule for — which is exactly why it can't count outside your own team."

> **Dev:** "TRL corrected a result down a week later and now our sheet is over. What happens?"
> **Domain expert:** "Your own board doesn't move — those are still your games. The fixture gets flagged as over TRL so someone goes back and fixes it, and until they do it can't count for the social league."

> **Dev:** "When a User joins, do they appear on the Leaderboard?"
> **Domain expert:** "Not automatically. The Admin manages the Player roster separately. A User can be linked to a Player, but joining the Team just gives them edit access."

## Flagged ambiguities

- "member" was used loosely to mean anyone associated with a team — resolved: **Member** is a specific TeamMembership role (accepted, non-admin). A Player is a roster entry, not a membership concept.
- "score" was used to mean both the game result and a player's points tally — resolved: **result** (from Spawtz) for the game outcome, **points** for a Player's tally, **GameStat** for what Members enter.
- "official" was used for both the Spawtz scoreline and the app's own state — resolved: the **official score** is TRL's number, and a Fixture whose sheet squares with it is **verified**. "Not matching TRL" splits into two cases worth telling apart in the UI: *awaiting result* (entered early, nothing to check against yet) and *over official* (checked and failed).
- "invalid" was used for early entry — resolved: early stats are saved, shown **and counted**; they are simply not **verified** yet. Nothing is discarded, delayed, or held back for being early. Verification is a fact recorded about a Fixture, not a gate on a Team's own numbers — the only thing it will gate is the **Social league**.
- "leaderboard" was ambiguous once a cross-team board was proposed — resolved: **Leaderboard** is a single Team's, and every appearance counts on it immediately; **Social league** is the cross-team board, and only verified Fixtures may count towards it.
- "games played" was ambiguous while every roster Player got a GameStat row on save — resolved: only an **Appearance** (played set) counts. Rows predating the played column were backfilled from whether a try or assist was recorded, so a scoreless appearance in an old fixture reads as absent until someone re-ticks it.
- "event" was reached for repeatedly to name a per-try row — resolved: **event** stays reserved, as Fixture's avoid-list has it. The row for a try is a **Touchdown**; the row for a one-player stat is a **Play**. Neither is called an event, a scoring event, or a stat record.
- "GameStat" quietly meant two things — resolved (#15): an **Appearance** (this Player took the field) and a tally (how many tries and assists). Only the tally is replaceable by counting rows; the appearance is not derivable from anything and survives as its own record.
- "assist" was modelled as a stat in its own right, sitting in a column beside tries — resolved (#15): an assist is not a thing that happens, it is *who passed it*. It becomes a column on the **Touchdown** it produced, which is what makes "assists ≤ tries" impossible to violate rather than merely validated.
- "try" is ambiguous between the everyday word and the record — resolved: the record is a **Touchdown**, TRL's own word for what it scores as one point. **Try** stays the word used on screen and out loud; nothing in the UI says touchdown.
