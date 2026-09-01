# Try Tally

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
A Fixture whose official score has arrived and whose StatSheet fits inside it. A Fixture is unverified either because TRL has not published yet (awaiting result) or because the sheet claims more than TRL recorded (over official). Verification does **not** gate a Team's own Leaderboard or its Players' StatLines — those count every appearance the moment it is entered. It gates the Social league, where one team's unchecked sheet would distort everyone else's standing.
_Avoid_: Approved, confirmed, locked, official (a Fixture is verified; the *score* is official)

**Social league** _(planned — not built)_:
A Leaderboard spanning every Team that plays the same competition: one location, one day of the week. Unlike a Team's own board it ranks strangers against each other, so only **verified** Fixtures may count towards it — a Team cannot lift itself above another by entering stats TRL never recorded. This is the sole reason Fixture carries `stats_verified`. Open question: whether the grouping key is the Team's `spawtz_league_id` (TRL's own notion of a competition) or location plus weekday derived separately — Season names like "Bardon Mondays - 2026 Winter" suggest TRL already models it.
_Avoid_: Global leaderboard, public league, ladder (a ladder is TRL's team standings, not ours)

**GameStat**:
A Player's performance in a single Fixture: whether they played, plus tries and assists as integer columns. Points = (tries × 2) + (assists × 1). Entered post-game by any Member, always through a StatSheet.
_Avoid_: Stat, score, record

**StatSheet**:
Every GameStat for one Fixture, saved as a unit. The only writer of GameStats, which is what makes the official score enforceable: a sheet totalling more tries — or more assists — than TRL published is refused outright and handed back with the Member's own numbers in it.
_Avoid_: Form, entry, submission, bulk update

**Appearance**:
A GameStat with played set — the Player took the field in that Fixture. A GameStat with played false records the opposite: named on the sheet but did not play. Only appearances count towards games played and every average derived from it. Recording a try or an assist implies an appearance.
_Avoid_: Attendance, cap, selection

**StatLine**:
A tally of tries, assists, appearances and seasons over some set of GameStats, plus the per-game and per-season averages that fall out of it. The same object serves a Player's season, their career, or any slice between. Counts every appearance, verified or not; `StatLine.unconfirmed` breaks out the slice TRL has not checked, for the Player to see and for the Social league to subtract.
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
