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
A named competition period (e.g. "Summer 2025") synced from Spawtz. Fixtures belong to a Season. The Leaderboard is always scoped to a Season.
_Avoid_: Competition, round, year

**Fixture**:
A scheduled game in a Season against an opponent. Date, opponent name, and result are sourced from Spawtz — never entered manually. GameStats are recorded against a Fixture.
_Avoid_: Game, match, event

**GameStat**:
A Player's performance in a single Fixture: tries and assists as integer columns. Points = (tries × 2) + (assists × 1). Entered post-game by any Member.
_Avoid_: Stat, score, record

**Leaderboard**:
A ranking of Players within a Team's Season ordered by points (then tries, then assists as tiebreakers).
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
- A **User** has many **TeamMemberships** (and through them, many Teams)
- A **Player** is optionally linked to one **User**

## Example dialogue

> **Dev:** "Can a Member update the opponent score after a game?"
> **Domain expert:** "No — the opponent score and result come from Spawtz only. Members enter GameStats: which Players played, how many tries, how many assists."

> **Dev:** "When a User joins, do they appear on the Leaderboard?"
> **Domain expert:** "Not automatically. The Admin manages the Player roster separately. A User can be linked to a Player, but joining the Team just gives them edit access."

## Flagged ambiguities

- "member" was used loosely to mean anyone associated with a team — resolved: **Member** is a specific TeamMembership role (accepted, non-admin). A Player is a roster entry, not a membership concept.
- "score" was used to mean both the game result and a player's points tally — resolved: **result** (from Spawtz) for the game outcome, **points** for a Player's tally, **GameStat** for what Members enter.
